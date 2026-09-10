extends RefCounted
class_name PythonLikeOperators


const Values = preload("res://interpreter/python_like/runtime/python_like_values.gd")
const RuntimeFailure = preload("res://interpreter/python_like/runtime/python_like_runtime_failure.gd")
const RuntimeResult = preload("res://interpreter/python_like/runtime/python_like_runtime_result.gd")

const INT_MAX: int = 9223372036854775807
const INT_MIN: int = -9223372036854775807 - 1


static func apply_unary(operator: String, operand) -> RuntimeResult:
	match operator:
		"not":
			return RuntimeResult.success(Values.boolean_value(not operand.is_truthy()))
		"+", "-":
			if not _is_numeric(operand):
				return _type_error("O operador '%s' exige um valor numérico." % operator)
			if operand is Values.FloatValue:
				var float_result: float = operand.numeric_value
				if operator == "-":
					float_result = -float_result
				return _checked_float(float_result)
			var integer := _as_int(operand)
			if operator == "-":
				if integer == INT_MIN:
					return _overflow_error()
				integer = -integer
			return RuntimeResult.success(Values.IntegerValue.new(integer))
	return _type_error("Operador unário desconhecido: '%s'." % operator)


static func apply_binary(operator: String, left, right) -> RuntimeResult:
	match operator:
		"+":
			if left is Values.StringValue and right is Values.StringValue:
				return RuntimeResult.success(Values.StringValue.new(
					left.string_value + right.string_value
				))
			return _numeric_binary(operator, left, right)
		"-", "*", "/", "//", "%":
			if operator == "*":
				var string_repeat: Variant = _string_repetition(left, right)
				if string_repeat != null:
					return string_repeat
			return _numeric_binary(operator, left, right)
	return _type_error("Operador binário ainda não suportado: '%s'." % operator)


static func apply_comparison(operator: String, left, right) -> RuntimeResult:
	if operator == "==" or operator == "!=":
		if left.value_type in [Values.Type.LIST, Values.Type.DICTIONARY] \
				or right.value_type in [Values.Type.LIST, Values.Type.DICTIONARY]:
			return _type_error(
				"Igualdade estrutural de coleções ainda não é executada nesta etapa."
			)
		var equal: bool = left.semantic_equals(right)
		return RuntimeResult.success(Values.boolean_value(equal if operator == "==" else not equal))

	var numeric := _is_numeric(left) and _is_numeric(right)
	var strings := left is Values.StringValue and right is Values.StringValue
	if not numeric and not strings:
		return _type_error(
			"Não é possível comparar %s com %s usando '%s'." % [
				left.type_name(), right.type_name(), operator
			]
		)
	var left_value = _as_float(left) if numeric else left.string_value
	var right_value = _as_float(right) if numeric else right.string_value
	var result: bool
	match operator:
		"<": result = left_value < right_value
		"<=": result = left_value <= right_value
		">": result = left_value > right_value
		">=": result = left_value >= right_value
		_: return _type_error("Operador de comparação desconhecido: '%s'." % operator)
	return RuntimeResult.success(Values.boolean_value(result))


static func checked_integer_multiply(left: int, right: int) -> RuntimeResult:
	if left == 0 or right == 0:
		return RuntimeResult.success(Values.IntegerValue.new(0))
	if left > 0:
		if right > 0 and left > INT_MAX / right:
			return _overflow_error()
		if right < 0 and right < INT_MIN / left:
			return _overflow_error()
	else:
		if right > 0 and left < INT_MIN / right:
			return _overflow_error()
		if right < 0 and left < INT_MAX / right:
			return _overflow_error()
	return RuntimeResult.success(Values.IntegerValue.new(left * right))


