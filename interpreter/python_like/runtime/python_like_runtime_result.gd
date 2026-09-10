extends RefCounted
class_name PythonLikeRuntimeResult


const RuntimeFailure = preload("res://interpreter/python_like/runtime/python_like_runtime_failure.gd")

enum Status {
	VALUE,
	NO_VALUE,
	FAILURE,
	SUSPENDED,
}

var status: Status
var _value: Variant
var _failure: RuntimeFailure


func _init(result_status: Status, result_value = null, result_failure = null) -> void:
	status = result_status
	_value = result_value
	_failure = result_failure


static func success(result_value: Variant):
	return new(Status.VALUE, result_value)


static func no_value():
	return new(Status.NO_VALUE)


static func failed(result_failure: RuntimeFailure):
	return new(Status.FAILURE, null, result_failure)


static func suspended(request):
	return new(Status.SUSPENDED, request)


func has_value() -> bool:
	return status == Status.VALUE


func has_no_value() -> bool:
	return status == Status.NO_VALUE


func has_failure() -> bool:
	return status == Status.FAILURE


func is_suspended() -> bool:
	return status == Status.SUSPENDED


func value() -> Variant:
	return _value if has_value() else null


func failure() -> RuntimeFailure:
	return _failure if has_failure() else null


func suspension():
	return _value if is_suspended() else null
