extends RefCounted
class_name PythonLikeValues


enum Type {
	INTEGER,
	FLOAT,
	BOOLEAN,
	STRING,
	NONE,
	LIST,
	DICTIONARY,
	FUNCTION,
	BUILTIN_FUNCTION,
	RANGE,
}


class EqualityContext extends RefCounted:
	var _active_pairs := {}

	func is_active(left: RuntimeValue, right: RuntimeValue) -> bool:
		return _active_pairs.has(_pair_key(left, right))

	func enter(left: RuntimeValue, right: RuntimeValue) -> void:
		_active_pairs[_pair_key(left, right)] = true

	func leave(left: RuntimeValue, right: RuntimeValue) -> void:
		_active_pairs.erase(_pair_key(left, right))

	func _pair_key(left: RuntimeValue, right: RuntimeValue) -> String:
		return "%d:%d" % [left.get_instance_id(), right.get_instance_id()]


class RepresentationContext extends RefCounted:
	var _active_identities := {}

	func is_active(value: RuntimeValue) -> bool:
		return _active_identities.has(value.identity_id())

	func enter(value: RuntimeValue) -> void:
		_active_identities[value.identity_id()] = true

	func leave(value: RuntimeValue) -> void:
		_active_identities.erase(value.identity_id())


class RuntimeValue extends RefCounted:
	var value_type: Type

	func _init(runtime_type: Type) -> void:
		value_type = runtime_type

	func type_name() -> String:
		return "value"

	func is_truthy() -> bool:
		return true

	func semantic_equals(other: RuntimeValue) -> bool:
		if other == null:
			return false
		return _semantic_equals(other, EqualityContext.new())

	func _semantic_equals(other: RuntimeValue, _context: EqualityContext) -> bool:
		return self == other

	func display_text() -> String:
		return _to_display(RepresentationContext.new())

	func representation() -> String:
		return _to_repr(RepresentationContext.new())

	func _to_display(context: RepresentationContext) -> String:
		return _to_repr(context)

	func _to_repr(_context: RepresentationContext) -> String:
		return "<value>"

	func has_identity() -> bool:
		return false

	func identity_id() -> int:
		return 0

	func is_identical_to(other: RuntimeValue) -> bool:
		return has_identity() and other != null and self == other

	func is_discarded() -> bool:
		return false

	func discard() -> void:
		pass


class IdentityValue extends RuntimeValue:
	var _discarded := false

	func _init(runtime_type: Type) -> void:
		super(runtime_type)

	func has_identity() -> bool:
		return true

	func identity_id() -> int:
		return get_instance_id()

	func is_discarded() -> bool:
		return _discarded

	func discard() -> void:
		_discarded = true


class IntegerValue extends RuntimeValue:
	var numeric_value: int

	func _init(number: int) -> void:
		super(Type.INTEGER)
		numeric_value = number

	func type_name() -> String:
		return "int"

	func is_truthy() -> bool:
		return numeric_value != 0

	func _semantic_equals(other: RuntimeValue, _context: EqualityContext) -> bool:
		if other is IntegerValue:
			return numeric_value == other.numeric_value
		if other is FloatValue:
			return float(numeric_value) == other.numeric_value
		if other is BooleanValue:
			return numeric_value == (1 if other.boolean_value else 0)
		return false

	func _to_repr(_context: RepresentationContext) -> String:
		return str(numeric_value)


class FloatValue extends RuntimeValue:
	var numeric_value: float

	func _init(number: float) -> void:
		super(Type.FLOAT)
		numeric_value = number

	func type_name() -> String:
		return "float"

	func is_truthy() -> bool:
		return numeric_value != 0.0

	func _semantic_equals(other: RuntimeValue, _context: EqualityContext) -> bool:
		if other is FloatValue:
			return numeric_value == other.numeric_value
		if other is IntegerValue:
			return numeric_value == float(other.numeric_value)
		if other is BooleanValue:
			return numeric_value == (1.0 if other.boolean_value else 0.0)
		return false

	func _to_repr(_context: RepresentationContext) -> String:
		var text := str(numeric_value)
		if not text.contains(".") and not text.contains("e") and not text.contains("E"):
			text += ".0"
		return text


class BooleanValue extends RuntimeValue:
	var boolean_value: bool

	func _init(state: bool) -> void:
		super(Type.BOOLEAN)
		boolean_value = state

	func type_name() -> String:
		return "bool"

	func is_truthy() -> bool:
		return boolean_value

	func _semantic_equals(other: RuntimeValue, _context: EqualityContext) -> bool:
		if other is BooleanValue:
			return boolean_value == other.boolean_value
		if other is IntegerValue:
			return (1 if boolean_value else 0) == other.numeric_value
		if other is FloatValue:
			return (1.0 if boolean_value else 0.0) == other.numeric_value
		return false

	func _to_repr(_context: RepresentationContext) -> String:
		return "True" if boolean_value else "False"


class StringValue extends RuntimeValue:
	var string_value: String

	func _init(text: String) -> void:
		super(Type.STRING)
		string_value = text

	func type_name() -> String:
		return "str"

	func is_truthy() -> bool:
		return not string_value.is_empty()

	func _semantic_equals(other: RuntimeValue, _context: EqualityContext) -> bool:
		return other is StringValue and string_value == other.string_value

	func _to_display(_context: RepresentationContext) -> String:
		return string_value

	func _to_repr(_context: RepresentationContext) -> String:
		return "'%s'" % _escaped_content()

	func _escaped_content() -> String:
		var escaped := ""
		for index in range(string_value.length()):
			var character := string_value.substr(index, 1)
			match character:
				"\\": escaped += "\\\\"
				"'": escaped += "\\'"
				"\n": escaped += "\\n"
				"\r": escaped += "\\r"
				"\t": escaped += "\\t"
				"\b": escaped += "\\b"
				"\f": escaped += "\\f"
				_: escaped += character
		return escaped


class NoneValue extends RuntimeValue:
	func _init() -> void:
		super(Type.NONE)

	func type_name() -> String:
		return "NoneType"

	func is_truthy() -> bool:
		return false

	func _semantic_equals(other: RuntimeValue, _context: EqualityContext) -> bool:
		return other is NoneValue

	func _to_repr(_context: RepresentationContext) -> String:
		return "None"


static var _none_singleton
static var _true_singleton
static var _false_singleton


static func none_value() -> NoneValue:
	if _none_singleton == null:
		_none_singleton = NoneValue.new()
	return _none_singleton


static func boolean_value(state: bool) -> BooleanValue:
	if state:
		if _true_singleton == null:
			_true_singleton = BooleanValue.new(true)
		return _true_singleton
	if _false_singleton == null:
		_false_singleton = BooleanValue.new(false)
	return _false_singleton