static func _numeric_binary(operator: String, left, right) -> RuntimeResult:
	if not _is_numeric(left) or not _is_numeric(right):
		return _type_error("O operador '%s' exige operandos numéricos compatíveis." % operator)
	var use_float := left is Values.FloatValue or right is Values.FloatValue
	if operator in ["/", "//", "%"] and _is_zero(right):
		return RuntimeResult.failed(RuntimeFailure.new(
			"runtime", "RUNTIME_DIVISION_BY_ZERO", "Divisão ou módulo por zero."
		))
	if use_float:
		var a := _as_float(left)
		var b := _as_float(right)
		var value: float
		match operator:
			"+": value = a + b
			"-": value = a - b
			"*": value = a * b
			"/": value = a / b
			"//": value = floor(a / b)
			"%":
				value = fmod(a, b)
				if value != 0.0 and ((value < 0.0) != (b < 0.0)):
					value += b
		return _checked_float(value)

	var a := _as_int(left)
	var b := _as_int(right)
	match operator:
		"+":
			if (b > 0 and a > INT_MAX - b) or (b < 0 and a < INT_MIN - b):
				return _overflow_error()
			return RuntimeResult.success(Values.IntegerValue.new(a + b))
		"-":
			if (b < 0 and a > INT_MAX + b) or (b > 0 and a < INT_MIN + b):
				return _overflow_error()
			return RuntimeResult.success(Values.IntegerValue.new(a - b))
		"*":
			return checked_integer_multiply(a, b)
		"/":
			return _checked_float(float(a) / float(b))
		"//":
			if a == INT_MIN and b == -1:
				return _overflow_error()
			var quotient: int = a / b
			var remainder: int = a % b
			if remainder != 0 and ((remainder < 0) != (b < 0)):
				quotient -= 1
			return RuntimeResult.success(Values.IntegerValue.new(quotient))
		"%":
			if a == INT_MIN and b == -1:
				return RuntimeResult.success(Values.IntegerValue.new(0))
			var remainder: int = a % b
			if remainder != 0 and ((remainder < 0) != (b < 0)):
				remainder += b
			return RuntimeResult.success(Values.IntegerValue.new(remainder))
	return _type_error("Operador numérico desconhecido: '%s'." % operator)


static func _string_repetition(left, right):
	var text_value = null
	var count_value = null
	if left is Values.StringValue and _is_integral(right):
		text_value = left
		count_value = right
	elif right is Values.StringValue and _is_integral(left):
		text_value = right
		count_value = left
	if text_value == null:
		return null
	return RuntimeResult.success(Values.StringValue.new(
		text_value.string_value.repeat(maxi(0, _as_int(count_value)))
	))


static func _is_numeric(value) -> bool:
	return value is Values.IntegerValue or value is Values.FloatValue \
		or value is Values.BooleanValue


static func _is_integral(value) -> bool:
	return value is Values.IntegerValue or value is Values.BooleanValue


static func _as_int(value) -> int:
	if value is Values.BooleanValue:
		return 1 if value.boolean_value else 0
	return value.numeric_value


static func _as_float(value) -> float:
	if value is Values.BooleanValue:
		return 1.0 if value.boolean_value else 0.0
	return float(value.numeric_value)


static func _is_zero(value) -> bool:
	return _as_float(value) == 0.0


static func _checked_float(value: float) -> RuntimeResult:
	if is_nan(value) or is_inf(value):
		return RuntimeResult.failed(RuntimeFailure.new(
			"runtime", "RUNTIME_NON_FINITE_NUMBER",
			"A operação produziu um número float não finito."
		))
	return RuntimeResult.success(Values.FloatValue.new(value))


static func _type_error(message: String) -> RuntimeResult:
	return RuntimeResult.failed(RuntimeFailure.new("type", "TYPE_INVALID_OPERATION", message))


static func _overflow_error() -> RuntimeResult:
	return RuntimeResult.failed(RuntimeFailure.new(
		"runtime", "RUNTIME_INTEGER_OVERFLOW",
		"O resultado inteiro excede o intervalo de 64 bits."
	))
