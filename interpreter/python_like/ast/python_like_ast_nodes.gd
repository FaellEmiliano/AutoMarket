extends RefCounted
class_name PythonLikeAstNodes


class SourceSpan extends RefCounted:
	var start_offset: int
	var end_offset: int
	var start_line: int
	var start_column: int
	var end_line: int
	var end_column: int

	func _init(begin_offset: int, finish_offset: int, begin_line: int,
			begin_column: int, finish_line: int, finish_column: int) -> void:
		start_offset = begin_offset
		end_offset = finish_offset
		start_line = begin_line
		start_column = begin_column
		end_line = finish_line
		end_column = finish_column

	static func from_token(token) -> SourceSpan:
		return SourceSpan.new(
			token.start_offset, token.end_offset,
			token.line, token.column, token.end_line, token.end_column
		)

	static func between(first, last) -> SourceSpan:
		return SourceSpan.new(
			first.start_offset, last.end_offset,
			first.line, first.column, last.end_line, last.end_column
		)

	func to_dictionary() -> Dictionary:
		return {
			"start_offset": start_offset,
			"end_offset": end_offset,
			"start_line": start_line,
			"start_column": start_column,
			"end_line": end_line,
			"end_column": end_column,
		}


class AstNode extends RefCounted:
	var span: SourceSpan
	var type: String

	func _init(node_type: String, source_span: SourceSpan) -> void:
		type = node_type
		span = source_span


class StatementNode extends AstNode:
	func _init(node_type: String, source_span: SourceSpan) -> void:
		super(node_type, source_span)


class ExpressionNode extends AstNode:
	func _init(node_type: String, source_span: SourceSpan) -> void:
		super(node_type, source_span)


class ProgramNode extends AstNode:
	var statements: Array

	func _init(program_statements: Array, source_span: SourceSpan) -> void:
		super("program", source_span)
		statements = program_statements


class ExpressionStatementNode extends StatementNode:
	var expression: ExpressionNode

	func _init(statement_expression: ExpressionNode, source_span: SourceSpan) -> void:
		super("expression_statement", source_span)
		expression = statement_expression


class SimpleAssignmentNode extends StatementNode:
	var target: ExpressionNode
	var value: ExpressionNode
	var operator: String = "="
	var operator_span: SourceSpan

	func _init(assignment_target: ExpressionNode, assignment_value: ExpressionNode,
			source_span: SourceSpan, assignment_operator_span: SourceSpan) -> void:
		super("simple_assignment", source_span)
		target = assignment_target
		value = assignment_value
		operator_span = assignment_operator_span


class CompoundAssignmentNode extends StatementNode:
	var target: ExpressionNode
	var value: ExpressionNode
	var operator: String
	var operator_span: SourceSpan

	func _init(assignment_target: ExpressionNode, assignment_operator: String,
			assignment_value: ExpressionNode, source_span: SourceSpan,
			assignment_operator_span: SourceSpan) -> void:
		super("compound_assignment", source_span)
		target = assignment_target
		operator = assignment_operator
		value = assignment_value
		operator_span = assignment_operator_span


# A block represents the complete suite grammar. Its span starts at the NEWLINE
# after the header colon and ends at the exclusive end of DEDENT. INDENT may
# cover indentation whitespace; DEDENT is normally zero-width at the next token.
class BlockNode extends AstNode:
	var statements: Array
	var newline_span: SourceSpan
	var indent_span: SourceSpan
	var dedent_span: SourceSpan

	func _init(block_statements: Array, source_span: SourceSpan,
			block_newline_span: SourceSpan, block_indent_span: SourceSpan,
			block_dedent_span: SourceSpan) -> void:
		super("block", source_span)
		statements = block_statements
		newline_span = block_newline_span
		indent_span = block_indent_span
		dedent_span = block_dedent_span


class ConditionalBranchNode extends AstNode:
	var keyword: String
	var condition: ExpressionNode
	var body: BlockNode
	var keyword_span: SourceSpan
	var colon_span: SourceSpan

	func _init(branch_keyword: String, branch_condition: ExpressionNode,
			branch_body: BlockNode, source_span: SourceSpan,
			branch_keyword_span: SourceSpan, branch_colon_span: SourceSpan) -> void:
		super("conditional_branch", source_span)
		keyword = branch_keyword
		condition = branch_condition
		body = branch_body
		keyword_span = branch_keyword_span
		colon_span = branch_colon_span


