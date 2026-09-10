extends RefCounted
class_name PythonLikeExecutor


const Ast = preload("res://interpreter/python_like/ast/python_like_ast_nodes.gd")
const Values = preload("res://interpreter/python_like/runtime/python_like_values.gd")
const Collections = preload("res://interpreter/python_like/runtime/python_like_collections.gd")
const LexicalEnvironment = preload("res://interpreter/python_like/runtime/python_like_environment.gd")
const FunctionValue = preload("res://interpreter/python_like/runtime/python_like_function.gd")
const BuiltinFunctionValue = preload("res://interpreter/python_like/runtime/python_like_builtin_function.gd")
const RangeValue = preload("res://interpreter/python_like/runtime/python_like_range.gd")
const AutoMarketBridge = preload("res://interpreter/python_like/runtime/python_like_automarket_bridge.gd")
const ValueConverter = preload("res://interpreter/python_like/runtime/python_like_value_converter.gd")
const RuntimeFailure = preload("res://interpreter/python_like/runtime/python_like_runtime_failure.gd")
const RuntimeResult = preload("res://interpreter/python_like/runtime/python_like_runtime_result.gd")
const RuntimeLifecycle = preload("res://interpreter/python_like/runtime/python_like_runtime_lifecycle.gd")
const SuspensionRequest = preload("res://interpreter/python_like/runtime/python_like_suspension_request.gd")
const Frames = preload("res://interpreter/python_like/runtime/python_like_executor_frames.gd")
const Operators = preload("res://interpreter/python_like/runtime/python_like_operators.gd")

const DEFAULT_MAX_CALL_DEPTH: int = 64


var runtime_id: String = ""
var script_id: String = ""
var source_name: String = ""
var operation_count: int = 0
var max_call_depth: int = DEFAULT_MAX_CALL_DEPTH
var global_environment
var final_result
var _automarket_bridge

var _frames: Array = []
var _environment_stack: Array = []
var _call_stack: Array = []
var _output_lines: Array[String] = []
var _builtin_environment
var _lifecycle
var _failure
var _active: bool = false
var _finished: bool = false
var _stopped: bool = false
var _suspended: bool = false
var _pending_suspension
var _next_suspension_token: int = 1
var _delivery_tracking_active: bool = false
var _delivery_recursive_functions := {}


func configure_source_identity(new_runtime_id: String, new_script_id: String,
		new_source_name: String) -> void:
	runtime_id = new_runtime_id
	script_id = new_script_id
	source_name = new_source_name


func set_automarket_bridge(bridge) -> void:
	_automarket_bridge = bridge


func load_program(program, environment = null) -> RuntimeResult:
	dispose()
	_lifecycle = RuntimeLifecycle.new()
	_builtin_environment = environment
	if _builtin_environment == null:
		_builtin_environment = _lifecycle.track(LexicalEnvironment.new(null, "builtins"))
	var registration_result = _register_standard_builtins(_builtin_environment)
	if registration_result.has_failure():
		_failure = registration_result.failure()
		_finished = true
		return registration_result
	global_environment = environment if environment != null \
		else _lifecycle.track(LexicalEnvironment.new(_builtin_environment, "module"))
	_environment_stack = [global_environment]
	_call_stack.clear()
	_frames = [Frames.ProgramFrame.new(program)]
	operation_count = 0
	final_result = null
	_failure = null
	_active = true
	_finished = false
	_stopped = false
	_suspended = false
	_pending_suspension = null
	_delivery_tracking_active = false
	_delivery_recursive_functions.clear()
	return RuntimeResult.no_value()


func step() -> int:
	if not _active or _suspended or _frames.is_empty():
		return 0
	var frame = _frames.back()
	_process_frame(frame)
	operation_count += 1
	if _frames.is_empty() and _failure == null:
		_active = false
		_finished = true
	return 1


func is_active() -> bool:
	return _active


func is_finished() -> bool:
	return _finished


func was_stopped() -> bool:
	return _stopped


func is_suspended() -> bool:
	return _suspended


func pending_suspension():
	return _pending_suspension


func resume_suspension(token: int) -> bool:
	if not _suspended or _pending_suspension == null \
			or int(_pending_suspension.token) != token:
		return false
	_suspended = false
	_pending_suspension = null
	return true


func has_delivery_recursion(function_names: Array) -> bool:
	for function_name in function_names:
		if bool(_delivery_recursive_functions.get(str(function_name), false)):
			return true
	return false


func has_failure() -> bool:
	return _failure != null


func failure():
	return _failure


func frame_depth() -> int:
	return _frames.size()


func call_depth() -> int:
	return _call_stack.size()


func output_lines() -> Array[String]:
	return _output_lines.duplicate()


func output_text() -> String:
	return "" if _output_lines.is_empty() else "%s\n" % "\n".join(_output_lines)


func consume_output_lines() -> Array[String]:
	var result := _output_lines.duplicate()
	_output_lines.clear()
	return result


func stop() -> void:
	_frames.clear()
	_environment_stack.clear()
	_call_stack.clear()
	_active = false
	_finished = true
	_stopped = true
	_suspended = false
	_pending_suspension = null
	_delivery_tracking_active = false
	_delivery_recursive_functions.clear()
	if _lifecycle != null:
		_lifecycle.discard_all()


func dispose() -> void:
	_frames.clear()
	_environment_stack.clear()
	_call_stack.clear()
	_active = false
	_suspended = false
	_pending_suspension = null
	_delivery_tracking_active = false
	_delivery_recursive_functions.clear()
	if _lifecycle != null:
		_lifecycle.discard_all()
	_lifecycle = null
	global_environment = null
	_builtin_environment = null
	_output_lines.clear()


func _process_frame(frame) -> void:
	if frame is Frames.ProgramFrame:
		_process_program(frame)
	elif frame is Frames.BlockFrame:
		_process_block(frame)
	elif frame is Frames.IfFrame:
		_process_if(frame)
	elif frame is Frames.WhileFrame:
		_process_while(frame)
	elif frame is Frames.ForFrame:
		_process_for(frame)
	elif frame is Frames.BreakFrame:
		_process_break(frame)
	elif frame is Frames.ContinueFrame:
		_process_continue(frame)
	elif frame is Frames.FunctionDefinitionFrame:
		_process_function_definition(frame)
	elif frame is Frames.CallFrame:
		_process_call(frame)
	elif frame is Frames.BuiltinCallFrame:
		_process_builtin_call(frame)
	elif frame is Frames.FunctionExecutionFrame:
		_process_function_execution(frame)
	elif frame is Frames.ReturnFrame:
		_process_return(frame)
	elif frame is Frames.ExpressionStatementFrame:
		_process_expression_statement(frame)
	elif frame is Frames.AugmentedAssignmentFrame:
		_process_augmented_assignment(frame)
	elif frame is Frames.AssignmentFrame:
		_process_assignment(frame)
	elif frame is Frames.LiteralFrame:
		_process_literal(frame)
	elif frame is Frames.IdentifierFrame:
		_process_identifier(frame)
	elif frame is Frames.GroupFrame:
		_process_group(frame)
	elif frame is Frames.ListFrame:
		_process_list(frame)
	elif frame is Frames.DictionaryFrame:
		_process_dictionary(frame)
	elif frame is Frames.UnaryFrame:
		_process_unary(frame)
	elif frame is Frames.BinaryFrame:
		_process_binary(frame)
	elif frame is Frames.LogicalFrame:
		_process_logical(frame)
	elif frame is Frames.ComparisonChainFrame:
		_process_comparison(frame)
	elif frame is Frames.MembershipFrame:
		_process_membership(frame)
	elif frame is Frames.IndexReadFrame:
		_process_index_read(frame)
	elif frame is Frames.IndexWriteFrame:
		_process_index_write(frame)
	elif frame is Frames.OperatorFrame:
		_process_operator(frame)
	else:
		_fail(_new_failure(
			"internal", "INTERNAL_UNKNOWN_FRAME",
			"O executor encontrou um frame desconhecido.", null
		))


