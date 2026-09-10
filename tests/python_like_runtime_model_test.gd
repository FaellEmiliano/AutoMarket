extends Node


const Values = preload("res://interpreter/python_like/runtime/python_like_values.gd")
const Collections = preload("res://interpreter/python_like/runtime/python_like_collections.gd")
const LexicalEnvironment = preload("res://interpreter/python_like/runtime/python_like_environment.gd")
const FunctionValue = preload("res://interpreter/python_like/runtime/python_like_function.gd")
const RuntimeFailure = preload("res://interpreter/python_like/runtime/python_like_runtime_failure.gd")
const RuntimeResult = preload("res://interpreter/python_like/runtime/python_like_runtime_result.gd")
const RuntimeLifecycle = preload("res://interpreter/python_like/runtime/python_like_runtime_lifecycle.gd")
const Ast = preload("res://interpreter/python_like/ast/python_like_ast_nodes.gd")

var _failures: Array[String] = []


func _ready() -> void:
	_test_scalar_values()
	_test_result_and_failure_states()
	_test_list_identity_and_mutation()
	_test_list_copy_operations_and_cycles()
	_test_dictionary_keys_and_order()
	_test_dictionary_operations_and_equality()
	_test_lexical_environments()
	_test_function_values_and_closures()
	_test_explicit_lifecycle()

	if _failures.is_empty():
		print("PYTHON_LIKE_RUNTIME_MODEL_TEST_OK")
	else:
		push_error("\n".join(_failures))
	await get_tree().process_frame
	get_tree().quit()


func _test_scalar_values() -> void:
	var zero := Values.IntegerValue.new(0)
	var one := Values.IntegerValue.new(1)
	var float_one := Values.FloatValue.new(1.0)
	var false_value := Values.boolean_value(false)
	var true_value := Values.boolean_value(true)
	var empty_string := Values.StringValue.new("")
	var text := Values.StringValue.new("linha\n'item'\\")
	var none := Values.none_value()

	_check(zero.type_name() == "int" and not zero.is_truthy() and zero.representation() == "0",
		"Inteiro deve expor tipo, truthiness e representação.")
	_check(float_one.type_name() == "float" and float_one.representation() == "1.0",
		"Float integral deve preservar o sufixo .0.")
	_check(false_value.type_name() == "bool" and not false_value.is_truthy()
		and true_value.is_truthy() and true_value.representation() == "True",
		"Booleanos devem ser singletons com grafia Python.")
	_check(one.semantic_equals(float_one) and one.semantic_equals(true_value)
		and Values.FloatValue.new(0.0).semantic_equals(false_value),
		"Igualdade numérica deve incluir int, float e bool.")
	_check(not empty_string.is_truthy() and text.display_text() == "linha\n'item'\\"
		and text.representation() == "'linha\\n\\'item\\'\\\\'",
		"Strings devem diferenciar texto de print e repr escapada.")
	_check(none == Values.none_value() and none.type_name() == "NoneType"
		and not none.is_truthy() and none.representation() == "None",
		"None deve ser singleton falso com representação própria.")
	_check(not one.has_identity() and none.identity_id() == 0,
		"Escalares imutáveis não devem expor identidade mutável.")
	none.discard()
	_check(not none.is_discarded() and Values.none_value() == none,
		"Descarte de runtime não deve invalidar singletons imutáveis.")


func _test_result_and_failure_states() -> void:
	var none_result = RuntimeResult.success(Values.none_value())
	var pending = RuntimeResult.no_value()
	var failure := RuntimeFailure.new(
		"name", "NAME_NOT_DEFINED", "Nome ausente.", 3, 7, 4,
		"script_1", "Principal", "runtime_1", {"name": "item"}
	)
	var failed = RuntimeResult.failed(failure)
	_check(none_result.has_value() and none_result.value() is Values.NoneValue,
		"None deve ser um resultado com valor, não ausência interna.")
	_check(pending.has_no_value() and not pending.has_value() and not pending.has_failure(),
		"Operação sem resultado deve possuir estado próprio.")
	_check(failed.has_failure() and failed.failure() == failure and failed.value() == null,
		"Falha deve permanecer distinta de valor e ausência.")
	var data := failure.to_dictionary()
	_check(data.code == "NAME_NOT_DEFINED" and data.line == 3 and data.column == 7
		and data.script_id == "script_1" and data.details.name == "item",
		"Falha estruturada deve preservar posição e contexto neutro.")


