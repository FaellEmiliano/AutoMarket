extends Node


const LexerScript = preload("res://interpreter/python_like/lexer/python_like_lexer.gd")
const ParserScript = preload("res://interpreter/python_like/parser/python_like_parser.gd")
const ExecutorScript = preload("res://interpreter/python_like/runtime/python_like_executor.gd")
const Values = preload("res://interpreter/python_like/runtime/python_like_values.gd")
const Collections = preload("res://interpreter/python_like/runtime/python_like_collections.gd")
const RangeValue = preload("res://interpreter/python_like/runtime/python_like_range.gd")
const FakeAutoMarketBridge = preload("res://tests/fake_python_like_automarket_bridge.gd")

var _failures: Array[String] = []


func _ready() -> void:
	_test_literals_operators_and_assignments()
	_test_short_circuit_and_chained_comparisons()
	_test_lists_dictionaries_and_index_mutation()
	_test_blocks_conditionals_and_scope()
	_test_while_break_and_continue()
	_test_for_lists_dictionaries_and_nesting()
	_test_iteration_mutation_guards()
	_test_loop_incremental_stop()
	_test_incremental_progress_and_cleanup()
	_test_functions_returns_and_calls()
	_test_function_scope_and_recursion()
	_test_function_failures_and_control_flow()
	_test_range_builtin()
	_test_len_builtin()
	_test_print_builtin()
	_test_builtins_in_functions_and_incrementality()
	_test_automarket_bridge_availability_and_stock()
	_test_automarket_synchronous_builtins()
	_test_automarket_conversion_and_errors()
	_test_automarket_builtins_in_functions()
	_test_wait_suspension_and_state()
	_test_wait_in_functions_loops_and_recursion()
	_test_wait_errors()
	_test_structured_failures()

	if _failures.is_empty():
		print("PYTHON_LIKE_EXECUTOR_TEST_OK")
	else:
		push_error("\n".join(_failures))
	await get_tree().process_frame
	get_tree().quit()


func _test_literals_operators_and_assignments() -> void:
	var executor = _execute(
		"a = 1 + 2 * 3\n"
		+ "b = -2 ** 2\n"
		+ "c = 2 ** 3 ** 2\n"
		+ "d = 7 // -3\n"
		+ "e = -7 % 3\n"
		+ "f = 3 / 2\n"
		+ "g = 'ab' * 2\n"
		+ "n = None\n"
		+ "a += 5\n"
		+ "sub = 10\nsub -= 3\n"
		+ "mul = 4\nmul *= 3\n"
		+ "div = 9\ndiv /= 2\n"
		+ "floor_assign = 9\nfloor_assign //= 2\n"
		+ "mod_assign = 9\nmod_assign %= 4\n"
	)
	_check(not executor.has_failure() and executor.is_finished(),
		"Programa simples deve terminar sem falha.")
	_check(_integer(executor, "a") == 12, "Atribuição composta deve reutilizar o binding local.")
	_check(_integer(executor, "b") == -4, "Unário deve ter precedência inferior à potência.")
	_check(_integer(executor, "c") == 512, "Potência associativa à direita deve executar incrementalmente.")
	_check(_integer(executor, "d") == -3 and _integer(executor, "e") == 2,
		"Divisão inteira e módulo devem seguir os sinais do Python.")
	_check(absf(_float(executor, "f") - 1.5) < 0.0001,
		"Divisão comum deve produzir float.")
	_check(_value(executor, "g").string_value == "abab" and _value(executor, "n") is Values.NoneValue,
		"Strings e None devem usar valores próprios do runtime.")
	_check(_integer(executor, "sub") == 7 and _integer(executor, "mul") == 12
		and absf(_float(executor, "div") - 4.5) < 0.0001
		and _integer(executor, "floor_assign") == 4
		and _integer(executor, "mod_assign") == 1,
		"Todos os operadores compostos aceitos pelo parser devem executar.")


func _test_short_circuit_and_chained_comparisons() -> void:
	var executor = _execute(
		"left = False and nome_ausente\n"
		+ "right = 'ok' or outro_ausente\n"
		+ "chain = 1 < 2 < 3\n"
		+ "stopped_chain = 3 < 2 < nome_ausente\n"
		+ "numeric_equal = 1 == True\n"
		+ "text_order = 'b' >= 'a'\n"
		+ "different = 'a' != 'b'\n"
		+ "empty_is_false = not []\n"
	)
	_check(not executor.has_failure(),
		"Curto-circuito lógico e de comparação não deve avaliar nomes posteriores.")
	_check(not _value(executor, "left").boolean_value,
		"and deve devolver o operando falso da esquerda.")
	_check(_value(executor, "right").string_value == "ok",
		"or deve devolver o operando verdadeiro da esquerda.")
	_check(_value(executor, "chain").boolean_value
		and not _value(executor, "stopped_chain").boolean_value,
		"Comparações encadeadas devem produzir bool e interromper na primeira falha.")
	_check(_value(executor, "numeric_equal").boolean_value
		and _value(executor, "text_order").boolean_value
		and _value(executor, "different").boolean_value
		and _value(executor, "empty_is_false").boolean_value,
		"Comparações primitivas e truthiness devem seguir o subconjunto Python-like.")


