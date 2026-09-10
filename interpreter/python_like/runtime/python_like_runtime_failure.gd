extends RefCounted
class_name PythonLikeRuntimeFailure


var category: String
var code: String
var message: String
var line: int
var column: int
var length: int
var script_id: String
var source_name: String
var runtime_id: String
var details: Dictionary


func _init(failure_category: String, failure_code: String, failure_message: String,
		failure_line: int = 0, failure_column: int = 0, failure_length: int = 0,
		failure_script_id: String = "", failure_source_name: String = "",
		failure_runtime_id: String = "", failure_details: Dictionary = {}) -> void:
	category = failure_category
	code = failure_code
	message = failure_message
	line = failure_line
	column = failure_column
	length = failure_length
	script_id = failure_script_id
	source_name = failure_source_name
	runtime_id = failure_runtime_id
	details = failure_details.duplicate(true)


func to_dictionary() -> Dictionary:
	var data := {
		"category": category,
		"code": code,
		"message": message,
		"line": line,
		"column": column,
		"length": length,
		"script_id": script_id,
		"details": details.duplicate(true),
	}
	if not source_name.is_empty():
		data["source_name"] = source_name
	if not runtime_id.is_empty():
		data["runtime_id"] = runtime_id
	return data