func _process_program(frame) -> void:
	if frame.has_incoming:
		var result = frame.take_incoming()
		var control = _control_signal(result)
		if control != null:
			_fail(_new_failure(
				"runtime", "RUNTIME_CONTROL_OUTSIDE_CONTEXT",
				"Controle de fluxo alcançou o nível superior.", control.span
			))
			return
		frame.statement_index += 1
		return
	if frame.statement_index >= frame.node.statements.size():
		_complete(RuntimeResult.no_value())
		return
	_push_node(frame.node.statements[frame.statement_index])


func _process_block(frame) -> void:
	if frame.has_incoming:
		var result = frame.take_incoming()
		if _control_signal(result) != null:
			_complete(result)
			return
		frame.statement_index += 1
		return
	if frame.statement_index >= frame.node.statements.size():
		_complete(RuntimeResult.no_value())
		return
	_push_node(frame.node.statements[frame.statement_index])


func _process_if(frame) -> void:
	match frame.state:
		0:
			frame.state = 1
			_push_node(_if_branch_at(frame.node, frame.branch_index).condition)
		1:
			if frame.has_incoming:
				frame.condition_value = frame.take_incoming().value()
				frame.state = 2
		2:
			if frame.condition_value.is_truthy():
				frame.selected_body = _if_branch_at(frame.node, frame.branch_index).body
				frame.state = 3
				return
			frame.branch_index += 1
			frame.condition_value = null
			if frame.branch_index < _if_branch_count(frame.node):
				frame.state = 0
			elif frame.node.else_branch != null:
				frame.selected_body = frame.node.else_branch.body
				frame.state = 3
			else:
				_complete(RuntimeResult.no_value())
		3:
			frame.state = 4
			_push_node(frame.selected_body)
		4:
			if frame.has_incoming:
				var result = frame.take_incoming()
				_complete(result if _control_signal(result) != null else RuntimeResult.no_value())


func _process_while(frame) -> void:
	match frame.state:
		0:
			frame.state = 1
			_push_node(frame.node.condition)
		1:
			if frame.has_incoming:
				frame.condition_value = frame.take_incoming().value()
				frame.state = 2
		2:
			if frame.condition_value.is_truthy():
				frame.state = 3
			else:
				_complete(RuntimeResult.no_value())
		3:
			frame.state = 4
			_push_node(frame.node.body)
		4:
			if not frame.has_incoming:
				return
			var result = frame.take_incoming()
			var control = _control_signal(result)
			if control == null or control.kind == Frames.ControlFlowSignal.Kind.CONTINUE:
				frame.condition_value = null
				frame.state = 0
			elif control.kind == Frames.ControlFlowSignal.Kind.BREAK:
				_complete(RuntimeResult.no_value())
			else:
				_complete(result)


func _process_for(frame) -> void:
	match frame.state:
		0:
			frame.state = 1
			_push_node(frame.node.iterable)
		1:
			if not frame.has_incoming:
				return
			frame.iterable = frame.take_incoming().value()
			if not frame.iterable is Collections.ListValue \
					and not frame.iterable is Collections.DictionaryValue \
					and not frame.iterable is RangeValue:
				_fail(_new_failure(
					"type", "TYPE_NOT_ITERABLE",
					"O for aceita list, dict ou range nesta etapa.",
					frame.node.iterable.span,
					{"type": frame.iterable.type_name()}
				))
				return
			frame.checks_mutation = frame.iterable is Collections.ListValue \
				or frame.iterable is Collections.DictionaryValue
			if frame.checks_mutation:
				frame.expected_mutation_version = frame.iterable.mutation_version
			frame.state = 2
		2:
			if frame.checks_mutation \
					and frame.iterable.mutation_version != frame.expected_mutation_version:
				_fail(_new_failure(
					"runtime", "RUNTIME_COLLECTION_MUTATED",
					"A coleção foi alterada durante a iteração.", frame.node.iterable.span,
					{
						"expected_version": frame.expected_mutation_version,
						"current_version": frame.iterable.mutation_version,
					}
				))
				return
			if frame.item_index >= frame.iterable.size():
				_complete(RuntimeResult.no_value())
				return
			var next_result
			if frame.iterable is Collections.ListValue or frame.iterable is RangeValue:
				next_result = frame.iterable.item_at_position(frame.item_index)
			else:
				next_result = frame.iterable.key_at_position(frame.item_index)
			if next_result.has_failure():
				_fail(_position_failure(next_result.failure(), frame.node.iterable.span))
				return
			frame.next_value = next_result.value()
			frame.item_index += 1
			frame.state = 3
		3:
			var binding_result = _current_environment().assign_local(
				frame.node.target.name, frame.next_value
			)
			if binding_result.has_failure():
				_fail(_position_failure(binding_result.failure(), frame.node.target.span))
				return
			frame.next_value = null
			frame.state = 4
		4:
			frame.state = 5
			_push_node(frame.node.body)
		5:
			if not frame.has_incoming:
				return
			var result = frame.take_incoming()
			var control = _control_signal(result)
			if control == null or control.kind == Frames.ControlFlowSignal.Kind.CONTINUE:
				frame.state = 2
			elif control.kind == Frames.ControlFlowSignal.Kind.BREAK:
				_complete(RuntimeResult.no_value())
			else:
				_complete(result)


func _process_break(frame) -> void:
	_complete(RuntimeResult.success(Frames.ControlFlowSignal.new(
		Frames.ControlFlowSignal.Kind.BREAK, frame.node.keyword_span
	)))


func _process_continue(frame) -> void:
	_complete(RuntimeResult.success(Frames.ControlFlowSignal.new(
		Frames.ControlFlowSignal.Kind.CONTINUE, frame.node.keyword_span
	)))


func _if_branch_count(node) -> int:
	return 1 + node.elif_branches.size()


func _if_branch_at(node, index: int):
	return node.if_branch if index == 0 else node.elif_branches[index - 1]


func _process_function_definition(frame) -> void:
	match frame.state:
		0:
			frame.definition_environment = _current_environment()
			frame.scan_stack.append({"node": frame.node.body, "index": 0})
			frame.state = 1
		1:
			if not frame.scan_stack.is_empty():
				_scan_function_local_node(frame, frame.scan_stack.pop_back())
				return
			frame.state = 2
		2:
			frame.function_value = _track(FunctionValue.new(
				frame.node.name, [], frame.node.body,
				frame.node.span, frame.definition_environment
			))
			frame.state = 3
		3:
			if frame.parameter_index < frame.node.parameters.size():
				frame.function_value.register_parameter(
					frame.node.parameters[frame.parameter_index]
				)
				frame.parameter_index += 1
				return
			frame.state = 4
		4:
			if frame.local_index < frame.local_name_list.size():
				frame.function_value.register_local_name(
					frame.local_name_list[frame.local_index]
				)
				frame.local_index += 1
				return
			frame.state = 5
		5:
			var definition_result = frame.definition_environment.assign_local(
				frame.node.name, frame.function_value
			)
			if definition_result.has_failure():
				_fail(_position_failure(definition_result.failure(), frame.node.name_span))
				return
			_complete(RuntimeResult.no_value())