func _test_lists_dictionaries_and_index_mutation() -> void:
	var executor = _execute(
		"a = [1, 2]\n"
		+ "b = a\n"
		+ "b[-1] = 7\n"
		+ "a[0] += 4\n"
		+ "d = {'x': 1, 'x': 2}\n"
		+ "d['y'] = a[0]\n"
		+ "d['x'] *= 3\n"
		+ "has_seven = 7 in a\n"
		+ "has_x = 'x' in d\n"
		+ "missing = 'z' not in d\n"
		+ "joined = a + [9]\n"
		+ "repeated = [3] * 3\n"
	)
	_check(not executor.has_failure(), "Coleções e indexação devem executar sem falha.")
	var a = _value(executor, "a")
	var b = _value(executor, "b")
	_check(a is Collections.ListValue and a.is_identical_to(b)
		and a.representation() == "[5, 7]",
		"Bindings devem compartilhar a identidade e as mutações da lista.")
	var dictionary = _value(executor, "d")
	_check(dictionary.representation() == "{'x': 6, 'y': 5}",
		"Dicionário deve substituir chave repetida, preservar ordem e aceitar atribuição.")
	_check(_value(executor, "has_seven").boolean_value
		and _value(executor, "has_x").boolean_value
		and _value(executor, "missing").boolean_value,
		"in/not in deve percorrer listas e chaves de dicionários.")
	_check(_value(executor, "joined").representation() == "[5, 7, 9]"
		and _value(executor, "repeated").representation() == "[3, 3, 3]",
		"Concatenação e repetição devem criar listas novas.")


func _test_blocks_conditionals_and_scope() -> void:
	var executor = _execute(
		"if True:\n"
		+ "    resultado = 10\n"
		+ "if False:\n"
		+ "    nunca = nome_ausente\n"
		+ "elif []:\n"
		+ "    nunca = outro_ausente\n"
		+ "elif {'ok': 1}:\n"
		+ "    ramo = 2\n"
		+ "else:\n"
		+ "    ramo = 3\n"
		+ "if False:\n"
		+ "    fallback = nome_ausente\n"
		+ "else:\n"
		+ "    fallback = 4\n"
		+ "depois = resultado + ramo\n"
	)
	_check(not executor.has_failure() and _integer(executor, "resultado") == 10
		and _integer(executor, "ramo") == 2 and _integer(executor, "fallback") == 4
		and _integer(executor, "depois") == 12,
		"Blocos condicionais devem escolher um ramo e reutilizar o ambiente atual.")
	_check(executor.global_environment.binding_count() == 4,
		"if/elif/else não deve criar ambientes ou bindings de ramos não executados.")


func _test_while_break_and_continue() -> void:
	var executor = _execute(
		"i = 0\n"
		+ "soma = 0\n"
		+ "while i < 10:\n"
		+ "    i += 1\n"
		+ "    if i == 3:\n"
		+ "        continue\n"
		+ "    if i == 6:\n"
		+ "        break\n"
		+ "    soma += i\n"
		+ "terminou = True\n"
	)
	_check(not executor.has_failure() and _integer(executor, "i") == 6
		and _integer(executor, "soma") == 12
		and _value(executor, "terminou").boolean_value,
		"while deve reavaliar condição e consumir break/continue no loop mais interno.")


func _test_for_lists_dictionaries_and_nesting() -> void:
	var executor = _execute(
		"total = 0\n"
		+ "for valor in [1, 2, 3]:\n"
		+ "    total += valor\n"
		+ "chaves = ''\n"
		+ "for chave in {'a': 1, 'b': 2}:\n"
		+ "    chaves += chave\n"
		+ "contador = 0\n"
		+ "for x in [1, 2]:\n"
		+ "    for y in [1, 2, 3]:\n"
		+ "        if y == 2:\n"
		+ "            continue\n"
		+ "        if x == 2 and y == 3:\n"
		+ "            break\n"
		+ "        contador += 1\n"
		+ "ultimo_x = x\n"
	)
	_check(not executor.has_failure() and _integer(executor, "total") == 6
		and _value(executor, "chaves").string_value == "ab"
		and _integer(executor, "contador") == 3 and _integer(executor, "ultimo_x") == 2,
		"for deve iterar listas/dicts em ordem e isolar controle no loop mais interno.")


func _test_iteration_mutation_guards() -> void:
	var list_executor = _execute(
		"itens = [1, 2]\n"
		+ "alias = itens\n"
		+ "for item in itens:\n"
		+ "    alias[0] = item\n"
	)
	_check(list_executor.has_failure()
		and list_executor.failure().code == "RUNTIME_COLLECTION_MUTATED"
		and list_executor.failure().line == 3,
		"Mutação de lista por alias deve falhar no avanço seguinte do for.")

	var dictionary_executor = _execute(
		"dados = {'a': 1, 'b': 2}\n"
		+ "for chave in dados:\n"
		+ "    dados['a'] = 9\n"
	)
	_check(dictionary_executor.has_failure()
		and dictionary_executor.failure().code == "RUNTIME_COLLECTION_MUTATED"
		and dictionary_executor.failure().details.expected_version == 2
		and dictionary_executor.failure().details.current_version == 3,
		"Substituir valor existente também deve invalidar iteração de dicionário.")


func _test_loop_incremental_stop() -> void:
	var executor = _prepare(
		"contador = 0\n"
		+ "while True:\n"
		+ "    contador += 1\n"
	).executor
	var previous_operations: int = executor.operation_count
	for _step_index in range(250):
		var consumed: int = executor.step()
		_check(consumed == 1 and executor.operation_count == previous_operations + 1,
			"Loop ativo deve consumir uma operação previsível por step.")
		previous_operations = executor.operation_count
	_check(executor.is_active() and _integer(executor, "contador") > 0,
		"Loop infinito deve permanecer ativo e avançar sem monopolizar um step.")
	executor.stop()
	_check(executor.was_stopped() and executor.is_finished() and executor.frame_depth() == 0,
		"stop deve interromper loop infinito entre operações.")


