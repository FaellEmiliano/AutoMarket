extends RefCounted
class_name PythonLikeLexError


var category: String
var code: String
var message: String
var line: int
var column: int
var length: int
var details: Dictionary


func _init(error_category: String, error_code: String, error_message: String,
		start_line: int, start_column: int, error_length: int = 1,
		extra_details: Dictionary = {}) -> void:
	category = error_category
	code = error_code
	message = error_message
	line = start_line
	column = start_column
	length = maxi(0, error_length)
	details = extra_details.duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"category": category,
		"code": code,
		"message": message,
		"line": line,
		"column": column,
		"length": length,
		"details": details.duplicate(true),
	}