func _scan_function_local_node(frame, work: Dictionary) -> void:
	var node = work.node
	var child_index: int = work.index
	if node is Ast.BlockNode:
		if child_index < node.statements.size():
			frame.scan_stack.append({"node": node, "index": child_index + 1})
			frame.scan_stack.append({"node": node.statements[child_index], "index": 0})
	elif node is Ast.IfStatementNode:
		var body_count: int = 1 + node.elif_branches.size() \
			+ (1 if node.else_branch != null else 0)
		if child_index < body_count:
			var child_body
			if child_index == 0:
				child_body = node.if_branch.body
			elif child_index <= node.elif_branches.size():
				child_body = node.elif_branches[child_index - 1].body
			else:
				child_body = node.else_branch.body
			frame.scan_stack.append({"node": node, "index": child_index + 1})
			frame.scan_stack.append({"node": child_body, "index": 0})
	elif node is Ast.WhileStatementNode:
		frame.scan_stack.append({"node": node.body, "index": 0})
	elif node is Ast.ForStatementNode:
		_record_function_local(frame, node.target.name)
		frame.scan_stack.append({"node": node.body, "index": 0})
	elif node is Ast.SimpleAssignmentNode or node is Ast.CompoundAssignmentNode:
		if node.target is Ast.IdentifierNode:
			_record_function_local(frame, node.target.name)
	elif node is Ast.FunctionDefinitionNode:
		_record_function_local(frame, node.name)


func _record_function_local(frame, local_name: String) -> void:
	if frame.local_names.has(local_name):
		return
	frame.local_names[local_name] = true
	frame.local_name_list.append(local_name)


func _process_call(frame) -> void:
	match frame.state:
		0:
			frame.state = 1
			_push_node(frame.node.callee)
		1:
			if frame.has_incoming:
				frame.callable_value = frame.take_incoming().value()
				frame.state = 2
		2:
			if frame.argument_index >= frame.node.arguments.size():
				frame.state = 4
				return
			frame.state = 3
			_push_node(frame.node.arguments[frame.argument_index])
		3:
			if frame.has_incoming:
				frame.argument_values.append(frame.take_incoming().value())
				frame.argument_index += 1
				frame.state = 2
		4:
			if not frame.callable_value is FunctionValue \
					and not frame.callable_value is BuiltinFunctionValue:
				_fail(_new_failure(
					"type", "TYPE_NOT_CALLABLE",
					"O valor do tipo '%s' não pode ser chamado." \
						% frame.callable_value.type_name(), frame.node.callee.span,
					{"type": frame.callable_value.type_name()}
				))
				return
			var arity_result = _validate_call_arity(
				frame.callable_value, frame.argument_values.size(), frame.node.span
			)
			if arity_result.has_failure():
				_fail(arity_result.failure())
				return
			if frame.callable_value is BuiltinFunctionValue:
				var builtin_frame := Frames.BuiltinCallFrame.new(frame.node)
				builtin_frame.function_value = frame.callable_value
				builtin_frame.argument_values = frame.argument_values
				builtin_frame.call_span = frame.node.span
				frame.state = 9
				_frames.append(builtin_frame)
				return
			_observe_delivery_recursive_call(frame.callable_value)
			if _call_stack.size() >= max_call_depth:
				_fail(_new_failure(
					"recursion", "RUNTIME_MAX_CALL_DEPTH",
					"A profundidade máxima de %d chamadas foi excedida." \
						% max_call_depth, frame.node.span,
					{"maximum": max_call_depth, "depth": _call_stack.size(),
						"function": frame.callable_value.function_name}
				))
				return
			var environment_result = frame.callable_value.create_call_environment(false)
			if environment_result.has_failure():
				_fail(_position_failure(environment_result.failure(), frame.node.span))
				return
			frame.local_environment = _track(environment_result.value())
			frame.state = 5
		5:
			if frame.local_index < frame.callable_value.local_count():
				var local_result = frame.local_environment.mark_local(
					frame.callable_value.local_name_at(frame.local_index)
				)
				if local_result.has_failure():
					_fail(_position_failure(local_result.failure(), frame.node.span))
					return
				frame.local_index += 1
				return
			frame.state = 6
		6:
			if frame.parameter_index >= frame.argument_values.size():
				frame.state = 7
				return
			var parameter_name: String = frame.callable_value.parameter_name_at(
				frame.parameter_index
			)
			var binding_result = frame.local_environment.assign_local(
				parameter_name, frame.argument_values[frame.parameter_index]
			)
			if binding_result.has_failure():
				_fail(_position_failure(binding_result.failure(), frame.node.span))
				return
			frame.parameter_index += 1
		7:
			var function_frame := Frames.FunctionExecutionFrame.new(
				frame.callable_value.body
			)
			function_frame.function_value = frame.callable_value
			function_frame.local_environment = frame.local_environment
			function_frame.caller_environment = _current_environment()
			function_frame.call_span = frame.node.span
			_environment_stack.append(frame.local_environment)
			_call_stack.append(function_frame)
			frame.state = 8
			_frames.append(function_frame)
		8:
			if frame.has_incoming:
				_complete(frame.take_incoming())
		9:
			if frame.has_incoming:
				_complete(frame.take_incoming())


func _process_builtin_call(frame) -> void:
	if frame.state == 0:
		var result = frame.function_value.invoke(frame.argument_values)
		if result.is_suspended():
			frame.suspension_request = result.suspension()
			_pending_suspension = frame.suspension_request
			_suspended = true
			frame.state = 1
			return
		_complete(_position_result(result, frame.call_span))
		return
	_complete(RuntimeResult.success(Values.none_value()))


func _validate_call_arity(callable_value, received: int, span) -> RuntimeResult:
	var minimum: int = callable_value.minimum_arity()
	var maximum: int = callable_value.maximum_arity()
	if received >= minimum and (maximum < 0 or received <= maximum):
		return RuntimeResult.no_value()
	var expected_text: String
	if maximum < 0:
		expected_text = "pelo menos %d" % minimum
	elif minimum == maximum:
		expected_text = str(minimum)
	else:
		expected_text = "entre %d e %d" % [minimum, maximum]
	var details := {
		"function": callable_value.callable_name(),
		"minimum": minimum,
		"maximum": maximum,
		"received": received,
	}
	if minimum == maximum:
		details["expected"] = minimum
	return RuntimeResult.failed(_new_failure(
		"arity", "ARITY_MISMATCH",
		"A função '%s' espera %s argumento(s), mas recebeu %d." % [
			callable_value.callable_name(), expected_text, received
		], span, details
	))


func _process_function_execution(frame) -> void:
	if frame.state == 0:
		frame.state = 1
		_push_node(frame.function_value.body)
		return
	if not frame.has_incoming:
		return
	var body_result = frame.take_incoming()
	var control = _control_signal(body_result)
	var return_value = Values.none_value()
	if control != null:
		if control.kind != Frames.ControlFlowSignal.Kind.RETURN:
			_fail(_new_failure(
				"runtime", "RUNTIME_CONTROL_CROSSED_FUNCTION",
				"Controle de loop atravessou o limite de uma função.", control.span
			))
			return
		return_value = control.value
	if not _exit_function(frame):
		return
	_complete(RuntimeResult.success(return_value))


