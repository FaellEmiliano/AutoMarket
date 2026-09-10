extends Node


const LexerScript = preload("res://interpreter/python_like/lexer/python_like_lexer.gd")
const TokenData = preload("res://interpreter/python_like/lexer/python_like_token.gd")

var _failures: Array[String] = []


func _ready() -> void:
	_test_empty_source()
	_test_identifiers_and_keywords()
	_test_literal_keywords()
	_test_numbers()
	_test_strings_and_escapes()
	_test_comments()
	_test_all_operators_and_delimiters()
	_test_simple_newline()
	_test_block_indent_and_dedent()
	_test_nested_blocks_and_multiple_dedents()
	_test_invalid_indentation()
	_test_blank_and_comment_lines_inside_block()
	_test_eof_inside_block()
	_test_implicit_line_continuation()
	_test_multiline_list_and_dictionary()
	_test_delimiter_errors()
	_test_unknown_character_and_unterminated_string()
	_test_token_positions()
	_test_error_positions_and_recovery()
	_test_large_source_progress()
	_test_official_checkout_example()

	if _failures.is_empty():
		print("PYTHON_LIKE_LEXER_TEST_OK")
	else:
		push_error("\n".join(_failures))

	await get_tree().process_frame
	get_tree().quit()


func _test_empty_source() -> void:
	var lexer = _lex("")
	_check_types(lexer, ["EOF"], "Fonte vazia")
	_check(lexer.errors.is_empty(), "Fonte vazia não deve produzir erro.")
	var eof = lexer.tokens[0]
	_check_token(eof, "", null, 1, 1, 0, "EOF vazio")


func _test_identifiers_and_keywords() -> void:
	var source := "and break continue def elif else False for if in None not or return True while produto_1 preço async\n"
	var lexer = _lex(source)
	_check_types(lexer, [
		"KW_AND", "KW_BREAK", "KW_CONTINUE", "KW_DEF", "KW_ELIF", "KW_ELSE",
		"KW_FALSE", "KW_FOR", "KW_IF", "KW_IN", "KW_NONE", "KW_NOT", "KW_OR",
		"KW_RETURN", "KW_TRUE", "KW_WHILE", "NAME", "NAME", "NAME", "NEWLINE", "EOF",
	], "Identificadores e keywords")
	_check(lexer.errors.is_empty(), "Identificadores Unicode e keywords válidos não devem falhar.")
	_check_token(lexer.tokens[16], "produto_1", "produto_1", 1, 80, 9, "Identificador ASCII")
	_check(lexer.tokens[17].lexeme == "preço", "Lexer deve preservar identificador Unicode.")
	_check(lexer.tokens[18].type == TokenData.Type.NAME, "Keyword Python fora do MVP deve permanecer NAME para o parser rejeitar.")

	var reserved = _lex("__class__\n")
	_check_error(reserved, "LEX_RESERVED_IDENTIFIER", 1, 1, 9, "Identificador reservado")


func _test_literal_keywords() -> void:
	var lexer = _lex("True False None\n")
	_check_types(lexer, ["KW_TRUE", "KW_FALSE", "KW_NONE", "NEWLINE", "EOF"], "Literais keyword")
	_check(lexer.tokens[0].value == true, "True deve normalizar para bool verdadeiro.")
	_check(lexer.tokens[1].value == false, "False deve normalizar para bool falso.")
	_check(lexer.tokens[2].value == null, "None deve normalizar para null interno.")


func _test_numbers() -> void:
	var lexer = _lex("0 42 1_000 .5 2. 1e3 2.5e-2 7+2 produto.preco 1.method\n")
	_check_types(lexer, [
		"INT", "INT", "INT", "FLOAT", "FLOAT", "FLOAT", "FLOAT",
		"INT", "PLUS", "INT", "NAME", "DOT", "NAME", "INT", "DOT", "NAME",
		"NEWLINE", "EOF",
	], "Números, operador e ponto de método")
	_check(lexer.errors.is_empty(), "Formatos numéricos válidos não devem produzir erros.")
	_check_token(lexer.tokens[2], "1_000", 1000, 1, 6, 5, "Inteiro com separador")
	_check_token(lexer.tokens[3], ".5", 0.5, 1, 12, 2, "Float sem inteiro")
	_check_token(lexer.tokens[4], "2.", 2.0, 1, 15, 2, "Float sem fração")
	_check(lexer.tokens[11].lexeme == ".", "Ponto de acesso deve permanecer DOT.")
	_check(lexer.tokens[14].type == TokenData.Type.DOT, "Ponto após inteiro antes de método deve permanecer DOT.")

	var invalid = _lex("1__2 0x10 1e+ 1.2.3 + 2\n")
	_check(_error_codes(invalid) == [
		"LEX_INVALID_NUMBER", "LEX_INVALID_NUMBER", "LEX_INVALID_NUMBER", "LEX_INVALID_NUMBER",
	], "Sequências numéricas inválidas devem gerar códigos estáveis.")
	_check(_type_names(invalid).has("PLUS"), "Número inválido não pode consumir o operador seguinte.")


