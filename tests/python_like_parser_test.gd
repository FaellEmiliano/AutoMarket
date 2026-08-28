extends Node


const LexerScript = preload("res://interpreter/python_like/lexer/python_like_lexer.gd")
const ParserScript = preload("res://interpreter/python_like/parser/python_like_parser.gd")
const Ast = preload("res://interpreter/python_like/ast/python_like_ast_nodes.gd")

var _failures: Array[String] = []


func _ready() -> void:
	_test_empty_program()
	_test_literals_and_collections()
	_test_simple_and_compound_assignments()
	_test_expression_precedence()
	_test_power_associativity_and_unary_precedence()
	_test_chained_comparison_shape()
	_test_postfix_chains()
	_test_statement_and_program_spans()
	_test_structured_errors_and_recovery()
	_test_unsupported_stage_constructs()
	_test_unsupported_python_features()
	_test_all_nodes_have_valid_spans()

	if _failures.is_empty():
		print("PYTHON_LIKE_PARSER_TEST_OK")
	else:
		push_error("\n".join(_failures))

	await get_tree().process_frame
	get_tree().quit()


func _test_empty_program() -> void:
	var result := _parse("")
	_check(result.parser.errors.is_empty(), "Programa vazio não deve produzir erro.")
	_check(result.program is Ast.ProgramNode, "Parser deve produzir ProgramNode.")
	_check(result.program.statements.is_empty(), "Programa vazio não deve conter statements.")
	_check_span(result.program.span, 0, 0, 1, 1, 1, 1, "Span do programa vazio")


func _test_literals_and_collections() -> void:
	var result := _parse("1\n2.5\n'oi'\nTrue\nFalse\nNone\n[1, 2,]\n{'a': 1, 'b': [False],}\n(3 + 4)\n")
	_check_no_errors(result, "Literais e coleções")
	var statements: Array = result.program.statements
	_check(statements.size() == 9, "Todos os literais devem gerar statements.")
	_check(statements[0].expression is Ast.IntegerLiteralNode and statements[0].expression.value == 1,
		"Inteiro deve preservar tipo e valor.")
	_check(statements[1].expression is Ast.FloatLiteralNode and statements[1].expression.value == 2.5,
		"Float deve preservar tipo e valor.")
	_check(statements[2].expression is Ast.StringLiteralNode and statements[2].expression.value == "oi",
		"String deve preservar tipo e valor normalizado.")
	_check(statements[3].expression is Ast.BooleanLiteralNode and statements[3].expression.value,
		"True deve produzir BooleanLiteralNode.")
	_check(statements[4].expression is Ast.BooleanLiteralNode and not statements[4].expression.value,
		"False deve produzir BooleanLiteralNode.")
	_check(statements[5].expression is Ast.NoneLiteralNode, "None deve possuir nó próprio.")
	var list = statements[6].expression
	_check(list is Ast.ListLiteralNode and list.elements.size() == 2,
		"Lista deve aceitar elementos e vírgula final.")
	var dictionary = statements[7].expression
	_check(dictionary is Ast.DictionaryLiteralNode and dictionary.entries.size() == 2,
		"Dicionário deve preservar entradas ordenadas.")
	_check(dictionary.entries[0] is Ast.DictionaryEntryNode,
		"Entrada de dicionário deve ser nó reconhecível.")
	_check(dictionary.entries[1].value is Ast.ListLiteralNode,
		"Valores de dicionário devem aceitar expressões compostas.")
	_check(statements[8].expression is Ast.GroupExpressionNode,
		"Parênteses devem ser preservados como agrupamento posicional.")


func _test_simple_and_compound_assignments() -> void:
	var source := "x = 1\nx += 2\nx -= 3\nx *= 4\nx /= 5\nx //= 6\nx %= 7\nlista[-1] = 8\n"
	var result := _parse(source)
	_check_no_errors(result, "Atribuições")
	var statements: Array = result.program.statements
	_check(statements.size() == 8, "Todas as atribuições devem ser preservadas.")
	_check(statements[0] is Ast.SimpleAssignmentNode and statements[0].operator == "=",
		"Atribuição simples deve possuir nó próprio.")
	var expected := ["+=", "-=", "*=", "/=", "//=", "%="]
	for index in range(expected.size()):
		var statement = statements[index + 1]
		_check(statement is Ast.CompoundAssignmentNode and statement.operator == expected[index],
			"Operador composto %s deve ser preservado." % expected[index])
	_check(statements[7].target is Ast.IndexExpressionNode,
		"Indexação deve ser alvo válido de atribuição.")
	_check(statements[7].target.index is Ast.UnaryExpressionNode,
		"Índice negativo deve preservar o operador unário.")


