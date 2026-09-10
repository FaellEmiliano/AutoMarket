extends RefCounted
class_name PythonLikeAutoMarketRuntimeBridge


class Response extends RefCounted:
	enum Status { SUCCESS, FAILURE, SUSPENDED }

	var status: Status
	var value: Variant
	var category: String
	var code: String
	var message: String
	var details: Dictionary
	var output_lines: Array[String]
	var suspension_seconds: float

	func _init(response_status: Status, response_value = null,
			failure_category: String = "", failure_code: String = "",
			failure_message: String = "", failure_details: Dictionary = {},
			response_output: Array[String] = [], requested_seconds: float = 0.0) -> void:
		status = response_status
		value = response_value
		category = failure_category
		code = failure_code
		message = failure_message
		details = failure_details.duplicate(true)
		output_lines = response_output.duplicate()
		suspension_seconds = requested_seconds

	func is_success() -> bool:
		return status == Status.SUCCESS

	func is_suspended() -> bool:
		return status == Status.SUSPENDED

	static func succeeded(response_value = null,
			response_output: Array[String] = []) -> Response:
		return Response.new(Status.SUCCESS, response_value, "", "", "", {},
			response_output)

	static func failed(failure_code: String, failure_message: String,
			failure_category: String = "gameplay",
			failure_details: Dictionary = {}) -> Response:
		return Response.new(Status.FAILURE, null, failure_category,
			failure_code, failure_message, failure_details)

	static func suspended(seconds: float) -> Response:
		return Response.new(Status.SUSPENDED, null, "", "", "", {}, [], seconds)


func read_input(_context: Dictionary) -> Response:
	return _unsupported("input")


func send(_values: Array, _context: Dictionary) -> Response:
	return _unsupported("send")


func read_sensor(_name: String, _context: Dictionary) -> Response:
	return _unsupported("sensor")


func get_stock(_context: Dictionary) -> Response:
	return _unsupported("get_stock")


func buy_stock(_purchase: Array, _context: Dictionary) -> Response:
	return _unsupported("buy_stock")


func get_deliveries(_context: Dictionary) -> Response:
	return _unsupported("get_deliveries")


func declare_profit(_profits: Array, _context: Dictionary) -> Response:
	return _unsupported("declare_profit")


func wait(_seconds: float, _context: Dictionary) -> Response:
	return _unsupported("wait")


func _unsupported(operation: String) -> Response:
	return Response.failed(
		"AUTOMARKET_BRIDGE_METHOD_UNAVAILABLE",
		"A bridge não implementa a operação '%s'." % operation,
		"bridge", {"operation": operation}
	)
