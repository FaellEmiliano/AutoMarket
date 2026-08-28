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
	_test_if_elif_else()
	_test_while_and_for()
	_test_nested_compound_statements()
	_test_deep_nesting_progress()
	_test_block_and_compound_spans()
	_test_block_aware_error_recovery()
	_test_invalid_for_targets_and_loop_else()
	_test_deferred_constructs_and_stray_clauses()
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


func _test_if_elif_else() -> void:
	var source := (
		"if total > 50:\n"
		+ "    desconto = 1\n"
		+ "elif total == 50:\n"
		+ "    desconto = 2\n"
		+ "elif total > 0:\n"
		+ "    desconto = 3\n"
		+ "else:\n"
		+ "    desconto = 4\n"
		+ "final = desconto\n"
	)
	var result := _parse(source)
	_check_no_errors(result, "if/elif/else")
	_check(result.program.statements.size() == 2,
		"if completo e statement posterior devem permanecer no programa.")
	var statement = result.program.statements[0]
	_check(statement is Ast.IfStatementNode, "if deve produzir IfStatementNode.")
	_check(statement.if_branch is Ast.ConditionalBranchNode
		and statement.if_branch.keyword == "if",
		"Ramo principal deve preservar sua identidade.")
	_check(statement.if_branch.condition is Ast.ComparisonExpressionNode,
		"Condição principal deve permanecer separada do body.")
	_check(statement.if_branch.body is Ast.BlockNode
		and statement.if_branch.body.statements.size() == 1,
		"Body principal deve ser BlockNode não vazio.")
	_check(statement.elif_branches.size() == 2,
		"Múltiplos elif devem ser preservados em ordem.")
	_check(statement.elif_branches[0].keyword == "elif"
		and statement.elif_branches[1].keyword == "elif",
		"elif não pode ser convertido em if artificial aninhado.")
	_check(statement.else_branch is Ast.ElseBranchNode
		and statement.else_branch.body.statements.size() == 1,
		"else opcional deve possuir ramo e body próprios.")
	_check(statement.if_branch.keyword_span.start_column == 1
		and statement.if_branch.colon_span.start_column == 14,
		"Ramo principal deve preservar spans de keyword e dois-pontos.")
	_check(statement.else_branch.keyword_span.start_line == 7
		and statement.else_branch.colon_span.start_column == 5,
		"else deve preservar spans de keyword e dois-pontos.")


func _test_while_and_for() -> void:
	var result := _parse(
		"while ativo:\n"
		+ "    tentativas += 1\n"
		+ "for produto in produtos:\n"
		+ "    print(produto)\n"
	)
	_check_no_errors(result, "while e for")
	_check(result.program.statements.size() == 2, "while e for devem gerar dois statements.")
	var while_statement = result.program.statements[0]
	_check(while_statement is Ast.WhileStatementNode,
		"while deve produzir WhileStatementNode.")
	_check(while_statement.condition is Ast.IdentifierNode
		and while_statement.body.statements[0] is Ast.CompoundAssignmentNode,
		"while deve preservar condição e body.")
	_check(while_statement.keyword_span.start_column == 1
		and while_statement.colon_span.start_column == 12,
		"while deve preservar keyword e dois-pontos.")
	var for_statement = result.program.statements[1]
	_check(for_statement is Ast.ForStatementNode, "for deve produzir ForStatementNode.")
	_check(for_statement.target is Ast.IdentifierNode and for_statement.target.name == "produto",
		"Alvo de for deve ser um único IdentifierNode.")
	_check(for_statement.iterable is Ast.IdentifierNode
		and for_statement.iterable.name == "produtos",
		"Expressão iterável deve permanecer separada do alvo.")
	_check(for_statement.body.statements[0] is Ast.ExpressionStatementNode,
		"Body de for deve aceitar statements simples.")
	_check(for_statement.keyword_span.start_line == 3
		and for_statement.in_span.start_column == 13
		and for_statement.colon_span.start_column == 24,
		"for deve preservar spans de for, in e dois-pontos.")


func _test_nested_compound_statements() -> void:
	var source := (
		"for item in itens:\n"
		+ "    if item:\n"
		+ "        while ativo:\n"
		+ "            processar(item)\n"
		+ "    else:\n"
		+ "        ignorar(item)\n"
		+ "fim = True\n"
	)
	var result := _parse(source)
	_check_no_errors(result, "Aninhamento de statements compostos")
	var for_statement = result.program.statements[0]
	var if_statement = for_statement.body.statements[0]
	var while_statement = if_statement.if_branch.body.statements[0]
	_check(for_statement is Ast.ForStatementNode
		and if_statement is Ast.IfStatementNode
		and while_statement is Ast.WhileStatementNode,
		"for, if e while devem aceitar aninhamento recursivo.")
	_check(while_statement.body.statements[0].expression is Ast.CallExpressionNode,
		"Statement simples deve permanecer no bloco mais interno.")
	_check(if_statement.else_branch.body.statements[0].expression is Ast.CallExpressionNode,
		"else deve se associar ao if interno no mesmo nível de indentação.")
	_check(result.program.statements[1] is Ast.SimpleAssignmentNode,
		"Dedents múltiplos devem devolver o parser ao nível superior.")