func _test_expression_precedence() -> void:
	var result := _parse("resultado = 1 or 2 and not 3 < 4 + 5 * -6 ** 2\n")
	_check_no_errors(result, "Precedência completa")
	var expression = result.program.statements[0].value
	_check(expression is Ast.LogicalExpressionNode and expression.operator == "or",
		"or deve ter a menor precedência.")
	_check(expression.right is Ast.LogicalExpressionNode and expression.right.operator == "and",
		"and deve ligar antes de or.")
	var not_expression = expression.right.right
	_check(not_expression is Ast.UnaryExpressionNode and not_expression.operator == "not",
		"not deve ligar acima de and e abaixo de comparação.")
	var comparison = not_expression.operand
	_check(comparison is Ast.ComparisonExpressionNode and comparison.operators == ["<"],
		"Comparação deve ligar acima de not.")
	var sum = comparison.operands[1]
	_check(sum is Ast.BinaryExpressionNode and sum.operator == "+",
		"Adição deve permanecer abaixo da multiplicação.")
	_check(sum.right is Ast.BinaryExpressionNode and sum.right.operator == "*",
		"Multiplicação deve ligar antes da adição.")
	_check(sum.right.right is Ast.UnaryExpressionNode and sum.right.right.operator == "-",
		"Sinal unário deve envolver a potência do operando.")
	_check(sum.right.right.operand is Ast.BinaryExpressionNode and sum.right.right.operand.operator == "**",
		"Potência deve ligar antes do sinal unário.")


func _test_power_associativity_and_unary_precedence() -> void:
	var result := _parse("a = -2 ** 2\nb = 2 ** -1\nc = 2 ** 3 ** 2\n")
	_check_no_errors(result, "Potência e unários")
	var negative_power = result.program.statements[0].value
	_check(negative_power is Ast.UnaryExpressionNode and negative_power.operand is Ast.BinaryExpressionNode,
		"-2 ** 2 deve ser representado como -(2 ** 2).")
	var negative_exponent = result.program.statements[1].value
	_check(negative_exponent is Ast.BinaryExpressionNode and negative_exponent.right is Ast.UnaryExpressionNode,
		"2 ** -1 deve aceitar fator unário à direita.")
	var right_associative = result.program.statements[2].value
	_check(right_associative is Ast.BinaryExpressionNode
		and right_associative.right is Ast.BinaryExpressionNode
		and right_associative.right.operator == "**",
		"Potência deve associar à direita.")


func _test_chained_comparison_shape() -> void:
	var result := _parse("a < f() < c not in itens\n")
	_check_no_errors(result, "Comparação encadeada")
	var comparison = result.program.statements[0].expression
	_check(comparison is Ast.ComparisonExpressionNode, "Comparação deve possuir nó próprio.")
	_check(comparison.operands.size() == 4, "Comparação encadeada deve preservar cada operando uma vez.")
	_check(comparison.operators == ["<", "<", "not in"],
		"Comparação deve preservar operadores, incluindo not in.")
	_check(comparison.operands[1] is Ast.CallExpressionNode,
		"Operando intermediário chamável não pode ser duplicado por dessugaring.")
	_check(comparison.operator_spans[2].start_column == 13
		and comparison.operator_spans[2].end_column == 19,
		"Span de not in deve cobrir os dois tokens.")