func _test_strings_and_escapes() -> void:
	var simple = _lex("'simples' \"dupla\"\n")
	_check_types(simple, ["STRING", "STRING", "NEWLINE", "EOF"], "Strings simples e duplas")
	_check_token(simple.tokens[0], "'simples'", "simples", 1, 1, 9, "String simples")
	_check_token(simple.tokens[1], "\"dupla\"", "dupla", 1, 11, 7, "String dupla")

	var slash := String.chr(92)
	var quote := "\""
	var escaped_source := (
		"'it" + slash + "'s' "
		+ quote + "a" + slash + quote + "b" + quote + " "
		+ quote + slash + slash + slash + "n" + slash + "t"
		+ slash + "u0041" + slash + "U0001F600" + quote + "\n"
	)
	var escaped = _lex(escaped_source)
	_check_types(escaped, ["STRING", "STRING", "STRING", "NEWLINE", "EOF"], "Escapes")
	_check(escaped.errors.is_empty(), "Escapes permitidos não devem produzir erros.")
	_check(escaped.tokens[0].value == "it's", "Aspa simples escapada deve ser normalizada.")
	_check(escaped.tokens[1].value == "a\"b", "Aspa dupla escapada deve ser normalizada.")
	_check(escaped.tokens[2].value == "\\\n\tA😀", "Barra, controles e Unicode devem ser normalizados.")
	_check(escaped.tokens[2].lexeme.contains(slash + "u0041"), "Lexema deve preservar o escape Unicode original.")

	var invalid_escape = _lex(quote + slash + "q" + quote + "\n")
	_check_error(invalid_escape, "LEX_INVALID_ESCAPE", 1, 2, 2, "Escape inválido")


func _test_comments() -> void:
	var lexer = _lex("x = 1 # inline\n    # comentário indentado\n# comentário base\ny = 2")
	_check_types(lexer, [
		"NAME", "ASSIGN", "INT", "NEWLINE",
		"NAME", "ASSIGN", "INT", "NEWLINE", "EOF",
	], "Comentários")
	_check(lexer.errors.is_empty(), "Comentários não devem alterar indentação nem produzir erros.")


func _test_all_operators_and_delimiters() -> void:
	var source := "+ - * / // % ** = += -= *= /= //= %= == != < <= > >= () [] {} : , . and or not in\n"
	var lexer = _lex(source)
	_check_types(lexer, [
		"PLUS", "MINUS", "STAR", "SLASH", "DOUBLE_SLASH", "PERCENT", "DOUBLE_STAR",
		"ASSIGN", "PLUS_ASSIGN", "MINUS_ASSIGN", "STAR_ASSIGN", "SLASH_ASSIGN",
		"DOUBLE_SLASH_ASSIGN", "PERCENT_ASSIGN", "EQ", "NOT_EQ", "LT", "LT_EQ", "GT", "GT_EQ",
		"LPAREN", "RPAREN", "LBRACKET", "RBRACKET", "LBRACE", "RBRACE",
		"COLON", "COMMA", "DOT", "KW_AND", "KW_OR", "KW_NOT", "KW_IN", "NEWLINE", "EOF",
	], "Operadores e delimitadores")
	_check(lexer.errors.is_empty(), "Todos os operadores e delimitadores do MVP devem ser aceitos.")


func _test_simple_newline() -> void:
	var lexer = _lex("x = 1\n")
	_check_types(lexer, ["NAME", "ASSIGN", "INT", "NEWLINE", "EOF"], "NEWLINE simples")
	_check_token(lexer.tokens[3], "\n", null, 1, 6, 1, "NEWLINE físico")

	var synthetic = _lex("x = 1")
	_check_types(synthetic, ["NAME", "ASSIGN", "INT", "NEWLINE", "EOF"], "NEWLINE sintético")
	_check_token(synthetic.tokens[3], "", null, 1, 6, 0, "NEWLINE sintético")


