extends RefCounted
class_name PythonLikeParser


const TokenData = preload("res://interpreter/python_like/lexer/python_like_token.gd")
const Ast = preload("res://interpreter/python_like/ast/python_like_ast_nodes.gd")
const ParseError = preload("res://interpreter/python_like/parser/python_like_parse_error.gd")

const ASSIGNMENT_TYPES := [
	TokenData.Type.ASSIGN,
	TokenData.Type.PLUS_ASSIGN,
	TokenData.Type.MINUS_ASSIGN,
	TokenData.Type.STAR_ASSIGN,
	TokenData.Type.SLASH_ASSIGN,
	TokenData.Type.DOUBLE_SLASH_ASSIGN,
	TokenData.Type.PERCENT_ASSIGN,
]

const UNSUPPORTED_STAGE_TYPES := {
	TokenData.Type.KW_IF: "if",
	TokenData.Type.KW_ELIF: "elif",
	TokenData.Type.KW_ELSE: "else",
	TokenData.Type.KW_WHILE: "while",
	TokenData.Type.KW_FOR: "for",
	TokenData.Type.KW_DEF: "def",
	TokenData.Type.KW_RETURN: "return",
	TokenData.Type.KW_BREAK: "break",
	TokenData.Type.KW_CONTINUE: "continue",
}

const RESERVED_NAME_LEXEMES := {
	"as": true,
	"assert": true,
	"async": true,
	"await": true,
	"case": true,
	"class": true,
	"del": true,
	"except": true,
	"finally": true,
	"from": true,
	"global": true,
	"import": true,
	"is": true,
	"lambda": true,
	"match": true,
	"nonlocal": true,
	"pass": true,
	"raise": true,
	"try": true,
	"with": true,
	"yield": true,
}


var tokens: Array
var errors: Array = []
var _position: int = 0


func _init(source_tokens: Array = []) -> void:
	tokens = source_tokens


func parse() -> Ast.ProgramNode:
	errors.clear()
	_position = 0
	var statements: Array = []

	if tokens.is_empty():
		return null

	while not _check(TokenData.Type.EOF):
		if _match(TokenData.Type.NEWLINE):
			continue

		var iteration_start := _position
		var statement = _parse_simple_statement()
		if statement != null:
			statements.append(statement)
		if _position == iteration_start:
			_advance()

	var eof = _current()
	var program_span: Ast.SourceSpan
	if statements.is_empty():
		program_span = Ast.SourceSpan.from_token(eof)
	else:
		program_span = _span_between(statements[0].span, statements[-1].span)
	return Ast.ProgramNode.new(statements, program_span)


func _parse_simple_statement():
	if UNSUPPORTED_STAGE_TYPES.has(_current().type):
		_add_unsupported_stage_error(_current())
		_synchronize_statement()
		return null

	if _check(TokenData.Type.INDENT) or _check(TokenData.Type.DEDENT):
		_add_error(
			"PARSE_UNSUPPORTED_STAGE",
			"Blocos indentados ainda não são aceitos nesta etapa do parser.",
			_current(),
			{"construction": _current().get_type_name(), "stage": "simple_statements"}
		)
		_synchronize_statement()
		return null

	var left = _parse_or_expression()
	if left == null:
		_synchronize_statement()
		return null

	var statement = null
	if _current().type in ASSIGNMENT_TYPES:
		var operator_token = _advance()
		var valid_target := left is Ast.IdentifierNode or left is Ast.IndexExpressionNode
		if not valid_target:
			_add_error(
				"PARSE_INVALID_ASSIGNMENT_TARGET",
				"O lado esquerdo da atribuição deve ser um nome ou uma indexação.",
				_token_for_span(left.span),
				{"operator": operator_token.lexeme}
			)
		var value = _parse_or_expression()
		if value != null and valid_target:
			var assignment_span := _span_between(left.span, value.span)
			var operator_span := Ast.SourceSpan.from_token(operator_token)
			if operator_token.type == TokenData.Type.ASSIGN:
				statement = Ast.SimpleAssignmentNode.new(left, value, assignment_span, operator_span)
			else:
				statement = Ast.CompoundAssignmentNode.new(
					left, operator_token.lexeme, value, assignment_span, operator_span
				)
	else:
		statement = Ast.ExpressionStatementNode.new(left, left.span)

	if not _check(TokenData.Type.NEWLINE) and not _check(TokenData.Type.EOF):
		if _current().type in ASSIGNMENT_TYPES:
			_add_error(
				"PARSE_UNSUPPORTED_FEATURE",
				"Atribuição encadeada não faz parte do MVP Python-like.",
				_current(), {"feature": "chained_assignment"}
			)
		elif UNSUPPORTED_STAGE_TYPES.has(_current().type):
			_add_unsupported_stage_error(_current())
		elif _check(TokenData.Type.NAME) and RESERVED_NAME_LEXEMES.has(_current().lexeme):
			_add_unsupported_name_error(_current())
		else:
			_add_error(
				"PARSE_EXPECTED_NEWLINE",
				"Cada linha aceita exatamente um statement.",
				_current(),
				{"found": _current().get_type_name()}
			)
		_synchronize_statement()
		return null

	_match(TokenData.Type.NEWLINE)
	return statement


