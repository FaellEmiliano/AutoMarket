extends "res://interpreter/python_like/runtime/python_like_values.gd".IdentityValue
class_name PythonLikeBuiltinFunctionValue


const Values = preload("res://interpreter/python_like/runtime/python_like_values.gd")
const RuntimeFailure = preload("res://interpreter/python_like/runtime/python_like_runtime_failure.gd")
const RuntimeResult = preload("res://interpreter/python_like/runtime/python_like_runtime_result.gd")


var function_name: String
var _minimum_arity: int
var _maximum_arity: int
var _implementation: Callable


func _init(name: String, minimum_arguments: int, maximum_arguments: int,
		implementation: Callable) -> void:
	super(Values.Type.BUILTIN_FUNCTION)
	function_name = name
	_minimum_arity = minimum_arguments
	_maximum_arity = maximum_arguments
	_implementation = implementation


func type_name() -> String:
	return "builtin_function"


func is_truthy() -> bool:
	return not is_discarded()


func callable_name() -> String:
	return function_name


func minimum_arity() -> int:
	return _minimum_arity


func maximum_arity() -> int:
	return _maximum_arity


func invoke(arguments: Array) -> RuntimeResult:
	if is_discarded() or not _implementation.is_valid():
		return RuntimeResult.failed(RuntimeFailure.new(
			"internal", "INTERNAL_INVALID_STATE",
			"A função nativa '%s' não está disponível." % function_name
		))
	var result = _implementation.call(arguments)
	if not result is RuntimeResult:
		return RuntimeResult.failed(RuntimeFailure.new(
			"internal", "INTERNAL_INVALID_BUILTIN_RESULT",
			"A função nativa '%s' retornou um resultado interno inválido." \
				% function_name
		))
	return result


func _semantic_equals(other: Values.RuntimeValue,
		_context: Values.EqualityContext) -> bool:
	return not is_discarded() and self == other


func _to_repr(_context: Values.RepresentationContext) -> String:
	return "<discarded built-in function>" if is_discarded() \
		else "<built-in function %s>" % function_name


func discard() -> void:
	if is_discarded():
		return
	_implementation = Callable()
	super()
