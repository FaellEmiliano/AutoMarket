extends RefCounted
class_name PythonLikeExecutorFrames


class Frame extends RefCounted:
	var node
	var state: int = 0
	var has_incoming: bool = false
	var incoming

	func _init(source_node = null) -> void:
		node = source_node

	func accept(result) -> void:
		has_incoming = true
		incoming = result

	func take_incoming():
		var result = incoming
		has_incoming = false
		incoming = null
		return result


class ProgramFrame extends Frame:
	var statement_index: int = 0


class BlockFrame extends Frame:
	var statement_index: int = 0


class IfFrame extends Frame:
	var branch_index: int = 0
	var condition_value
	var selected_body


class WhileFrame extends Frame:
	var condition_value


class ForFrame extends Frame:
	var iterable
	var item_index: int = 0
	var checks_mutation: bool = false
	var expected_mutation_version: int = 0
	var next_value


class BreakFrame extends Frame:
	pass


class ContinueFrame extends Frame:
	pass


class FunctionDefinitionFrame extends Frame:
	var definition_environment
	var scan_stack: Array = []
	var local_names := {}
	var local_name_list: Array = []
	var function_value
	var parameter_index: int = 0
	var local_index: int = 0


class CallFrame extends Frame:
	var callable_value
	var argument_values: Array = []
	var argument_index: int = 0
	var local_environment
	var local_index: int = 0
	var parameter_index: int = 0


class BuiltinCallFrame extends Frame:
	var function_value
	var argument_values: Array = []
	var call_span
	var suspension_request


class FunctionExecutionFrame extends Frame:
	var function_value
	var local_environment
	var caller_environment
	var call_span


class ReturnFrame extends Frame:
	var return_value


class ControlFlowSignal extends RefCounted:
	enum Kind { BREAK, CONTINUE, RETURN }

	var kind: Kind
	var span
	var value

	func _init(signal_kind: Kind, source_span, signal_value = null) -> void:
		kind = signal_kind
		span = source_span
		value = signal_value


class ExpressionStatementFrame extends Frame:
	pass


class AssignmentFrame extends Frame:
	var target
	var assigned_value


class AugmentedAssignmentFrame extends AssignmentFrame:
	var left_value
	var computed_value


class LiteralFrame extends Frame:
	pass


class IdentifierFrame extends Frame:
	pass


class GroupFrame extends Frame:
	pass


class ListFrame extends Frame:
	var result
	var element_index: int = 0


class DictionaryFrame extends Frame:
	var result
	var entry_index: int = 0
	var key_value
	var entry_value
	var scan_index: int = 0


class UnaryFrame extends Frame:
	var operand


class BinaryFrame extends Frame:
	var left
	var right
	var result_collection
	var copy_index: int = 0
	var repetition_index: int = 0
	var repeat_source
	var repeat_count: int = 0
	var result_text: String = ""


class LogicalFrame extends Frame:
	var left


class ComparisonChainFrame extends Frame:
	var operand_index: int = 0
	var left
	var right


class MembershipFrame extends Frame:
	var needle
	var collection
	var item_index: int = 0
	var negate: bool = false


class IndexReadFrame extends Frame:
	var collection
	var index
	var scan_index: int = 0
	var values_are_resolved: bool = false


class ResolvedTarget extends RefCounted:
	enum Kind { NAME, INDEX }

	var kind: Kind
	var name: String = ""
	var collection
	var index
	var span

	static func name_target(target_name: String, target_span):
		var target := ResolvedTarget.new()
		target.kind = Kind.NAME
		target.name = target_name
		target.span = target_span
		return target

	static func index_target(target_collection, target_index, target_span):
		var target := ResolvedTarget.new()
		target.kind = Kind.INDEX
		target.collection = target_collection
		target.index = target_index
		target.span = target_span
		return target


class IndexWriteFrame extends Frame:
	var target
	var value
	var collection
	var index
	var scan_index: int = 0
	var commit_mode: bool = false


class OperatorFrame extends Frame:
	var operator: String
	var left
	var right
	var operator_span
	var power_result: int = 1
	var power_base: int = 0
	var power_exponent: int = 0
	var power_phase: int = 0

	func _init(binary_operator: String, left_value, right_value, source_span) -> void:
		super(null)
		operator = binary_operator
		left = left_value
		right = right_value
		operator_span = source_span
