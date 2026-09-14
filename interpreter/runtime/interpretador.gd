extends Node
class_name Interpreter

signal execution_started
signal execution_finished
signal execution_error(text)
signal execution_diagnostics(diagnostics)
signal output_changed(text)
signal sleep_requested(seconds)
 
@export var debug = false
var executor: Executor = Executor.new()
var executor_flag := false
var erros: Array = []
var saidas: Array[String] = []
var _tem_erro_fatal := false
var _tempo_inicio: int = 0
var _execution_active := false
var source_name := ""
var output_prefix := ""
var emit_debug_to_eventbus := true
var scheduler_managed := false
var max_output_lines := 200
var max_prints_per_frame := 20
var _prints_this_frame := 0
var _suppressed_prints_this_frame := 0
var _batch_output_updates := false
var _output_changed_this_frame := false
var _sleep_requested := false
 
# ─── Registro de erros ────────────────────────────────────────────────────────
 
## Erros de parse/lexer: acumula e continua (para reportar múltiplos erros)
func registrar_erro(msg: String, linha: int = -1, coluna: int = -1,
		tipo: ErroInterpretador.TipoErro = ErroInterpretador.TipoErro.RUNTIME,
		codigo: String = "", comprimento: int = 0) -> void:
	var e = ErroInterpretador.new(msg, linha, coluna, tipo, codigo, comprimento)
	erros.append(e)
	print("[Interpreter] ", e.formatar())
 
## Erros de runtime: para imediatamente e emite debug
func erro_runtime(msg: String, linha: int = -1, coluna: int = -1) -> void:
	registrar_erro(msg, linha, coluna, ErroInterpretador.TipoErro.RUNTIME)
	_tem_erro_fatal = true
	_finish_execution()
	_emitir_erros()
 
## Para a execução imediatamente (alias de erro_runtime, aceita tipo customizado)
func erro_fatal(msg: String, linha: int = -1, coluna: int = -1,
		tipo: ErroInterpretador.TipoErro = ErroInterpretador.TipoErro.RUNTIME) -> void:
	registrar_erro(msg, linha, coluna, tipo)
	_tem_erro_fatal = true
	_finish_execution()
	_emitir_erros()
 
func tem_erros() -> bool:
	return erros.size() > 0

func set_source_name(display_name: String) -> void:
	source_name = display_name.strip_edges()
	output_prefix = source_name
 
func _formatar_erros() -> String:
	var linhas := []
	for e in erros:
		var texto: String = e.formatar()
		linhas.append(texto)
	return _format_output_text("\n".join(linhas))

func get_diagnostics() -> Array:
	var diagnostics := []
	for error in erros:
		if error != null and error.has_method("to_dictionary"):
			diagnostics.append(error.to_dictionary())
	return diagnostics

func emitir_saida(texto: String) -> void:
	if max_prints_per_frame > 0 and _prints_this_frame >= max_prints_per_frame:
		_suppressed_prints_this_frame += 1
		return
	_prints_this_frame += 1
	_append_output_line(texto)
	if _batch_output_updates:
		_output_changed_this_frame = true
	else:
		_emit_debug_text(_format_output_text("\n".join(saidas)))

func begin_scheduler_frame() -> void:
	_prints_this_frame = 0
	_suppressed_prints_this_frame = 0
	_output_changed_this_frame = false
	_batch_output_updates = true

func end_scheduler_frame() -> void:
	if tem_erros():
		_batch_output_updates = false
		_output_changed_this_frame = false
		return
	if _suppressed_prints_this_frame > 0:
		_append_output_line("saida limitada: %d prints omitidos neste frame" % _suppressed_prints_this_frame)
		_output_changed_this_frame = true
	_batch_output_updates = false
	if _output_changed_this_frame:
		_emit_debug_text(_format_output_text("\n".join(saidas)))

func _append_output_line(texto: String) -> void:
	saidas.append(texto)
	if max_output_lines <= 0:
		return
	while saidas.size() > max_output_lines:
		saidas.pop_front()

