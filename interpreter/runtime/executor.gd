extends Node
class_name Executor

const DeliveryConfigData = preload("res://data/DeliveryConfig.gd")

var input_stack
var id

var interpreter
var execution_stack = []
var call_stack = []
var builtins = {}
var runtime_id := ""
var script_id := ""
var program_ast = null
var delivery_program_facts = null
var delivery_report_id := 0
var delivery_recursive_functions := {}
var max_call_depth := DeliveryConfigData.MAX_CALL_DEPTH

var is_finished = false

const SIGNAL_BREAK = "break"
const SIGNAL_CONTINUE = "continue"
const SIGNAL_RETURN = "return"

# ─── Stack helpers ─────────────────────────────────────────────────────────────

func push_frame(type, node):
	var frame = {
		"type": type,
		"node": node,
		"index": 0,
		"state": {}
	}
	execution_stack.append(frame)

func make_signal(type, value = null) -> Dictionary:
	return { "type": type, "value": value }

func pop_frame():
	execution_stack.pop_back()
	if execution_stack.is_empty():
		is_finished = true

func current_frame() -> Variant:
	if execution_stack.is_empty():
		return null
	return execution_stack.back()

func current_env() -> Variant:
	if call_stack.is_empty():
		interpreter.erro_fatal("call_stack vazia — erro interno do executor")
		return null
	return call_stack.back()

func push_scope():
	var env = current_env()
	if env == null:
		return
	env["scope_stack"].append({})

func pop_scope():
	var env = current_env()
	if env == null:
		return
	if env["scope_stack"].is_empty():
		return
	env["scope_stack"].pop_back()

func current_scope() -> Variant:
	var env = current_env()
	if env == null:
		return null
	var scopes = env["scope_stack"]
	if scopes.is_empty():
		return null
	return scopes[scopes.size() - 1]

func register_builtin(name, fn):
	builtins[name] = fn

# ─── Inicialização ─────────────────────────────────────────────────────────────

func load_program(program_node, context):
	self.input_stack = context.inputs.duplicate()
	self.id = context.id
	execution_stack.clear()
	call_stack.clear()
	is_finished = false
	program_ast = program_node
	delivery_program_facts = null
	delivery_report_id = 0
	delivery_recursive_functions.clear()

	var builtins_obj = Builtins.new()
	builtins_obj.register(self)

	var global_frame = {
		"name": "global",
		"scope_stack": [{}],
		"parent": null
	}
	call_stack.append(global_frame)
	push_frame("program", program_node)

# ─── Loop de execução ──────────────────────────────────────────────────────────

func step():
	if is_finished:
		return

	var frame = current_frame()
	if frame == null:
		is_finished = true
		return

	var signal_ = process_frame(frame)
	if signal_ != null:
		handle_signal(signal_)

func handle_signal(signal_):
	match signal_.type:
		SIGNAL_BREAK:    handle_break()
		SIGNAL_CONTINUE: handle_continue()
		SIGNAL_RETURN:   handle_return(signal_)

# ─── Dispatch de frames ────────────────────────────────────────────────────────

func process_frame(frame) -> Variant:
	match frame.type:
		"program":              process_program(frame)
		"block":                process_block(frame)
		"expression_statement": process_expression_statement(frame)
		"assign":               process_assign(frame)
		"var_decl":             process_var_decl(frame)
		"if":                   process_if(frame)
		"while":                process_while(frame)
		"break":                return make_signal(SIGNAL_BREAK)
		"continue":             return make_signal(SIGNAL_CONTINUE)
		"return":               return process_return(frame)
		"function_decl":        process_function_decl(frame)
		"function_call":        process_function_call(frame)
		"expression":           process_expression(frame)
		"for":                  process_for(frame)
		"global_block":         process_global_block(frame)
		"array_decl":           process_array_decl(frame)
		_:
			interpreter.erro_fatal("Tipo de frame não implementado: " + str(frame.type))
	return null

# ─── Program / Block ───────────────────────────────────────────────────────────

