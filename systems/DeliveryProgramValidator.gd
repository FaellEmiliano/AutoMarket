extends RefCounted
class_name DeliveryProgramValidator

const Facts = preload("res://interpreter/analysis/delivery_program_facts.gd")


static func validate(program_facts) -> Dictionary:
	var result := {
		"valid": false,
		"errors": [],
		"recursive_functions": [],
		"has_user_function": false,
		"has_loop": false,
		"has_get_deliveries": false,
		"has_declare_profit": false,
		"has_response_array": false
	}
	if not program_facts is Facts:
		result.errors.append("Não consegui analisar o programa do Delivery.")
		return result

	result.has_user_function = program_facts.has_user_function
	result.has_loop = program_facts.has_loop
	result.has_get_deliveries = program_facts.has_get_deliveries
	result.has_declare_profit = program_facts.has_declare_profit
	result.has_response_array = program_facts.has_response_array
	result.recursive_functions = program_facts.valid_recursive_functions.duplicate()
	if not program_facts.has_user_function:
		result.errors.append("O desafio do Delivery precisa de uma função criada por você.")
	if program_facts.recursive_declarations.is_empty():
		result.errors.append("Uma função do cálculo precisa chamar a si mesma.")
	else:
		result.recursive_function_has_if = program_facts.recursive_function_has_if
		result.recursive_function_has_case_base = \
			program_facts.recursive_function_has_case_base
		if not program_facts.recursive_function_has_if:
			result.errors.append("A função recursiva precisa usar if para reconhecer o caso-base.")
		if not program_facts.recursive_function_has_case_base:
			result.errors.append("Não encontrei um caso-base que interrompa a recursão.")
	if not program_facts.has_loop:
		result.errors.append("Use for ou while para processar as três categorias.")
	if not program_facts.has_get_deliveries:
		result.errors.append("Use get_deliveries() para ler o relatório atual.")
	if not program_facts.has_declare_profit:
		result.errors.append("Use declare_profit() para enviar os lucros.")
	if not program_facts.has_response_array:
		result.errors.append("declare_profit() precisa receber um array com 3 posições.")
	result.valid = result.errors.is_empty()
	return result


static func analyze(program_facts) -> Dictionary:
	return validate(program_facts)
