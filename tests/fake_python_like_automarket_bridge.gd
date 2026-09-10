extends "res://interpreter/python_like/runtime/python_like_automarket_bridge.gd"
class_name FakePythonLikeAutoMarketRuntimeBridge


const Bridge = preload("res://interpreter/python_like/runtime/python_like_automarket_bridge.gd")


var calls: Array = []
var _responses := {}


func set_response(operation: String, value = null,
		output_lines: Array[String] = []) -> void:
	_responses[operation] = Bridge.Response.succeeded(value, output_lines)


func set_failure(operation: String, code: String, message: String,
		category: String = "gameplay", details: Dictionary = {}) -> void:
	_responses[operation] = Bridge.Response.failed(code, message, category, details)


func set_suspension(operation: String, seconds: float) -> void:
	_responses[operation] = Bridge.Response.suspended(seconds)


func calls_for(operation: String) -> Array:
	return calls.filter(func(call): return call.operation == operation)


func read_input(context: Dictionary) -> Bridge.Response:
	return _record("input", [], context)


func send(values: Array, context: Dictionary) -> Bridge.Response:
	return _record("send", values, context)


func read_sensor(name: String, context: Dictionary) -> Bridge.Response:
	return _record("sensor", [name], context)


func get_stock(context: Dictionary) -> Bridge.Response:
	return _record("get_stock", [], context)


func buy_stock(purchase: Array, context: Dictionary) -> Bridge.Response:
	return _record("buy_stock", [purchase], context)


func get_deliveries(context: Dictionary) -> Bridge.Response:
	return _record("get_deliveries", [], context)


func declare_profit(profits: Array, context: Dictionary) -> Bridge.Response:
	return _record("declare_profit", [profits], context)


func wait(seconds: float, context: Dictionary) -> Bridge.Response:
	return _record("wait", [seconds], context)


func _record(operation: String, arguments: Array,
		context: Dictionary) -> Bridge.Response:
	calls.append({
		"operation": operation,
		"arguments": arguments.duplicate(true),
		"context": context.duplicate(true),
	})
	return _responses.get(operation, Bridge.Response.failed(
		"FAKE_RESPONSE_NOT_CONFIGURED",
		"A fake não possui resposta para '%s'." % operation,
		"bridge", {"operation": operation}
	))
