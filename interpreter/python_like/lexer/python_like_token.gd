extends RefCounted
class_name PythonLikeToken


enum Type {
	# Structural
	EOF,
	NEWLINE,
	INDENT,
	DEDENT,

	# Values and names
	NAME,
	INT,
	FLOAT,
	STRING,

	# Keywords
	KW_AND,
	KW_BREAK,
	KW_CONTINUE,
	KW_DEF,
	KW_ELIF,
	KW_ELSE,
	KW_FALSE,
	KW_FOR,
	KW_IF,
	KW_IN,
	KW_NONE,
	KW_NOT,
	KW_OR,
	KW_RETURN,
	KW_TRUE,
	KW_WHILE,

	# Arithmetic and assignment
	PLUS,
	MINUS,
	STAR,
	SLASH,
	DOUBLE_SLASH,
	PERCENT,
	DOUBLE_STAR,
	ASSIGN,
	PLUS_ASSIGN,
	MINUS_ASSIGN,
	STAR_ASSIGN,
	SLASH_ASSIGN,
	DOUBLE_SLASH_ASSIGN,
	PERCENT_ASSIGN,

	# Comparison
	EQ,
	NOT_EQ,
	LT,
	LT_EQ,
	GT,
	GT_EQ,

	# Delimiters
	LPAREN,
	RPAREN,
	LBRACKET,
	RBRACKET,
	LBRACE,
	RBRACE,
	COLON,
	COMMA,
	DOT,
}


var type: Type
var lexeme: String
var value: Variant
var line: int
var column: int
var length: int
var end_line: int
var end_column: int
var start_offset: int
var end_offset: int


func _init(token_type: Type, original_lexeme: String, normalized_value: Variant,
		start_line: int, start_column: int, token_length: int,
		finish_line: int, finish_column: int, begin_offset: int, finish_offset: int) -> void:
	type = token_type
	lexeme = original_lexeme
	value = normalized_value
	line = start_line
	column = start_column
	length = token_length
	end_line = finish_line
	end_column = finish_column
	start_offset = begin_offset
	end_offset = finish_offset


func get_type_name() -> String:
	return Type.keys()[type]


func to_dictionary() -> Dictionary:
	return {
		"type": get_type_name(),
		"lexeme": lexeme,
		"value": value,
		"line": line,
		"column": column,
		"length": length,
		"end_line": end_line,
		"end_column": end_column,
		"start_offset": start_offset,
		"end_offset": end_offset,
	}