class ElseBranchNode extends AstNode:
	var body: BlockNode
	var keyword_span: SourceSpan
	var colon_span: SourceSpan

	func _init(branch_body: BlockNode, source_span: SourceSpan,
			branch_keyword_span: SourceSpan, branch_colon_span: SourceSpan) -> void:
		super("else_branch", source_span)
		body = branch_body
		keyword_span = branch_keyword_span
		colon_span = branch_colon_span


class IfStatementNode extends StatementNode:
	var if_branch: ConditionalBranchNode
	var elif_branches: Array
	var else_branch: ElseBranchNode

	func _init(main_branch: ConditionalBranchNode, additional_branches: Array,
			optional_else_branch, source_span: SourceSpan) -> void:
		super("if_statement", source_span)
		if_branch = main_branch
		elif_branches = additional_branches
		else_branch = optional_else_branch


class WhileStatementNode extends StatementNode:
	var condition: ExpressionNode
	var body: BlockNode
	var keyword_span: SourceSpan
	var colon_span: SourceSpan

	func _init(loop_condition: ExpressionNode, loop_body: BlockNode,
			source_span: SourceSpan, loop_keyword_span: SourceSpan,
			loop_colon_span: SourceSpan) -> void:
		super("while_statement", source_span)
		condition = loop_condition
		body = loop_body
		keyword_span = loop_keyword_span
		colon_span = loop_colon_span


class ForStatementNode extends StatementNode:
	var target: IdentifierNode
	var iterable: ExpressionNode
	var body: BlockNode
	var keyword_span: SourceSpan
	var in_span: SourceSpan
	var colon_span: SourceSpan

	func _init(loop_target: IdentifierNode, loop_iterable: ExpressionNode,
			loop_body: BlockNode, source_span: SourceSpan,
			loop_keyword_span: SourceSpan, loop_in_span: SourceSpan,
			loop_colon_span: SourceSpan) -> void:
		super("for_statement", source_span)
		target = loop_target
		iterable = loop_iterable
		body = loop_body
		keyword_span = loop_keyword_span
		in_span = loop_in_span
		colon_span = loop_colon_span


class IntegerLiteralNode extends ExpressionNode:
	var value: int
	var lexeme: String

	func _init(literal_value: int, original_lexeme: String, source_span: SourceSpan) -> void:
		super("integer_literal", source_span)
		value = literal_value
		lexeme = original_lexeme


class FloatLiteralNode extends ExpressionNode:
	var value: float
	var lexeme: String

	func _init(literal_value: float, original_lexeme: String, source_span: SourceSpan) -> void:
		super("float_literal", source_span)
		value = literal_value
		lexeme = original_lexeme


class StringLiteralNode extends ExpressionNode:
	var value: String
	var lexeme: String

	func _init(literal_value: String, original_lexeme: String, source_span: SourceSpan) -> void:
		super("string_literal", source_span)
		value = literal_value
		lexeme = original_lexeme


class BooleanLiteralNode extends ExpressionNode:
	var value: bool
	var lexeme: String

	func _init(literal_value: bool, original_lexeme: String, source_span: SourceSpan) -> void:
		super("boolean_literal", source_span)
		value = literal_value
		lexeme = original_lexeme


class NoneLiteralNode extends ExpressionNode:
	func _init(source_span: SourceSpan) -> void:
		super("none_literal", source_span)


class ListLiteralNode extends ExpressionNode:
	var elements: Array

	func _init(list_elements: Array, source_span: SourceSpan) -> void:
		super("list_literal", source_span)
		elements = list_elements


class DictionaryEntryNode extends AstNode:
	var key: ExpressionNode
	var value: ExpressionNode
	var colon_span: SourceSpan

	func _init(entry_key: ExpressionNode, entry_value: ExpressionNode,
			source_span: SourceSpan, entry_colon_span: SourceSpan) -> void:
		super("dictionary_entry", source_span)
		key = entry_key
		value = entry_value
		colon_span = entry_colon_span