func process_program(frame):
	match frame.index:
		0:
			push_frame("global_block", frame.node)
			frame.index = 1
		1:
			var main_fn = get_variable("main")
			if main_fn == null:
				interpreter.erro_fatal("Não achei a função main(). O script precisa começar por ela.")
				pop_frame()
				return
			push_frame("function_call", ASTNodes.FunctionCallNode.new("main", []))
			frame.index = 2
		2:
			pop_frame()

func process_block(frame):
	var statements = frame.node.statements
	match frame.index:
		0:
			push_scope()
			frame.index = 1
		1:
			if frame.state.get("i") == null:
				frame.state["i"] = 0
			if frame.state["i"] >= statements.size():
				frame.index = 2
				return
			var stmt = statements[frame.state["i"]]
			frame.state["i"] += 1
			push_frame(stmt.type, stmt)
		2:
			pop_scope()
			pop_frame()

func process_expression_statement(frame):
	match frame.index:
		0:
			var expr = frame.node.expression
			if expr == null:
				pop_frame()
				return
			if expr.type == "assign":
				push_frame("assign", expr)
			elif expr.type == "function_call":
				push_frame("function_call", expr)
			else:
				push_frame("expression", expr)
			frame.index = 1
		1:
			pop_frame()

# ─── Eval síncrono (apenas para expressões simples sem function_call) ──────────

func eval(node) -> Variant:
	if node == null:
		interpreter.erro_fatal("Tentativa de avaliar nó nulo")
		return null
	match node.type:
		"number":       return node.value
		"binary":       return eval_binary(node)
		"identifier":   return get_variable(node.name)
		"bool":         return node.value
		"array_access": return get_array_value(node)
		"array_literal": return build_array_literal_value(_eval_array_literal_elements(node))
		"string":       return node.value
		_:
			interpreter.erro_runtime("Não sei calcular esse tipo de valor: " + node.type)
			return null

func eval_binary(node) -> Variant:
	var left = eval(node.left)
	var right = eval(node.right)
	return apply_op(node.op, left, right)

# ─── Variáveis ─────────────────────────────────────────────────────────────────

func get_variable(name) -> Variant:
	var env = current_env()
	while env != null:
		var scopes = env["scope_stack"]
		for i in range(scopes.size() - 1, -1, -1):
			if name in scopes[i]:
				return scopes[i][name]["value"]
		env = env["parent"]
	interpreter.erro_runtime("A variável '" + str(name) + "' ainda não tem valor.")
	return null

func set_variable(name, value):
	var env = current_env()
	while env != null:
		var scopes = env["scope_stack"]
		for i in range(scopes.size() - 1, -1, -1):
			if name in scopes[i]:
				var var_data = scopes[i][name]
				var_data["value"] = coerce_value(value, var_data["type"])
				return
		env = env["parent"]
	interpreter.erro_runtime("A variável '" + name + "' não foi declarada.")

func get_variable_wrapper(name) -> Variant:
	var env = current_env()
	while env != null:
		var scopes = env["scope_stack"]
		for i in range(scopes.size() - 1, -1, -1):
			if name in scopes[i]:
				return scopes[i][name]
		env = env["parent"]
	interpreter.erro_runtime("A variável '" + str(name) + "' ainda não existe.")
	return null

func declare_variable(name, value, type):
	var scope = current_scope()
	if scope == null:
		interpreter.erro_fatal("Nenhum escopo ativo para declarar '" + name + "'")
		return
	if typeof(value) == TYPE_DICTIONARY and value.get("type") == "function":
		scope[name] = { "type": "function", "value": value }
		return
	scope[name] = { "type": type, "value": coerce_value(value, type) }

# ─── Assign / Decl ─────────────────────────────────────────────────────────────