func _test_deep_nesting_progress() -> void:
	var source := ""
	var depth := 48
	for level in range(depth):
		source += "    ".repeat(level) + "if True:\n"
	source += "    ".repeat(depth) + "valor = 1\n"
	var result := _parse(source)
	_check_no_errors(result, "Aninhamento profundo")
	var statement = result.program.statements[0]
	for level in range(depth):
		_check(statement is Ast.IfStatementNode,
			"Nível composto %d deve permanecer representado." % level)
		if not statement is Ast.IfStatementNode:
			return
		statement = statement.if_branch.body.statements[0]
	_check(statement is Ast.SimpleAssignmentNode,
		"Parser deve concluir o statement após todos os níveis sem guard artificial.")


func _test_block_and_compound_spans() -> void:
	var result := _parse("if True:\n    x = 1\ny = 2\n")
	_check_no_errors(result, "Spans de bloco e statement composto")
	var statement = result.program.statements[0]
	var block = statement.if_branch.body
	_check_span(block.span, 8, 19, 1, 9, 3, 1, "Span da suite")
	_check_span(block.newline_span, 8, 9, 1, 9, 2, 1, "Span do NEWLINE da suite")
	_check_span(block.indent_span, 9, 13, 2, 1, 2, 5, "Span do INDENT da suite")
	_check_span(block.dedent_span, 19, 19, 3, 1, 3, 1, "Span do DEDENT da suite")
	_check_span(statement.span, 0, 19, 1, 1, 3, 1, "Span do if completo")
	_check_span(result.program.span, 0, 24, 1, 1, 3, 6, "Span do programa composto")


func _test_block_aware_error_recovery() -> void:
	var missing_indent := _parse("if True:\nprint('fora')\nvalido = 1\n")
	_check(_error_codes(missing_indent.parser).has("PARSE_EXPECTED_INDENT"),
		"Suite sem indentação deve produzir PARSE_EXPECTED_INDENT.")
	_check(missing_indent.program.statements.size() == 2,
		"Statements sem indentação devem permanecer no nível externo durante recuperação.")

	var inline_suite := _parse("if True: print('inline')\nvalido = 1\n")
	_check(_error_codes(inline_suite.parser).has("PARSE_INLINE_SUITE_NOT_SUPPORTED"),
		"Suite inline deve produzir diagnóstico específico.")
	_check(inline_suite.program.statements.size() == 1
		and inline_suite.program.statements[0] is Ast.SimpleAssignmentNode,
		"Conteúdo inline inválido não pode vazar como statement independente.")

	var missing_colon := _parse("if True\nvalido = 1\n")
	_check(_error_codes(missing_colon.parser).has("PARSE_EXPECTED_COLON"),
		"Cabeçalho sem dois-pontos deve produzir PARSE_EXPECTED_COLON.")
	_check(missing_colon.program.statements.size() == 1,
		"Recuperação de cabeçalho deve preservar a próxima linha válida.")

	var nested_error := _parse(
		"if True:\n"
		+ "    x =\n"
		+ "    if False:\n"
		+ "        y = 1\n"
		+ "    z = 2\n"
		+ "depois = 3\n"
	)
	_check(_error_codes(nested_error.parser).has("PARSE_EXPECTED_EXPRESSION"),
		"Erro simples dentro de bloco deve continuar estruturado.")
	_check(nested_error.program.statements.size() == 2,
		"Erro interno não pode consumir o statement posterior ao bloco.")
	var recovered_if = nested_error.program.statements[0]
	_check(recovered_if.if_branch.body.statements.size() == 2
		and recovered_if.if_branch.body.statements[0] is Ast.IfStatementNode,
		"Recuperação deve parar no NEWLINE e respeitar DEDENTs aninhados.")


