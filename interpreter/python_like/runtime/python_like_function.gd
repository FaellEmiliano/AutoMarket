extends "res://interpreter/python_like/runtime/python_like_values.gd".IdentityValue
class_name PythonLikeFunctionValue


const Values = preload("res://interpreter/python_like/runtime/python_like_values.gd")
const LexicalEnvironment = preload("res://interpreter/python_like/runtime/python_like_environment.gd")
const RuntimeFailure = preload("res://interpreter/python_like/runtime/python_like_runtime_failure.gd")
const RuntimeResult = preload("res://interpreter/python_like/runtime/python_like_runtime_result.gd")


var function_name: String
var body
var source_span
var closure: LexicalEnvironment
var _parameter_names: Array[String] = []
var _local_names: Array[String] = []


func _init(name: String, parameters: Array, function_body, function_span,
		lexical_environment: LexicalEnvironment, local_names: Array = []) -> void:
	super(Values.Type.FUNCTION)
	function_name = name
	body = function_body
	source_span = function_span
	closure = lexical_environment
	for parameter in parameters:
		register_parameter(parameter)
	for local_name in local_names:
		register_local_name(str(local_name))


func type_name() -> String:
	return "function"


func is_truthy() -> bool:
	return not is_discarded()


func callable_name() -> String:
	return function_name


func minimum_arity() -> int:
	return parameter_count()


func maximum_arity() -> int:
	return parameter_count()


func parameter_count() -> int:
	return _parameter_names.size()


func parameter_name_at(index: int) -> String:
	if index < 0 or index >= _parameter_names.size():
		return ""
	return _parameter_names[index]


func local_count() -> int:
	return _local_names.size()


func local_name_at(index: int) -> String:
	if index < 0 or index >= _local_names.size():
		return ""
	return _local_names[index]


func register_parameter(parameter) -> void:
	var parameter_name: String = str(parameter) \
		if typeof(parameter) == TYPE_STRING else parameter.name
	_parameter_names.append(parameter_name)
	register_local_name(parameter_name)


func register_local_name(local_name: String) -> void:
	if not _local_names.has(local_name):
		_local_names.append(local_name)


func create_call_environment(predeclare_locals: bool = true) -> RuntimeResult:
	if is_discarded():
		return RuntimeResult.failed(RuntimeFailure.new(
			"internal", "INTERNAL_INVALID_STATE", "A função já foi descartada."
		))
	var locals: Array = _local_names if predeclare_locals else []
	return RuntimeResult.success(LexicalEnvironment.new(closure, function_name, locals))


func _semantic_equals(other: Values.RuntimeValue,
		_context: Values.EqualityContext) -> bool:
	return not is_discarded() and self == other


func _to_repr(_context: Values.RepresentationContext) -> String:
	return "<discarded function>" if is_discarded() else "<function %s>" % function_name


func discard() -> void:
	if is_discarded():
		return
	_parameter_names.clear()
	_local_names.clear()
	body = null
	source_span = null
	closure = null
	super()