func _exit_function(frame) -> bool:
	if _call_stack.is_empty() or _call_stack.back() != frame \
			or _environment_stack.is_empty() \
			or _environment_stack.back() != frame.local_environment:
		_fail(_new_failure(
			"internal", "INTERNAL_CALL_STACK_MISMATCH",
			"A pilha incremental de chamadas ficou inconsistente.", frame.call_span
		))
		return false
	_call_stack.pop_back()
	_environment_stack.pop_back()
	if _environment_stack.is_empty() \
			or _environment_stack.back() != frame.caller_environment:
		_fail(_new_failure(
			"internal", "INTERNAL_ENVIRONMENT_STACK_MISMATCH",
			"A pilha de ambientes léxicos ficou inconsistente.", frame.call_span
		))
		return false
	return true


func _process_return(frame) -> void:
	if frame.state == 0:
		if frame.node.value == null:
			_complete(RuntimeResult.success(Frames.ControlFlowSignal.new(
				Frames.ControlFlowSignal.Kind.RETURN, frame.node.keyword_span,
				Values.none_value()
			)))
			return
		frame.state = 1
		_push_node(frame.node.value)
		return
	if frame.has_incoming:
		frame.return_value = frame.take_incoming().value()
		_complete(RuntimeResult.success(Frames.ControlFlowSignal.new(
			Frames.ControlFlowSignal.Kind.RETURN, frame.node.keyword_span,
			frame.return_value
		)))


func _process_expression_statement(frame) -> void:
	if frame.state == 0:
		frame.state = 1
		_push_node(frame.node.expression)
		return
	if frame.has_incoming:
		frame.take_incoming()
		_complete(RuntimeResult.no_value())


func _process_assignment(frame) -> void:
	match frame.state:
		0:
			frame.state = 1
			_resolve_target(frame, frame.node.target)
		1:
			if frame.target == null and frame.has_incoming:
				frame.target = frame.take_incoming().value()
				frame.state = 2
			return
		2:
			frame.state = 3
			_push_node(frame.node.value)
		3:
			if frame.has_incoming:
				frame.assigned_value = frame.take_incoming().value()
				frame.state = 4
		4:
			_commit_assignment(frame, frame.target, frame.assigned_value, 5)
		5:
			if frame.has_incoming:
				frame.take_incoming()
				_complete(RuntimeResult.no_value())


func _process_augmented_assignment(frame) -> void:
	match frame.state:
		0:
			frame.state = 1
			_resolve_target(frame, frame.node.target)
		1:
			if frame.target == null and frame.has_incoming:
				frame.target = frame.take_incoming().value()
				frame.state = 2
		2:
			if frame.target.kind == Frames.ResolvedTarget.Kind.NAME:
				var lookup = _current_environment().lookup(frame.target.name)
				if lookup.has_failure():
					_fail(_position_failure(lookup.failure(), frame.target.span))
					return
				frame.left_value = lookup.value()
				frame.state = 4
			else:
				var reader := Frames.IndexReadFrame.new(frame.node.target)
				reader.collection = frame.target.collection
				reader.index = frame.target.index
				reader.values_are_resolved = true
				frame.state = 3
				_frames.append(reader)
		3:
			if frame.has_incoming:
				frame.left_value = frame.take_incoming().value()
				frame.state = 4
		4:
			frame.state = 5
			_push_node(frame.node.value)
		5:
			if frame.has_incoming:
				frame.assigned_value = frame.take_incoming().value()
				frame.state = 6
		6:
			var simple_operator: String = frame.node.operator.trim_suffix("=")
			frame.state = 7
			_frames.append(Frames.OperatorFrame.new(
				simple_operator, frame.left_value, frame.assigned_value,
				frame.node.operator_span
			))
		7:
			if frame.has_incoming:
				frame.computed_value = frame.take_incoming().value()
				frame.state = 8
		8:
			_commit_assignment(frame, frame.target, frame.computed_value, 9)
		9:
			if frame.has_incoming:
				frame.take_incoming()
				_complete(RuntimeResult.no_value())


func _resolve_target(frame, target_node) -> void:
	if target_node is Ast.IdentifierNode:
		frame.target = Frames.ResolvedTarget.name_target(target_node.name, target_node.span)
		frame.state = 2
	elif target_node is Ast.IndexExpressionNode:
		_frames.append(Frames.IndexWriteFrame.new(target_node))
	else:
		_fail(_new_failure(
			"runtime", "RUNTIME_INVALID_ASSIGNMENT_TARGET",
			"O alvo não pode receber uma atribuição.", target_node.span
		))


func _commit_assignment(frame, target, value, waiting_state: int) -> void:
	if target.kind == Frames.ResolvedTarget.Kind.NAME:
		var result = _current_environment().assign_local(target.name, value)
		if result.has_failure():
			_fail(_position_failure(result.failure(), target.span))
		else:
			_complete(RuntimeResult.no_value())
		return
	var writer := Frames.IndexWriteFrame.new(frame.node.target)
	writer.commit_mode = true
	writer.target = target
	writer.value = value
	frame.state = waiting_state
	_frames.append(writer)


func _process_literal(frame) -> void:
	var node = frame.node
	var value
	if node is Ast.IntegerLiteralNode:
		value = Values.IntegerValue.new(node.value)
	elif node is Ast.FloatLiteralNode:
		value = Values.FloatValue.new(node.value)
	elif node is Ast.StringLiteralNode:
		value = Values.StringValue.new(node.value)
	elif node is Ast.BooleanLiteralNode:
		value = Values.boolean_value(node.value)
	else:
		value = Values.none_value()
	_complete(RuntimeResult.success(value))


func _process_identifier(frame) -> void:
	var result = _current_environment().lookup(frame.node.name)
	if result.has_failure():
		_fail(_position_failure(result.failure(), frame.node.span))
	else:
		_complete(result)


func _process_group(frame) -> void:
	if frame.state == 0:
		frame.state = 1
		_push_node(frame.node.expression)
	elif frame.has_incoming:
		_complete(frame.take_incoming())


func _process_list(frame) -> void:
	if frame.state == 0:
		frame.result = _track(Collections.ListValue.new())
		frame.state = 1
		if frame.node.elements.is_empty():
			_complete(RuntimeResult.success(frame.result))
		return
	if frame.state == 1:
		frame.state = 2
		_push_node(frame.node.elements[frame.element_index])
		return
	if frame.has_incoming:
		var append_result = frame.result.append(frame.take_incoming().value())
		if append_result.has_failure():
			_fail(_position_failure(append_result.failure(), frame.node.span))
			return
		frame.element_index += 1
		if frame.element_index >= frame.node.elements.size():
			_complete(RuntimeResult.success(frame.result))
		else:
			frame.state = 1