func process_assign(frame):
	match frame.index:
		0:
			push_frame("expression", frame.node.value)
			frame.index = 1
		1:
			var target = frame.node.node
			var value = frame.state["value"]
			if target == null:
				interpreter.erro_runtime("Não dá para guardar valor nesse lugar.")
				pop_frame()
				return
			if _is_compound_assignment(frame.node):
				value = _apply_compound_assignment(frame.node.op, target, value)
				if value == null:
					pop_frame()
					return
			if target.type == "identifier":
				set_variable(target.name, value)
			elif target.type == "array_access":
				var arr_wrapper = get_variable_wrapper(target.array.name)
				if arr_wrapper == null:
					pop_frame()
					return
				var arr = arr_wrapper["value"]
				if arr == null or typeof(arr) != TYPE_DICTIONARY or not arr.has("dimensions"):
					interpreter.erro_runtime("'" + target.array.name + "' não é um array.")
					pop_frame()
					return
				var indexes = []
				var _idx_ok = true
				for idx_node in target.indexes:
					var idx_val = eval(idx_node)
					if idx_val == null:
						interpreter.erro_runtime("O índice do array veio vazio.")
						_idx_ok = false
						break
					indexes.append(idx_val)
				if not _idx_ok:
					pop_frame()
					return
				if indexes.size() != arr["dimensions"].size():
					interpreter.erro_runtime(
						"Esse array espera %d índice(s), mas recebeu %d." % [arr["dimensions"].size(), indexes.size()]
					)
					pop_frame()
					return
				var offset = compute_offset(indexes, arr["dimensions"])
				if offset < 0 or offset >= arr["data"].size():
					interpreter.erro_runtime(
						"Índice fora do array: %d. O tamanho é %d." % [offset, arr["data"].size()]
					)
					pop_frame()
					return
				arr["data"][offset] = coerce_value(value, arr["element_type"])
			else:
				interpreter.erro_runtime("Não dá para atribuir valor em: " + str(target.type))
			pop_frame()

func _is_compound_assignment(node) -> bool:
	return node.op != null and node.op.type in [
		Token.TiposToken.OP_PLUS_EQUAL,
		Token.TiposToken.OP_MINUS_EQUAL,
		Token.TiposToken.OP_STAR_EQUAL,
		Token.TiposToken.OP_SLASH_EQUAL
	]

func _apply_compound_assignment(op, target, right_value) -> Variant:
	var left_value = null
	if target.type == "identifier":
		left_value = get_variable(target.name)
	elif target.type == "array_access":
		left_value = get_array_value(target)
	else:
		interpreter.erro_runtime("Não dá para atribuir valor em: " + str(target.type))
		return null

	var simple_op_type = _compound_to_simple_operator(op.type)
	if simple_op_type == null:
		interpreter.erro_runtime("Não reconheci esse operador: " + str(op.value))
		return null
	return apply_op(Token.new(simple_op_type, str(op.value).left(1), op.linha, op.coluna), left_value, right_value)

func _compound_to_simple_operator(type):
	match type:
		Token.TiposToken.OP_PLUS_EQUAL:  return Token.TiposToken.OP_PLUS
		Token.TiposToken.OP_MINUS_EQUAL: return Token.TiposToken.OP_MINUS
		Token.TiposToken.OP_STAR_EQUAL:  return Token.TiposToken.OP_STAR
		Token.TiposToken.OP_SLASH_EQUAL: return Token.TiposToken.OP_SLASH
	return null

func process_var_decl(frame):
	match frame.index:
		0:
			if frame.node.value != null:
				push_frame("expression", frame.node.value)
				frame.index = 1
			else:
				frame.state["value"] = null
				frame.index = 1
		1:
			declare_variable(frame.node.name, frame.state["value"], frame.node.type_var)
			pop_frame()

# ─── Controle de fluxo ─────────────────────────────────────────────────────────

func process_if(frame):
	match frame.index:
		0:
			push_frame("expression", frame.node.condicao)
			frame.index = 1
		1:
			frame.state["cond"] = frame.state.get("value", false)
			if frame.state["cond"]:
				push_frame("block", frame.node.if_branch)
			elif frame.node.else_branch != null:
				push_frame("block", frame.node.else_branch)
			frame.index = 2
		2:
			pop_frame()