func _parse_or_expression():
	var expression = _parse_and_expression()
	while expression != null and _match(TokenData.Type.KW_OR):
		var operator_token = _previous()
		var right = _parse_and_expression()
		if right == null:
			return null
		expression = Ast.LogicalExpressionNode.new(
			expression, operator_token.lexeme, right,
			_span_between(expression.span, right.span), Ast.SourceSpan.from_token(operator_token)
		)
	return expression


func _parse_and_expression():
	var expression = _parse_not_expression()
	while expression != null and _match(TokenData.Type.KW_AND):
		var operator_token = _previous()
		var right = _parse_not_expression()
		if right == null:
			return null
		expression = Ast.LogicalExpressionNode.new(
			expression, operator_token.lexeme, right,
			_span_between(expression.span, right.span), Ast.SourceSpan.from_token(operator_token)
		)
	return expression


func _parse_not_expression():
	if _match(TokenData.Type.KW_NOT):
		var operator_token = _previous()
		var operand = _parse_not_expression()
		if operand == null:
			return null
		return Ast.UnaryExpressionNode.new(
			operator_token.lexeme, operand,
			_span_from_token_to_span(operator_token, operand.span),
			Ast.SourceSpan.from_token(operator_token)
		)
	return _parse_comparison()


func _parse_comparison():
	var first = _parse_sum()
	if first == null:
		return null

	var operands: Array = [first]
	var operators: Array[String] = []
	var operator_spans: Array = []
	while _is_comparison_start():
		var first_operator_token = _advance()
		var operator_text: String = first_operator_token.lexeme
		var operator_span := Ast.SourceSpan.from_token(first_operator_token)
		if first_operator_token.type == TokenData.Type.KW_NOT:
			var in_token = _advance()
			operator_text = "not in"
			operator_span = Ast.SourceSpan.between(first_operator_token, in_token)
		var right = _parse_sum()
		if right == null:
			return null
		operators.append(operator_text)
		operator_spans.append(operator_span)
		operands.append(right)

	if operators.is_empty():
		return first
	return Ast.ComparisonExpressionNode.new(
		operands, operators, operator_spans,
		_span_between(first.span, operands[-1].span)
	)


func _parse_sum():
	var expression = _parse_term()
	while expression != null and (_check(TokenData.Type.PLUS) or _check(TokenData.Type.MINUS)):
		var operator_token = _advance()
		var right = _parse_term()
		if right == null:
			return null
		expression = _make_binary(expression, operator_token, right)
	return expression


func _parse_term():
	var expression = _parse_factor()
	while expression != null and _current().type in [
		TokenData.Type.STAR,
		TokenData.Type.SLASH,
		TokenData.Type.DOUBLE_SLASH,
		TokenData.Type.PERCENT,
	]:
		var operator_token = _advance()
		var right = _parse_factor()
		if right == null:
			return null
		expression = _make_binary(expression, operator_token, right)
	return expression


func _parse_factor():
	if _check(TokenData.Type.PLUS) or _check(TokenData.Type.MINUS):
		var operator_token = _advance()
		var operand = _parse_factor()
		if operand == null:
			return null
		return Ast.UnaryExpressionNode.new(
			operator_token.lexeme, operand,
			_span_from_token_to_span(operator_token, operand.span),
			Ast.SourceSpan.from_token(operator_token)
		)
	return _parse_power()