func _process_dictionary(frame) -> void:
	if frame.state == 0:
		frame.result = _track(Collections.DictionaryValue.new())
		frame.state = 1
		if frame.node.entries.is_empty():
			_complete(RuntimeResult.success(frame.result))
		return
	var entry = frame.node.entries[frame.entry_index]
	match frame.state:
		1:
			frame.state = 2
			_push_node(entry.key)
		2:
			if frame.has_incoming:
				frame.key_value = frame.take_incoming().value()
				if not frame.result.is_valid_key(frame.key_value):
					_fail(_new_failure(
						"type", "TYPE_UNHASHABLE_KEY",
						"A chave deve ser int, float, bool, str ou None.", entry.key.span
					))
					return
				frame.state = 3
		3:
			frame.state = 4
			_push_node(entry.value)
		4:
			if frame.has_incoming:
				frame.entry_value = frame.take_incoming().value()
				frame.scan_index = 0
				frame.state = 5
		5:
			var position := -1
			if frame.scan_index < frame.result.size():
				var existing = frame.result.key_at_position(frame.scan_index)
				if existing.has_failure():
					_fail(_position_failure(existing.failure(), entry.key.span))
					return
				if existing.value().semantic_equals(frame.key_value):
					position = frame.scan_index
				else:
					frame.scan_index += 1
					return
			var set_result = frame.result.set_item_at_position(
				position, frame.key_value, frame.entry_value
			)
			if set_result.has_failure():
				_fail(_position_failure(set_result.failure(), entry.span))
				return
			frame.entry_index += 1
			if frame.entry_index >= frame.node.entries.size():
				_complete(RuntimeResult.success(frame.result))
			else:
				frame.key_value = null
				frame.entry_value = null
				frame.state = 1


func _process_unary(frame) -> void:
	if frame.state == 0:
		frame.state = 1
		_push_node(frame.node.operand)
	elif frame.state == 1 and frame.has_incoming:
		frame.operand = frame.take_incoming().value()
		frame.state = 2
	else:
		_complete(_position_result(
			Operators.apply_unary(frame.node.operator, frame.operand),
			frame.node.operator_span
		))


func _process_binary(frame) -> void:
	match frame.state:
		0:
			frame.state = 1
			_push_node(frame.node.left)
		1:
			if frame.has_incoming:
				frame.left = frame.take_incoming().value()
				frame.state = 2
		2:
			frame.state = 3
			_push_node(frame.node.right)
		3:
			if frame.has_incoming:
				frame.right = frame.take_incoming().value()
				frame.state = 4
		4:
			if _begin_or_continue_list_binary(frame):
				return
			frame.state = 5
			_frames.append(Frames.OperatorFrame.new(
				frame.node.operator, frame.left, frame.right, frame.node.operator_span
			))
		5:
			if frame.has_incoming:
				_complete(frame.take_incoming())
		10, 11, 12, 13:
			_continue_list_binary(frame)


func _begin_or_continue_list_binary(frame) -> bool:
	if frame.node.operator == "+" and frame.left is Collections.ListValue \
			and frame.right is Collections.ListValue:
		frame.result_collection = _track(Collections.ListValue.new())
		frame.copy_index = 0
		frame.state = 10
		return true
	if frame.node.operator == "*":
		if frame.left is Collections.ListValue and _is_integral(frame.right):
			frame.repeat_source = frame.left
			frame.repeat_count = maxi(0, _integral_value(frame.right))
		elif frame.right is Collections.ListValue and _is_integral(frame.left):
			frame.repeat_source = frame.right
			frame.repeat_count = maxi(0, _integral_value(frame.left))
		elif frame.left is Values.StringValue and _is_integral(frame.right):
			frame.repeat_source = frame.left
			frame.repeat_count = maxi(0, _integral_value(frame.right))
			frame.repetition_index = 0
			frame.result_text = ""
			frame.state = 13
			return true
		elif frame.right is Values.StringValue and _is_integral(frame.left):
			frame.repeat_source = frame.right
			frame.repeat_count = maxi(0, _integral_value(frame.left))
			frame.repetition_index = 0
			frame.result_text = ""
			frame.state = 13
			return true
		else:
			return false
		frame.result_collection = _track(Collections.ListValue.new())
		frame.copy_index = 0
		frame.repetition_index = 0
		frame.state = 12
		return true
	return false


func _continue_list_binary(frame) -> void:
	if frame.state == 13:
		if frame.repetition_index >= frame.repeat_count:
			_complete(RuntimeResult.success(Values.StringValue.new(frame.result_text)))
			return
		frame.result_text += frame.repeat_source.string_value
		frame.repetition_index += 1
		return
	if frame.state == 10:
		if frame.copy_index >= frame.left.size():
			frame.copy_index = 0
			frame.state = 11
			return
		_copy_one_list_item(frame.left, frame.result_collection, frame.copy_index, frame.node.span)
		frame.copy_index += 1
		return
	if frame.state == 11:
		if frame.copy_index >= frame.right.size():
			_complete(RuntimeResult.success(frame.result_collection))
			return
		_copy_one_list_item(frame.right, frame.result_collection, frame.copy_index, frame.node.span)
		frame.copy_index += 1
		return
	if frame.repeat_count == 0 or frame.repeat_source.size() == 0 \
			or frame.repetition_index >= frame.repeat_count:
		_complete(RuntimeResult.success(frame.result_collection))
		return
	_copy_one_list_item(
		frame.repeat_source, frame.result_collection, frame.copy_index, frame.node.span
	)
	frame.copy_index += 1
	if frame.copy_index >= frame.repeat_source.size():
		frame.copy_index = 0
		frame.repetition_index += 1


func _copy_one_list_item(source, destination, index: int, span) -> void:
	var item = source.item_at_position(index)
	if item.has_failure():
		_fail(_position_failure(item.failure(), span))
		return
	var append_result = destination.append(item.value())
	if append_result.has_failure():
		_fail(_position_failure(append_result.failure(), span))


func _process_logical(frame) -> void:
	match frame.state:
		0:
			frame.state = 1
			_push_node(frame.node.left)
		1:
			if frame.has_incoming:
				frame.left = frame.take_incoming().value()
				frame.state = 2
		2:
			var short_circuits: bool = (frame.node.operator == "and" and not frame.left.is_truthy()) \
				or (frame.node.operator == "or" and frame.left.is_truthy())
			if short_circuits:
				_complete(RuntimeResult.success(frame.left))
			else:
				frame.state = 3
		3:
			frame.state = 4
			_push_node(frame.node.right)
		4:
			if frame.has_incoming:
				_complete(frame.take_incoming())


func _process_comparison(frame) -> void:
	if frame.state == 0:
		frame.state = 1
		_push_node(frame.node.operands[0])
		return
	if frame.state == 1 and frame.has_incoming:
		frame.left = frame.take_incoming().value()
		frame.operand_index = 0
		frame.state = 2
		return
	if frame.state == 2:
		frame.state = 3
		_push_node(frame.node.operands[frame.operand_index + 1])
		return
	if frame.state == 3 and frame.has_incoming:
		frame.right = frame.take_incoming().value()
		frame.state = 4
		return
	if frame.state == 4:
		var operator: String = frame.node.operators[frame.operand_index]
		if operator == "in" or operator == "not in":
			var membership := Frames.MembershipFrame.new(frame.node)
			membership.needle = frame.left
			membership.collection = frame.right
			membership.negate = operator == "not in"
			frame.state = 5
			_frames.append(membership)
			return
		var result = Operators.apply_comparison(operator, frame.left, frame.right)
		if result.has_failure():
			_fail(_position_failure(
				result.failure(), frame.node.operator_spans[frame.operand_index]
			))
			return
		_finish_comparison_step(frame, result.value())
	elif frame.state == 5 and frame.has_incoming:
		_finish_comparison_step(frame, frame.take_incoming().value())


func _finish_comparison_step(frame, comparison_value) -> void:
	if not comparison_value.is_truthy():
		_complete(RuntimeResult.success(Values.boolean_value(false)))
		return
	frame.operand_index += 1
	if frame.operand_index >= frame.node.operators.size():
		_complete(RuntimeResult.success(Values.boolean_value(true)))
	else:
		frame.left = frame.right
		frame.right = null
		frame.state = 2


