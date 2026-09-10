extends RefCounted
class_name PythonLikeLexer


const TokenData = preload("res://interpreter/python_like/lexer/python_like_token.gd")
const LexError = preload("res://interpreter/python_like/lexer/python_like_lex_error.gd")

const INDENT_WIDTH := 4

const KEYWORDS := {
	"and": TokenData.Type.KW_AND,
	"break": TokenData.Type.KW_BREAK,
	"continue": TokenData.Type.KW_CONTINUE,
	"def": TokenData.Type.KW_DEF,
	"elif": TokenData.Type.KW_ELIF,
	"else": TokenData.Type.KW_ELSE,
	"False": TokenData.Type.KW_FALSE,
	"for": TokenData.Type.KW_FOR,
	"if": TokenData.Type.KW_IF,
	"in": TokenData.Type.KW_IN,
	"None": TokenData.Type.KW_NONE,
	"not": TokenData.Type.KW_NOT,
	"or": TokenData.Type.KW_OR,
	"return": TokenData.Type.KW_RETURN,
	"True": TokenData.Type.KW_TRUE,
	"while": TokenData.Type.KW_WHILE,
}

const THREE_CHARACTER_TOKENS := {
	"//=": TokenData.Type.DOUBLE_SLASH_ASSIGN,
}

const TWO_CHARACTER_TOKENS := {
	"**": TokenData.Type.DOUBLE_STAR,
	"//": TokenData.Type.DOUBLE_SLASH,
	"==": TokenData.Type.EQ,
	"!=": TokenData.Type.NOT_EQ,
	"<=": TokenData.Type.LT_EQ,
	">=": TokenData.Type.GT_EQ,
	"+=": TokenData.Type.PLUS_ASSIGN,
	"-=": TokenData.Type.MINUS_ASSIGN,
	"*=": TokenData.Type.STAR_ASSIGN,
	"/=": TokenData.Type.SLASH_ASSIGN,
	"%=": TokenData.Type.PERCENT_ASSIGN,
}

const ONE_CHARACTER_TOKENS := {
	"+": TokenData.Type.PLUS,
	"-": TokenData.Type.MINUS,
	"*": TokenData.Type.STAR,
	"/": TokenData.Type.SLASH,
	"%": TokenData.Type.PERCENT,
	"=": TokenData.Type.ASSIGN,
	"<": TokenData.Type.LT,
	">": TokenData.Type.GT,
	"(": TokenData.Type.LPAREN,
	")": TokenData.Type.RPAREN,
	"[": TokenData.Type.LBRACKET,
	"]": TokenData.Type.RBRACKET,
	"{": TokenData.Type.LBRACE,
	"}": TokenData.Type.RBRACE,
	":": TokenData.Type.COLON,
	",": TokenData.Type.COMMA,
	".": TokenData.Type.DOT,
}

const OPENING_DELIMITERS := {
	"(": ")",
	"[": "]",
	"{": "}",
}

const CLOSING_DELIMITERS := {
	")": "(",
	"]": "[",
	"}": "{",
}


var source: String
var tokens: Array = []
var errors: Array = []

var _position := 0
var _line := 1
var _column := 1
var _at_line_start := true
var _line_has_code := false
var _current_line_last_type := -1
var _can_indent := false
var _indent_stack: Array[int] = [0]
var _indent_style := ""
var _delimiter_stack: Array[Dictionary] = []
var _halted := false
var _identifier_start_regex := RegEx.new()
var _identifier_continue_regex := RegEx.new()


func _init(raw_source: String = "") -> void:
	# Positions and offsets are defined over a source normalized to LF, as required
	# by the language specification. Lexemes preserve this normalized source text.
	source = raw_source.replace("\r\n", "\n").replace("\r", "\n")
	_identifier_start_regex.compile("^(?:_|\\p{L})$")
	_identifier_continue_regex.compile("^(?:_|\\p{L}|\\p{N})$")


func tokenize() -> Array:
	_reset_state()

	while not _is_at_end() and not _halted:
		if _at_line_start:
			_process_line_start()
			if _at_line_start or _halted or _is_at_end():
				continue

		var character := _peek()
		if character == " " or character == "\t":
			_advance()
			continue
		if character == "\n":
			_process_newline()
			continue
		if character == "#":
			_skip_comment()
			continue

		_scan_token()

	_finish_tokens()
	return tokens


