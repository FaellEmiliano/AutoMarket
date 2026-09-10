extends RefCounted
class_name PythonLikeValueConverter


const Values = preload("res://interpreter/python_like/runtime/python_like_values.gd")
const Collections = preload("res://interpreter/python_like/runtime/python_like_collections.gd")
const RuntimeFailure = preload("res://interpreter/python_like/runtime/python_like_runtime_failure.gd")
const RuntimeResult = preload("res://interpreter/python_like/runtime/python_like_runtime_result.gd")


static func to_native(value) -> RuntimeResult:
	return _to_native(value, {})


static func from_native(value, lifecycle) -> RuntimeResult:
	return _from_native(value, lifecycle, [])


static func _to_native(value, active_identities: Dictionary) -> RuntimeResult:
	if value is Values.NoneValue:
		return RuntimeResult.success(null)
	if value is Values.BooleanValue:
		return RuntimeResult.success(value.boolean_value)
	if value is Values.IntegerValue or value is Values.FloatValue:
		return RuntimeResult.success(value.numeric_value)
	if value is Values.StringValue:
		return RuntimeResult.success(value.string_value)
	if value is Collections.ListValue:
		return _list_to_native(value, active_identities)
	if value is Collections.DictionaryValue:
		return _dictionary_to_native(value, active_identities)
	return _unsupported_python_value(value.type_name() if value != null else "internal_absence")


static func _list_to_native(value, active_identities: Dictionary) -> RuntimeResult:
	var identity: int = value.identity_id()
	if active_identities.has(identity):
		return _cyclic_value_failure("list")
	active_identities[identity] = true
	var result: Array = []
	for index in range(value.size()):
		var item_result = value.item_at_position(index)
		if item_result.has_failure():
			active_identities.erase(identity)
			return item_result
		var converted = _to_native(item_result.value(), active_identities)
		if converted.has_failure():
			active_identities.erase(identity)
			return converted
		result.append(converted.value())
	active_identities.erase(identity)
	return RuntimeResult.success(result)


static func _dictionary_to_native(value, active_identities: Dictionary) -> RuntimeResult:
	var identity: int = value.identity_id()
	if active_identities.has(identity):
		return _cyclic_value_failure("dict")
	active_identities[identity] = true
	var result: Dictionary = {}
	for index in range(value.size()):
		var key_result = value.key_at_position(index)
		var value_result = value.value_at_position(index)
		if key_result.has_failure() or value_result.has_failure():
			active_identities.erase(identity)
			return key_result if key_result.has_failure() else value_result
		var converted_key = _to_native(key_result.value(), active_identities)
		var converted_value = _to_native(value_result.value(), active_identities)
		if converted_key.has_failure() or converted_value.has_failure():
			active_identities.erase(identity)
			return converted_key if converted_key.has_failure() else converted_value
		result[converted_key.value()] = converted_value.value()
	active_identities.erase(identity)
	return RuntimeResult.success(result)


static func _from_native(value, lifecycle, active_containers: Array) -> RuntimeResult:
	match typeof(value):
		TYPE_NIL:
			return RuntimeResult.success(Values.none_value())
		TYPE_BOOL:
			return RuntimeResult.success(Values.boolean_value(value))
		TYPE_INT:
			return RuntimeResult.success(Values.IntegerValue.new(value))
		TYPE_FLOAT:
			return RuntimeResult.success(Values.FloatValue.new(value))
		TYPE_STRING:
			return RuntimeResult.success(Values.StringValue.new(value))
		TYPE_ARRAY:
			return _array_from_native(value, lifecycle, active_containers)
		TYPE_DICTIONARY:
			return _dictionary_from_native(value, lifecycle, active_containers)
	return _unsupported_native_value(type_string(typeof(value)))


static func _array_from_native(value: Array, lifecycle,
		active_containers: Array) -> RuntimeResult:
	if _contains_same_container(active_containers, value):
		return _cyclic_value_failure("Array")
	active_containers.append(value)
	var result = lifecycle.track(Collections.ListValue.new())
	for native_item in value:
		var converted = _from_native(native_item, lifecycle, active_containers)
		if converted.has_failure():
			active_containers.pop_back()
			return converted
		var append_result = result.append(converted.value())
		if append_result.has_failure():
			active_containers.pop_back()
			return append_result
	active_containers.pop_back()
	return RuntimeResult.success(result)


static func _dictionary_from_native(value: Dictionary, lifecycle,
		active_containers: Array) -> RuntimeResult:
	if _contains_same_container(active_containers, value):
		return _cyclic_value_failure("Dictionary")
	active_containers.append(value)
	var result = lifecycle.track(Collections.DictionaryValue.new())
	for native_key in value:
		var converted_key = _from_native(native_key, lifecycle, active_containers)
		var converted_value = _from_native(value[native_key], lifecycle, active_containers)
		if converted_key.has_failure() or converted_value.has_failure():
			active_containers.pop_back()
			return converted_key if converted_key.has_failure() else converted_value
		var set_result = result.set_item(converted_key.value(), converted_value.value())
		if set_result.has_failure():
			active_containers.pop_back()
			return set_result
	active_containers.pop_back()
	return RuntimeResult.success(result)


static func _contains_same_container(active_containers: Array, candidate) -> bool:
	for active in active_containers:
		if is_same(active, candidate):
			return true
	return false


static func _unsupported_python_value(type_name: String) -> RuntimeResult:
	return RuntimeResult.failed(RuntimeFailure.new(
		"conversion", "RUNTIME_UNSUPPORTED_GAMEPLAY_VALUE",
		"O valor Python-like do tipo '%s' não pode atravessar a bridge." % type_name,
		0, 0, 0, "", "", "", {"direction": "to_gameplay", "type": type_name}
	))


static func _unsupported_native_value(type_name: String) -> RuntimeResult:
	return RuntimeResult.failed(RuntimeFailure.new(
		"conversion", "RUNTIME_UNSUPPORTED_GAMEPLAY_VALUE",
		"O valor de gameplay do tipo '%s' não pode entrar no runtime." % type_name,
		0, 0, 0, "", "", "", {"direction": "from_gameplay", "type": type_name}
	))


static func _cyclic_value_failure(type_name: String) -> RuntimeResult:
	return RuntimeResult.failed(RuntimeFailure.new(
		"conversion", "RUNTIME_UNSUPPORTED_GAMEPLAY_VALUE",
		"Estruturas cíclicas não podem atravessar a bridge nesta etapa.",
		0, 0, 0, "", "", "", {"type": type_name, "reason": "cyclic"}
	))