func _process_membership(frame) -> void:
	if not frame.collection is Collections.ListValue \
			and not frame.collection is Collections.DictionaryValue:
		_fail(_new_failure(
			"type", "TYPE_NOT_ITERABLE",
			"O operando à direita de 'in' deve ser list ou dict nesta etapa.", frame.node.span
		))
		return
	var size: int = frame.collection.size()
	if frame.item_index >= size:
		_complete(RuntimeResult.success(Values.boolean_value(frame.negate)))
		return
	var candidate_result
	if frame.collection is Collections.ListValue:
		candidate_result = frame.collection.item_at_position(frame.item_index)
	else:
		candidate_result = frame.collection.key_at_position(frame.item_index)
	if candidate_result.has_failure():
		_fail(_position_failure(candidate_result.failure(), frame.node.span))
		return
	if candidate_result.value().value_type in [Values.Type.LIST, Values.Type.DICTIONARY] \
			or frame.needle.value_type in [Values.Type.LIST, Values.Type.DICTIONARY]:
		_fail(_new_failure(
			"type", "TYPE_INVALID_OPERATION",
			"Pertinência com igualdade estrutural de coleções ainda não é executada nesta etapa.",
			frame.node.span
		))
		return
	if candidate_result.value().semantic_equals(frame.needle):
		_complete(RuntimeResult.success(Values.boolean_value(not frame.negate)))
	else:
		frame.item_index += 1


func _process_index_read(frame) -> void:
	if not frame.values_are_resolved:
		match frame.state:
			0:
				frame.state = 1
				_push_node(frame.node.collection)
			1:
				if frame.has_incoming:
					frame.collection = frame.take_incoming().value()
					frame.state = 2
			2:
				frame.state = 3
				_push_node(frame.node.index)
			3:
				if frame.has_incoming:
					frame.index = frame.take_incoming().value()
					frame.values_are_resolved = true
		return
	_read_resolved_index(frame)


func _read_resolved_index(frame) -> void:
	if frame.collection is Collections.ListValue:
		_complete(_position_result(
			frame.collection.get_item(frame.index), frame.node.index.span
		))
		return
	if frame.collection is Collections.DictionaryValue:
		if not frame.collection.is_valid_key(frame.index):
			_fail(_new_failure(
				"type", "TYPE_UNHASHABLE_KEY",
				"A chave deve ser int, float, bool, str ou None.", frame.node.index.span
			))
			return
		if frame.scan_index >= frame.collection.size():
			_fail(_new_failure(
				"key", "KEY_NOT_FOUND",
				"A chave %s não existe." % frame.index.representation(), frame.node.index.span
			))
			return
		var key_result = frame.collection.key_at_position(frame.scan_index)
		if key_result.has_failure():
			_fail(_position_failure(key_result.failure(), frame.node.index.span))
		elif key_result.value().semantic_equals(frame.index):
			_complete(_position_result(
				frame.collection.value_at_position(frame.scan_index), frame.node.index.span
			))
		else:
			frame.scan_index += 1
		return
	_fail(_new_failure(
		"type", "TYPE_NOT_SUBSCRIPTABLE",
		"Valores do tipo %s não aceitam indexação." % frame.collection.type_name(),
		frame.node.collection.span
	))


func _process_index_write(frame) -> void:
	if frame.commit_mode:
		_commit_resolved_index(frame)
		return
	match frame.state:
		0:
			frame.state = 1
			_push_node(frame.node.collection)
		1:
			if frame.has_incoming:
				frame.collection = frame.take_incoming().value()
				frame.state = 2
		2:
			frame.state = 3
			_push_node(frame.node.index)
		3:
			if not frame.has_incoming:
				return
			frame.index = frame.take_incoming().value()
			if not frame.collection is Collections.ListValue \
					and not frame.collection is Collections.DictionaryValue:
				_fail(_new_failure(
					"type", "TYPE_NOT_SUBSCRIPTABLE",
					"O alvo da atribuição não aceita indexação.", frame.node.collection.span
				))
				return
			if frame.collection is Collections.DictionaryValue \
					and not frame.collection.is_valid_key(frame.index):
				_fail(_new_failure(
					"type", "TYPE_UNHASHABLE_KEY",
					"A chave deve ser int, float, bool, str ou None.", frame.node.index.span
				))
				return
			_complete(RuntimeResult.success(Frames.ResolvedTarget.index_target(
				frame.collection, frame.index, frame.node.index.span
			)))


func _commit_resolved_index(frame) -> void:
	var collection = frame.target.collection
	var index = frame.target.index
	if collection is Collections.ListValue:
		_complete(_position_result(collection.set_item(index, frame.value), frame.target.span))
		return
	if frame.scan_index < collection.size():
		var key_result = collection.key_at_position(frame.scan_index)
		if key_result.has_failure():
			_fail(_position_failure(key_result.failure(), frame.target.span))
		elif key_result.value().semantic_equals(index):
			_complete(_position_result(
				collection.set_item_at_position(frame.scan_index, index, frame.value),
				frame.target.span
			))
		else:
			frame.scan_index += 1
		return
	_complete(_position_result(
		collection.set_item_at_position(-1, index, frame.value), frame.target.span
	))


func _process_operator(frame) -> void:
	if frame.operator == "**":
		_process_power(frame)
		return
	_complete(_position_result(
		Operators.apply_binary(frame.operator, frame.left, frame.right),
		frame.operator_span
	))


func _process_power(frame) -> void:
	if not _is_numeric(frame.left) or not _is_numeric(frame.right):
		_complete(_position_result(
			RuntimeResult.failed(RuntimeFailure.new(
				"type", "TYPE_INVALID_OPERATION", "O operador '**' exige números."
			)), frame.operator_span
		))
		return
	if frame.left is Values.FloatValue or frame.right is Values.FloatValue \
			or _integral_value(frame.right) < 0:
		var base := _numeric_float(frame.left)
		var exponent := _numeric_float(frame.right)
		if base == 0.0 and exponent < 0.0:
			_fail(_new_failure(
				"runtime", "RUNTIME_DIVISION_BY_ZERO",
				"Zero não pode ser elevado a expoente negativo.", frame.operator_span
			))
			return
		var value: float = pow(base, exponent)
		if is_nan(value) or is_inf(value):
			_fail(_new_failure(
				"runtime", "RUNTIME_NON_FINITE_NUMBER",
				"A potência produziu um float não finito.", frame.operator_span
			))
		else:
			_complete(RuntimeResult.success(Values.FloatValue.new(value)))
		return
	if frame.state == 0:
		frame.power_base = _integral_value(frame.left)
		frame.power_exponent = _integral_value(frame.right)
		frame.power_result = 1
		frame.state = 1
		return
	if frame.power_exponent == 0:
		_complete(RuntimeResult.success(Values.IntegerValue.new(frame.power_result)))
		return
	if frame.power_phase == 0:
		if frame.power_exponent & 1:
			var product = Operators.checked_integer_multiply(
				frame.power_result, frame.power_base
			)
			if product.has_failure():
				_fail(_position_failure(product.failure(), frame.operator_span))
				return
			frame.power_result = product.value().numeric_value
		frame.power_phase = 1
		return
	frame.power_exponent >>= 1
	if frame.power_exponent > 0:
		var square = Operators.checked_integer_multiply(frame.power_base, frame.power_base)
		if square.has_failure():
			_fail(_position_failure(square.failure(), frame.operator_span))
			return
		frame.power_base = square.value().numeric_value
	frame.power_phase = 0