class DictionaryLiteralNode extends ExpressionNode:
	var entries: Array

	func _init(dictionary_entries: Array, source_span: SourceSpan) -> void:
		super("dictionary_literal", source_span)
		entries = dictionary_entries


class IdentifierNode extends ExpressionNode:
	var name: String

	func _init(identifier_name: String, source_span: SourceSpan) -> void:
		super("identifier", source_span)
		name = identifier_name


class GroupExpressionNode extends ExpressionNode:
	var expression: ExpressionNode

	func _init(grouped_expression: ExpressionNode, source_span: SourceSpan) -> void:
		super("group_expression", source_span)
		expression = grouped_expression


class UnaryExpressionNode extends ExpressionNode:
	var operator: String
	var operand: ExpressionNode
	var operator_span: SourceSpan

	func _init(unary_operator: String, unary_operand: ExpressionNode,
			source_span: SourceSpan, unary_operator_span: SourceSpan) -> void:
		super("unary_expression", source_span)
		operator = unary_operator
		operand = unary_operand
		operator_span = unary_operator_span


class BinaryExpressionNode extends ExpressionNode:
	var left: ExpressionNode
	var operator: String
	var right: ExpressionNode
	var operator_span: SourceSpan

	func _init(left_operand: ExpressionNode, binary_operator: String,
			right_operand: ExpressionNode, source_span: SourceSpan,
			binary_operator_span: SourceSpan) -> void:
		super("binary_expression", source_span)
		left = left_operand
		operator = binary_operator
		right = right_operand
		operator_span = binary_operator_span


class LogicalExpressionNode extends ExpressionNode:
	var left: ExpressionNode
	var operator: String
	var right: ExpressionNode
	var operator_span: SourceSpan

	func _init(left_operand: ExpressionNode, logical_operator: String,
			right_operand: ExpressionNode, source_span: SourceSpan,
			logical_operator_span: SourceSpan) -> void:
		super("logical_expression", source_span)
		left = left_operand
		operator = logical_operator
		right = right_operand
		operator_span = logical_operator_span


class ComparisonExpressionNode extends ExpressionNode:
	var operands: Array
	var operators: Array[String]
	var operator_spans: Array

	func _init(comparison_operands: Array, comparison_operators: Array[String],
			comparison_operator_spans: Array, source_span: SourceSpan) -> void:
		super("comparison_expression", source_span)
		operands = comparison_operands
		operators = comparison_operators
		operator_spans = comparison_operator_spans


class CallExpressionNode extends ExpressionNode:
	var callee: ExpressionNode
	var arguments: Array
	var opening_span: SourceSpan
	var closing_span: SourceSpan

	func _init(call_callee: ExpressionNode, call_arguments: Array,
			source_span: SourceSpan, call_opening_span: SourceSpan,
			call_closing_span: SourceSpan) -> void:
		super("call_expression", source_span)
		callee = call_callee
		arguments = call_arguments
		opening_span = call_opening_span
		closing_span = call_closing_span


class IndexExpressionNode extends ExpressionNode:
	var collection: ExpressionNode
	var index: ExpressionNode
	var opening_span: SourceSpan
	var closing_span: SourceSpan

	func _init(indexed_collection: ExpressionNode, index_expression: ExpressionNode,
			source_span: SourceSpan, index_opening_span: SourceSpan,
			index_closing_span: SourceSpan) -> void:
		super("index_expression", source_span)
		collection = indexed_collection
		index = index_expression
		opening_span = index_opening_span
		closing_span = index_closing_span


class AttributeExpressionNode extends ExpressionNode:
	var object: ExpressionNode
	var attribute: String
	var dot_span: SourceSpan
	var attribute_span: SourceSpan

	func _init(attribute_object: ExpressionNode, attribute_name: String,
			source_span: SourceSpan, attribute_dot_span: SourceSpan,
			name_span: SourceSpan) -> void:
		super("attribute_expression", source_span)
		object = attribute_object
		attribute = attribute_name
		dot_span = attribute_dot_span
		attribute_span = name_span