func _test_incremental_progress_and_cleanup() -> void:
	var prepared = _prepare("dados = [1, 2, 3, 4]\nresultado = dados[2] + 1\n")
	var executor = prepared.executor
	var previous_count: int = executor.operation_count
	var steps := 0
	while executor.is_active() and steps < 1000:
		var consumed: int = executor.step()
		_check(consumed == 1 and executor.operation_count == previous_count + 1,
			"Cada step ativo deve consumir exatamente uma operação.")
		previous_count = executor.operation_count
		steps += 1
	_check(steps > 10 and steps < 1000 and executor.frame_depth() == 0
		and _integer(executor, "resultado") == 4,
		"Expressões compostas devem avançar em vários steps e liberar todos os frames.")
	_check(executor.step() == 0 and executor.operation_count == previous_count,
		"step após o término não deve consumir orçamento.")

	var stopped = _prepare("dados = [1, 2, 3, 4, 5]\n").executor
	stopped.step()
	stopped.stop()
	_check(stopped.is_finished() and stopped.was_stopped() and stopped.frame_depth() == 0
		and stopped.step() == 0,
		"stop deve encerrar e descartar frames sem trabalho posterior.")


func _test_functions_returns_and_calls() -> void:
	var executor = _execute(
		"def soma(a, b):\n"
		+ "    return a + b\n"
		+ "def sem_valor():\n"
		+ "    return\n"
		+ "def sem_return():\n"
		+ "    local = 10\n"
		+ "def escolha(x):\n"
		+ "    if x > 0:\n"
		+ "        return 10\n"
		+ "    return 20\n"
		+ "resultado = soma(2, 3)\n"
		+ "vazio = sem_valor()\n"
		+ "natural = sem_return()\n"
		+ "positivo = escolha(1)\n"
		+ "negativo = escolha(0)\n"
	)
	_check(not executor.has_failure() and _integer(executor, "resultado") == 5,
		"Função deve receber parâmetros posicionais e devolver seu resultado.")
	_check(_value(executor, "vazio") is Values.NoneValue
		and _value(executor, "natural") is Values.NoneValue,
		"return sem expressão e término natural devem devolver None.")
	_check(_integer(executor, "positivo") == 10 and _integer(executor, "negativo") == 20,
		"return antecipado deve atravessar if e preservar ambos os caminhos.")

	var nested = _execute(
		"def dobro(x):\n"
		+ "    return x * 2\n"
		+ "def soma(a, b):\n"
		+ "    return a + b\n"
		+ "resultado = soma(dobro(2), dobro(3))\n"
	)
	_check(not nested.has_failure() and _integer(nested, "resultado") == 10,
		"Chamadas aninhadas devem devolver valores ao frame chamador.")

	var order = _execute(
		"ordem = [0, 0, 0]\n"
		+ "cursor = [0]\n"
		+ "def marcar(valor):\n"
		+ "    ordem[cursor[0]] = valor\n"
		+ "    cursor[0] += 1\n"
		+ "    return valor\n"
		+ "def combinar(a, b, c):\n"
		+ "    return a * 100 + b * 10 + c\n"
		+ "resultado = combinar(marcar(1), marcar(2), marcar(3))\n"
	)
	_check(not order.has_failure() and _integer(order, "resultado") == 123
		and _value(order, "ordem").representation() == "[1, 2, 3]",
		"Argumentos devem ser avaliados incrementalmente da esquerda para a direita.")


func _test_function_scope_and_recursion() -> void:
	var local_scope = _execute(
		"x = 5\n"
		+ "def f():\n"
		+ "    x = 10\n"
		+ "    return x\n"
		+ "resultado = f()\n"
	)
	_check(not local_scope.has_failure() and _integer(local_scope, "resultado") == 10
		and _integer(local_scope, "x") == 5,
		"Atribuições locais de função não devem sobrescrever o módulo.")

	var lexical = _execute(
		"x = 10\n"
		+ "def f():\n"
		+ "    return x\n"
		+ "def g():\n"
		+ "    x = 20\n"
		+ "    return f()\n"
		+ "resultado = g()\n"
	)
	_check(not lexical.has_failure() and _integer(lexical, "resultado") == 10,
		"Lookup de função deve usar o ambiente léxico, não o chamador dinâmico.")

	var parameter = _execute(
		"x = 100\n"
		+ "def f(x):\n"
		+ "    return x\n"
		+ "resultado = f(5)\n"
	)
	_check(not parameter.has_failure() and _integer(parameter, "resultado") == 5
		and _integer(parameter, "x") == 100,
		"Parâmetros devem ser bindings do ambiente local da chamada.")

	var no_leak = _execute("def f():\n    local = 123\nf()\n")
	var missing_local = no_leak.global_environment.lookup("local")
	_check(not no_leak.has_failure() and missing_local.has_failure()
		and missing_local.failure().code == "NAME_NOT_DEFINED",
		"Variável criada dentro da função não deve vazar ao módulo.")

	var recursive = _prepare(
		"def fatorial(n):\n"
		+ "    if n <= 1:\n"
		+ "        return 1\n"
		+ "    return n * fatorial(n - 1)\n"
		+ "resultado = fatorial(5)\n"
	).executor
	var recursive_steps := 0
	var greatest_call_depth := 0
	while recursive.is_active() and recursive_steps < 10000:
		var previous_operations: int = recursive.operation_count
		_check(recursive.step() == 1
			and recursive.operation_count == previous_operations + 1,
			"Chamada recursiva ativa deve consumir exatamente uma operação por step.")
		greatest_call_depth = maxi(greatest_call_depth, recursive.call_depth())
		recursive_steps += 1
	_check(not recursive.has_failure() and _integer(recursive, "resultado") == 120
		and recursive.call_depth() == 0 and greatest_call_depth == 5
		and recursive_steps < 10000,
		"Recursão deve usar a pilha incremental e restaurá-la no término.")