func _parse_power():
	var expression = _parse_primary()
	if expression != null and _match(TokenData.Type.DOUBLE_STAR):
		var operator_token = _previous()
		var right = _parse_factor()
		if right == null:
			return null
		expression = _make_binary(expression, operator_token, right)
	return expression


func _parse_primary():
	var expression = _parse_atom()
	while expression != null:
		if _match(TokenData.Type.LPAREN):
			expression = _finish_call(expression, _previous())
		elif _match(TokenData.Type.LBRACKET):
			expression = _finish_index(expression, _previous())
		elif _match(TokenData.Type.DOT):
			expression = _finish_attribute(expression, _previous())
		else:
			break
	return expression


func _parse_atom():
	if _match(TokenData.Type.INT):
		var token = _previous()
		return Ast.IntegerLiteralNode.new(token.value, token.lexeme, Ast.SourceSpan.from_token(token))
	if _match(TokenData.Type.FLOAT):
		var token = _previous()
		return Ast.FloatLiteralNode.new(token.value, token.lexeme, Ast.SourceSpan.from_token(token))
	if _match(TokenData.Type.STRING):
		var token = _previous()
		return Ast.StringLiteralNode.new(token.value, token.lexeme, Ast.SourceSpan.from_token(token))
	if _match(TokenData.Type.KW_TRUE) or _match(TokenData.Type.KW_FALSE):
		var token = _previous()
		return Ast.BooleanLiteralNode.new(token.value, token.lexeme, Ast.SourceSpan.from_token(token))
	if _match(TokenData.Type.KW_NONE):
		return Ast.NoneLiteralNode.new(Ast.SourceSpan.from_token(_previous()))
	if _match(TokenData.Type.NAME):
		var token = _previous()
		if RESERVED_NAME_LEXEMES.has(token.lexeme):
			_add_unsupported_name_error(token)
			return null
		return Ast.IdentifierNode.new(token.value, Ast.SourceSpan.from_token(token))
	if _match(TokenData.Type.LPAREN):
		return _finish_group(_previous())
	if _match(TokenData.Type.LBRACKET):
		return _finish_list(_previous())
	if _match(TokenData.Type.LBRACE):
		return _finish_dictionary(_previous())

	if UNSUPPORTED_STAGE_TYPES.has(_current().type):
		_add_unsupported_stage_error(_current())
	else:
		_add_error(
			"PARSE_EXPECTED_EXPRESSION",
			"Era esperada uma expressão.",
			_current(),
			{"found": _current().get_type_name()}
		)
	if not _is_expression_boundary(_current().type):
		_advance()
	return null


func _finish_group(opening_token):
	if _check(TokenData.Type.RPAREN):
		_add_error("PARSE_EXPECTED_EXPRESSION", "Parênteses vazios não formam uma expressão.", _current())
		_advance()
		return null
	var expression = _parse_or_expression()
	if expression == null:
		return null
	if _check(TokenData.Type.COMMA):
		_add_error(
			"PARSE_UNSUPPORTED_FEATURE",
			"Tuples não fazem parte do MVP Python-like.",
			_current(), {"feature": "tuple"}
		)
		return null
	var closing_token = _consume(
		TokenData.Type.RPAREN, "PARSE_EXPECTED_RPAREN",
		"Falta ')' para fechar a expressão agrupada."
	)
	if closing_token == null:
		return null
	return Ast.GroupExpressionNode.new(
		expression, Ast.SourceSpan.between(opening_token, closing_token)
	)


func _finish_list(opening_token):
	var elements: Array = []
	if not _check(TokenData.Type.RBRACKET):
		while true:
			var element = _parse_or_expression()
			if element == null:
				return null
			elements.append(element)
			if _check(TokenData.Type.KW_FOR):
				_add_error(
					"PARSE_UNSUPPORTED_FEATURE",
					"Comprehensions não fazem parte do MVP Python-like.",
					_current(), {"feature": "comprehension"}
				)
				return null
			if not _match(TokenData.Type.COMMA):
				break
			if _check(TokenData.Type.RBRACKET):
				break
	var closing_token = _consume(
		TokenData.Type.RBRACKET, "PARSE_EXPECTED_RBRACKET",
		"Falta ']' para fechar a lista."
	)
	if closing_token == null:
		return null
	return Ast.ListLiteralNode.new(elements, Ast.SourceSpan.between(opening_token, closing_token))