func process_while(frame):
	match frame.index:
		0:
			push_frame("expression", frame.node.condicao)
			frame.index = 1
		1:
			frame.state["cond"] = frame.state.get("value", false)
			if frame.state["cond"]:
				push_frame("block", frame.node.body)
				frame.index = 2
			else:
				pop_frame()
		2:
			frame.index = 0

func handle_break():
	while not execution_stack.is_empty():
		var frame = current_frame()
		pop_frame()
		if frame.type == "while" or frame.type == "for":
			return
	interpreter.erro_runtime("break só funciona dentro de while ou for.")

func handle_continue():
	while not execution_stack.is_empty():
		var frame = current_frame()
		if frame.type == "while" or frame.type == "for":
			if frame.type == "for":
				frame.index = 3
			else:
				frame.index = 0
			return
		pop_frame()
	interpreter.erro_runtime("continue só funciona dentro de while ou for.")

func process_return(frame) -> Variant:
	match frame.index:
		0:
			if frame.node.value != null:
				push_frame("expression", frame.node.value)
				frame.index = 1
			else:
				frame.state["value"] = null
				frame.index = 2
		1:
			return make_signal(SIGNAL_RETURN, frame.state["value"])
	return null

func handle_return(signal_):
	var return_value = signal_.value
	while not execution_stack.is_empty():
		var frame = current_frame()
		if frame.type == "function_call":
			frame.state["return_value"] = return_value
			frame.index = 3
			return
		pop_frame()
	interpreter.erro_runtime("return só faz sentido dentro de uma função.")

# ─── Funções ───────────────────────────────────────────────────────────────────

func process_function_decl(frame):
	match frame.index:
		0:
			var fn_obj = {
				"type": "function",
				"name": frame.node.name,
				"params": frame.node.params,
				"body": frame.node.body
			}
			declare_variable(frame.node.name, fn_obj, frame.node.type_var)
			frame.index = 1
		1:
			pop_frame()

func process_function_call(frame):
	match frame.index:
		0:
			var fn_name = frame.node.name
			if fn_name in builtins:
				frame.state["builtin"] = builtins[fn_name]
				frame.state["is_builtin"] = true
				frame.state["args"] = []
				frame.state["arg_index"] = 0
				frame.index = 1
				return
			var fn = get_variable(fn_name)
			if fn == null:
				# erro já registrado por get_variable
				pop_frame()
				return
			if typeof(fn) != TYPE_DICTIONARY or fn.get("type") != "function":
				interpreter.erro_runtime("'" + frame.node.name + "' não é uma função.")
				pop_frame()
				return
			frame.state["fn"] = fn
			frame.state["args"] = []
			frame.state["arg_index"] = 0
			frame.index = 1

		1:
			var args_nodes = frame.node.args
			var i = frame.state["arg_index"]
			if i >= args_nodes.size():
				frame.index = 2
				return
			push_frame("expression", args_nodes[i])
			frame.index = 1.5

		1.5:
			frame.state["args"].append(frame.state.get("value"))
			frame.state.erase("value")
			frame.state["arg_index"] += 1
			frame.index = 1

		2:
			if frame.state.get("is_builtin"):
				var result = frame.state["builtin"].call(frame.state["args"])
				deliver_result_to_parent(result)
				pop_frame()
				return

			var fn = frame.state["fn"]
			var args = frame.state["args"]
			if call_stack.size() >= max_call_depth:
				interpreter.erro_runtime("O limite de chamadas recursivas foi atingido. Confira se o caso-base consegue encerrar a função.")
				pop_frame()
				return

			if delivery_report_id > 0:
				var function_name := str(fn.name)
				for active_frame in call_stack:
					if str(active_frame.get("name", "")) == function_name:
						delivery_recursive_functions[function_name] = true
						break

			var new_frame = {
				"name": fn.name,
				"scope_stack": [],
				"parent": current_env()
			}
			call_stack.append(new_frame)
			push_scope()

			for i in range(fn.params.size()):
				var param_type = fn.params[i][0]
				var param_name = fn.params[i][1]
				var value = args[i] if i < args.size() else null
				new_frame["scope_stack"].back()[param_name] = {
					"type": param_type,
					"value": coerce_value(value, param_type)
				}

			push_frame("block", fn.body)
			frame.index = 3

		3:
			frame.index = 4

		4:
			var result = frame.state.get("return_value")
			call_stack.pop_back()
			deliver_result_to_parent(result)
			frame.state.erase("return_value")
			pop_frame()

