extends Node

const Lexer = preload("res://interpreter/python_like/lexer/python_like_lexer.gd")
const Parser = preload("res://interpreter/python_like/parser/python_like_parser.gd")
const Executor = preload("res://interpreter/python_like/runtime/python_like_executor.gd")
const FakeBridge = preload("res://tests/fake_python_like_automarket_bridge.gd")
var failures: Array[String] = []
var executors: Array = []

func _ready() -> void:
	_test_values_and_aliases()
	_test_order_and_bound_methods()
	_test_errors()
	_test_failed_calls_and_iteration()
	_test_wait_stop_and_method_lifetime()
	for executor in executors:
		executor.dispose()
	if failures.is_empty():
		print("PYTHON_LIKE_LIST_METHODS_TEST_OK")
	else:
		for message in failures:
			push_error(message)
	get_tree().quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func prepare(source: String, bridge = null):
	var lexer := Lexer.new(source)
	var parser := Parser.new(lexer.tokenize())
	var program = parser.parse()
	check(lexer.errors.is_empty() and parser.errors.is_empty(), "Method source parses")
	var executor := Executor.new()
	executor.configure_source_identity("methods_runtime", "methods_script", "Listas")
	if bridge != null:
		executor.set_automarket_bridge(bridge)
	executor.load_program(program)
	executors.append(executor)
	return executor

func run_source(source: String):
	var executor = prepare(source)
	finish(executor)
	return executor

func finish(executor) -> void:
	var steps := 0
	while executor.is_active() and not executor.is_suspended() and steps < 20000:
		executor.step()
		steps += 1
	check(steps < 20000, "List methods terminate within operation budget")

func _test_values_and_aliases() -> void:
	var executor = run_source("""itens = [10, 20]
alias = itens
print(itens.append(30))
print(alias)
print(itens.pop())
print(itens.pop(0))
print(itens)
matriz = [[1]]
matriz[0].append(2)
print(matriz)
print(matriz.pop().pop(-1))
lista = [0, 1, 2]
print(lista.pop(True))
print(lista.pop(-2))
print(lista.pop())
x = []
x.append(x)
print(x)
print(x.pop())
""")
	check(not executor.has_failure(), "append/pop must execute, including self references")
	check(executor.output_lines() == ["None", "[10, 20, 30]", "30", "10", "[20]", "[[1, 2]]", "2", "1", "0", "2", "[[...]]", "[]"], "Mutation, return values, nested lists, negative and bool indices")

func _test_order_and_bound_methods() -> void:
	var executor = run_source("""def receber(log, lista):
    log.append(1)
    return lista

def argumento(log):
    log.append(2)
    return 9

log = []
lista = []
receber(log, lista).append(argumento(log))
print(log)
print(lista)
inserir = lista.append
original = lista
lista = []
inserir(8)
print(original)
print(lista)
remover = original.pop
print(remover(0))
""")
	check(not executor.has_failure() and executor.output_lines() == ["[1, 2]", "[9]", "[9, 8]", "[]", "9"], "Receiver evaluates once, before arguments, and bound methods keep receiver identity")

func _test_errors() -> void:
	for entry in [
		["a = []\na.pop()\n", "INDEX_OUT_OF_RANGE"],
		["a = [1]\na.pop(1)\n", "INDEX_OUT_OF_RANGE"],
		["a = [1]\na.pop(-2)\n", "INDEX_OUT_OF_RANGE"],
		["a = [1]\na.pop(0.0)\n", "INDEX_NOT_INTEGER"],
		["a = [1]\na.pop('0')\n", "INDEX_NOT_INTEGER"],
		["a = []\na.append()\n", "ARITY_MISMATCH"],
		["a = []\na.append(1, 2)\n", "ARITY_MISMATCH"],
		["a = [1]\na.pop(0, 1)\n", "ARITY_MISMATCH"],
		["a = []\na.clear()\n", "ATTRIBUTE_NOT_FOUND"],
		["a = 1\na.append(2)\n", "ATTRIBUTE_NOT_FOUND"],
		["a = {}\na.pop(1)\n", "ATTRIBUTE_NOT_FOUND"],
		["a = None\na.append(2)\n", "ATTRIBUTE_NOT_FOUND"],
		["a = []\na._elements\n", "ATTRIBUTE_NOT_FOUND"]
	]:
		var executor = run_source(entry[0])
		check(executor.has_failure() and executor.failure().code == entry[1], "Method error: %s" % entry[0])
		if executor.has_failure():
			check(executor.failure().line == 2 and executor.failure().script_id == "methods_script", "Method failure preserves source span and identity")

func _test_wait_stop_and_method_lifetime() -> void:
	var bridge := FakeBridge.new()
	bridge.set_suspension("wait", 0)
	var executor = prepare("""lista = []
while True:
    lista.append(1)
    lista.pop(0)
    wait(0)
""", bridge)
	finish(executor)
	check(executor.is_suspended(), "Methods work before cooperative wait")
	if executor.has_failure():
		return
	var count: int = executor._lifecycle.tracked_count()
	for _iteration in range(20):
		var token: int = executor.pending_suspension().token
		check(executor.resume_suspension(token), "Cooperative method loop resumes")
		finish(executor)
	check(executor._lifecycle.tracked_count() == count, "Repeated method lookup must not retain a new bound method every loop")
	var list_value = executor.global_environment.lookup("lista").value()
	var token: int = executor.pending_suspension().token
	executor.stop()
	check(list_value.is_discarded() and executor._lifecycle.tracked_count() == 0, "Stop releases list and bound methods")
	check(not executor.resume_suspension(token), "Stopped method loop cannot resume")
	var cycle = run_source("a = []\na.append(a.append)\n")
	check(not cycle.has_failure(), "A list may store its own bound method")
	cycle.dispose()
	check(cycle._lifecycle == null and cycle._list_methods.is_empty(), "Method/list cycles are broken during disposal")


func _test_failed_calls_and_iteration() -> void:
	for operation in ["a.pop(99)", "a.pop(0.0)", "a.append()", "a.append(3, 4)"]:
		var executor = run_source("a = [10, 20]\n" + operation + "\n")
		check(executor.has_failure() and executor.global_environment.lookup("a").value().representation() == "[10, 20]", "Invalid method call must not mutate receiver")
	for operation in ["a.append(3)", "a.pop()"]:
		var executor = run_source("a = [1, 2]\nfor item in a:\n    " + operation + "\n")
		check(executor.has_failure() and executor.failure().code == "RUNTIME_COLLECTION_MUTATED", "Methods preserve for mutation guard")