func _finish_dictionary(opening_token):
	var entries: Array = []
	if not _check(TokenData.Type.RBRACE):
		while true:
			var key = _parse_or_expression()
			if key == null:
				return null
			var colon_token = _consume(
				TokenData.Type.COLON, "PARSE_EXPECTED_COLON",
				"Cada item de dicionário precisa de ':' entre chave e valor."
			)
			if colon_token == null:
				return null
			var value = _parse_or_expression()
			if value == null:
				return null
			entries.append(Ast.DictionaryEntryNode.new(
				key, value, _span_between(key.span, value.span), Ast.SourceSpan.from_token(colon_token)
			))
			if _check(TokenData.Type.KW_FOR):
				_add_error(
					"PARSE_UNSUPPORTED_FEATURE",
					"Comprehensions não fazem parte do MVP Python-like.",
					_current(), {"feature": "comprehension"}
				)
				return null
			if not _match(TokenData.Type.COMMA):
				break
			if _check(TokenData.Type.RBRACE):
				break
	var closing_token = _consume(
		TokenData.Type.RBRACE, "PARSE_EXPECTED_RBRACE",
		"Falta '}' para fechar o dicionário."
	)
	if closing_token == null:
		return null
	return Ast.DictionaryLiteralNode.new(entries, Ast.SourceSpan.between(opening_token, closing_token))


func _finish_call(callee, opening_token):
	var arguments: Array = []
	if not _check(TokenData.Type.RPAREN):
		while true:
			if _check(TokenData.Type.STAR) or _check(TokenData.Type.DOUBLE_STAR):
				_add_error(
					"PARSE_UNSUPPORTED_FEATURE",
					"Expansão de argumentos não faz parte do MVP Python-like.",
					_current(), {"feature": "variadic_arguments"}
				)
				return null
			var argument = _parse_or_expression()
			if argument == null:
				return null
			if _check(TokenData.Type.ASSIGN):
				_add_error(
					"PARSE_UNSUPPORTED_FEATURE",
					"Argumentos nomeados não fazem parte do MVP Python-like.",
					_current(), {"feature": "named_arguments"}
				)
				return null
			arguments.append(argument)
			if not _match(TokenData.Type.COMMA):
				break
			if _check(TokenData.Type.RPAREN):
				break
	var closing_token = _consume(
		TokenData.Type.RPAREN, "PARSE_EXPECTED_RPAREN",
		"Falta ')' para fechar a chamada."
	)
	if closing_token == null:
		return null
	return Ast.CallExpressionNode.new(
		callee, arguments, _span_from_span_to_token(callee.span, closing_token),
		Ast.SourceSpan.from_token(opening_token), Ast.SourceSpan.from_token(closing_token)
	)


func _finish_index(collection, opening_token):
	if _check(TokenData.Type.COLON):
		_add_error(
			"PARSE_UNSUPPORTED_FEATURE",
			"Slicing não faz parte do MVP Python-like.",
			_current(), {"feature": "slicing"}
		)
		return null
	var index = _parse_or_expression()
	if index == null:
		return null
	if _check(TokenData.Type.COLON):
		_add_error(
			"PARSE_UNSUPPORTED_FEATURE",
			"Slicing não faz parte do MVP Python-like.",
			_current(), {"feature": "slicing"}
		)
		return null
	var closing_token = _consume(
		TokenData.Type.RBRACKET, "PARSE_EXPECTED_RBRACKET",
		"Falta ']' para fechar a indexação."
	)
	if closing_token == null:
		return null
	return Ast.IndexExpressionNode.new(
		collection, index, _span_from_span_to_token(collection.span, closing_token),
		Ast.SourceSpan.from_token(opening_token), Ast.SourceSpan.from_token(closing_token)
	)


func _finish_attribute(object, dot_token):
	if UNSUPPORTED_STAGE_TYPES.has(_current().type):
		_add_unsupported_stage_error(_current())
		return null
	if not _check(TokenData.Type.NAME):
		_add_error(
			"PARSE_EXPECTED_ATTRIBUTE",
			"Era esperado um nome depois de '.'.",
			_current(), {"found": _current().get_type_name()}
		)
		return null
	var name_token = _advance()
	if RESERVED_NAME_LEXEMES.has(name_token.lexeme):
		_add_unsupported_name_error(name_token)
		return null
	return Ast.AttributeExpressionNode.new(
		object, name_token.value, _span_from_span_to_token(object.span, name_token),
		Ast.SourceSpan.from_token(dot_token), Ast.SourceSpan.from_token(name_token)
	)