func deliver_result_to_parent(value):
	if execution_stack.size() < 2:
		return
	var parent = execution_stack[execution_stack.size() - 2]
	parent.state["value"] = value
	parent.state.erase("waiting_for")

func begin_delivery_report(report_id: int) -> void:
	if delivery_report_id == report_id:
		return
	delivery_report_id = report_id
	delivery_recursive_functions.clear()

func has_delivery_recursion(function_names: Array) -> bool:
	for function_name in function_names:
		if bool(delivery_recursive_functions.get(str(function_name), false)):
			return true
	return false

# ─── Expressões async ──────────────────────────────────────────────────────────

func has_function_call(node) -> bool:
	if node == null:
		return false
	if node.type == "function_call":
		return true
	if node.type == "array_access":
		return has_function_call(node.indexes[0])
	if node.type == "array_literal":
		for element in node.elements:
			if has_function_call(element):
				return true
		return false
	if node.type == "binary":
		return has_function_call(node.left) or has_function_call(node.right)
	return false

func process_expression(frame):
	var node = frame.node
	if node == null:
		interpreter.erro_fatal("O executor recebeu uma expressão vazia.")
		pop_frame()
		return

	match node.type:
		"number":
			deliver_result_to_parent(node.value)
			pop_frame()
		"string":
			deliver_result_to_parent(node.value)
			pop_frame()
		"bool":
			deliver_result_to_parent(node.value)
			pop_frame()
		"array_access":
			var value = get_array_value(node)
			deliver_result_to_parent(value)
			pop_frame()
		"array_literal":
			match frame.index:
				0:
					frame.state["values"] = []
					frame.state["element_index"] = 0
					frame.index = 1
				1:
					var elements = node.elements
					var i = int(frame.state["element_index"])
					if i >= elements.size():
						deliver_result_to_parent(build_array_literal_value(frame.state["values"]))
						pop_frame()
						return
					push_frame("expression", elements[i])
					frame.index = 2
				2:
					frame.state["values"].append(frame.state.get("value"))
					frame.state.erase("value")
					frame.state["element_index"] += 1
					frame.index = 1
		"identifier":
			var value = get_variable(node.name)
			deliver_result_to_parent(value)
			pop_frame()
		"function_call":
			match frame.index:
				0:
					push_frame("function_call", node)
					frame.index = 1
				1:
					deliver_result_to_parent(frame.state.get("value"))
					pop_frame()
		"binary":
			# AND com curto-circuito
			if node.op.type == Token.TiposToken.OP_AND:
				match frame.index:
					0:
						push_frame("expression", node.left)
						frame.index = 1
					1:
						if not frame.state.get("value", false):
							deliver_result_to_parent(false)
							pop_frame()
							return
						push_frame("expression", node.right)
						frame.index = 2
					2:
						deliver_result_to_parent(frame.state.get("value", false))
						pop_frame()
				return
			# OR com curto-circuito
			if node.op.type == Token.TiposToken.OP_OR:
				match frame.index:
					0:
						push_frame("expression", node.left)
						frame.index = 1
					1:
						if frame.state.get("value", false):
							deliver_result_to_parent(true)
							pop_frame()
							return
						push_frame("expression", node.right)
						frame.index = 2
					2:
						deliver_result_to_parent(frame.state.get("value", false))
						pop_frame()
				return
			# Binário genérico
			match frame.index:
				0:
					push_frame("expression", node.left)
					frame.index = 1
				1:
					frame.state["left"] = frame.state.get("value")
					push_frame("expression", node.right)
					frame.index = 2
				2:
					frame.state["right"] = frame.state.get("value")
					var result = apply_op(node.op, frame.state["left"], frame.state["right"])
					deliver_result_to_parent(result)
					pop_frame()
		"unary":
			match frame.index:
				0:
					push_frame("expression", node.operando)
					frame.index = 1
				1:
					var value = frame.state.get("value")
					match node.op.type:
						Token.TiposToken.OP_MINUS:
							deliver_result_to_parent(-value)
						Token.TiposToken.OP_NOT:
							deliver_result_to_parent(not value)
						Token.TiposToken.OP_PLUS_PLUS:
							if node.operando == null or node.operando.type != "identifier":
								interpreter.erro_runtime("'++' precisa de uma variável.")
								deliver_result_to_parent(value)
							else:
								var name = node.operando.name
								var new_val = get_variable(name) + 1
								set_variable(name, new_val)
								deliver_result_to_parent(new_val if node.prefix else new_val - 1)
						Token.TiposToken.OP_MINUS_MINUS:
							if node.operando == null or node.operando.type != "identifier":
								interpreter.erro_runtime("'--' precisa de uma variável.")
								deliver_result_to_parent(value)
							else:
								var name = node.operando.name
								var new_val = get_variable(name) - 1
								set_variable(name, new_val)
								deliver_result_to_parent(new_val if node.prefix else new_val + 1)
					pop_frame()
		_:
			interpreter.erro_runtime("Não sei lidar com essa expressão: " + str(node.type))
			deliver_result_to_parent(null)
			pop_frame()