func _test_function_failures_and_control_flow() -> void:
	var while_return = _execute(
		"def f():\n"
		+ "    while True:\n"
		+ "        return 7\n"
		+ "resultado = f()\n"
	)
	_check(not while_return.has_failure() and _integer(while_return, "resultado") == 7,
		"return deve atravessar while sem ser consumido como continue.")

	var for_return = _execute(
		"def f():\n"
		+ "    for x in [1, 2, 3]:\n"
		+ "        if x == 2:\n"
		+ "            return x\n"
		+ "    return 0\n"
		+ "resultado = f()\n"
	)
	_check(not for_return.has_failure() and _integer(for_return, "resultado") == 2,
		"return deve atravessar for e estruturas condicionais aninhadas.")

	var loop_controls = _execute(
		"def f():\n"
		+ "    total = 0\n"
		+ "    for x in [1, 2, 3]:\n"
		+ "        for y in [1, 2, 3]:\n"
		+ "            if y == 1:\n"
		+ "                continue\n"
		+ "            if x == 2:\n"
		+ "                break\n"
		+ "            total += y\n"
		+ "    return total\n"
		+ "resultado = f()\n"
	)
	_check(not loop_controls.has_failure() and _integer(loop_controls, "resultado") == 10,
		"break/continue aninhados devem ser consumidos antes do return posterior.")

	var too_few = _execute("def f(a, b):\n    return a + b\nf(1)\n")
	_check(too_few.has_failure() and too_few.failure().code == "ARITY_MISMATCH"
		and too_few.failure().details.expected == 2
		and too_few.failure().details.received == 1,
		"Argumentos insuficientes devem produzir erro tipado de aridade.")

	var too_many = _execute("def f(a):\n    return a\nf(1, 2)\n")
	_check(too_many.has_failure() and too_many.failure().code == "ARITY_MISMATCH"
		and too_many.failure().details.expected == 1
		and too_many.failure().details.received == 2,
		"Argumentos excedentes devem produzir erro tipado de aridade.")

	var max_depth = _execute("def f():\n    return f()\nf()\n")
	_check(max_depth.has_failure() and max_depth.failure().code == "RUNTIME_MAX_CALL_DEPTH"
		and max_depth.failure().details.maximum == 64 and max_depth.call_depth() == 0,
		"Recursão infinita deve terminar no limite explícito sem estourar GDScript.")

	var unbound_local = _execute(
		"x = 9\n"
		+ "def f():\n"
		+ "    resultado = x\n"
		+ "    x = 1\n"
		+ "    return resultado\n"
		+ "f()\n"
	)
	_check(unbound_local.has_failure()
		and unbound_local.failure().code == "NAME_UNBOUND_LOCAL"
		and unbound_local.failure().line == 3,
		"Nome atribuído pela função deve ser local em todo o corpo, antes da atribuição.")


func _test_range_builtin() -> void:
	var executor = _execute(
		"stop_total = 0\n"
		+ "for i in range(5):\n"
		+ "    stop_total += i\n"
		+ "start_total = 0\n"
		+ "for i in range(2, 5):\n"
		+ "    start_total += i\n"
		+ "negative_total = 0\n"
		+ "for i in range(5, 0, -1):\n"
		+ "    negative_total += i\n"
		+ "empty_count = 0\n"
		+ "for i in range(5, 5):\n"
		+ "    empty_count += 1\n"
		+ "wrong_direction = 0\n"
		+ "for i in range(0, 5, -1):\n"
		+ "    wrong_direction += 1\n"
	)
	_check(not executor.has_failure()
		and _integer(executor, "stop_total") == 10
		and _integer(executor, "start_total") == 9
		and _integer(executor, "negative_total") == 15
		and _integer(executor, "empty_count") == 0
		and _integer(executor, "wrong_direction") == 0,
		"range deve respeitar stop exclusivo, direção, step e ranges vazios.")

	var zero_step = _execute(
		"for i in range(0, 10, 0):\n    valor = i\n"
	)
	_check(zero_step.has_failure() and zero_step.failure().code == "RANGE_ZERO_STEP",
		"range com step zero deve produzir erro tipado.")

	var no_arguments = _execute("range()\n")
	var too_many = _execute("range(1, 2, 3, 4)\n")
	_check(no_arguments.has_failure() and no_arguments.failure().code == "ARITY_MISMATCH"
		and no_arguments.failure().details.minimum == 1
		and too_many.has_failure() and too_many.failure().code == "ARITY_MISMATCH"
		and too_many.failure().details.maximum == 3,
		"range deve aceitar somente uma, duas ou três posições.")

	var invalid_type = _execute("range('5')\n")
	_check(invalid_type.has_failure()
		and invalid_type.failure().code == "TYPE_INVALID_ARGUMENT"
		and invalid_type.failure().details.expected == "int"
		and invalid_type.failure().details.received == "str",
		"range deve rejeitar argumentos que não sejam int.")


func _test_len_builtin() -> void:
	var executor = _execute(
		"list_length = len([1, 2, 3])\n"
		+ "dict_length = len({'a': 1, 'b': 2})\n"
		+ "string_length = len('AutoMarket')\n"
		+ "range_length = len(range(10))\n"
		+ "negative_range_length = len(range(5, 0, -1))\n"
	)
	_check(not executor.has_failure()
		and _integer(executor, "list_length") == 3
		and _integer(executor, "dict_length") == 2
		and _integer(executor, "string_length") == 10
		and _integer(executor, "range_length") == 10
		and _integer(executor, "negative_range_length") == 5,
		"len deve medir listas, dicionários, strings e ranges lazy.")

	var invalid = _execute("len(10)\n")
	_check(invalid.has_failure() and invalid.failure().code == "TYPE_NO_LENGTH"
		and invalid.failure().details.type == "int",
		"len não deve converter silenciosamente tipos sem tamanho para zero.")
	var no_arguments = _execute("len()\n")
	var too_many = _execute("len([], [])\n")
	_check(no_arguments.has_failure() and no_arguments.failure().code == "ARITY_MISMATCH"
		and too_many.has_failure() and too_many.failure().code == "ARITY_MISMATCH",
		"len deve exigir exatamente um argumento.")