func _test_block_indent_and_dedent() -> void:
	var lexer = _lex("if total > 50:\n    desconto = 0.1\nelse:\n    desconto = 0\n")
	_check_types(lexer, [
		"KW_IF", "NAME", "GT", "INT", "COLON", "NEWLINE",
		"INDENT", "NAME", "ASSIGN", "FLOAT", "NEWLINE", "DEDENT",
		"KW_ELSE", "COLON", "NEWLINE", "INDENT", "NAME", "ASSIGN", "INT", "NEWLINE",
		"DEDENT", "EOF",
	], "Bloco oficial com INDENT e DEDENT")
	_check(lexer.errors.is_empty(), "Bloco válido não deve produzir erro.")
	_check_token(lexer.tokens[6], "    ", 4, 2, 1, 4, "INDENT")
	_check(lexer.tokens[11].length == 0 and lexer.tokens[11].line == 3, "DEDENT deve ser sintético na linha de retorno.")

	var tabs = _lex("if True:\n\tx = 1\n")
	_check(tabs.errors.is_empty(), "Fonte exclusivamente indentada com tab deve ser aceita.")
	_check(tabs.tokens[4].type == TokenData.Type.INDENT and tabs.tokens[4].value == 4, "Tab deve valer uma unidade de quatro colunas.")


func _test_nested_blocks_and_multiple_dedents() -> void:
	var lexer = _lex("if True:\n    if False:\n        x = 1\n    y = 2\nz = 3\n")
	_check_types(lexer, [
		"KW_IF", "KW_TRUE", "COLON", "NEWLINE", "INDENT",
		"KW_IF", "KW_FALSE", "COLON", "NEWLINE", "INDENT",
		"NAME", "ASSIGN", "INT", "NEWLINE", "DEDENT",
		"NAME", "ASSIGN", "INT", "NEWLINE", "DEDENT",
		"NAME", "ASSIGN", "INT", "NEWLINE", "EOF",
	], "Blocos aninhados")
	_check(lexer.errors.is_empty(), "Blocos aninhados válidos não devem falhar.")

	var types := _type_names(lexer)
	var base_name_index := types.rfind("NAME")
	_check(base_name_index >= 2 and types[base_name_index - 1] == "DEDENT", "Retorno à base deve emitir o segundo DEDENT antes do statement.")

	var multiple = _lex("if True:\n    if True:\n        x = 1\ny = 2\n")
	var multiple_types := _type_names(multiple)
	var y_index := multiple_types.rfind("NAME")
	_check(y_index >= 2 and multiple_types[y_index - 1] == "DEDENT" and multiple_types[y_index - 2] == "DEDENT",
		"Uma linha pode receber vários DEDENT antes do primeiro token.")


func _test_invalid_indentation() -> void:
	var invalid_dedent = _lex("if True:\n    x = 1\n  y = 2\n")
	_check_error(invalid_dedent, "INDENT_INVALID_DEDENT", 3, 1, 2, "Dedent inválido")
	_check(_type_names(invalid_dedent).back() == "EOF", "Erro estrutural deve encerrar controladamente com EOF.")

	var invalid_width = _lex("if True:\n  x = 1\n")
	_check_error(invalid_width, "INDENT_INVALID_WIDTH", 2, 1, 2, "Largura inválida")

	var unexpected = _lex("x = 1\n    y = 2\n")
	_check_error(unexpected, "INDENT_UNEXPECTED", 2, 1, 4, "Indentação inesperada")

	var mixed_prefix = _lex("if True:\n \tx = 1\n")
	_check_error(mixed_prefix, "INDENT_MIXED_WHITESPACE", 2, 1, 2, "Mistura no prefixo")

	var mixed_file = _lex("if True:\n    x = 1\nif True:\n\ty = 2\n")
	_check(_error_codes(mixed_file).has("INDENT_MIXED_WHITESPACE"), "Alternar espaços e tabs na mesma fonte deve falhar.")


func _test_blank_and_comment_lines_inside_block() -> void:
	var source := "if True:\n    x = 1\n\n    # comentário\n\n    y = 2\nz = 3\n"
	var lexer = _lex(source)
	_check(lexer.errors.is_empty(), "Linhas vazias e comentários dentro de bloco devem ser ignorados estruturalmente.")
	_check(_count_type(lexer, "INDENT") == 1, "Linhas vazias não podem criar INDENT extra.")
	_check(_count_type(lexer, "DEDENT") == 1, "Comentário não pode antecipar DEDENT.")
	_check(_count_type(lexer, "NEWLINE") == 4, "Somente linhas com código devem gerar NEWLINE lógico.")