func _reset_state() -> void:
	tokens.clear()
	errors.clear()
	_position = 0
	_line = 1
	_column = 1
	_at_line_start = true
	_line_has_code = false
	_current_line_last_type = -1
	_can_indent = false
	_indent_stack = [0]
	_indent_style = ""
	_delimiter_stack.clear()
	_halted = false


func _process_line_start() -> void:
	var prefix_start := _position
	var prefix_line := _line
	var prefix_has_spaces := false
	var prefix_has_tabs := false
	var indentation := 0

	while _peek() == " " or _peek() == "\t":
		if _peek() == " ":
			prefix_has_spaces = true
			indentation += 1
		else:
			prefix_has_tabs = true
			indentation += INDENT_WIDTH
		_advance()

	if _peek() == "#":
		_skip_comment()
		if _peek() == "\n":
			_advance()
		_at_line_start = true
		return
	if _peek() == "\n":
		_advance()
		_at_line_start = true
		return
	if _is_at_end():
		return

	if not _delimiter_stack.is_empty():
		_at_line_start = false
		return

	var line_style := ""
	if prefix_has_spaces and prefix_has_tabs:
		_add_error(
			"indentation",
			"INDENT_MIXED_WHITESPACE",
			"Tabs e espaços não podem ser misturados na indentação.",
			prefix_line,
			1,
			_position - prefix_start
		)
		_halted = true
		return
	elif prefix_has_spaces:
		line_style = "spaces"
	elif prefix_has_tabs:
		line_style = "tabs"

	if not line_style.is_empty():
		if _indent_style.is_empty():
			_indent_style = line_style
		elif _indent_style != line_style:
			_add_error(
				"indentation",
				"INDENT_MIXED_WHITESPACE",
				"A fonte deve usar somente tabs ou somente espaços para indentar.",
				prefix_line,
				1,
				_position - prefix_start,
				{"first_style": _indent_style, "line_style": line_style}
			)
			_halted = true
			return

	var current_indentation: int = _indent_stack.back()
	if indentation > current_indentation:
		if indentation != current_indentation + INDENT_WIDTH:
			_add_error(
				"indentation",
				"INDENT_INVALID_WIDTH",
				"Cada novo bloco deve avançar exatamente quatro colunas.",
				prefix_line,
				1,
				_position - prefix_start,
				{"current": current_indentation, "received": indentation}
			)
			_halted = true
			return
		if not _can_indent:
			_add_error(
				"indentation",
				"INDENT_UNEXPECTED",
				"Indentação inesperada.",
				prefix_line,
				1,
				_position - prefix_start
			)
			_halted = true
			return
		_indent_stack.append(indentation)
		_add_token(
			TokenData.Type.INDENT,
			source.substr(prefix_start, _position - prefix_start),
			indentation,
			prefix_line,
			1,
			_position - prefix_start,
			_line,
			_column,
			prefix_start,
			_position,
			false
		)
	elif indentation < current_indentation:
		if not _indent_stack.has(indentation):
			_add_error(
				"indentation",
				"INDENT_INVALID_DEDENT",
				"Dedent não corresponde a nenhum nível de indentação anterior.",
				prefix_line,
				1,
				_position - prefix_start,
				{"known_levels": _indent_stack.duplicate(), "received": indentation}
			)
			_halted = true
			return
		while _indent_stack.back() > indentation:
			_indent_stack.pop_back()
			_add_synthetic_token(TokenData.Type.DEDENT, _indent_stack.back(), _line, _column, _position)

	_can_indent = false
	_at_line_start = false
	_line_has_code = false
	_current_line_last_type = -1


func _process_newline() -> void:
	if not _delimiter_stack.is_empty():
		_advance()
		_at_line_start = true
		return

	var start_offset := _position
	var start_line := _line
	var start_column := _column
	_advance()
	if _line_has_code:
		_add_token(
			TokenData.Type.NEWLINE,
			"\n",
			null,
			start_line,
			start_column,
			1,
			_line,
			_column,
			start_offset,
			_position,
			false
		)
		_can_indent = _current_line_last_type == TokenData.Type.COLON
	_at_line_start = true
	_line_has_code = false
	_current_line_last_type = -1


