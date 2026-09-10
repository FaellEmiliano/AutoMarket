extends RefCounted
class_name PythonLikeDeliveryProgramAnalyzer


const AST = preload("res://interpreter/python_like/ast/python_like_ast_nodes.gd")
const Config = preload("res://data/DeliveryConfig.gd")
const Facts = preload("res://interpreter/analysis/delivery_program_facts.gd")


static func analyze(program):
	if program == null:
		return null
	var facts = Facts.new()
	var all_nodes := _flatten(program)
	var response_names := {}
	var declare_calls := []
	var functions := []

	for node in all_nodes:
		if node is AST.FunctionDefinitionNode:
			functions.append(node)
			facts.has_user_function = true
		elif node is AST.ForStatementNode or node is AST.WhileStatementNode:
			facts.has_loop = true
		elif node is AST.SimpleAssignmentNode \
				and node.target is AST.IdentifierNode \
				and node.value is AST.ListLiteralNode \
				and node.value.elements.size() == Config.REPORT_SIZE:
			response_names[node.target.name] = true
		elif node is AST.CallExpressionNode and node.callee is AST.IdentifierNode:
			var called_name: String = node.callee.name
			if called_name == "get_deliveries":
				facts.has_get_deliveries = true
			elif called_name == "declare_profit":
				facts.has_declare_profit = true
				declare_calls.append(node)

	for function_node in functions:
		_analyze_function(function_node, facts)

	for call_node in declare_calls:
		if call_node.arguments.size() != 1:
			continue
		var argument = call_node.arguments[0]
		if argument is AST.ListLiteralNode \
				and argument.elements.size() == Config.REPORT_SIZE:
			facts.has_response_array = true
		elif argument is AST.IdentifierNode and response_names.has(argument.name):
			facts.has_response_array = true
	return facts


static func _analyze_function(function_node, facts) -> void:
	var function_name: String = function_node.name
	var has_self_call := false
	var has_if := false
	var has_case_base := false
	for body_node in _flatten(function_node.body):
		if _is_direct_call_to(body_node, function_name):
			has_self_call = true
		elif body_node is AST.IfStatementNode:
			has_if = true
			for branch_body in _if_branch_bodies(body_node):
				if _branch_is_case_base(branch_body, function_name):
					has_case_base = true
	if not has_self_call:
		return
	facts.recursive_declarations.append(function_name)
	facts.recursive_function_has_if = facts.recursive_function_has_if or has_if
	facts.recursive_function_has_case_base = \
		facts.recursive_function_has_case_base or has_case_base
	if has_if and has_case_base:
		facts.valid_recursive_functions.append(function_name)


static func _if_branch_bodies(node) -> Array:
	var bodies := [node.if_branch.body]
	for branch in node.elif_branches:
		bodies.append(branch.body)
	if node.else_branch != null:
		bodies.append(node.else_branch.body)
	return bodies


static func _branch_is_case_base(branch, function_name: String) -> bool:
	var has_return := false
	for node in _flatten(branch):
		if node is AST.ReturnStatementNode:
			has_return = true
		elif _is_direct_call_to(node, function_name):
			return false
	return has_return


static func _is_direct_call_to(node, function_name: String) -> bool:
	return node is AST.CallExpressionNode \
		and node.callee is AST.IdentifierNode \
		and node.callee.name == function_name


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
	if node is AST.ExpressionStatementNode:
		return [node.expression]
	if node is AST.SimpleAssignmentNode or node is AST.CompoundAssignmentNode:
		return [node.target, node.value]
	if node is AST.ConditionalBranchNode:
		return [node.condition, node.body]
	if node is AST.ElseBranchNode:
		return [node.body]
	if node is AST.IfStatementNode:
		return [node.if_branch] + node.elif_branches + [node.else_branch]
	if node is AST.WhileStatementNode:
		return [node.condition, node.body]
	if node is AST.ForStatementNode:
		return [node.target, node.iterable, node.body]
	if node is AST.FunctionDefinitionNode:
		return [node.body]
	if node is AST.ReturnStatementNode:
		return [node.value]
	if node is AST.ListLiteralNode:
		return node.elements
	if node is AST.DictionaryLiteralNode:
		return node.entries
	if node is AST.DictionaryEntryNode:
		return [node.key, node.value]
	if node is AST.GroupExpressionNode:
		return [node.expression]
	if node is AST.UnaryExpressionNode:
		return [node.operand]
	if node is AST.BinaryExpressionNode or node is AST.LogicalExpressionNode:
		return [node.left, node.right]
	if node is AST.ComparisonExpressionNode:
		return node.operands
	if node is AST.CallExpressionNode:
		return [node.callee] + node.arguments
	if node is AST.IndexExpressionNode:
		return [node.collection, node.index]
	if node is AST.AttributeExpressionNode:
		return [node.object]
	return []