func _test_eof_inside_block() -> void:
	var lexer = _lex("if True:\n    x = 1")
	_check_types(lexer, [
		"KW_IF", "KW_TRUE", "COLON", "NEWLINE", "INDENT",
		"NAME", "ASSIGN", "INT", "NEWLINE", "DEDENT", "EOF",
	], "EOF dentro de bloco")
	_check(lexer.tokens[8].length == 0, "EOF sem quebra física deve gerar NEWLINE sintético.")
	_check(lexer.tokens[9].length == 0, "DEDENT de EOF deve ser sintético.")


func _test_implicit_line_continuation() -> void:
	var lexer = _lex("total = (\n    1 +\n    2\n)\n")
	_check_types(lexer, [
		"NAME", "ASSIGN", "LPAREN", "INT", "PLUS", "INT", "RPAREN", "NEWLINE", "EOF",
	], "Continuação implícita em parênteses")
	_check(lexer.errors.is_empty(), "Nova linha e indentação dentro de parênteses devem ser ignoradas.")
	_check(_count_type(lexer, "INDENT") == 0 and _count_type(lexer, "DEDENT") == 0,
		"Agrupamento não pode produzir INDENT ou DEDENT.")


func _test_multiline_list_and_dictionary() -> void:
	var lexer = _lex("valores = [\n    1,\n    2,\n]\ndados = {\n    'a': 1,\n    'b': 2,\n}\n")
	_check(lexer.errors.is_empty(), "Lista e dicionário multilinha devem ser válidos.")
	_check(_count_type(lexer, "NEWLINE") == 2, "Somente o fechamento de cada atribuição deve gerar NEWLINE.")
	_check(_count_type(lexer, "INDENT") == 0, "Indentação visual dentro de coleções deve ser ignorada.")
	_check(_type_names(lexer).has("LBRACKET") and _type_names(lexer).has("LBRACE"),
		"Coleções multilinha devem preservar seus delimitadores.")


func _test_delimiter_errors() -> void:
	var unclosed = _lex("x = (1 +\n    2")
	_check_error(unclosed, "LEX_UNCLOSED_DELIMITER", 1, 5, 1, "Delimitador não fechado")
	_check(_count_type(unclosed, "NEWLINE") == 0, "Delimitador aberto no EOF deve prevalecer sobre NEWLINE sintético.")

	var mismatched = _lex("[1)\n")
	_check_error(mismatched, "LEX_MISMATCHED_DELIMITER", 1, 3, 1, "Delimitador incompatível")
	_check(mismatched.errors[0].details.get("expected") == "]", "Erro incompatível deve informar fechamento esperado.")

	var unexpected = _lex("] x\n")
	_check_error(unexpected, "LEX_UNEXPECTED_CLOSING_DELIMITER", 1, 1, 1, "Fechamento inesperado")
	_check(_type_names(unexpected).has("NAME"), "Fechamento inesperado recuperável não pode impedir progresso.")


func _test_unknown_character_and_unterminated_string() -> void:
	var unknown = _lex("@ x\n")
	_check_error(unknown, "LEX_INVALID_CHARACTER", 1, 1, 1, "Caractere desconhecido")
	_check_types(unknown, ["NAME", "NEWLINE", "EOF"], "Recuperação após caractere desconhecido")

	var unterminated_eof = _lex("\"aberta")
	_check_error(unterminated_eof, "LEX_UNTERMINATED_STRING", 1, 1, 7, "String não terminada no EOF")

	var unterminated_line = _lex("'aberta\nx = 1\n")
	_check_error(unterminated_line, "LEX_UNTERMINATED_STRING", 1, 1, 7, "String não terminada na linha")
	_check(_type_names(unterminated_line).has("NAME"), "Nova linha após string inválida deve permitir recuperação na linha seguinte.")


func _test_token_positions() -> void:
	var lexer = _lex("x = 1\r\nnome = 2\r\n")
	_check(lexer.errors.is_empty(), "CRLF deve ser normalizado sem erro.")
	var name_token = lexer.tokens[4]
	_check_token(name_token, "nome", "nome", 2, 1, 4, "Posição em múltiplas linhas")
	_check(name_token.start_offset == 6 and name_token.end_offset == 10, "Offsets devem usar a fonte normalizada para LF.")
	_check(name_token.end_line == 2 and name_token.end_column == 5, "Token deve preservar posição final exclusiva.")


