extends Node


const PythonLexer = preload("res://interpreter/python_like/lexer/python_like_lexer.gd")
const PythonParser = preload("res://interpreter/python_like/parser/python_like_parser.gd")
const PythonAnalyzer = preload("res://interpreter/python_like/analysis/python_like_delivery_program_analyzer.gd")
const CLikeAnalyzer = preload("res://interpreter/analysis/c_like_delivery_program_analyzer.gd")
const Validator = preload("res://systems/DeliveryProgramValidator.gd")
const ConcreteBridge = preload("res://interpreter/runtime/godot_automarket_python_bridge.gd")

var _failures: Array[String] = []


func _ready() -> void:
	_test_python_recursion_shapes()
	_test_language_parity()
	_test_missing_facts_are_rejected()

	if _failures.is_empty():
		print("DELIVERY_PROGRAM_ANALYZERS_TEST_OK")
	else:
		push_error("\n".join(_failures))
	await get_tree().process_frame
	get_tree().quit()


func _test_python_recursion_shapes() -> void:
	var direct = _python_facts("""
def f(n):
    if n <= 0:
        return 0
    return f(n - 1)
""")
	_check(direct.recursive_declarations == ["f"],
		"Recursão direta Python-like deve ser detectada.")
	_check(direct.valid_recursive_functions == ["f"],
		"Recursão com if e caso-base deve ser válida.")

	var non_recursive = _python_facts("""
def f(n):
    return n + 1
""")
	_check(non_recursive.recursive_declarations.is_empty(),
		"Função sem autochamada não deve ser recursiva.")

	var cross_call = _python_facts("""
def a():
    return 1

def b():
    return a()
""")
	_check(cross_call.recursive_declarations.is_empty(),
		"Chamar outra função não deve contar como recursão direta.")

	var nested = _python_facts("""
def f(n):
    if n <= 0:
        return 0
    while n > 0:
        return 1 + f(n - 1)
""")
	_check(nested.recursive_declarations == ["f"] and nested.has_loop,
		"Traversal deve alcançar autochamada aninhada em loop e expressão.")


func _test_language_parity() -> void:
	var python_valid = _python_facts("""
def resolver(quantidade, valor_base):
    if quantidade == 0:
        return 0
    return 2 * resolver(quantidade - 1, valor_base) + valor_base

entregas = get_deliveries()
lucros = [0, 0, 0]
for i in range(3):
    lucros[i] = resolver(entregas[i], i)
declare_profit(lucros)
""")
	var c_like_valid = _c_like_facts("""
int resolver(int quantidade, int valor_base) {
	if (quantidade == 0) { return 0; }
	return 2 * resolver(quantidade - 1, valor_base) + valor_base;
}
int main() {
	int entregas[3]; int lucros[3];
	entregas = get_deliveries();
	for (int i = 0; i < 3; i++) { lucros[i] = resolver(entregas[i], i); }
	declare_profit(lucros);
}
""")
	var python_result := Validator.validate(python_valid)
	var c_like_result := Validator.validate(c_like_valid)
	_check(bool(python_result.valid) and bool(c_like_result.valid),
		"Programas equivalentes válidos devem passar nas duas linguagens.")
	_check(_comparable_facts(python_valid) == _comparable_facts(c_like_valid),
		"Analyzers equivalentes devem produzir os mesmos fatos pedagógicos.")
	_check(python_result.errors == c_like_result.errors,
		"Validator deve produzir mensagens equivalentes entre linguagens.")

	var python_non_recursive = _python_facts("""
def calcular(valor):
    return valor

entregas = get_deliveries()
lucros = [0, 0, 0]
for i in range(3):
    lucros[i] = calcular(entregas[i])
declare_profit(lucros)
""")
	var c_like_non_recursive = _c_like_facts("""
int calcular(int valor) { return valor; }
int main() {
	int entregas[3]; int lucros[3];
	entregas = get_deliveries();
	for (int i = 0; i < 3; i++) { lucros[i] = calcular(entregas[i]); }
	declare_profit(lucros);
}
""")
	var python_invalid := Validator.validate(python_non_recursive)
	var c_like_invalid := Validator.validate(c_like_non_recursive)
	_check(not bool(python_invalid.valid) and not bool(c_like_invalid.valid),
		"Ausência de recursão deve ser rejeitada nas duas linguagens.")
	_check(python_invalid.errors == c_like_invalid.errors
		and str(python_invalid.errors[0]).contains("chamar a si mesma"),
		"Rejeição pedagógica sem recursão deve manter a mesma mensagem.")


func _test_missing_facts_are_rejected() -> void:
	var validation := Validator.validate(null)
	_check(not bool(validation.valid)
		and str(validation.errors[0]).contains("Não consegui analisar"),
		"Validator não deve aceitar ausência de fatos.")
	var bridge = ConcreteBridge.new()
	bridge._delivery_report_id = 1
	var response = bridge.declare_profit([1, 2, 3], {
		"runtime_id": "test", "script_id": "test"
	})
	_check(not response.is_success()
		and response.code == "AUTOMARKET_PROGRAM_FACTS_UNAVAILABLE",
		"Bridge deve produzir falha tipada quando fatos não estiverem disponíveis.")


func _python_facts(source: String):
	var lexer = PythonLexer.new(source)
	var tokens: Array = lexer.tokenize()
	_check(lexer.errors.is_empty(), "Fonte Python-like do analyzer deve ser léxica válida.")
	var parser = PythonParser.new(tokens)
	var program = parser.parse()
	_check(parser.errors.is_empty(), "Fonte Python-like do analyzer deve ser sintaticamente válida.")
	return PythonAnalyzer.analyze(program)


func _c_like_facts(source: String):
	FeatureManager.unlock_feature(FeatureManager.FEATURE_IF)
	FeatureManager.unlock_feature(FeatureManager.FEATURE_STOCK)
	var interpreter := Interpreter.new()
	interpreter.scheduler_managed = true
	interpreter.emit_debug_to_eventbus = false
	add_child(interpreter)
	interpreter.run(source, EnvContext.new([], 0, []))
	_check(not interpreter.tem_erros(), "Fonte C-like do analyzer deve ser válida.")
	var facts = CLikeAnalyzer.analyze(interpreter.executor.program_ast)
	interpreter.stop_execution()
	interpreter.queue_free()
	return facts


func _comparable_facts(facts) -> Dictionary:
	var result: Dictionary = facts.to_dictionary()
	result.erase("recursive_declarations")
	result.erase("recursive_functions")
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