func _make_binary(left, operator_token, right):
	return Ast.BinaryExpressionNode.new(
		left, operator_token.lexeme, right, _span_between(left.span, right.span),
		Ast.SourceSpan.from_token(operator_token)
	)


func _is_comparison_start() -> bool:
	if _current().type in [
		TokenData.Type.EQ,
		TokenData.Type.NOT_EQ,
		TokenData.Type.LT,
		TokenData.Type.LT_EQ,
		TokenData.Type.GT,
		TokenData.Type.GT_EQ,
		TokenData.Type.KW_IN,
	]:
		return true
	return _check(TokenData.Type.KW_NOT) and _peek_type(1) == TokenData.Type.KW_IN


func _is_expression_boundary(token_type: int) -> bool:
	return token_type in [
		TokenData.Type.NEWLINE,
		TokenData.Type.EOF,
		TokenData.Type.RPAREN,
		TokenData.Type.RBRACKET,
		TokenData.Type.RBRACE,
		TokenData.Type.COMMA,
		TokenData.Type.COLON,
	]


func _synchronize_statement() -> void:
	while not _check(TokenData.Type.EOF) and not _check(TokenData.Type.NEWLINE):
		_advance()
	_match(TokenData.Type.NEWLINE)


func _consume(token_type: int, error_code: String, error_message: String):
	if _check(token_type):
		return _advance()
	if UNSUPPORTED_STAGE_TYPES.has(_current().type):
		_add_unsupported_stage_error(_current())
		return null
	_add_error(error_code, error_message, _current(), {"found": _current().get_type_name()})
	return null


func _add_unsupported_name_error(token) -> void:
	var suggestion := ""
	if token.lexeme == "await":
		suggestion = "Use wait(segundos) para espera cooperativa."
	_add_error(
		"PARSE_UNSUPPORTED_FEATURE",
		"'%s' é uma palavra reservada de um recurso não suportado. %s" % [token.lexeme, suggestion],
		token, {"feature": token.lexeme, "suggestion": suggestion}
	)


func _add_unsupported_stage_error(token) -> void:
	var construction: String = UNSUPPORTED_STAGE_TYPES[token.type]
	_add_error(
		"PARSE_UNSUPPORTED_STAGE",
		"A construção '%s' ainda não é aceita nesta etapa do parser." % construction,
		token, {"construction": construction, "stage": "simple_statements"}
	)


func _add_error(code: String, message: String, token, details: Dictionary = {}) -> void:
	errors.append(ParseError.new(code, message.strip_edges(), token, details))


func _check(token_type: int) -> bool:
	return _current().type == token_type


func _match(token_type: int) -> bool:
	if not _check(token_type):
		return false
	_advance()
	return true


func _advance():
	if not _check(TokenData.Type.EOF):
		_position += 1
	return _previous()


func _current():
	return tokens[mini(_position, tokens.size() - 1)]


func _previous():
	return tokens[maxi(0, _position - 1)]


func _peek_type(distance: int) -> int:
	return tokens[mini(_position + distance, tokens.size() - 1)].type


func _span_between(first: Ast.SourceSpan, last: Ast.SourceSpan) -> Ast.SourceSpan:
	return Ast.SourceSpan.new(
		first.start_offset, last.end_offset,
		first.start_line, first.start_column, last.end_line, last.end_column
	)


func _span_from_token_to_span(first, last: Ast.SourceSpan) -> Ast.SourceSpan:
	return Ast.SourceSpan.new(
		first.start_offset, last.end_offset,
		first.line, first.column, last.end_line, last.end_column
	)


func _span_from_span_to_token(first: Ast.SourceSpan, last) -> Ast.SourceSpan:
	return Ast.SourceSpan.new(
		first.start_offset, last.end_offset,
		first.start_line, first.start_column, last.end_line, last.end_column
	)


func _token_for_span(source_span: Ast.SourceSpan):
	for token in tokens:
		if token.start_offset == source_span.start_offset:
			return token
	return _current()