func _format_output_text(texto: String) -> String:
	if output_prefix.is_empty() or texto.is_empty():
		return texto

	var linhas := []
	for linha in texto.split("\n", false):
		linhas.append("[%s] %s" % [output_prefix, linha])
	return "\n".join(linhas)

func _emit_debug_text(texto: String) -> void:
	emit_signal("output_changed", texto)
	if emit_debug_to_eventbus:
		EventBus.emit_signal("send_debug", texto)
 
# ─── Pipeline principal ───────────────────────────────────────────────────────
 
func run(codigo: String, context) -> void:
	_finish_execution()
	erros.clear()
	saidas.clear()
	_emit_debug_text("")
	_tem_erro_fatal = false
	_sleep_requested = false
	executor_flag = false
	_execution_active = false
	_tempo_inicio = Time.get_ticks_msec()
 
	# 1. Tokenizar
	var lexer = Lexer.new(codigo)
	lexer.interpreter = self
	var tokens = lexer.tokenize()
 
	if tem_erros():
		_emitir_erros()
		return
 
	if debug:
		TokenPrinter.new().print_tokens(tokens)
 
	# 2. Parser
	var parser = Parser.new(tokens)
	parser.interpreter = self
	var ast = parser.parse()
 
	if tem_erros():
		_emitir_erros()
		return
 
	if debug:
		parser.print_parser()
		var printer = ASTPrinter.new()
		printer.print_ast(ast)
 
	# 3. Executor
	executor.load_program(ast, context)
	executor.interpreter = self
	_start_execution()

func stop_execution() -> void:
	_finish_execution()

func request_sleep(seconds: float) -> void:
	_sleep_requested = true
	emit_signal("sleep_requested", maxf(0.0, seconds))

func _start_execution() -> void:
	if executor_flag and _execution_active:
		return
	executor_flag = true
	_execution_active = true
	emit_signal("execution_started")

func _finish_execution() -> void:
	var was_active := _execution_active or executor_flag
	executor_flag = false
	if executor != null:
		executor.is_finished = true
	_execution_active = false
	if was_active:
		emit_signal("execution_finished")
 
# ─── Loop de execução ─────────────────────────────────────────────────────────
 
var steps_per_frame = 1
 
func _process(_delta: float) -> void:
	if scheduler_managed:
		return
	begin_scheduler_frame()
	execute_operation_budget(steps_per_frame)
	end_scheduler_frame()

func execute_operation_budget(max_operations: int) -> int:
	if executor == null or not executor_flag:
		return 0
 
	if executor.is_finished:
		_finish_execution()
		_emitir_sucesso()
		return 0
 
	var operations := 0
	var budget: int = maxi(1, max_operations)
	for _i in range(budget):
		executor.step()
		operations += 1
 
		if _tem_erro_fatal or executor.is_finished or _sleep_requested:
			break
 
	if tem_erros():
		_finish_execution()
		_emitir_erros()
	elif executor.is_finished:
		_finish_execution()
		_emitir_sucesso()
	return operations

func consume_sleep_request() -> bool:
	var requested := _sleep_requested
	_sleep_requested = false
	return requested
 
# ─── Saída ────────────────────────────────────────────────────────────────────
 
func _emitir_erros() -> void:
	if erros.is_empty():
		return
	var texto = _formatar_erros()
	if not saidas.is_empty():
		texto = _format_output_text("\n".join(saidas)) + "\n" + texto
	print("[Interpreter] Erros:\n", texto)
	emit_signal("execution_diagnostics", get_diagnostics())
	emit_signal("execution_error", texto)
	_emit_debug_text(texto)
 
func _emitir_sucesso() -> void:
	if tem_erros():
		return
	if not saidas.is_empty():
		return
	var ms = Time.get_ticks_msec() - _tempo_inicio
	var texto = _format_output_text("Executado em %dms" % ms)
	print("[Interpreter] ", texto)
	_emit_debug_text(texto)