func _test_print_builtin() -> void:
	var executor = _execute(
		"printed = print('hello')\n"
		+ "print('valor', 10, True)\n"
		+ "print()\n"
		+ "print(10, 3.5, True, False, None, 'abc', [1, 2, 3], {'a': 1}, range(3))\n"
	)
	var lines: Array[String] = executor.output_lines()
	_check(not executor.has_failure() and lines.size() == 4
		and _value(executor, "printed") is Values.NoneValue
		and lines[0] == "hello"
		and lines[1] == "valor 10 True"
		and lines[2] == ""
		and lines[3] == "10 3.5 True False None abc [1, 2, 3] {'a': 1} range(3)",
		"print deve usar texto estável, espaços e preservar chamadas vazias.")
	_check(executor.output_text() == (
		"hello\nvalor 10 True\n\n"
		+ "10 3.5 True False None abc [1, 2, 3] {'a': 1} range(3)\n"
	), "Buffer textual deve manter uma quebra de linha por chamada de print.")

	var ordered = _execute(
		"def a():\n"
		+ "    print('a')\n"
		+ "    return 1\n"
		+ "def b():\n"
		+ "    print('b')\n"
		+ "    return 2\n"
		+ "print(a(), b())\n"
	)
	_check(not ordered.has_failure()
		and ordered.output_lines() == ["a", "b", "1 2"],
		"print deve observar a avaliação de argumentos da esquerda para a direita.")


func _test_builtins_in_functions_and_incrementality() -> void:
	var executor = _execute(
		"def tamanho(x):\n"
		+ "    return len(x)\n"
		+ "def soma(n):\n"
		+ "    resultado = 0\n"
		+ "    for i in range(n):\n"
		+ "        resultado += i\n"
		+ "    return resultado\n"
		+ "def recursiva(n):\n"
		+ "    if n == 0:\n"
		+ "        return len([])\n"
		+ "    return len([n]) + recursiva(n - 1)\n"
		+ "length_result = tamanho([1, 2, 3])\n"
		+ "sum_result = soma(5)\n"
		+ "recursive_result = recursiva(4)\n"
	)
	_check(not executor.has_failure()
		and _integer(executor, "length_result") == 3
		and _integer(executor, "sum_result") == 10
		and _integer(executor, "recursive_result") == 4,
		"Built-ins devem funcionar em funções sem quebrar retorno, loops ou recursão.")

	var incremental = _prepare(
		"grande = range(1000000)\n"
		+ "contador = 0\n"
		+ "for i in grande:\n"
		+ "    contador += 1\n"
	).executor
	var steps := 0
	while incremental.is_active() and steps < 250:
		var previous_operations: int = incremental.operation_count
		_check(incremental.step() == 1
			and incremental.operation_count == previous_operations + 1,
			"Iteração de range deve consumir uma operação previsível por step.")
		steps += 1
	var range_result = incremental.global_environment.lookup("grande")
	var count_result = incremental.global_environment.lookup("contador")
	_check(incremental.is_active() and not incremental.has_failure()
		and not range_result.has_failure() and range_result.value() is RangeValue
		and range_result.value().size() == 1000000
		and not count_result.has_failure()
		and count_result.value().numeric_value > 0
		and count_result.value().numeric_value < 1000000,
		"range grande deve permanecer lazy e avançar sem materialização antecipada.")
	incremental.stop()


func _test_automarket_bridge_availability_and_stock() -> void:
	var python_only = _execute("x = len(range(5))\nprint(x)\n")
	_check(not python_only.has_failure() and _integer(python_only, "x") == 5
		and python_only.output_lines() == ["5"],
		"Built-ins Python devem continuar independentes da bridge AutoMarket.")

	var unavailable = _execute("get_stock()\n")
	_check(unavailable.has_failure()
		and unavailable.failure().code == "AUTOMARKET_BRIDGE_UNAVAILABLE"
		and unavailable.failure().category == "bridge"
		and unavailable.failure().details.operation == "get_stock",
		"Built-in AutoMarket sem bridge deve falhar de forma tipada.")

	var stock_snapshot := [3, 5, 7]
	var bridge := FakeAutoMarketBridge.new()
	bridge.set_response("get_stock", stock_snapshot)
	var executor = _execute(
		"estoque = get_stock()\n"
		+ "quantidade = len(estoque)\n"
		+ "estoque[1] = 99\n",
		10000, "stock_script", bridge
	)
	stock_snapshot[0] = 42
	_check(not executor.has_failure()
		and _value(executor, "estoque").representation() == "[3, 99, 7]"
		and _integer(executor, "quantidade") == 3
		and stock_snapshot == [42, 5, 7],
		"Conversão de estoque deve copiar dados nas duas direções da fronteira.")
	var stock_calls: Array = bridge.calls_for("get_stock")
	_check(stock_calls.size() == 1
		and stock_calls[0].context.runtime_id == "runtime_test"
		and stock_calls[0].context.script_id == "stock_script",
		"A bridge deve receber identidade explícita do runtime e do script.")


