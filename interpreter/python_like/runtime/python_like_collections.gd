extends RefCounted
class_name PythonLikeCollections


const Values = preload("res://interpreter/python_like/runtime/python_like_values.gd")
const RuntimeFailure = preload("res://interpreter/python_like/runtime/python_like_runtime_failure.gd")
const RuntimeResult = preload("res://interpreter/python_like/runtime/python_like_runtime_result.gd")


class ListValue extends Values.IdentityValue:
	var _elements: Array = []
	var mutation_version: int = 0

	func _init() -> void:
		super(Values.Type.LIST)

	func type_name() -> String:
		return "list"

	func is_truthy() -> bool:
		return not _elements.is_empty() and not is_discarded()

	func size() -> int:
		return _elements.size()

	func item_at_position(position: int) -> RuntimeResult:
		if is_discarded():
			return _discarded_failure()
		if position < 0 or position >= _elements.size():
			return RuntimeResult.failed(RuntimeFailure.new(
				"internal", "INTERNAL_INVALID_STATE",
				"Posição interna de lista fora do intervalo."
			))
		return RuntimeResult.success(_elements[position])

	func append(value: Values.RuntimeValue) -> RuntimeResult:
		var validation = _validate_value(value)
		if validation != null:
			return validation
		_elements.append(value)
		mutation_version += 1
		return RuntimeResult.success(Values.none_value())

	func get_item(index: Values.RuntimeValue) -> RuntimeResult:
		var normalized := _normalized_index(index)
		if normalized.has_failure():
			return normalized
		return RuntimeResult.success(_elements[normalized.value().numeric_value])

	func set_item(index: Values.RuntimeValue, value: Values.RuntimeValue) -> RuntimeResult:
		var validation = _validate_value(value)
		if validation != null:
			return validation
		var normalized := _normalized_index(index)
		if normalized.has_failure():
			return normalized
		_elements[normalized.value().numeric_value] = value
		mutation_version += 1
		return RuntimeResult.success(Values.none_value())

	func contains(value: Values.RuntimeValue) -> RuntimeResult:
		var validation = _validate_value(value)
		if validation != null:
			return validation
		for element in _elements:
			if element.semantic_equals(value):
				return RuntimeResult.success(Values.boolean_value(true))
		return RuntimeResult.success(Values.boolean_value(false))

	func pop_last() -> RuntimeResult:
		if is_discarded():
			return _discarded_failure()
		if _elements.is_empty():
			return RuntimeResult.failed(RuntimeFailure.new(
				"index", "INDEX_OUT_OF_RANGE", "Não é possível remover de uma lista vazia."
			))
		var value: Values.RuntimeValue = _elements.pop_back()
		mutation_version += 1
		return RuntimeResult.success(value)

	func pop_at(index: Values.RuntimeValue) -> RuntimeResult:
		var normalized := _normalized_index(index)
		if normalized.has_failure():
			return normalized
		var value: Values.RuntimeValue = _elements.pop_at(normalized.value().numeric_value)
		mutation_version += 1
		return RuntimeResult.success(value)

	func concatenated(other: ListValue) -> RuntimeResult:
		if is_discarded() or other == null or other.is_discarded():
			return _discarded_failure()
		var result := ListValue.new()
		for element in _elements:
			result._elements.append(element)
		for element in other._elements:
			result._elements.append(element)
		return RuntimeResult.success(result)

	func repeated(times: int) -> RuntimeResult:
		if is_discarded():
			return _discarded_failure()
		var result := ListValue.new()
		for _repetition in range(maxi(0, times)):
			for element in _elements:
				result._elements.append(element)
		return RuntimeResult.success(result)

	func _normalized_index(index: Values.RuntimeValue) -> RuntimeResult:
		if is_discarded():
			return _discarded_failure()
		var raw_index: int
		if index is Values.IntegerValue:
			raw_index = index.numeric_value
		elif index is Values.BooleanValue:
			raw_index = 1 if index.boolean_value else 0
		else:
			return RuntimeResult.failed(RuntimeFailure.new(
				"index", "INDEX_NOT_INTEGER", "O índice de lista deve ser int ou bool."
			))
		if raw_index < 0:
			raw_index += _elements.size()
		if raw_index < 0 or raw_index >= _elements.size():
			return RuntimeResult.failed(RuntimeFailure.new(
				"index", "INDEX_OUT_OF_RANGE", "Índice de lista fora do intervalo.",
				0, 0, 0, "", "", "", {"index": raw_index, "size": _elements.size()}
			))
		return RuntimeResult.success(Values.IntegerValue.new(raw_index))

	func _validate_value(value: Values.RuntimeValue):
		if is_discarded():
			return _discarded_failure()
		if value == null:
			return RuntimeResult.failed(RuntimeFailure.new(
				"internal", "INTERNAL_INVALID_STATE",
				"Uma coleção não pode armazenar ausência interna de valor."
			))
		return null

	func _discarded_failure() -> RuntimeResult:
		return RuntimeResult.failed(RuntimeFailure.new(
			"internal", "INTERNAL_INVALID_STATE", "A lista já foi descartada."
		))

	func _semantic_equals(other: Values.RuntimeValue,
			context: Values.EqualityContext) -> bool:
		if not other is ListValue or is_discarded() or other.is_discarded():
			return false
		if self == other:
			return true
		if _elements.size() != other._elements.size():
			return false
		if context.is_active(self, other):
			return true
		context.enter(self, other)
		for index in range(_elements.size()):
			if not _elements[index]._semantic_equals(other._elements[index], context):
				context.leave(self, other)
				return false
		context.leave(self, other)
		return true

	func _to_repr(context: Values.RepresentationContext) -> String:
		if is_discarded():
			return "<discarded list>"
		if context.is_active(self):
			return "[...]"
		context.enter(self)
		var parts: Array[String] = []
		for element in _elements:
			parts.append(element._to_repr(context))
		context.leave(self)
		return "[%s]" % ", ".join(parts)

	func discard() -> void:
		if is_discarded():
			return
		_elements.clear()
		mutation_version += 1
		super()