func _register_standard_builtins(environment) -> RuntimeResult:
	var definitions := [
		["range", 1, 3, Callable(self, "_builtin_range")],
		["len", 1, 1, Callable(self, "_builtin_len")],
		["print", 0, -1, Callable(self, "_builtin_print")],
		["input", 0, 0, Callable(self, "_builtin_automarket_input")],
		["send", 0, -1, Callable(self, "_builtin_automarket_send")],
		["sensor", 1, 1, Callable(self, "_builtin_automarket_sensor")],
		["get_stock", 0, 0, Callable(self, "_builtin_automarket_get_stock")],
		["buy_stock", 1, 1, Callable(self, "_builtin_automarket_buy_stock")],
		["get_deliveries", 0, 0, Callable(self, "_builtin_automarket_get_deliveries")],
		["declare_profit", 1, 1, Callable(self, "_builtin_automarket_declare_profit")],
		["wait", 1, 1, Callable(self, "_builtin_automarket_wait")],
	]
	for definition in definitions:
		var builtin_name: String = definition[0]
		if environment.has_local_binding(builtin_name):
			var existing_result = environment.lookup(builtin_name)
			if existing_result.has_failure() \
					or not existing_result.value() is BuiltinFunctionValue:
				continue
		var builtin_value = _track(BuiltinFunctionValue.new(
			builtin_name, definition[1], definition[2], definition[3]
		))
		var definition_result = environment.define(builtin_name, builtin_value)
		if definition_result.has_failure():
			return definition_result
	return RuntimeResult.no_value()


func _builtin_range(arguments: Array) -> RuntimeResult:
	for index in range(arguments.size()):
		if not arguments[index] is Values.IntegerValue:
			return RuntimeResult.failed(RuntimeFailure.new(
				"type", "TYPE_INVALID_ARGUMENT",
				"O argumento %d de range deve ser int, não %s." % [
					index + 1, arguments[index].type_name()
				], 0, 0, 0, "", "", "",
				{"function": "range", "argument": index + 1,
					"expected": "int", "received": arguments[index].type_name()}
			))
	var first := 0
	var exclusive_stop: int
	var increment := 1
	match arguments.size():
		1:
			exclusive_stop = arguments[0].numeric_value
		2:
			first = arguments[0].numeric_value
			exclusive_stop = arguments[1].numeric_value
		3:
			first = arguments[0].numeric_value
			exclusive_stop = arguments[1].numeric_value
			increment = arguments[2].numeric_value
	return RangeValue.create(first, exclusive_stop, increment, arguments.size())


func _builtin_len(arguments: Array) -> RuntimeResult:
	var value = arguments[0]
	if value is Collections.ListValue or value is Collections.DictionaryValue \
			or value is RangeValue:
		return RuntimeResult.success(Values.IntegerValue.new(value.size()))
	if value is Values.StringValue:
		return RuntimeResult.success(Values.IntegerValue.new(value.string_value.length()))
	return RuntimeResult.failed(RuntimeFailure.new(
		"type", "TYPE_NO_LENGTH",
		"O valor do tipo '%s' não possui tamanho." % value.type_name(),
		0, 0, 0, "", "", "", {"type": value.type_name()}
	))


func _builtin_print(arguments: Array) -> RuntimeResult:
	var parts: Array[String] = []
	for value in arguments:
		parts.append(value.display_text())
	_output_lines.append(" ".join(parts))
	return RuntimeResult.success(Values.none_value())


func _builtin_automarket_input(_arguments: Array) -> RuntimeResult:
	if not _has_automarket_bridge():
		return _bridge_unavailable("input")
	return _finish_bridge_call(_automarket_bridge.read_input(_automarket_context()))


func _builtin_automarket_send(arguments: Array) -> RuntimeResult:
	if not _has_automarket_bridge():
		return _bridge_unavailable("send")
	var native_values: Array = []
	for value in arguments:
		var converted = ValueConverter.to_native(value)
		if converted.has_failure():
			return converted
		native_values.append(converted.value())
	return _finish_bridge_call(_automarket_bridge.send(
		native_values, _automarket_context()
	))


func _builtin_automarket_sensor(arguments: Array) -> RuntimeResult:
	if not arguments[0] is Values.StringValue:
		return _builtin_type_failure("sensor", 1, "str", arguments[0])
	if not _has_automarket_bridge():
		return _bridge_unavailable("sensor")
	return _finish_bridge_call(_automarket_bridge.read_sensor(
		arguments[0].string_value, _automarket_context()
	))


func _builtin_automarket_get_stock(_arguments: Array) -> RuntimeResult:
	if not _has_automarket_bridge():
		return _bridge_unavailable("get_stock")
	return _finish_bridge_call(_automarket_bridge.get_stock(_automarket_context()))


func _builtin_automarket_buy_stock(arguments: Array) -> RuntimeResult:
	if not arguments[0] is Collections.ListValue:
		return _builtin_type_failure("buy_stock", 1, "list", arguments[0])
	if not _has_automarket_bridge():
		return _bridge_unavailable("buy_stock")
	var converted = ValueConverter.to_native(arguments[0])
	if converted.has_failure():
		return converted
	return _finish_bridge_call(_automarket_bridge.buy_stock(
		converted.value(), _automarket_context()
	))


func _builtin_automarket_get_deliveries(_arguments: Array) -> RuntimeResult:
	if not _has_automarket_bridge():
		return _bridge_unavailable("get_deliveries")
	var result = _finish_bridge_call(_automarket_bridge.get_deliveries(
		_automarket_context()
	))
	if not result.has_failure() and not result.is_suspended():
		_delivery_tracking_active = true
		_delivery_recursive_functions.clear()
	return result


func _builtin_automarket_declare_profit(arguments: Array) -> RuntimeResult:
	if not arguments[0] is Collections.ListValue:
		return _builtin_type_failure("declare_profit", 1, "list", arguments[0])
	if not _has_automarket_bridge():
		return _bridge_unavailable("declare_profit")
	var converted = ValueConverter.to_native(arguments[0])
	if converted.has_failure():
		return converted
	return _finish_bridge_call(_automarket_bridge.declare_profit(
		converted.value(), _automarket_context()
	))


func _builtin_automarket_wait(arguments: Array) -> RuntimeResult:
	var argument = arguments[0]
	if not argument is Values.IntegerValue and not argument is Values.FloatValue:
		return _builtin_type_failure("wait", 1, "int ou float", argument)
	var seconds := float(argument.numeric_value)
	if not is_finite(seconds):
		return RuntimeResult.failed(RuntimeFailure.new(
			"runtime", "RUNTIME_INVALID_VALUE",
			"wait() exige um número finito.",
			0, 0, 0, "", "", "", {"function": "wait", "value": seconds}
		))
	seconds = maxf(0.0, seconds)
	if not _has_automarket_bridge():
		return _bridge_unavailable("wait")
	var result = _finish_bridge_call(_automarket_bridge.wait(
		seconds, _automarket_context()
	))
	if result.has_failure() or result.is_suspended():
		return result
	return RuntimeResult.failed(RuntimeFailure.new(
		"bridge", "AUTOMARKET_WAIT_NOT_SUSPENDED",
		"A bridge concluiu wait() sem iniciar a suspensão cooperativa.",
		0, 0, 0, "", "", "", {"function": "wait"}
	))


