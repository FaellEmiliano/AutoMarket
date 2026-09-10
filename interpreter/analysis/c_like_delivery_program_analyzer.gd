extends RefCounted
class_name CLikeDeliveryProgramAnalyzer


const AST = preload("res://interpreter/ast/ast_nodes.gd")
const Config = preload("res://data/DeliveryConfig.gd")
const Facts = preload("res://interpreter/analysis/delivery_program_facts.gd")


static func analyze(program):
	if program == null:
		return null
	var facts = Facts.new()
	var all_nodes := _flatten(program)
	var array_sizes := {}
	var declare_calls := []
	var functions := []

	for node in all_nodes:
		if node is AST.FunctionDeclNode:
			functions.append(node)
			if str(node.name) != "main":
				facts.has_user_function = true
		elif node is AST.ForNode or node is AST.WhileNode:
			facts.has_loop = true
		elif node is AST.ArrayDeclNode:
			array_sizes[str(node.name)] = _static_array_size(node)
		elif node is AST.FunctionCallNode:
			if str(node.name) == "get_deliveries":
				facts.has_get_deliveries = true
			elif str(node.name) == "declare_profit":
				facts.has_declare_profit = true
				declare_calls.append(node)

	for function_node in functions:
		_analyze_function(function_node, facts)

	for call_node in declare_calls:
		if call_node.args.size() != 1:
			continue
		var argument = call_node.args[0]
		if argument is AST.IdentifierNode \
				and int(array_sizes.get(str(argument.name), -1)) == Config.REPORT_SIZE:
			facts.has_response_array = true
		elif argument is AST.ArrayLiteralNode \
				and argument.elements.size() == Config.REPORT_SIZE:
			facts.has_response_array = true
	return facts


static func _analyze_function(function_node, facts) -> void:
	var function_name := str(function_node.name)
	if function_name == "main":
		return
	var has_self_call := false
	var has_if := false
	var has_case_base := false
	for body_node in _flatten(function_node.body):
		if body_node is AST.FunctionCallNode and str(body_node.name) == function_name:
			has_self_call = true
		elif body_node is AST.IfNode:
			has_if = true
			if _branch_is_case_base(body_node.if_branch, function_name) \
					or _branch_is_case_base(body_node.else_branch, function_name):
				has_case_base = true
	if not has_self_call:
		return
	facts.recursive_declarations.append(function_name)
	facts.recursive_function_has_if = facts.recursive_function_has_if or has_if
	facts.recursive_function_has_case_base = \
		facts.recursive_function_has_case_base or has_case_base
	if has_if and has_case_base:
		facts.valid_recursive_functions.append(function_name)


static func _static_array_size(node) -> int:
	if node.sizes.size() != 1:
		return -1
	var size_node = node.sizes[0]
	return int(size_node.value) if size_node is AST.NumberNode else -1


static func _branch_is_case_base(branch, function_name: String) -> bool:
	if branch == null:
		return false
	var has_return := false
	for node in _flatten(branch):
		if node is AST.ReturnNode:
			has_return = true
		elif node is AST.FunctionCallNode and str(node.name) == function_name:
			return false
	return has_return


static func _flatten(root) -> Array:
	var result := []
	if root == null:
		return result
	var stack := [root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node == null:
			continue
		result.append(node)
		for child in _children(node):
			if child != null:
				stack.append(child)
	return result


static func _children(node) -> Array:
	if node is AST.ProgramNode or node is AST.BlockNode:
		return node.statements
	if node is AST.VarDeclNode:
		return [node.value]
	if node is AST.ArrayDeclNode:
		return node.sizes
	if node is AST.ArrayAccessNode:
		return [node.array] + node.indexes
	if node is AST.ArrayLiteralNode:
		return node.elements
	if node is AST.IfNode:
		return [node.condicao, node.if_branch, node.else_branch]
	if node is AST.WhileNode:
		return [node.condicao, node.body]
	if node is AST.ForNode:
		return [node.init, node.condicao, node.incremento, node.body]
	if node is AST.ReturnNode:
		return [node.value]
	if node is AST.FunctionDeclNode:
		return [node.body]
	if node is AST.FunctionCallNode:
		return node.args
	if node is AST.ExpressionStatementNode:
		return [node.expression]
	if node is AST.AssignNode:
		return [node.node, node.value]
	if node is AST.UnaryOpNode:
		return [node.operando]
	if node is AST.BinaryOpNode:
		return [node.left, node.right]
	return []