func _test_postfix_chains() -> void:
	var result := _parse("produtos[codigo][\"preco\"]\nobj.metodo(1, 2,).itens[0]\n")
	_check_no_errors(result, "Cadeias postfix")
	var nested_index = result.program.statements[0].expression
	_check(nested_index is Ast.IndexExpressionNode
		and nested_index.collection is Ast.IndexExpressionNode,
		"Indexações postfix sucessivas devem ser aninhadas da esquerda para a direita.")
	_check(nested_index.collection.collection is Ast.IdentifierNode,
		"A cadeia deve preservar a coleção base.")
	var chain = result.program.statements[1].expression
	_check(chain is Ast.IndexExpressionNode and chain.collection is Ast.AttributeExpressionNode,
		"Acesso, chamada, novo acesso e índice devem compor uma única cadeia.")
	_check(chain.collection.object is Ast.CallExpressionNode,
		"Atributo após chamada deve preservar a chamada como objeto.")
	_check(chain.collection.object.callee is Ast.AttributeExpressionNode,
		"Chamada de método deve preservar o acesso a atributo como callee.")


func _test_statement_and_program_spans() -> void:
	var result := _parse("\n  # comentário\ntotal = (1 + 2) * 3\nprodutos[codigo][\"preco\"]\n")
	_check_no_errors(result, "Spans compostos")
	var assignment = result.program.statements[0]
	_check_span(assignment.span, 16, 35, 3, 1, 3, 20, "Span da atribuição")
	_check_span(assignment.value.span, 24, 35, 3, 9, 3, 20, "Span da expressão composta")
	_check_span(assignment.value.left.span, 24, 31, 3, 9, 3, 16, "Span do agrupamento")
	var postfix = result.program.statements[1].expression
	_check_span(postfix.span, 36, 61, 4, 1, 4, 26, "Span da cadeia postfix")
	_check_span(result.program.span, 16, 61, 3, 1, 4, 26, "Span do programa")


func _test_structured_errors_and_recovery() -> void:
	var result := _parse("x =\ny = 2\n[1] + 2 = 3\nz = 4\n")
	_check(_error_codes(result.parser).has("PARSE_EXPECTED_EXPRESSION"),
		"Valor ausente deve produzir erro de expressão.")
	_check(_error_codes(result.parser).has("PARSE_INVALID_ASSIGNMENT_TARGET"),
		"Alvo inválido deve produzir erro específico.")
	_check(result.parser.errors[0].category == "syntax",
		"Erro de parser deve possuir categoria neutra.")
	_check(result.parser.errors[0].line == 1 and result.parser.errors[0].column == 4,
		"Erro deve apontar linha e coluna do token problemático.")
	_check(result.parser.errors[0].start_offset == 3 and result.parser.errors[0].end_offset == 4,
		"Erro deve preservar offsets posicionais.")
	_check(result.program.statements.size() == 2,
		"Recuperação por NEWLINE deve preservar statements válidos posteriores.")
	_check(result.program.statements[0].target.name == "y"
		and result.program.statements[1].target.name == "z",
		"Recuperação não pode fabricar nós neutros.")


func _test_unsupported_stage_constructs() -> void:
	var samples := {
		"if True:\n    x = 1\n": "if",
		"elif True:\n": "elif",
		"else:\n": "else",
		"while True:\n": "while",
		"for x in itens:\n": "for",
		"def f():\n": "def",
		"return 1\n": "return",
		"break\n": "break",
		"continue\n": "continue",
		"x if condicao else y\n": "if",
		"f(x for x in itens)\n": "for",
	}
	for source in samples:
		var result := _parse(source)
		var matching = result.parser.errors.filter(
			func(error): return error.code == "PARSE_UNSUPPORTED_STAGE"
		)
		_check(not matching.is_empty(),
			"Construção %s deve falhar de forma estruturada nesta etapa." % samples[source])
		_check(result.parser._position <= result.parser.tokens.size(),
			"Construção não suportada não pode travar o parser.")


func _test_unsupported_python_features() -> void:
	var samples := {
		"await(1)\n": "await",
		"x = [n for n in itens]\n": "comprehension",
		"x = itens[1:2]\n": "slicing",
		"f(valor=1)\n": "named_arguments",
		"x = (1, 2)\n": "tuple",
		"x = y = 1\n": "chained_assignment",
	}
	for source in samples:
		var result := _parse(source)
		var matching = result.parser.errors.filter(
			func(error):
				return (
					error.code == "PARSE_UNSUPPORTED_FEATURE"
					and error.details.get("feature") == samples[source]
				)
		)
		_check(not matching.is_empty(),
			"Recurso %s deve produzir erro estruturado específico." % samples[source])