func _test_error_positions_and_recovery() -> void:
	var positioned = _lex("x = @\n")
	_check_error(positioned, "LEX_INVALID_CHARACTER", 1, 5, 1, "Posição de erro")

	var slash := String.chr(92)
	var quote := "\""
	var source := "@ $\nx = " + quote + slash + "q" + quote + "\n"
	var multiple = _lex(source)
	_check(_error_codes(multiple) == [
		"LEX_INVALID_CHARACTER", "LEX_INVALID_CHARACTER", "LEX_INVALID_ESCAPE",
	], "Erros recuperáveis devem ser acumulados na ordem da fonte.")
	_check(multiple.errors[0].line == 1 and multiple.errors[1].column == 3,
		"Múltiplos erros devem preservar posições independentes.")
	_check(multiple.errors[2].line == 2 and multiple.errors[2].column == 6,
		"Escape inválido deve apontar para a barra invertida.")


func _test_large_source_progress() -> void:
	var source := ""
	for index in range(300):
		source += "valor_%d = %d\n" % [index, index]
	var lexer = _lex(source)
	_check(lexer.errors.is_empty(), "Fonte suficientemente grande e válida deve terminar sem erro.")
	_check(lexer.tokens.size() == 1201, "Fonte de progresso deve produzir sequência completa de tokens.")
	_check(_type_names(lexer).back() == "EOF", "Fonte grande deve sempre alcançar EOF.")


func _test_official_checkout_example() -> void:
	var lexer = _lex("produtos = tabela_produtos()\nfor produto in produtos:\n    print(produto)\n")
	_check_types(lexer, [
		"NAME", "ASSIGN", "NAME", "LPAREN", "RPAREN", "NEWLINE",
		"KW_FOR", "NAME", "KW_IN", "NAME", "COLON", "NEWLINE", "INDENT",
		"NAME", "LPAREN", "NAME", "RPAREN", "NEWLINE", "DEDENT", "EOF",
	], "Exemplo oficial do novo caixa")
	_check(lexer.errors.is_empty(), "Exemplo oficial com tabela_produtos deve ser lexicamente válido.")


func _lex(source: String):
	var lexer = LexerScript.new(source)
	lexer.tokenize()
	return lexer


func _type_names(lexer) -> Array[String]:
	var result: Array[String] = []
	for token in lexer.tokens:
		result.append(token.get_type_name())
	return result


func _error_codes(lexer) -> Array[String]:
	var result: Array[String] = []
	for error in lexer.errors:
		result.append(error.code)
	return result


func _count_type(lexer, type_name: String) -> int:
	return _type_names(lexer).count(type_name)


func _check_types(lexer, expected: Array, label: String) -> void:
	var actual := _type_names(lexer)
	_check(actual == expected, "%s: tipos esperados %s, recebidos %s." % [label, expected, actual])


func _check_token(token, expected_lexeme: String, expected_value: Variant,
		expected_line: int, expected_column: int, expected_length: int, label: String) -> void:
	_check(token.lexeme == expected_lexeme, "%s: lexema incorreto: %s." % [label, token.lexeme])
	_check(token.value == expected_value, "%s: valor incorreto: %s." % [label, token.value])
	_check(token.line == expected_line, "%s: linha esperada %d, recebida %d." % [label, expected_line, token.line])
	_check(token.column == expected_column, "%s: coluna esperada %d, recebida %d." % [label, expected_column, token.column])
	_check(token.length == expected_length, "%s: comprimento esperado %d, recebido %d." % [label, expected_length, token.length])


func _check_error(lexer, expected_code: String, expected_line: int,
		expected_column: int, expected_length: int, label: String) -> void:
	var matching = lexer.errors.filter(func(error): return error.code == expected_code)
	_check(not matching.is_empty(), "%s: erro %s não foi produzido; recebidos %s." % [label, expected_code, _error_codes(lexer)])
	if matching.is_empty():
		return
	var error = matching[0]
	_check(error.line == expected_line, "%s: linha de erro esperada %d, recebida %d." % [label, expected_line, error.line])
	_check(error.column == expected_column, "%s: coluna de erro esperada %d, recebida %d." % [label, expected_column, error.column])
	_check(error.length == expected_length, "%s: comprimento de erro esperado %d, recebido %d." % [label, expected_length, error.length])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
