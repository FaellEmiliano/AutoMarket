extends RefCounted
class_name DeliveryProgramFacts


var has_user_function: bool = false
var has_loop: bool = false
var has_get_deliveries: bool = false
var has_declare_profit: bool = false
var has_response_array: bool = false
var recursive_declarations: Array[String] = []
var valid_recursive_functions: Array[String] = []
var recursive_function_has_if: bool = false
var recursive_function_has_case_base: bool = false


func to_dictionary() -> Dictionary:
	return {
		"has_user_function": has_user_function,
		"has_loop": has_loop,
		"has_get_deliveries": has_get_deliveries,
		"has_declare_profit": has_declare_profit,
		"has_response_array": has_response_array,
		"recursive_declarations": recursive_declarations.duplicate(),
		"recursive_functions": valid_recursive_functions.duplicate(),
		"recursive_function_has_if": recursive_function_has_if,
		"recursive_function_has_case_base": recursive_function_has_case_base,
	}