func _test_list_identity_and_mutation() -> void:
	var first := Collections.ListValue.new()
	var alias = first
	first.append(Values.IntegerValue.new(1))
	first.append(Values.IntegerValue.new(2))
	alias.append(Values.IntegerValue.new(3))
	_check(first.has_identity() and first.is_identical_to(alias) and first.size() == 3,
		"Aliases devem compartilhar identidade e mutações da lista.")
	_check(first.representation() == "[1, 2, 3]" and first.is_truthy(),
		"Lista deve usar representação Python-like ordenada.")
	_check(first.get_item(Values.IntegerValue.new(-1)).value().numeric_value == 3,
		"Índice negativo deve contar a partir do fim.")
	var version := first.mutation_version
	first.set_item(Values.IntegerValue.new(0), Values.StringValue.new("novo"))
	_check(first.mutation_version == version + 1
		and first.representation() == "['novo', 2, 3]",
		"Substituição por índice deve mutar o alias e incrementar a versão.")
	_check(first.get_item(Values.StringValue.new("0")).failure().code == "INDEX_NOT_INTEGER",
		"Índice não inteiro deve gerar falha estruturada.")
	_check(first.get_item(Values.IntegerValue.new(9)).failure().code == "INDEX_OUT_OF_RANGE",
		"Índice fora do intervalo deve gerar falha estruturada.")
	_check(first.pop_last().value().numeric_value == 3 and first.size() == 2,
		"pop sem índice deve remover e retornar o último elemento.")


func _test_list_copy_operations_and_cycles() -> void:
	var inner := Collections.ListValue.new()
	inner.append(Values.IntegerValue.new(7))
	var outer := Collections.ListValue.new()
	outer.append(inner)
	var repeated = outer.repeated(2).value()
	_check(repeated.size() == 2
		and repeated.get_item(Values.IntegerValue.new(0)).value().is_identical_to(inner)
		and repeated.get_item(Values.IntegerValue.new(1)).value().is_identical_to(inner),
		"Repetição deve criar lista nova preservando referências internas.")
	var concatenated = outer.concatenated(repeated).value()
	_check(not concatenated.is_identical_to(outer) and concatenated.size() == 3,
		"Concatenação deve criar uma nova lista.")

	var left_cycle := Collections.ListValue.new()
	var right_cycle := Collections.ListValue.new()
	left_cycle.append(left_cycle)
	right_cycle.append(right_cycle)
	_check(left_cycle.representation() == "[[...]]",
		"Representação de lista deve abreviar ciclo direto.")
	_check(left_cycle.semantic_equals(right_cycle),
		"Igualdade estrutural deve terminar para ciclos equivalentes.")
	right_cycle.append(Values.none_value())
	_check(not left_cycle.semantic_equals(right_cycle),
		"Proteção de ciclos não pode esconder divergência estrutural.")
	left_cycle.discard()
	right_cycle.discard()


func _test_dictionary_keys_and_order() -> void:
	var dictionary := Collections.DictionaryValue.new()
	dictionary.set_item(Values.IntegerValue.new(1), Values.StringValue.new("int"))
	dictionary.set_item(Values.boolean_value(true), Values.StringValue.new("bool"))
	dictionary.set_item(Values.StringValue.new("x"), Values.IntegerValue.new(2))
	dictionary.set_item(Values.none_value(), Values.IntegerValue.new(3))
	_check(dictionary.size() == 3,
		"1 e True devem compartilhar a mesma entrada numérica.")
	_check(dictionary.representation() == "{1: 'bool', 'x': 2, None: 3}",
		"Substituição deve preservar a chave e a ordem de inserção originais.")
	_check(dictionary.get_item(Values.FloatValue.new(1.0)).value().string_value == "bool",
		"1.0 deve consultar a mesma chave que 1 e True.")
	_check(dictionary.contains_key(Values.StringValue.new("x")).value().boolean_value,
		"Associação em dicionário deve testar somente chaves.")
	var invalid_key := Collections.ListValue.new()
	_check(dictionary.set_item(invalid_key, Values.none_value()).failure().code
		== "TYPE_UNHASHABLE_KEY",
		"Coleções não podem ser chaves de dicionário no MVP.")


func _test_dictionary_operations_and_equality() -> void:
	var first := Collections.DictionaryValue.new()
	first.set_item(Values.StringValue.new("a"), Values.IntegerValue.new(1))
	first.set_item(Values.StringValue.new("b"), Values.IntegerValue.new(2))
	var second := Collections.DictionaryValue.new()
	second.set_item(Values.StringValue.new("b"), Values.IntegerValue.new(2))
	second.set_item(Values.StringValue.new("a"), Values.IntegerValue.new(1))
	_check(first.semantic_equals(second),
		"Igualdade de dicionário não deve depender da ordem de inserção.")
	_check(first.get_or_none(Values.StringValue.new("missing")).value() is Values.NoneValue,
		"dict.get ausente deve retornar None real.")
	var fallback := Values.StringValue.new("fallback")
	_check(first.get_or(Values.StringValue.new("missing"), fallback).value() == fallback,
		"dict.get com fallback deve preservar a referência fornecida.")
	_check(first.pop(Values.StringValue.new("a")).value().numeric_value == 1,
		"dict.pop deve remover e retornar o valor.")
	_check(first.get_item(Values.StringValue.new("a")).failure().code == "KEY_NOT_FOUND",
		"Consulta de chave ausente deve produzir KEY_NOT_FOUND.")

	var cycle := Collections.DictionaryValue.new()
	cycle.set_item(Values.StringValue.new("self"), cycle)
	_check(cycle.representation() == "{'self': {...}}",
		"Representação de dicionário deve abreviar ciclo direto.")
	cycle.discard()