func _scan_token() -> void:
	var character := _peek()
	_line_has_code = true

	if _is_digit(character) or (character == "." and _is_digit(_peek(1))):
		_scan_number()
		return
	if _is_identifier_start(character):
		_scan_identifier()
		return
	if character == "'" or character == "\"":
		_scan_string()
		return

	var three := _peek_string(3)
	if THREE_CHARACTER_TOKENS.has(three):
		_scan_fixed_token(three, THREE_CHARACTER_TOKENS[three])
		return
	var two := _peek_string(2)
	if TWO_CHARACTER_TOKENS.has(two):
		_scan_fixed_token(two, TWO_CHARACTER_TOKENS[two])
		return
	if ONE_CHARACTER_TOKENS.has(character):
		_scan_delimiter_or_fixed_token(character, ONE_CHARACTER_TOKENS[character])
		return

	var error_line := _line
	var error_column := _column
	var invalid_character := _advance()
	_add_error(
		"lexical",
		"LEX_INVALID_CHARACTER",
		"Caractere inválido: %s" % invalid_character,
		error_line,
		error_column,
		1,
		{"character": invalid_character}
	)


func _scan_identifier() -> void:
	var start_offset := _position
	var start_line := _line
	var start_column := _column
	while _is_identifier_continue(_peek()):
		_advance()

	var lexeme := source.substr(start_offset, _position - start_offset)
	var token_type: int = KEYWORDS.get(lexeme, TokenData.Type.NAME)
	var normalized_value: Variant = lexeme
	match token_type:
		TokenData.Type.KW_TRUE:
			normalized_value = true
		TokenData.Type.KW_FALSE:
			normalized_value = false
		TokenData.Type.KW_NONE:
			normalized_value = null

	if token_type == TokenData.Type.NAME and lexeme.begins_with("__") and lexeme.ends_with("__"):
		_add_error(
			"lexical",
			"LEX_RESERVED_IDENTIFIER",
			"Identificadores iniciados e terminados por '__' são reservados.",
			start_line,
			start_column,
			_position - start_offset,
			{"identifier": lexeme}
		)

	_add_token_from_span(token_type, lexeme, normalized_value, start_line, start_column, start_offset)


func _scan_number() -> void:
	# Numeric-looking runs stay isolated from following operators. Unsupported base
	# prefixes, identifier suffixes and incomplete exponents become one structured
	# error, while a method-access dot (for example, 1.method) remains a DOT token.
	var start_offset := _position
	var start_line := _line
	var start_column := _column
	var is_float := false
	var valid := true

	if _peek() == ".":
		is_float = true
		_advance()
		valid = _consume_digit_part() and valid
	else:
		valid = _consume_digit_part() and valid
		var character_after_dot := _peek(1)
		var dot_belongs_to_number := (
			_peek() == "."
			and (
				not _is_identifier_start(character_after_dot)
				or character_after_dot == "_"
				or character_after_dot == "e"
				or character_after_dot == "E"
			)
		)
		if dot_belongs_to_number:
			is_float = true
			_advance()
			if _peek() == "_":
				valid = false
			valid = _consume_digit_part(true) and valid

	if _peek() == "e" or _peek() == "E":
		is_float = true
		_advance()
		if _peek() == "+" or _peek() == "-":
			_advance()
		if not _consume_digit_part():
			valid = false

	if _is_identifier_continue(_peek()):
		valid = false
		while _is_identifier_continue(_peek()):
			_advance()

	if _peek() == "." and _is_digit(_peek(1)):
		valid = false
		_advance()
		_consume_digit_part(true)

	var lexeme := source.substr(start_offset, _position - start_offset)
	if not valid:
		_add_error(
			"lexical",
			"LEX_INVALID_NUMBER",
			"Número inválido: %s" % lexeme,
			start_line,
			start_column,
			_position - start_offset,
			{"lexeme": lexeme}
		)
		return

	var normalized_text := lexeme.replace("_", "")
	var token_type := TokenData.Type.FLOAT if is_float else TokenData.Type.INT
	var normalized_value: Variant = float(normalized_text) if is_float else int(normalized_text)
	_add_token_from_span(token_type, lexeme, normalized_value, start_line, start_column, start_offset)