func _finish_bridge_call(response) -> RuntimeResult:
	if not response is AutoMarketBridge.Response:
		return RuntimeResult.failed(RuntimeFailure.new(
			"bridge", "AUTOMARKET_BRIDGE_INVALID_RESPONSE",
			"A bridge retornou uma resposta inválida."
		))
	for line in response.output_lines:
		_output_lines.append(line)
	if response.is_suspended():
		var seconds := float(response.suspension_seconds)
		if not is_finite(seconds) or seconds < 0.0:
			return RuntimeResult.failed(RuntimeFailure.new(
				"bridge", "AUTOMARKET_WAIT_INVALID_RESPONSE",
				"A bridge retornou uma suspensão inválida.",
				0, 0, 0, "", "", "", {"seconds": seconds}
			))
		var request = SuspensionRequest.new(
			SuspensionRequest.KIND_SLEEP, seconds, _next_suspension_token
		)
		_next_suspension_token += 1
		return RuntimeResult.suspended(request)
	if not response.is_success():
		return RuntimeResult.failed(RuntimeFailure.new(
			response.category, response.code, response.message,
			0, 0, 0, "", "", "", response.details
		))
	return ValueConverter.from_native(response.value, _lifecycle)


func _has_automarket_bridge() -> bool:
	return _automarket_bridge != null \
		and _automarket_bridge is AutoMarketBridge


func _bridge_unavailable(operation: String) -> RuntimeResult:
	return RuntimeResult.failed(RuntimeFailure.new(
		"bridge", "AUTOMARKET_BRIDGE_UNAVAILABLE",
		"A API '%s' exige uma bridge AutoMarket configurada." % operation,
		0, 0, 0, "", "", "", {"operation": operation}
	))


func _builtin_type_failure(function_name: String, argument_index: int,
		expected_type: String, received_value) -> RuntimeResult:
	return RuntimeResult.failed(RuntimeFailure.new(
		"type", "TYPE_INVALID_ARGUMENT",
		"O argumento %d de %s deve ser %s, não %s." % [
			argument_index, function_name, expected_type, received_value.type_name()
		], 0, 0, 0, "", "", "", {
			"function": function_name,
			"argument": argument_index,
			"expected": expected_type,
			"received": received_value.type_name(),
		}
	))


func _automarket_context() -> Dictionary:
	return {
		"runtime_id": runtime_id,
		"script_id": script_id,
		"source_name": source_name,
	}


func _observe_delivery_recursive_call(function_value) -> void:
	if not _delivery_tracking_active:
		return
	var function_name: String = function_value.function_name
	for active_frame in _call_stack:
		if active_frame.function_value != null \
				and active_frame.function_value.function_name == function_name:
			_delivery_recursive_functions[function_name] = true
			return


func _push_node(node) -> void:
	var frame
	if node is Ast.ProgramNode:
		frame = Frames.ProgramFrame.new(node)
	elif node is Ast.BlockNode:
		frame = Frames.BlockFrame.new(node)
	elif node is Ast.IfStatementNode:
		frame = Frames.IfFrame.new(node)
	elif node is Ast.WhileStatementNode:
		frame = Frames.WhileFrame.new(node)
	elif node is Ast.ForStatementNode:
		frame = Frames.ForFrame.new(node)
	elif node is Ast.BreakStatementNode:
		frame = Frames.BreakFrame.new(node)
	elif node is Ast.ContinueStatementNode:
		frame = Frames.ContinueFrame.new(node)
	elif node is Ast.FunctionDefinitionNode:
		frame = Frames.FunctionDefinitionFrame.new(node)
	elif node is Ast.ReturnStatementNode:
		frame = Frames.ReturnFrame.new(node)
	elif node is Ast.ExpressionStatementNode:
		frame = Frames.ExpressionStatementFrame.new(node)
	elif node is Ast.SimpleAssignmentNode:
		frame = Frames.AssignmentFrame.new(node)
	elif node is Ast.CompoundAssignmentNode:
		frame = Frames.AugmentedAssignmentFrame.new(node)
	elif node is Ast.IntegerLiteralNode or node is Ast.FloatLiteralNode \
			or node is Ast.StringLiteralNode or node is Ast.BooleanLiteralNode \
			or node is Ast.NoneLiteralNode:
		frame = Frames.LiteralFrame.new(node)
	elif node is Ast.IdentifierNode:
		frame = Frames.IdentifierFrame.new(node)
	elif node is Ast.GroupExpressionNode:
		frame = Frames.GroupFrame.new(node)
	elif node is Ast.ListLiteralNode:
		frame = Frames.ListFrame.new(node)
	elif node is Ast.DictionaryLiteralNode:
		frame = Frames.DictionaryFrame.new(node)
	elif node is Ast.UnaryExpressionNode:
		frame = Frames.UnaryFrame.new(node)
	elif node is Ast.BinaryExpressionNode:
		frame = Frames.BinaryFrame.new(node)
	elif node is Ast.LogicalExpressionNode:
		frame = Frames.LogicalFrame.new(node)
	elif node is Ast.ComparisonExpressionNode:
		frame = Frames.ComparisonChainFrame.new(node)
	elif node is Ast.IndexExpressionNode:
		frame = Frames.IndexReadFrame.new(node)
	elif node is Ast.CallExpressionNode:
		frame = Frames.CallFrame.new(node)
	else:
		_fail(_new_failure(
			"runtime", "RUNTIME_UNSUPPORTED_NODE",
			"A construção '%s' ainda não é executada nesta etapa." % node.type,
			node.span, {"node_type": node.type, "stage": "functions_calls_return"}
		))
		return
	_frames.append(frame)


func _complete(result) -> void:
	if result.has_failure():
		_fail(result.failure())
		return
	_frames.pop_back()
	if _frames.is_empty():
		final_result = result
		return
	_frames.back().accept(result)


func _fail(runtime_failure) -> void:
	_failure = runtime_failure
	_frames.clear()
	_call_stack.clear()
	_environment_stack = [global_environment] if global_environment != null else []
	_active = false
	_finished = true


func _position_result(result, span):
	if result.has_failure():
		return RuntimeResult.failed(_position_failure(result.failure(), span))
	return result


func _control_signal(result):
	if result != null and result.has_value() \
			and result.value() is Frames.ControlFlowSignal:
		return result.value()
	return null


func _position_failure(base_failure, span):
	return _new_failure(
		base_failure.category, base_failure.code, base_failure.message, span,
		base_failure.details
	)


func _new_failure(category: String, code: String, message: String, span,
		details: Dictionary = {}):
	var line := 0
	var column := 0
	var length := 0
	if span != null:
		line = span.start_line
		column = span.start_column
		length = maxi(1, span.end_offset - span.start_offset)
	return RuntimeFailure.new(
		category, code, message, line, column, length,
		script_id, source_name, runtime_id, details
	)


func _track(resource):
	return _lifecycle.track(resource)


func _current_environment():
	return _environment_stack.back() if not _environment_stack.is_empty() else null


func _is_numeric(value) -> bool:
	return value is Values.IntegerValue or value is Values.FloatValue \
		or value is Values.BooleanValue


func _is_integral(value) -> bool:
	return value is Values.IntegerValue or value is Values.BooleanValue


func _integral_value(value) -> int:
	if value is Values.BooleanValue:
		return 1 if value.boolean_value else 0
	return value.numeric_value


func _numeric_float(value) -> float:
	if value is Values.BooleanValue:
		return 1.0 if value.boolean_value else 0.0
	return float(value.numeric_value)
