extends RefCounted
class_name PythonLikeEnvironment


const Values = preload("res://interpreter/python_like/runtime/python_like_values.gd")
const RuntimeFailure = preload("res://interpreter/python_like/runtime/python_like_runtime_failure.gd")
const RuntimeResult = preload("res://interpreter/python_like/runtime/python_like_runtime_result.gd")


var scope_name: String
var parent
var _bindings := {}
var _local_names := {}
var _discarded := false


func _init(lexical_parent = null,
		environment_name: String = "module", local_names: Array = []) -> void:
	parent = lexical_parent
	scope_name = environment_name
	for local_name in local_names:
		_local_names[str(local_name)] = true


func create_child(environment_name: String, local_names: Array = []):
	return get_script().new(self, environment_name, local_names)


func mark_local(name: String) -> RuntimeResult:
	if _discarded:
		return _discarded_failure()
	_local_names[name] = true
	return RuntimeResult.no_value()


func define(name: String, value: Values.RuntimeValue) -> RuntimeResult:
	if _discarded:
		return _discarded_failure()
	if value == null:
		return _invalid_value_failure(name)
	_local_names[name] = true
	_bindings[name] = value
	return RuntimeResult.success(value)


func assign_local(name: String, value: Values.RuntimeValue) -> RuntimeResult:
	return define(name, value)


func lookup(name: String) -> RuntimeResult:
	if _discarded:
		return _discarded_failure()
	if _bindings.has(name):
		return RuntimeResult.success(_bindings[name])
	if _local_names.has(name):
		return RuntimeResult.failed(RuntimeFailure.new(
			"name", "NAME_UNBOUND_LOCAL",
			"A variável local '%s' ainda não recebeu valor." % name,
			0, 0, 0, "", "", "", {"name": name, "scope": scope_name}
		))
	if parent != null:
		return parent.lookup(name)
	return RuntimeResult.failed(RuntimeFailure.new(
		"name", "NAME_NOT_DEFINED", "O nome '%s' não está definido." % name,
		0, 0, 0, "", "", "", {"name": name, "scope": scope_name}
	))


func has_local_binding(name: String) -> bool:
	return not _discarded and _bindings.has(name)


func is_declared_local(name: String) -> bool:
	return not _discarded and _local_names.has(name)


func binding_count() -> int:
	return _bindings.size()


func is_discarded() -> bool:
	return _discarded


func discard() -> void:
	if _discarded:
		return
	_bindings.clear()
	_local_names.clear()
	parent = null
	_discarded = true


func _invalid_value_failure(name: String) -> RuntimeResult:
	return RuntimeResult.failed(RuntimeFailure.new(
		"internal", "INTERNAL_INVALID_STATE",
		"O binding '%s' não pode receber ausência interna de valor." % name
	))


func _discarded_failure() -> RuntimeResult:
	return RuntimeResult.failed(RuntimeFailure.new(
		"internal", "INTERNAL_INVALID_STATE", "O ambiente léxico já foi descartado."
	))
