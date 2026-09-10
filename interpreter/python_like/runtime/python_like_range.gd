extends "res://interpreter/python_like/runtime/python_like_values.gd".RuntimeValue
class_name PythonLikeRangeValue


const Values = preload("res://interpreter/python_like/runtime/python_like_values.gd")
const Operators = preload("res://interpreter/python_like/runtime/python_like_operators.gd")
const RuntimeFailure = preload("res://interpreter/python_like/runtime/python_like_runtime_failure.gd")
const RuntimeResult = preload("res://interpreter/python_like/runtime/python_like_runtime_result.gd")


var start: int
var stop: int
var step: int
var argument_count: int
var _length: int


func _init(first: int, exclusive_stop: int, increment: int,
		length: int, original_argument_count: int) -> void:
	super(Values.Type.RANGE)
	start = first
	stop = exclusive_stop
	step = increment
	_length = length
	argument_count = original_argument_count


static func create(first: int, exclusive_stop: int, increment: int,
		original_argument_count: int) -> RuntimeResult:
	if increment == 0:
		return RuntimeResult.failed(RuntimeFailure.new(
			"runtime", "RANGE_ZERO_STEP", "O step de range não pode ser zero."
		))
	if (increment > 0 and first >= exclusive_stop) \
			or (increment < 0 and first <= exclusive_stop):
		return RuntimeResult.success(new(
			first, exclusive_stop, increment, 0, original_argument_count
		))
	var distance_result: RuntimeResult
	if increment > 0:
		distance_result = Operators.apply_binary(
			"-", Values.IntegerValue.new(exclusive_stop), Values.IntegerValue.new(first)
		)
	else:
		distance_result = Operators.apply_binary(
			"-", Values.IntegerValue.new(first), Values.IntegerValue.new(exclusive_stop)
		)
	if distance_result.has_failure():
		return distance_result
	if increment == Operators.INT_MIN:
		return RuntimeResult.failed(RuntimeFailure.new(
			"runtime", "RUNTIME_INTEGER_OVERFLOW",
			"O range excede os limites inteiros do runtime."
		))
	var distance: int = distance_result.value().numeric_value
	var stride: int = absi(increment)
	@warning_ignore("integer_division")
	var length: int = ((distance - 1) / stride) + 1
	return RuntimeResult.success(new(
		first, exclusive_stop, increment, length, original_argument_count
	))


func type_name() -> String:
	return "range"


func is_truthy() -> bool:
	return _length > 0


func size() -> int:
	return _length


func item_at_position(position: int) -> RuntimeResult:
	if position < 0 or position >= _length:
		return RuntimeResult.failed(RuntimeFailure.new(
			"internal", "INTERNAL_INVALID_STATE",
			"Posição interna de range fora do intervalo."
		))
	var offset_result = Operators.checked_integer_multiply(position, step)
	if offset_result.has_failure():
		return offset_result
	return Operators.apply_binary(
		"+", Values.IntegerValue.new(start), offset_result.value()
	)


func _to_repr(_context: Values.RepresentationContext) -> String:
	match argument_count:
		1:
			return "range(%d)" % stop
		2:
			return "range(%d, %d)" % [start, stop]
	return "range(%d, %d, %d)" % [start, stop, step]