func _test_invalid_for_targets_and_loop_else() -> void:
	var unpacking := _parse(
		"for a, b in itens:\n"
		+ "    print(a)\n"
		+ "valido = 1\n"
	)
	_check(_has_error_with_feature(unpacking.parser, "for_unpacking"),
		"Desempacotamento no alvo de for deve ser rejeitado explicitamente.")
	_check(unpacking.program.statements.size() == 1,
		"Body de for inválido deve ser descartado pela recuperação de bloco.")

	var missing_in := _parse(
		"for item produtos:\n"
		+ "    print(item)\n"
		+ "valido = 1\n"
	)
	_check(_error_codes(missing_in.parser).has("PARSE_EXPECTED_IN"),
		"for sem in deve produzir PARSE_EXPECTED_IN.")
	_check(missing_in.program.statements.size() == 1,
		"Suite de for com cabeçalho inválido não pode vazar para o programa.")

	var loop_else := _parse(
		"while ativo:\n"
		+ "    tick()\n"
		+ "else:\n"
		+ "    finalizar()\n"
		+ "for item in itens:\n"
		+ "    usar(item)\n"
		+ "else:\n"
		+ "    finalizar()\n"
		+ "depois = 1\n"
	)
	_check(_has_error_with_feature(loop_else.parser, "while_else")
		and _has_error_with_feature(loop_else.parser, "for_else"),
		"while else e for else devem permanecer fora desta etapa.")
	_check(loop_else.program.statements.size() == 3,
		"Loops válidos devem ser preservados e bodies de else adiados descartados.")


func _test_deferred_constructs_and_stray_clauses() -> void:
	var deferred := _parse(
		"if True:\n"
		+ "    def futura():\n"
		+ "        interna = 1\n"
		+ "    return 1\n"
		+ "    break\n"
		+ "    continue\n"
		+ "    pass\n"
		+ "    valida = 2\n"
		+ "depois = 3\n"
	)
	for construction in ["def", "return", "break", "continue"]:
		var matching = deferred.parser.errors.filter(
			func(error): return error.details.get("construction") == construction
		)
		_check(not matching.is_empty(),
			"Construção adiada %s deve manter diagnóstico estruturado dentro de bloco." % construction)
	_check(_has_error_with_feature(deferred.parser, "pass"),
		"pass deve continuar reservado e não pode virar identificador.")
	_check(deferred.program.statements.size() == 2,
		"Construções adiadas não podem romper os limites da suite.")
	_check(deferred.program.statements[0].if_branch.body.statements.size() == 1,
		"Body de def adiado e statements inválidos não podem vazar para o if.")

	var stray := _parse(
		"elif condicao:\n"
		+ "    indevido = 1\n"
		+ "else:\n"
		+ "    indevido = 2\n"
		+ "valido = 3\n"
	)
	_check(_error_codes(stray.parser).has("PARSE_UNEXPECTED_ELIF")
		and _error_codes(stray.parser).has("PARSE_UNEXPECTED_ELSE"),
		"elif e else sem if associado devem produzir erros específicos.")
	_check(stray.program.statements.size() == 1,
		"Suites de cláusulas órfãs devem ser descartadas integralmente.")


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
		"def f():\n": "def",
		"return 1\n": "return",
		"break\n": "break",
		"continue\n": "continue",
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
		"x if condicao else y\n": "conditional_expression",
		"f(x for x in itens)\n": "generator_expression",
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
	var result := _parse(
		"if dados:\n"
		+ "    for item in dados:\n"
		+ "        while item:\n"
		+ "            usar({'x': [obj.metodo(1)[0]],})\n"
		+ "elif not False or 2 in dados:\n"
		+ "    valor += 1\n"
		+ "else:\n"
		+ "    valor = None\n"
	)
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
	elif node is Ast.BlockNode:
		for index in range(node.statements.size()):
			_walk_and_check_spans(node.statements[index], "%s.statement[%d]" % [path, index])
	elif node is Ast.IfStatementNode:
		_walk_and_check_spans(node.if_branch, path + ".if_branch")
		for index in range(node.elif_branches.size()):
			_walk_and_check_spans(node.elif_branches[index], "%s.elif[%d]" % [path, index])
		if node.else_branch != null:
			_walk_and_check_spans(node.else_branch, path + ".else_branch")
	elif node is Ast.ConditionalBranchNode:
		_walk_and_check_spans(node.condition, path + ".condition")
		_walk_and_check_spans(node.body, path + ".body")
	elif node is Ast.ElseBranchNode:
		_walk_and_check_spans(node.body, path + ".body")
	elif node is Ast.WhileStatementNode:
		_walk_and_check_spans(node.condition, path + ".condition")
		_walk_and_check_spans(node.body, path + ".body")
	elif node is Ast.ForStatementNode:
		_walk_and_check_spans(node.target, path + ".target")
		_walk_and_check_spans(node.iterable, path + ".iterable")
		_walk_and_check_spans(node.body, path + ".body")
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


func _has_error_with_feature(parser, feature: String) -> bool:
	return not parser.errors.filter(
		func(error): return error.details.get("feature") == feature
	).is_empty()


func _check_span(span, start_offset: int, end_offset: int, start_line: int,
		start_column: int, end_line: int, end_column: int, label: String) -> void:
	_check(span.start_offset == start_offset and span.end_offset == end_offset
		and span.start_line == start_line and span.start_column == start_column
		and span.end_line == end_line and span.end_column == end_column,
		"%s incorreto: %s." % [label, span.to_dictionary()])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