func _test_lexical_environments() -> void:
	var global := LexicalEnvironment.new(null, "module")
	global.define("preco", Values.IntegerValue.new(10))
	var function_scope = global.create_child("calcular", ["local"])
	_check(function_scope.lookup("preco").value().numeric_value == 10,
		"Lookup deve seguir o pai léxico capturado.")
	_check(function_scope.lookup("local").failure().code == "NAME_UNBOUND_LOCAL",
		"Local conhecido sem binding não deve cair no global homônimo.")
	global.define("local", Values.IntegerValue.new(99))
	_check(function_scope.lookup("local").failure().code == "NAME_UNBOUND_LOCAL",
		"Binding global homônimo não pode esconder local ainda não atribuído.")
	function_scope.assign_local("local", Values.IntegerValue.new(2))
	_check(function_scope.lookup("local").value().numeric_value == 2
		and global.lookup("local").value().numeric_value == 99,
		"Atribuição local não deve reatribuir o ambiente capturado.")
	_check(global.lookup("ausente").failure().code == "NAME_NOT_DEFINED",
		"Nome ausente deve ser falha, não null ou None.")

	var other_global := LexicalEnvironment.new(null, "module")
	_check(other_global.lookup("preco").failure().code == "NAME_NOT_DEFINED",
		"Ambientes globais de runtimes distintos não devem compartilhar bindings.")
	var shared_list := Collections.ListValue.new()
	global.define("itens", shared_list)
	function_scope.lookup("itens").value().append(Values.IntegerValue.new(1))
	_check(global.lookup("itens").value().size() == 1,
		"Closure pode mutar coleção capturada sem reatribuir o binding externo.")


func _test_function_values_and_closures() -> void:
	var global := LexicalEnvironment.new(null, "module")
	global.define("capturado", Values.IntegerValue.new(1))
	var span := Ast.SourceSpan.new(0, 20, 1, 1, 2, 13)
	var body := Ast.BlockNode.new([], span, span, span, span)
	var parameter := Ast.ParameterNode.new("valor", Ast.SourceSpan.new(6, 11, 1, 7, 1, 12))
	var function := FunctionValue.new("somar", [parameter], body, span, global)
	var same = function
	var other := FunctionValue.new("somar", [parameter], body, span, global)
	_check(function.type_name() == "function" and function.is_truthy()
		and function.representation() == "<function somar>",
		"Função deve ter tipo, truthiness e representação determinística.")
	_check(function.parameter_count() == 1 and function.parameter_name_at(0) == "valor"
		and function.body == body and function.source_span == span,
		"Função deve preservar parâmetros, body e span.")
	_check(function.semantic_equals(same) and not function.semantic_equals(other),
		"Igualdade de funções deve usar identidade.")
	var call_environment = function.create_call_environment().value()
	_check(call_environment.parent == global
		and call_environment.lookup("capturado").value().numeric_value == 1,
		"Ambiente de chamada deve apontar para a closure léxica, não para o chamador.")
	_check(call_environment.lookup("valor").failure().code == "NAME_UNBOUND_LOCAL",
		"Parâmetros devem nascer como locais ainda sem binding.")
	global.assign_local("capturado", Values.IntegerValue.new(2))
	_check(call_environment.lookup("capturado").value().numeric_value == 2,
		"Closure deve capturar o ambiente por referência.")


func _test_explicit_lifecycle() -> void:
	var lifecycle := RuntimeLifecycle.new()
	var environment = lifecycle.track(LexicalEnvironment.new(null, "module"))
	var collection = lifecycle.track(Collections.ListValue.new())
	var function = lifecycle.track(FunctionValue.new("f", [], null, null, environment))
	environment.define("f", function)
	collection.append(collection)
	_check(lifecycle.tracked_count() == 3,
		"Ciclo de vida deve rastrear objetos que podem formar ciclos.")
	lifecycle.discard_all()
	_check(lifecycle.is_discarded() and lifecycle.tracked_count() == 0
		and environment.is_discarded() and collection.is_discarded()
		and function.is_discarded(),
		"Encerramento deve romper coleções, ambientes e closures idempotentemente.")
	lifecycle.discard_all()
	_check(collection.append(Values.none_value()).failure().code == "INTERNAL_INVALID_STATE",
		"Operação em valor descartado deve falhar sem reutilizar null.")
	_check(function.create_call_environment().failure().code == "INTERNAL_INVALID_STATE",
		"Função descartada deve produzir falha interna estruturada.")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
