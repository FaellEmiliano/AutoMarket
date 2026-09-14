extends "res://interpreter/runtime/language_runtime_backend.gd"
class_name PythonLikeRuntimeBackend


const PythonLexer = preload("res://interpreter/python_like/lexer/python_like_lexer.gd")
const PythonParser = preload("res://interpreter/python_like/parser/python_like_parser.gd")
const PythonExecutor = preload("res://interpreter/python_like/runtime/python_like_executor.gd")
const ConcreteBridge = preload("res://interpreter/runtime/godot_automarket_python_bridge.gd")
const DeliveryAnalyzer = preload("res://interpreter/python_like/analysis/python_like_delivery_program_analyzer.gd")

const MAX_OUTPUT_LINES := 200

var _executor
var _bridge
var _runtime_id := ""
var _script_id := ""
var _source_name := ""
var _output_lines: Array[String] = []
var _has_error := false
var _active := false
var _finished := true
var _sleep_requested := false
var _sleeping := false
var _sleep_token: int = 0
var _diagnostics: Array = []


func _init() -> void:
	_executor = PythonExecutor.new()
	_bridge = ConcreteBridge.new()
	_executor.set_automarket_bridge(_bridge)


func configure_runtime(runtime_id: String, script_id: String, source_name: String) -> void:
	_runtime_id = runtime_id
	_script_id = script_id
	_source_name = source_name
	_executor.configure_source_identity(runtime_id, script_id, source_name)


func start_source(source: String, _context: Variant) -> void:
	_output_lines.clear()
	_has_error = false
	_active = false
	_finished = false
	_sleep_requested = false
	_sleeping = false
	_sleep_token = 0
	_diagnostics.clear()
	_bridge.configure_program_facts(null, Callable())

	var lexer = PythonLexer.new(source)
	var tokens: Array = lexer.tokenize()
	if not lexer.errors.is_empty():
		_fail_with_diagnostics(lexer.errors)
		return

	var parser = PythonParser.new(tokens)
	var program = parser.parse()
	if not parser.errors.is_empty():
		_fail_with_diagnostics(parser.errors)
		return
	if program == null:
		_fail_with_text("PARSE_NO_PROGRAM", "Não foi possível criar o programa Python-like.", 1, 1)
		return

	var load_result = _executor.load_program(program)
	if load_result.has_failure():
		_fail_with_runtime_failure(load_result.failure())
		return
	var program_facts = DeliveryAnalyzer.analyze(program)
	_bridge.configure_program_facts(
		program_facts, Callable(_executor, "has_delivery_recursion")
	)
	_active = _executor.is_active()
	_finished = _executor.is_finished()
	if _finished:
		execution_finished.emit()


func begin_scheduler_frame() -> void:
	if not _sleeping:
		return
	if not _executor.resume_suspension(_sleep_token):
		_fail_with_text(
			"INTERNAL_INVALID_SUSPENSION",
			"A espera cooperativa não pôde ser retomada com segurança.", 0, 0
		)
		return
	_sleeping = false
	_sleep_token = 0


func end_scheduler_frame() -> void:
	pass


func execute_operation_budget(max_operations: int) -> int:
	if not _active or _has_error or max_operations <= 0:
		return 0
	var consumed := 0
	while consumed < max_operations and _executor.is_active() \
			and not _executor.is_suspended():
		var operation_count: int = _executor.step()
		if operation_count <= 0:
			break
		consumed += operation_count
		if _executor.is_suspended():
			_begin_sleep(_executor.pending_suspension())
			break
	_drain_new_output()

	if _executor.has_failure():
		_fail_with_runtime_failure(_executor.failure())
	elif not _executor.is_active() or _executor.is_finished():
		_active = false
		_finished = true
		_executor.dispose()
		_bridge.configure_program_facts(null, Callable())
		execution_finished.emit()
	return consumed


func stop_execution() -> void:
	if _executor != null:
		_executor.stop()
	_bridge.configure_program_facts(null, Callable())
	_active = false
	_finished = true
	_sleep_requested = false
	_sleeping = false
	_sleep_token = 0


func consume_sleep_request() -> bool:
	var requested := _sleep_requested
	_sleep_requested = false
	return requested


func has_errors() -> bool:
	return _has_error


func is_execution_active() -> bool:
	return _active


func is_finished() -> bool:
	return _finished


func _drain_new_output() -> void:
	var new_lines: Array[String] = _executor.consume_output_lines()
	if new_lines.is_empty():
		return
	for line in new_lines:
		_output_lines.append(_prefixed_line(line))
	while _output_lines.size() > MAX_OUTPUT_LINES:
		_output_lines.pop_front()
	output_changed.emit(_output_text())


func _fail_with_diagnostics(diagnostics: Array) -> void:
	for diagnostic in diagnostics:
		_diagnostics.append(_diagnostic_dictionary(diagnostic))
		_output_lines.append(_format_diagnostic(
			str(diagnostic.code), str(diagnostic.message),
			int(diagnostic.line), int(diagnostic.column)
		))
	_finish_error()


func _fail_with_runtime_failure(failure) -> void:
	_drain_new_output()
	_diagnostics.append(_diagnostic_dictionary(failure))
	_output_lines.append(_format_diagnostic(
		str(failure.code), str(failure.message),
		int(failure.line), int(failure.column)
	))
	_finish_error()


func _fail_with_text(code: String, message: String, line: int, column: int) -> void:
	_diagnostics.append({
		"category": "internal",
		"code": code,
		"message": message,
		"line": line,
		"column": column,
		"length": 0,
		"details": {},
	})
	_output_lines.append(_format_diagnostic(code, message, line, column))
	_finish_error()


func _finish_error() -> void:
	while _output_lines.size() > MAX_OUTPUT_LINES:
		_output_lines.pop_front()
	_has_error = true
	_active = false
	_finished = true
	_sleep_requested = false
	_sleeping = false
	_sleep_token = 0
	_executor.dispose()
	_bridge.configure_program_facts(null, Callable())
	var text := _output_text()
	output_changed.emit(text)
	execution_diagnostics.emit(_diagnostics.duplicate(true))
	execution_error.emit(text)

func _diagnostic_dictionary(diagnostic) -> Dictionary:
	if diagnostic != null and diagnostic.has_method("to_dictionary"):
		return diagnostic.to_dictionary()
	return {
		"category": "internal",
		"code": "UNKNOWN_DIAGNOSTIC",
		"message": str(diagnostic),
		"line": 0,
		"column": 0,
		"length": 0,
		"details": {},
	}


func _format_diagnostic(code: String, message: String, line: int, column: int) -> String:
	var position := ""
	if line > 0:
		position = "linha %d, coluna %d: " % [line, maxi(1, column)]
	return _prefixed_line("%s%s: %s" % [position, code, message])


func _prefixed_line(line: String) -> String:
	var display_name := _source_name if not _source_name.is_empty() else _script_id
	return "[%s] %s" % [display_name, line]


func _output_text() -> String:
	return "\n".join(_output_lines)


func _begin_sleep(request) -> void:
	if request == null:
		_fail_with_text(
			"INTERNAL_INVALID_SUSPENSION",
			"A espera cooperativa não forneceu uma requisição válida.", 0, 0
		)
		return
	_sleeping = true
	_sleep_requested = true
	_sleep_token = int(request.token)
	sleep_requested.emit(float(request.seconds))