class DictionaryEntry extends RefCounted:
	var key: Values.RuntimeValue
	var value: Values.RuntimeValue

	func _init(entry_key: Values.RuntimeValue, entry_value: Values.RuntimeValue) -> void:
		key = entry_key
		value = entry_value


class DictionaryValue extends Values.IdentityValue:
	var _entries: Array = []
	var mutation_version: int = 0

	func _init() -> void:
		super(Values.Type.DICTIONARY)

	func type_name() -> String:
		return "dict"

	func is_truthy() -> bool:
		return not _entries.is_empty() and not is_discarded()

	func size() -> int:
		return _entries.size()

	func key_at_position(position: int) -> RuntimeResult:
		if is_discarded():
			return _discarded_failure()
		if position < 0 or position >= _entries.size():
			return RuntimeResult.failed(RuntimeFailure.new(
				"internal", "INTERNAL_INVALID_STATE",
				"Posição interna de dicionário fora do intervalo."
			))
		return RuntimeResult.success(_entries[position].key)

	func value_at_position(position: int) -> RuntimeResult:
		if is_discarded():
			return _discarded_failure()
		if position < 0 or position >= _entries.size():
			return RuntimeResult.failed(RuntimeFailure.new(
				"internal", "INTERNAL_INVALID_STATE",
				"Posição interna de dicionário fora do intervalo."
			))
		return RuntimeResult.success(_entries[position].value)

	func set_item_at_position(position: int, key: Values.RuntimeValue,
			value: Values.RuntimeValue) -> RuntimeResult:
		var validation = _validate_key(key)
		if validation != null:
			return validation
		if value == null:
			return _invalid_value_failure()
		if position < -1 or position >= _entries.size():
			return RuntimeResult.failed(RuntimeFailure.new(
				"internal", "INTERNAL_INVALID_STATE",
				"Posição interna de dicionário fora do intervalo."
			))
		if position == -1:
			_entries.append(DictionaryEntry.new(key, value))
		else:
			_entries[position].value = value
		mutation_version += 1
		return RuntimeResult.success(Values.none_value())

	func contains_key(key: Values.RuntimeValue) -> RuntimeResult:
		var validation = _validate_key(key)
		if validation != null:
			return validation
		return RuntimeResult.success(Values.boolean_value(_find_key_index(key) >= 0))

	func get_item(key: Values.RuntimeValue) -> RuntimeResult:
		var validation = _validate_key(key)
		if validation != null:
			return validation
		var index := _find_key_index(key)
		if index < 0:
			return _missing_key_failure(key)
		return RuntimeResult.success(_entries[index].value)

	func get_or_none(key: Values.RuntimeValue) -> RuntimeResult:
		return get_or(key, Values.none_value())

	func get_or(key: Values.RuntimeValue, fallback: Values.RuntimeValue) -> RuntimeResult:
		var validation = _validate_key(key)
		if validation != null:
			return validation
		if fallback == null:
			return _invalid_value_failure()
		var index := _find_key_index(key)
		return RuntimeResult.success(fallback if index < 0 else _entries[index].value)

	func set_item(key: Values.RuntimeValue, value: Values.RuntimeValue) -> RuntimeResult:
		var validation = _validate_key(key)
		if validation != null:
			return validation
		if value == null:
			return _invalid_value_failure()
		var index := _find_key_index(key)
		if index < 0:
			_entries.append(DictionaryEntry.new(key, value))
		else:
			_entries[index].value = value
		mutation_version += 1
		return RuntimeResult.success(Values.none_value())

	func pop(key: Values.RuntimeValue) -> RuntimeResult:
		var validation = _validate_key(key)
		if validation != null:
			return validation
		var index := _find_key_index(key)
		if index < 0:
			return _missing_key_failure(key)
		var value: Values.RuntimeValue = _entries[index].value
		_entries.remove_at(index)
		mutation_version += 1
		return RuntimeResult.success(value)

	func pop_or(key: Values.RuntimeValue, fallback: Values.RuntimeValue) -> RuntimeResult:
		var validation = _validate_key(key)
		if validation != null:
			return validation
		if fallback == null:
			return _invalid_value_failure()
		var index := _find_key_index(key)
		if index < 0:
			return RuntimeResult.success(fallback)
		var value: Values.RuntimeValue = _entries[index].value
		_entries.remove_at(index)
		mutation_version += 1
		return RuntimeResult.success(value)

	func _find_key_index(key: Values.RuntimeValue) -> int:
		for index in range(_entries.size()):
			if _entries[index].key.semantic_equals(key):
				return index
		return -1

	func _validate_key(key: Values.RuntimeValue):
		if is_discarded():
			return _discarded_failure()
		if key == null or not is_valid_key(key):
			return RuntimeResult.failed(RuntimeFailure.new(
				"type", "TYPE_UNHASHABLE_KEY",
				"A chave deve ser int, float, bool, str ou None."
			))
		return null

	func is_valid_key(key: Values.RuntimeValue) -> bool:
		return key is Values.IntegerValue or key is Values.FloatValue \
			or key is Values.BooleanValue or key is Values.StringValue \
			or key is Values.NoneValue

	func _missing_key_failure(key: Values.RuntimeValue) -> RuntimeResult:
		return RuntimeResult.failed(RuntimeFailure.new(
			"key", "KEY_NOT_FOUND", "A chave %s não existe." % key.representation()
		))

	func _invalid_value_failure() -> RuntimeResult:
		return RuntimeResult.failed(RuntimeFailure.new(
			"internal", "INTERNAL_INVALID_STATE",
			"Um dicionário não pode armazenar ausência interna de valor."
		))

	func _discarded_failure() -> RuntimeResult:
		return RuntimeResult.failed(RuntimeFailure.new(
			"internal", "INTERNAL_INVALID_STATE", "O dicionário já foi descartado."
		))

	func _semantic_equals(other: Values.RuntimeValue,
			context: Values.EqualityContext) -> bool:
		if not other is DictionaryValue or is_discarded() or other.is_discarded():
			return false
		var other_dictionary: DictionaryValue = other
		if self == other:
			return true
		if _entries.size() != other_dictionary._entries.size():
			return false
		if context.is_active(self, other):
			return true
		context.enter(self, other)
		for entry in _entries:
			var other_index: int = other_dictionary._find_key_index(entry.key)
			if other_index < 0 or not entry.value._semantic_equals(
					other_dictionary._entries[other_index].value, context):
				context.leave(self, other)
				return false
		context.leave(self, other)
		return true

	func _to_repr(context: Values.RepresentationContext) -> String:
		if is_discarded():
			return "<discarded dict>"
		if context.is_active(self):
			return "{...}"
		context.enter(self)
		var parts: Array[String] = []
		for entry in _entries:
			parts.append("%s: %s" % [
				entry.key._to_repr(context), entry.value._to_repr(context)
			])
		context.leave(self)
		return "{%s}" % ", ".join(parts)

	func discard() -> void:
		if is_discarded():
			return
		_entries.clear()
		mutation_version += 1
		super()