func _test_all_nodes_have_valid_spans() -> void:
	var result := _parse("dados = {'x': [obj.metodo(1)[0]],}\nvalor += not False or 2 in dados\n")
	_check_no_errors(result, "Validação recursiva de spans")
	_walk_and_check_spans(result.program, "program")


func _walk_and_check_spans(node, path: String) -> void:
	_check(node != null and node.span != null, "%s deve possuir span." % path)
	if node == null or node.span == null:
		return
	_check(node.span.start_offset <= node.span.end_offset,
		"%s deve possuir offsets ordenados." % path)
	if node is Ast.ProgramNode:
		for index in range(node.statements.size()):
			_walk_and_check_spans(node.statements[index], "%s.statement[%d]" % [path, index])
	elif node is Ast.ExpressionStatementNode:
		_walk_and_check_spans(node.expression, path + ".expression")
	elif node is Ast.SimpleAssignmentNode or node is Ast.CompoundAssignmentNode:
		_walk_and_check_spans(node.target, path + ".target")
		_walk_and_check_spans(node.value, path + ".value")
	elif node is Ast.ListLiteralNode:
		for index in range(node.elements.size()):
			_walk_and_check_spans(node.elements[index], "%s.element[%d]" % [path, index])
	elif node is Ast.DictionaryLiteralNode:
		for index in range(node.entries.size()):
			_walk_and_check_spans(node.entries[index], "%s.entry[%d]" % [path, index])
	elif node is Ast.DictionaryEntryNode:
		_walk_and_check_spans(node.key, path + ".key")
		_walk_and_check_spans(node.value, path + ".value")
	elif node is Ast.GroupExpressionNode:
		_walk_and_check_spans(node.expression, path + ".grouped")
	elif node is Ast.UnaryExpressionNode:
		_walk_and_check_spans(node.operand, path + ".operand")
	elif node is Ast.BinaryExpressionNode or node is Ast.LogicalExpressionNode:
		_walk_and_check_spans(node.left, path + ".left")
		_walk_and_check_spans(node.right, path + ".right")
	elif node is Ast.ComparisonExpressionNode:
		for index in range(node.operands.size()):
			_walk_and_check_spans(node.operands[index], "%s.operand[%d]" % [path, index])
	elif node is Ast.CallExpressionNode:
		_walk_and_check_spans(node.callee, path + ".callee")
		for index in range(node.arguments.size()):
			_walk_and_check_spans(node.arguments[index], "%s.argument[%d]" % [path, index])
	elif node is Ast.IndexExpressionNode:
		_walk_and_check_spans(node.collection, path + ".collection")
		_walk_and_check_spans(node.index, path + ".index")
	elif node is Ast.AttributeExpressionNode:
		_walk_and_check_spans(node.object, path + ".object")


func _parse(source: String) -> Dictionary:
	var lexer = LexerScript.new(source)
	var tokens = lexer.tokenize()
	_check(lexer.errors.is_empty(), "Fonte do teste não deveria ter erros léxicos: %s" % [lexer.errors])
	var parser = ParserScript.new(tokens)
	var program = parser.parse()
	return {"lexer": lexer, "parser": parser, "program": program}


func _check_no_errors(result: Dictionary, label: String) -> void:
	_check(result.parser.errors.is_empty(), "%s: erros inesperados %s." % [label, _error_codes(result.parser)])


func _error_codes(parser) -> Array[String]:
	var result: Array[String] = []
	for error in parser.errors:
		result.append(error.code)
	return result


func _check_span(span, start_offset: int, end_offset: int, start_line: int,
		start_column: int, end_line: int, end_column: int, label: String) -> void:
	_check(span.start_offset == start_offset and span.end_offset == end_offset
		and span.start_line == start_line and span.start_column == start_column
		and span.end_line == end_line and span.end_column == end_column,
		"%s incorreto: %s." % [label, span.to_dictionary()])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