func _test_automarket_synchronous_builtins() -> void:
	var bridge := FakeAutoMarketBridge.new()
	bridge.set_response("sensor", true)
	bridge.set_response("input", 12.5)
	bridge.set_response("send", true)
	bridge.set_response("buy_stock", null, ["compra aplicada"])
	bridge.set_response("get_deliveries", [3, 0, 2])
	bridge.set_response("declare_profit", null, ["declaração recebida"])
	var executor = _execute(
		"cliente = sensor('cliente_na_tela')\n"
		+ "entrada = input()\n"
		+ "enviado = send(entrada, {'codigo': 10, 'itens': [1, 2, 3]})\n"
		+ "compra = [1, 0, 3]\n"
		+ "compra_resultado = buy_stock(compra)\n"
		+ "compra[0] = 9\n"
		+ "entregas = get_deliveries()\n"
		+ "declaracao = declare_profit([10, 20, 30])\n",
		10000, "delivery_script", bridge
	)
	_check(not executor.has_failure()
		and _value(executor, "cliente").boolean_value
		and absf(_float(executor, "entrada") - 12.5) < 0.0001
		and _value(executor, "enviado").boolean_value
		and _value(executor, "compra_resultado") is Values.NoneValue
		and _value(executor, "declaracao") is Values.NoneValue
		and _value(executor, "entregas").representation() == "[3, 0, 2]",
		"APIs síncronas devem converter argumentos e retornos neutros.")
	_check(executor.output_lines() == ["compra aplicada", "declaração recebida"],
		"Feedback síncrono da bridge deve usar o buffer desacoplado do executor.")
	var sensor_calls: Array = bridge.calls_for("sensor")
	var send_calls: Array = bridge.calls_for("send")
	var buy_calls: Array = bridge.calls_for("buy_stock")
	var declaration_calls: Array = bridge.calls_for("declare_profit")
	_check(sensor_calls.size() == 1
		and sensor_calls[0].arguments == ["cliente_na_tela"],
		"sensor deve encaminhar o nome textual sem inventar sensores.")
	_check(send_calls.size() == 1
		and send_calls[0].arguments == [12.5, {
			"codigo": 10, "itens": [1, 2, 3]
		}], "send deve receber estruturas GDScript recursivamente convertidas.")
	_check(buy_calls.size() == 1 and buy_calls[0].arguments == [[1, 0, 3]],
		"Mutar a lista Python-like depois de buy_stock não deve alterar a cópia da bridge.")
	_check(declaration_calls.size() == 1
		and declaration_calls[0].arguments == [[10, 20, 30]],
		"declare_profit deve encaminhar uma lista nativa independente.")


func _test_automarket_conversion_and_errors() -> void:
	var nested_bridge := FakeAutoMarketBridge.new()
	nested_bridge.set_response("get_deliveries", {
		"codigo": 10,
		"dados": [1, 2, {"ativo": true}],
	})
	var nested = _execute(
		"resultado = get_deliveries()\n",
		10000, "nested_script", nested_bridge
	)
	_check(not nested.has_failure()
		and _value(nested, "resultado").representation() \
			== "{'codigo': 10, 'dados': [1, 2, {'ativo': True}]}",
		"Retornos aninhados devem ser reconstruídos como valores Python-like.")

	var invalid_sensor_bridge := FakeAutoMarketBridge.new()
	invalid_sensor_bridge.set_response("sensor", true)
	var invalid_sensor = _execute(
		"sensor(10)\n", 10000, "invalid_sensor", invalid_sensor_bridge
	)
	_check(invalid_sensor.has_failure()
		and invalid_sensor.failure().code == "TYPE_INVALID_ARGUMENT"
		and invalid_sensor_bridge.calls.is_empty(),
		"sensor deve rejeitar tipo inválido antes de chegar à bridge.")

	var invalid_buy_bridge := FakeAutoMarketBridge.new()
	invalid_buy_bridge.set_response("buy_stock", null)
	var invalid_buy = _execute(
		"buy_stock(10)\n", 10000, "invalid_buy", invalid_buy_bridge
	)
	_check(invalid_buy.has_failure()
		and invalid_buy.failure().code == "TYPE_INVALID_ARGUMENT"
		and invalid_buy_bridge.calls.is_empty(),
		"buy_stock deve exigir lista antes de delegar ao gameplay.")
	var invalid_buy_arity = _execute(
		"buy_stock()\n", 10000, "invalid_buy_arity", invalid_buy_bridge
	)
	_check(invalid_buy_arity.has_failure()
		and invalid_buy_arity.failure().code == "ARITY_MISMATCH"
		and invalid_buy_bridge.calls.is_empty(),
		"buy_stock deve validar aridade antes da bridge.")

	var invalid_declaration_bridge := FakeAutoMarketBridge.new()
	invalid_declaration_bridge.set_response("declare_profit", null)
	var invalid_declaration = _execute(
		"declare_profit(10)\n", 10000, "invalid_declaration",
		invalid_declaration_bridge
	)
	var invalid_declaration_arity = _execute(
		"declare_profit()\n", 10000, "invalid_declaration_arity",
		invalid_declaration_bridge
	)
	_check(invalid_declaration.has_failure()
		and invalid_declaration.failure().code == "TYPE_INVALID_ARGUMENT"
		and invalid_declaration_arity.has_failure()
		and invalid_declaration_arity.failure().code == "ARITY_MISMATCH"
		and invalid_declaration_bridge.calls.is_empty(),
		"declare_profit deve validar lista e aridade antes da bridge.")

	var arity_bridge := FakeAutoMarketBridge.new()
	var invalid_arity = _execute(
		"get_stock(1)\n", 10000, "invalid_arity", arity_bridge
	)
	_check(invalid_arity.has_failure()
		and invalid_arity.failure().code == "ARITY_MISMATCH"
		and arity_bridge.calls.is_empty(),
		"Aridade inválida deve falhar antes da bridge.")

	var rejected_bridge := FakeAutoMarketBridge.new()
	rejected_bridge.set_failure(
		"buy_stock", "STOCK_PURCHASE_REJECTED", "Compra recusada.",
		"gameplay", {"reason": "capacity"}
	)
	var rejected = _execute(
		"buy_stock([1])\n", 10000, "rejected", rejected_bridge
	)
	_check(rejected.has_failure()
		and rejected.failure().code == "STOCK_PURCHASE_REJECTED"
		and rejected.failure().category == "gameplay"
		and rejected.failure().details.reason == "capacity",
		"Erro do gameplay deve atravessar a bridge sem virar erro de tipo.")

	var unsupported_bridge := FakeAutoMarketBridge.new()
	unsupported_bridge.set_response("get_stock", unsupported_bridge)
	var unsupported = _execute(
		"get_stock()\n", 10000, "unsupported", unsupported_bridge
	)
	_check(unsupported.has_failure()
		and unsupported.failure().code == "RUNTIME_UNSUPPORTED_GAMEPLAY_VALUE"
		and unsupported.failure().category == "conversion"
		and unsupported.failure().details.direction == "from_gameplay",
		"Valor de fronteira desconhecido deve falhar sem conversão silenciosa.")

	var outgoing_bridge := FakeAutoMarketBridge.new()
	outgoing_bridge.set_response("send", true)
	var outgoing = _execute(
		"send(range(3))\n", 10000, "outgoing", outgoing_bridge
	)
	_check(outgoing.has_failure()
		and outgoing.failure().code == "RUNTIME_UNSUPPORTED_GAMEPLAY_VALUE"
		and outgoing.failure().details.direction == "to_gameplay"
		and outgoing_bridge.calls.is_empty(),
		"Valor Python-like não suportado deve falhar antes de chegar ao gameplay.")