func _consume_digit_part(allow_empty: bool = false) -> bool:
	var saw_digit := false
	var previous_underscore := false
	var valid := true
	while _is_digit(_peek()) or _peek() == "_":
		if _peek() == "_":
			if not saw_digit or previous_underscore:
				valid = false
			previous_underscore = true
		else:
			saw_digit = true
			previous_underscore = false
		_advance()
	if previous_underscore:
		valid = false
	return valid and (saw_digit or allow_empty)


func _scan_string() -> void:
	var start_offset := _position
	var start_line := _line
	var start_column := _column
	var quote := _advance()
	var normalized_value := ""

	while not _is_at_end() and _peek() != "\n" and _peek() != quote:
		if _peek() != "\\":
			normalized_value += _advance()
			continue

		var escape_offset := _position
		var escape_line := _line
		var escape_column := _column
		_advance()
		if _is_at_end() or _peek() == "\n":
			break

		var escaped := _advance()
		match escaped:
			"\\": normalized_value += "\\"
			"'": normalized_value += "'"
			"\"": normalized_value += "\""
			"n": normalized_value += "\n"
			"r": normalized_value += "\r"
			"t": normalized_value += "\t"
			"b": normalized_value += "\b"
			"f": normalized_value += "\f"
			"u", "U":
				var digit_count := 4 if escaped == "u" else 8
				var hex_text := ""
				while hex_text.length() < digit_count and _is_hex_digit(_peek()):
					hex_text += _advance()
				if hex_text.length() != digit_count:
					_add_error(
						"lexical",
						"LEX_INVALID_ESCAPE",
						"Escape Unicode incompleto ou inválido.",
						escape_line,
						escape_column,
						maxi(2, _position - escape_offset),
						{"escape": source.substr(escape_offset, _position - escape_offset)}
					)
				else:
					var codepoint := hex_text.hex_to_int()
					if codepoint > 0x10ffff or (codepoint >= 0xd800 and codepoint <= 0xdfff):
						_add_error(
							"lexical",
							"LEX_INVALID_ESCAPE",
							"Escape Unicode fora do intervalo válido.",
							escape_line,
							escape_column,
							_position - escape_offset,
							{"codepoint": codepoint}
						)
					else:
						normalized_value += String.chr(codepoint)
			_:
				_add_error(
					"lexical",
					"LEX_INVALID_ESCAPE",
					"Escape não suportado: \\%s" % escaped,
					escape_line,
					escape_column,
					_position - escape_offset,
					{"escape": escaped}
				)

	if _peek() == quote:
		_advance()
		var lexeme := source.substr(start_offset, _position - start_offset)
		_add_token_from_span(TokenData.Type.STRING, lexeme, normalized_value, start_line, start_column, start_offset)
		return

	_add_error(
		"lexical",
		"LEX_UNTERMINATED_STRING",
		"String não terminada.",
		start_line,
		start_column,
		maxi(1, _position - start_offset),
		{"quote": quote}
	)
	if _is_at_end():
		_halted = true


func _scan_fixed_token(lexeme: String, token_type: int) -> void:
	var start_offset := _position
	var start_line := _line
	var start_column := _column
	for _index in range(lexeme.length()):
		_advance()
	_add_token_from_span(token_type, lexeme, lexeme, start_line, start_column, start_offset)


func _scan_delimiter_or_fixed_token(lexeme: String, token_type: int) -> void:
	var start_offset := _position
	var start_line := _line
	var start_column := _column

	if CLOSING_DELIMITERS.has(lexeme):
		if _delimiter_stack.is_empty():
			_advance()
			_add_error(
				"lexical",
				"LEX_UNEXPECTED_CLOSING_DELIMITER",
				"Delimitador de fechamento sem abertura: %s" % lexeme,
				start_line,
				start_column,
				1,
				{"found": lexeme}
			)
			return
		var opening: Dictionary = _delimiter_stack.back()
		if str(opening["expected"]) != lexeme:
			_advance()
			_add_error(
				"lexical",
				"LEX_MISMATCHED_DELIMITER",
				"Delimitador incompatível: esperado '%s', encontrado '%s'." % [opening["expected"], lexeme],
				start_line,
				start_column,
				1,
				{
					"expected": opening["expected"],
					"found": lexeme,
					"opening_line": opening["line"],
					"opening_column": opening["column"],
				}
			)
			_delimiter_stack.clear()
			_halted = true
			return
		_delimiter_stack.pop_back()

	_advance()
	_add_token_from_span(token_type, lexeme, lexeme, start_line, start_column, start_offset)
	if OPENING_DELIMITERS.has(lexeme):
		_delimiter_stack.append({
			"opening": lexeme,
			"expected": OPENING_DELIMITERS[lexeme],
			"line": start_line,
			"column": start_column,
			"offset": start_offset,
		})