# ─── Operadores ────────────────────────────────────────────────────────────────

func apply_op(op, left, right) -> Variant:
	if left == null or right == null:
		interpreter.erro_runtime(
			"Tem um valor vazio nessa conta. Alguma variável ficou sem inicializar?"
		)
		return null

	# Coerção automática float
	if typeof(left) == TYPE_FLOAT or typeof(right) == TYPE_FLOAT:
		left = float(left)
		right = float(right)

	match op.type:
		Token.TiposToken.OP_PLUS:         return left + right
		Token.TiposToken.OP_MINUS:        return left - right
		Token.TiposToken.OP_STAR:         return left * right
		Token.TiposToken.OP_SLASH:
			if right == 0:
				interpreter.erro_fatal("Divisão por zero não rola.")
				return null
			return left / right
		Token.TiposToken.OP_MOD:
			if right == 0:
				interpreter.erro_fatal("Módulo por zero não rola.")
				return null
			return int(left) % int(right)
		Token.TiposToken.OP_GREATER:       return left > right
		Token.TiposToken.OP_MINOR:         return left < right
		Token.TiposToken.OP_MINOR_EQUAL:   return left <= right
		Token.TiposToken.OP_GREATER_EQUAL: return left >= right
		Token.TiposToken.OP_EQUAL_EQUAL:   return left == right
		Token.TiposToken.OP_NOT_EQUAL:     return left != right

	interpreter.erro_runtime("Não reconheci o operador: " + str(op))
	return null

func _eval_array_literal_elements(node) -> Array:
	var values := []
	for element in node.elements:
		values.append(eval(element))
	return values

func build_array_literal_value(values: Array) -> Dictionary:
	return {
		"element_type": _infer_array_literal_element_type(values),
		"dimensions": [values.size()],
		"data": values.duplicate()
	}

func _infer_array_literal_element_type(values: Array) -> String:
	for value in values:
		if value is String:
			return "string"
	for value in values:
		if value is float:
			return "float"
	for value in values:
		if value is bool:
			return "bool"
	return "int"

# ─── For ───────────────────────────────────────────────────────────────────────