func _test_automarket_builtins_in_functions() -> void:
	var bridge := FakeAutoMarketBridge.new()
	bridge.set_response("get_stock", [2, 3, 4])
	var executor = _execute(
		"def total_estoque():\n"
		+ "    estoque = get_stock()\n"
		+ "    resultado = 0\n"
		+ "    for valor in estoque:\n"
		+ "        resultado += valor\n"
		+ "    return resultado\n"
		+ "x = total_estoque()\n"
		+ "quantidade = len(get_stock())\n",
		10000, "function_script", bridge
	)
	_check(not executor.has_failure() and _integer(executor, "x") == 9
		and _integer(executor, "quantidade") == 3
		and bridge.calls_for("get_stock").size() == 2,
		"Built-ins AutoMarket devem funcionar em funções e compor com built-ins Python.")


func _test_wait_suspension_and_state() -> void:
	var bridge := FakeAutoMarketBridge.new()
	bridge.set_suspension("wait", 0.25)
	var executor = _prepare(
		"x = 1\nprint('antes')\nwait(0.25)\nx = 2\nprint('depois')\n",
		"wait_state", bridge
	).executor
	var guard := 0
	while executor.is_active() and not executor.is_suspended() and guard < 1000:
		executor.step()
		guard += 1
	var request = executor.pending_suspension()
	var operations_before: int = int(executor.operation_count)
	_check(executor.is_suspended() and request != null
		and absf(float(request.seconds) - 0.25) < 0.0001
		and _integer(executor, "x") == 1,
		"wait deve suspender sem perder o estado anterior da execução.")
	_check(executor.output_lines() == ["antes"],
		"Output posterior ao wait não pode ser produzido antes da retomada.")
	_check(executor.step() == 0 and executor.operation_count == operations_before,
		"Executor suspenso não deve consumir operações.")
	_check(not executor.resume_suspension(int(request.token) + 1)
		and executor.is_suspended(),
		"Token obsoleto não pode reativar uma suspensão pendente.")
	_check(executor.resume_suspension(int(request.token)),
		"Token atual deve permitir retomar a suspensão.")
	_run_executor_to_completion(executor)
	_check(not executor.has_failure() and _integer(executor, "x") == 2
		and executor.output_lines() == ["antes", "depois"],
		"Retomada deve continuar exatamente após wait e preservar o output.")
	_check(bridge.calls_for("wait").size() == 1
		and bridge.calls_for("wait")[0].context.runtime_id == "runtime_test"
		and bridge.calls_for("wait")[0].context.script_id == "wait_state",
		"wait deve encaminhar a identidade correta para a bridge.")

	var zero_bridge := FakeAutoMarketBridge.new()
	zero_bridge.set_suspension("wait", 0.0)
	var zero = _resume_all_suspensions("resultado = wait(0)\n", zero_bridge)
	_check(zero.sleep_count == 1
		and _value(zero.executor, "resultado") is Values.NoneValue,
		"wait(0) deve ceder uma vez e retornar None após a retomada.")


func _test_wait_in_functions_loops_and_recursion() -> void:
	var bridge := FakeAutoMarketBridge.new()
	bridge.set_suspension("wait", 0.01)
	var function_result = _resume_all_suspensions(
		"def f():\n"
		+ "    local = 7\n"
		+ "    wait(0.01)\n"
		+ "    local = local + 3\n"
		+ "    return local\n"
		+ "resultado = f()\n",
		bridge
	)
	_check(function_result.sleep_count == 1
		and _integer(function_result.executor, "resultado") == 10,
		"wait dentro de função deve preservar ambiente local e call stack.")

	bridge = FakeAutoMarketBridge.new()
	bridge.set_suspension("wait", 0.01)
	var loop_result = _resume_all_suspensions(
		"x = 0\n"
		+ "for i in range(3):\n"
		+ "    wait(0.01)\n"
		+ "    x = x + 1\n",
		bridge
	)
	_check(loop_result.sleep_count == 3
		and _integer(loop_result.executor, "x") == 3,
		"Cada iteração deve manter seu ForFrame e produzir uma suspensão independente.")

	bridge = FakeAutoMarketBridge.new()
	bridge.set_suspension("wait", 0.01)
	var recursion_result = _resume_all_suspensions(
		"def f(n):\n"
		+ "    if n == 0:\n"
		+ "        return 0\n"
		+ "    wait(0.01)\n"
		+ "    return 1 + f(n - 1)\n"
		+ "resultado = f(3)\n",
		bridge
	)
	_check(recursion_result.sleep_count == 3
		and _integer(recursion_result.executor, "resultado") == 3,
		"Suspensões recursivas não podem corromper a pilha de chamadas incremental.")