func _skip_comment() -> void:
	while not _is_at_end() and _peek() != "\n":
		_advance()


func _finish_tokens() -> void:
	if not _halted and not _delimiter_stack.is_empty():
		for opening in _delimiter_stack:
			_add_error(
				"lexical",
				"LEX_UNCLOSED_DELIMITER",
				"Delimitador '%s' não foi fechado." % opening["opening"],
				int(opening["line"]),
				int(opening["column"]),
				1,
				{"opening": opening["opening"], "expected": opening["expected"]}
			)
		_halted = true

	if not _halted:
		if _line_has_code:
			_add_synthetic_token(TokenData.Type.NEWLINE, null, _line, _column, _position)
		while _indent_stack.size() > 1:
			_indent_stack.pop_back()
			_add_synthetic_token(TokenData.Type.DEDENT, _indent_stack.back(), _line, _column, _position)

	_add_synthetic_token(TokenData.Type.EOF, null, _line, _column, _position)


func _add_token_from_span(token_type: int, lexeme: String, normalized_value: Variant,
		start_line: int, start_column: int, start_offset: int) -> void:
	_add_token(
		token_type,
		lexeme,
		normalized_value,
		start_line,
		start_column,
		_position - start_offset,
		_line,
		_column,
		start_offset,
		_position
	)


func _add_synthetic_token(token_type: int, normalized_value: Variant,
		token_line: int, token_column: int, token_offset: int) -> void:
	_add_token(
		token_type,
		"",
		normalized_value,
		token_line,
		token_column,
		0,
		token_line,
		token_column,
		token_offset,
		token_offset,
		false
	)


func _add_token(token_type: int, lexeme: String, normalized_value: Variant,
		start_line: int, start_column: int, token_length: int,
		finish_line: int, finish_column: int, start_offset: int, finish_offset: int,
		counts_as_code: bool = true) -> void:
	tokens.append(TokenData.new(
		token_type,
		lexeme,
		normalized_value,
		start_line,
		start_column,
		token_length,
		finish_line,
		finish_column,
		start_offset,
		finish_offset
	))
	if counts_as_code and token_type not in [
		TokenData.Type.NEWLINE,
		TokenData.Type.INDENT,
		TokenData.Type.DEDENT,
		TokenData.Type.EOF,
	]:
		_line_has_code = true
		_current_line_last_type = token_type


func _add_error(category: String, code: String, message: String,
		error_line: int, error_column: int, error_length: int = 1,
		details: Dictionary = {}) -> void:
	errors.append(LexError.new(
		category,
		code,
		message,
		error_line,
		error_column,
		error_length,
		details
	))


func _advance() -> String:
	if _is_at_end():
		return ""
	var character := source[_position]
	_position += 1
	if character == "\n":
		_line += 1
		_column = 1
	else:
		_column += 1
	return character


func _peek(offset: int = 0) -> String:
	var target := _position + offset
	if target < 0 or target >= source.length():
		return ""
	return source[target]


func _peek_string(count: int) -> String:
	if _position + count > source.length():
		return ""
	return source.substr(_position, count)


func _is_at_end() -> bool:
	return _position >= source.length()


func _is_digit(character: String) -> bool:
	return character.length() == 1 and character >= "0" and character <= "9"


func _is_identifier_start(character: String) -> bool:
	if character.is_empty():
		return false
	return _identifier_start_regex.search(character) != null


func _is_identifier_continue(character: String) -> bool:
	if character.is_empty():
		return false
	return _identifier_continue_regex.search(character) != null


func _is_hex_digit(character: String) -> bool:
	if _is_digit(character):
		return true
	var lowered := character.to_lower()
	return lowered.length() == 1 and lowered >= "a" and lowered <= "f"