func process_for(frame):
	match frame.index:
		0:
			if frame.node.init != null:
				push_frame(frame.node.init.type, frame.node.init)
				frame.index = 1
				return
			frame.index = 1
		1:
			if frame.node.condicao != null:
				push_frame("expression", frame.node.condicao)
				frame.index = 2
				return
			frame.state["cond"] = true
			frame.index = 2
		2:
			if frame.node.condicao != null:
				frame.state["cond"] = frame.state.get("value", false)
			if frame.state["cond"]:
				push_frame("block", frame.node.body)
				frame.index = 3
			else:
				pop_frame()
		3:
			if frame.node.incremento != null:
				if frame.node.incremento.type == "assign":
					push_frame("assign", frame.node.incremento)
				else:
					push_frame("expression", frame.node.incremento)
				frame.index = 4
				return
			frame.index = 4
		4:
			frame.index = 1

# ─── Coerção de tipos ──────────────────────────────────────────────────────────

func coerce_value(value, target_type) -> Variant:
	if target_type == null or target_type == "":
		return value
	if target_type == "array_decl" or target_type == "array" or target_type == "function":
		return value
	match target_type:
		"int":
			if value == null:
				return 0
			return int(value)
		"float":
			if value == null:
				return 0.0
			return float(value)
		"string":
			if value == null:
				return ""
			return str(value)
		"bool":
			if value == null:
				return false
			return bool(value)
	interpreter.erro_runtime("Tipo desconhecido: '" + str(target_type) + "'.")
	return value

# ─── Global block ──────────────────────────────────────────────────────────────

func process_global_block(frame):
	var statements = frame.node.statements
	match frame.index:
		0:
			frame.state["i"] = 0
			frame.index = 1
		1:
			if frame.state["i"] >= statements.size():
				pop_frame()
				return
			var stmt = statements[frame.state["i"]]
			frame.state["i"] += 1
			push_frame(stmt.type, stmt)

# ─── Arrays ────────────────────────────────────────────────────────────────────

func process_array_decl(frame):
	match frame.index:
		0:
			var dimensions = []
			for size_node in frame.node.sizes:
				dimensions.append(eval(size_node))

			var total_size = 1
			for d in dimensions:
				if d <= 0:
					interpreter.erro_fatal("Tamanho de array inválido: %d." % d)
					pop_frame()
					return
				total_size *= d

			if total_size > 1000000:
				interpreter.erro_fatal("Esse array ficou grande demais: %d elementos." % total_size)
				pop_frame()
				return

			var data = []
			data.resize(total_size)
			data.fill(0)

			var arr_value = {
				"element_type": frame.node.type_var,
				"dimensions": dimensions,
				"data": data
			}
			declare_variable(frame.node.name, arr_value, "array")
			frame.index = 1
		1:
			pop_frame()

func get_array_value(node) -> Variant:
	var arr_wrapper = get_variable_wrapper(node.array.name)
	if arr_wrapper == null:
		return null
	var arr = arr_wrapper["value"]
	if arr == null or not arr.has("dimensions"):
		interpreter.erro_runtime("A variável '" + node.array.name + "' não é um array.")
		return null

	var indexes = []
	for idx_node in node.indexes:
		indexes.append(eval(idx_node))

	if indexes.size() != arr["dimensions"].size():
		interpreter.erro_runtime(
			"Esse array espera %d índice(s), mas recebeu %d." % [arr["dimensions"].size(), indexes.size()]
		)
		return null

	var offset = compute_offset(indexes, arr["dimensions"])
	if offset < 0 or offset >= arr["data"].size():
		interpreter.erro_fatal(
			"Índice fora do array: %d. O array tem %d elemento(s)." % [offset, arr["data"].size()]
		)
		return null

	return arr["data"][offset]

func compute_offset(indexes, dimensions) -> int:
	var offset = 0
	var stride = 1
	for i in range(dimensions.size() - 1, -1, -1):
		var idx = indexes[i]
		if idx == null:
			interpreter.erro_runtime("O índice na posição %d veio vazio." % i)
			return 0
		offset += int(idx) * stride
		stride *= dimensions[i]
	return offset