func _test_wait_errors() -> void:
	var unavailable = _execute("wait(1)\n")
	_check(unavailable.has_failure()
		and unavailable.failure().code == "AUTOMARKET_BRIDGE_UNAVAILABLE",
		"wait sem bridge deve falhar de forma controlada.")

	var invalid_type = _execute("wait('abc')\n")
	_check(invalid_type.has_failure()
		and invalid_type.failure().code == "TYPE_INVALID_ARGUMENT",
		"wait deve rejeitar valores não numéricos com erro tipado.")

	var bridge := FakeAutoMarketBridge.new()
	bridge.set_suspension("wait", 0.0)
	var negative = _resume_all_suspensions("resultado = wait(-1)\n", bridge)
	var negative_calls: Array = bridge.calls_for("wait")
	_check(negative.sleep_count == 1
		and _value(negative.executor, "resultado") is Values.NoneValue
		and negative_calls.size() == 1
		and negative_calls[0].arguments == [0.0],
		"Regra C-like explícita deve normalizar wait negativo para zero e ceder uma vez.")

	var rejected_bridge := FakeAutoMarketBridge.new()
	rejected_bridge.set_failure(
		"wait", "AUTOMARKET_WAIT_START_FAILED", "Espera indisponível.", "bridge"
	)
	var rejected = _execute("wait(1)\n", 1000, "wait_rejected", rejected_bridge)
	_check(rejected.has_failure()
		and rejected.failure().code == "AUTOMARKET_WAIT_START_FAILED",
		"Falha ao iniciar espera deve atravessar a bridge como erro tipado.")

	var synchronous_bridge := FakeAutoMarketBridge.new()
	synchronous_bridge.set_response("wait", null)
	var synchronous = _execute("wait(1)\n", 1000, "wait_sync", synchronous_bridge)
	_check(synchronous.has_failure()
		and synchronous.failure().code == "AUTOMARKET_WAIT_NOT_SUSPENDED",
		"Bridge não pode concluir wait sincronamente por engano.")


func _test_structured_failures() -> void:
	var missing = _execute("x = 1\ny = ausente + 2\n", 1000, "script_missing")
	_check(missing.has_failure() and missing.failure().code == "NAME_NOT_DEFINED"
		and missing.failure().line == 2 and missing.failure().column == 5
		and missing.failure().length == 7
		and missing.failure().script_id == "script_missing",
		"Nome ausente deve preservar código, span e identidade da fonte.")

	var target_first = _execute("a = 1\na[0] = nome_ausente\n")
	_check(target_first.has_failure()
		and target_first.failure().code == "TYPE_NOT_SUBSCRIPTABLE",
		"O alvo indexado deve ser resolvido antes da expressão à direita.")

	var zero = _execute("x = 4 / 0\n")
	_check(zero.has_failure() and zero.failure().code == "RUNTIME_DIVISION_BY_ZERO"
		and zero.failure().line == 1 and zero.failure().column == 7,
		"Falha de operador deve apontar para o operador.")

	var call = _execute("x = funcao()\n")
	_check(call.has_failure() and call.failure().code == "NAME_NOT_DEFINED",
		"Chamada deve resolver o callable antes de tentar executá-lo.")

	var invalid_iterable = _execute("for item in 3:\n    valor = item\n")
	_check(invalid_iterable.has_failure()
		and invalid_iterable.failure().code == "TYPE_NOT_ITERABLE"
		and invalid_iterable.failure().line == 1
		and invalid_iterable.failure().details.type == "int",
		"for sobre valor não iterável deve produzir erro estruturado posicional.")

func _prepare(source: String, source_script_id: String = "script_test",
		automarket_bridge = null) -> Dictionary:
	var lexer = LexerScript.new(source)
	var tokens = lexer.tokenize()
	_check(lexer.errors.is_empty(), "Fonte de executor não deveria falhar no lexer: %s" % [lexer.errors])
	var parser = ParserScript.new(tokens)
	var program = parser.parse()
	_check(parser.errors.is_empty(), "Fonte de executor não deveria falhar no parser: %s" % [parser.errors])
	var executor = ExecutorScript.new()
	executor.configure_source_identity("runtime_test", source_script_id, "Teste")
	if automarket_bridge != null:
		executor.set_automarket_bridge(automarket_bridge)
	executor.load_program(program)
	return {"executor": executor, "program": program}


func _execute(source: String, max_steps: int = 10000,
		source_script_id: String = "script_test", automarket_bridge = null):
	var executor = _prepare(source, source_script_id, automarket_bridge).executor
	var steps := 0
	while executor.is_active() and steps < max_steps:
		executor.step()
		steps += 1
	_check(steps < max_steps, "Executor excedeu o limite de segurança do teste.")
	return executor


func _run_executor_to_completion(executor, max_steps: int = 10000) -> void:
	var steps := 0
	while executor.is_active() and not executor.is_suspended() and steps < max_steps:
		executor.step()
		steps += 1
	_check(steps < max_steps, "Executor retomado excedeu o limite de segurança do teste.")


func _resume_all_suspensions(source: String, bridge,
		max_steps: int = 20000) -> Dictionary:
	var executor = _prepare(source, "wait_test", bridge).executor
	var steps := 0
	var sleep_count := 0
	while executor.is_active() and steps < max_steps:
		if executor.is_suspended():
			var request = executor.pending_suspension()
			_check(request != null and executor.resume_suspension(int(request.token)),
				"Suspensão pendente deve possuir token retomável.")
			sleep_count += 1
		else:
			executor.step()
			steps += 1
	_check(steps < max_steps, "Executor com suspensões excedeu o limite de segurança.")
	_check(not executor.has_failure() and executor.is_finished(),
		"Executor com suspensões deveria concluir sem falha.")
	return {"executor": executor, "sleep_count": sleep_count}


func _value(executor, name: String):
	var result = executor.global_environment.lookup(name)
	_check(not result.has_failure(), "Binding '%s' deveria existir." % name)
	return result.value()


func _integer(executor, name: String) -> int:
	var value = _value(executor, name)
	return value.numeric_value if value is Values.IntegerValue else 0


func _float(executor, name: String) -> float:
	var value = _value(executor, name)
	return value.numeric_value if value is Values.FloatValue else 0.0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
