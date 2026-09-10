extends RefCounted
class_name PythonLikeParseError


var category: String = "syntax"
var code: String
var message: String
var line: int
var column: int
var length: int
var start_offset: int
var end_offset: int
var end_line: int
var end_column: int
var details: Dictionary


func _init(error_code: String, error_message: String, token,
		extra_details: Dictionary = {}) -> void:
	code = error_code
	message = error_message
	line = token.line
	column = token.column
	length = maxi(0, token.length)
	start_offset = token.start_offset
	end_offset = token.end_offset
	end_line = token.end_line
	end_column = token.end_column
	details = extra_details.duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"category": category,
		"code": code,
		"message": message,
		"line": line,
		"column": column,
		"length": length,
		"start_offset": start_offset,
		"end_offset": end_offset,
		"end_line": end_line,
		"end_column": end_column,
		"details": details.duplicate(true),
	}
