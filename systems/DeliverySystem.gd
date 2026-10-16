extends Node

signal state_changed()
signal report_available(report_id, deliveries)
signal declaration_accepted(result)
signal declaration_rejected(message)
signal delivery_completed(result)

# Legacy ordinals remain valid in old saves.
enum State { LOCKED, WAITING_DECLARATION, COOLDOWN, COMPLETED, MOVING }
const Config = preload("res://data/DeliveryConfig.gd")
const Generator = preload("res://systems/DeliveryMapGenerator.gd")
const Validator = preload("res://systems/DeliveryRouteValidator.gd")

var state: State = State.LOCKED
var next_report_id := 1
var active_report_id := 0
var last_rewarded_report_id := 0
var completed_deliveries := 0
var last_result: Dictionary = {}
var last_feedback := ""
var last_feedback_kind := ""
var cooldown_seconds := Config.COOLDOWN_SECONDS
var cells_per_second := Config.CELLS_PER_SECOND
var _cooldown := 0.0
var _map: Dictionary = {}
var _history: Array = []
var _previous_destination: Array = []
var _route: Array = []
var _route_progress := 0.0
var _driver := Vector2.ZERO
var _suppress_unlock_feedback := false

func _ready() -> void:
	FeatureManager.feature_unlocked.connect(_on_feature_unlocked)

func _process(delta: float) -> void:
	if not is_unlocked():
		return
	if state == State.LOCKED:
		_generate_report(false, false)
	elif state == State.MOVING:
		advance_driver(delta)
	elif state == State.COOLDOWN:
		_cooldown = maxf(0.0, _cooldown - delta)
		if _cooldown <= 0.0:
			_generate_report(true, true)

func is_unlocked() -> bool:
	return FeatureManager.has_feature(FeatureManager.FEATURE_DELIVERY)

func unlock(emit_feedback := true) -> void:
	_suppress_unlock_feedback = not emit_feedback
	FeatureManager.unlock_feature(FeatureManager.FEATURE_DELIVERY)
	_suppress_unlock_feedback = false
	InterpreterSystem.ensure_delivery_script()
	if state == State.LOCKED:
		_generate_report(emit_feedback, emit_feedback)

func _on_feature_unlocked(feature_id: String) -> void:
	if feature_id == FeatureManager.FEATURE_DELIVERY:
		InterpreterSystem.ensure_delivery_script()
		if state == State.LOCKED:
			_generate_report(not _suppress_unlock_feedback, not _suppress_unlock_feedback)

func current_delivery() -> Variant:
	if not is_unlocked() or state != State.WAITING_DECLARATION:
		return null
	return {"id": active_report_id, "origem": _map.origin.duplicate(), "destino": _map.destination.duplicate()}

func current_matrix() -> Array:
	if current_delivery() == null:
		return []
	return _map.matrix.duplicate(true)

func submit_route(route: Variant, delivery_id: int) -> Dictionary:
	var error := ""
	if not is_unlocked():
		error = "Você ainda não liberou o Delivery Online."
	elif state == State.MOVING:
		error = "O motoqueiro já está em andamento. Aguarde a chegada."
	elif state != State.WAITING_DECLARATION:
		error = "Não existe entrega pendente. Aguarde a próxima com wait(1)."
	elif delivery_id != active_report_id:
		error = "Esta rota pertence a outra entrega. Leia entrega_atual() e mapa_entrega() novamente."
	else:
		error = Validator.validate(route, _map.matrix, _map.origin, _map.destination)
	if not error.is_empty():
		last_feedback = error
		last_feedback_kind = "rejected"
		state_changed.emit()
		declaration_rejected.emit(error)
		return {"success": false, "message": error}
	_route = route.duplicate(true)
	_route_progress = 0.0
	state = State.MOVING
	last_feedback = "Rota aceita. Motoqueiro a caminho!"
	last_feedback_kind = "accepted"
	state_changed.emit()
	return {"success": true, "message": last_feedback}

# Gameplay movement in matrix coordinates; the renderer only observes it.
func advance_driver(delta: float) -> void:
	if state != State.MOVING or _route.is_empty():
		return
	_route_progress = minf(float(_route.size() - 1), _route_progress + maxf(delta, 0.0) * maxf(0.1, cells_per_second))
	var index := int(floor(_route_progress))
	var next := mini(index + 1, _route.size() - 1)
	_driver = Vector2(_route[index][0], _route[index][1]).lerp(Vector2(_route[next][0], _route[next][1]), _route_progress - index)
	if index == _route.size() - 1:
		_finish_delivery()

func _finish_delivery() -> void:
	if state != State.MOVING or active_report_id <= last_rewarded_report_id:
		return
	last_rewarded_report_id = active_report_id
	completed_deliveries += 1
	state = State.COOLDOWN
	_cooldown = maxf(0.0, cooldown_seconds)
	last_result = {"id": active_report_id, "reward": Config.REWARD, "completed": completed_deliveries}
	active_report_id = 0
	last_feedback = "Entrega concluída! +%d moedas." % Config.REWARD
	last_feedback_kind = "completed"
	# Close before money/save signals, which can be reentrant.
	ChallengeSystem.record_delivery(completed_deliveries)
	EventBus.emit_signal("update_money", Config.REWARD)
	Saves.solicitar_save("delivery_chegada")
	state_changed.emit()
	delivery_completed.emit(last_result.duplicate(true))
	declaration_accepted.emit(last_result.duplicate(true))

func _generate_report(emit_feedback: bool, persist: bool, seed_value := -1) -> void:
	if not is_unlocked() or state in [State.MOVING, State.WAITING_DECLARATION]:
		return
	var seed_number: int = randi() if seed_value < 0 else seed_value
	_map = Generator.generate(seed_number, Config.INTERSECTIONS, Config.MIN_DISTANCE, Config.MIN_ROUTE_MOVES,
		Config.MIN_DEAD_ENDS, Config.MAX_GENERATION_ATTEMPTS, _history, _previous_destination)
	_history.append(_map.fingerprint)
	if _history.size() > 32:
		_history.pop_front()
	_previous_destination = _map.destination.duplicate()
	active_report_id = next_report_id
	next_report_id += 1
	state = State.WAITING_DECLARATION
	_driver = Vector2.ZERO
	_route.clear()
	_route_progress = 0.0
	last_feedback = "Programe uma rota até o destino amarelo. Consulte a ajuda Delivery."
	last_feedback_kind = ""
	InterpreterSystem.ensure_delivery_script()
	state_changed.emit()
	report_available.emit(active_report_id, [])
	if emit_feedback:
		EventBus.emit_signal("player_notification", "Nova entrega disponível! Use mapa_entrega() e entrega_atual().")
	if persist:
		Saves.solicitar_save("delivery_novo_mapa")

func get_cooldown_remaining() -> int:
	return int(ceil(_cooldown))

func get_view_data() -> Dictionary:
	return {"state": state, "unlocked": is_unlocked(), "map": _map.duplicate(true),
		"route": _route.duplicate(true), "driver": _driver, "completed": completed_deliveries,
		"challenge_completed": completed_deliveries >= Config.REQUIRED_DELIVERIES,
		"reward": Config.REWARD, "cooldown_remaining": get_cooldown_remaining(),
		"last_feedback": last_feedback, "last_feedback_kind": last_feedback_kind, "last_result": last_result.duplicate(true)}

func get_save_data() -> Dictionary:
	return {"schema_version": 2, "state": int(state), "next_report_id": next_report_id,
		"active_report_id": active_report_id, "last_rewarded_report_id": last_rewarded_report_id,
		"completed_deliveries": completed_deliveries, "cooldown": _cooldown,
		"map": _map.duplicate(true), "history": _history.duplicate(), "last_result": last_result.duplicate(true)}

func load_save_data(data: Dictionary) -> void:
	state = State.LOCKED
	_map.clear()
	_route.clear()
	_route_progress = 0.0
	_driver = Vector2.ZERO
	last_feedback = ""
	last_feedback_kind = ""
	_history = []
	_previous_destination = []
	completed_deliveries = maxi(0, int(data.get("completed_deliveries", 0)))
	last_rewarded_report_id = maxi(0, int(data.get("last_rewarded_report_id", 0)))
	next_report_id = maxi(last_rewarded_report_id + 1, int(data.get("next_report_id", 1)))
	active_report_id = 0
	last_result = data.get("last_result", {}).duplicate(true) if data.get("last_result") is Dictionary else {}
	_cooldown = clampf(float(data.get("cooldown", 0.0)), 0.0, Config.COOLDOWN_SECONDS)
	if int(data.get("schema_version", 0)) == 2:
		if data.get("history") is Array:
			for item in data.history.slice(0, 32):
				if item is String:
					_history.append(item)
		var raw_map: Variant = data.get("map", {})
		if _valid_saved_map(raw_map):
			_map = raw_map.duplicate(true)
			_previous_destination = _map.destination.duplicate()
			var job_id := int(data.get("active_report_id", 0))
			if int(data.get("state", 0)) in [State.WAITING_DECLARATION, State.MOVING] and job_id > last_rewarded_report_id:
				active_report_id = job_id
				next_report_id = maxi(next_report_id, job_id + 1)
				# Interrupted travel restarts pending, with the same map and no credit.
				state = State.WAITING_DECLARATION
		if state == State.LOCKED and int(data.get("state", 0)) == State.COOLDOWN:
			state = State.COOLDOWN
	state_changed.emit()

func _valid_saved_map(value: Variant) -> bool:
	if not value is Dictionary or not value.get("matrix") is Array:
		return false
	if not value.get("origin") is Array or value.origin.size() != 2:
		return false
	for item in value.origin:
		if not (item is int or item is float) or item != 0:
			return false
	value.origin = [0, 0]
	var matrix: Array = value.matrix
	var side := matrix.size()
	if side < 3 or side > 29 or side % 2 == 0 or not value.get("destination") is Array:
		return false
	var open_segments := 0
	var walkable := 0
	for row in range(side):
		if not matrix[row] is Array or matrix[row].size() != side:
			return false
		for col in range(side):
			var cell: Variant = matrix[row][col]
			if not (cell is int or cell is float) or float(cell) != float(int(cell)) or int(cell) < 0 or int(cell) > 2:
				return false
			if row % 2 == 1 and col % 2 == 1:
				if cell != 0:
					return false
			elif row % 2 == 0 and col % 2 == 0:
				if cell != 1:
					return false
			elif cell == 1:
				open_segments += 1
			elif cell != 2:
				return false
			matrix[row][col] = int(cell)
			if cell == 1:
				walkable += 1
	var intersections := int((side + 1) * 0.5)
	if open_segments != int(intersections * intersections) - 1:
		return false
	var visited := {Vector2i.ZERO: true}
	var queue := [Vector2i.ZERO]
	var cursor := 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		for direction in Generator.DIRECTIONS:
			var next: Vector2i = current + direction
			if next.x >= 0 and next.y >= 0 and next.x < side and next.y < side and matrix[next.x][next.y] == 1 and not visited.has(next):
				visited[next] = true
				queue.append(next)
	var destination: Array = value.destination
	if destination.size() != 2:
		return false
	for index in range(2):
		if not (destination[index] is int or destination[index] is float) or float(destination[index]) != float(int(destination[index])):
			return false
		destination[index] = int(destination[index])
	return visited.size() == walkable and destination != [0, 0] and destination[0] % 2 == 0 and destination[1] % 2 == 0 and visited.has(Vector2i(destination[0], destination[1]))

# Old scripts receive guidance and can never pay out.
func request_deliveries(_runtime_id: String, _script_id: String) -> Dictionary:
	return {"success": false, "message": "O Delivery mudou: use entrega_atual(), mapa_entrega() e enviar_rota(rota)."}

func submit_declaration(_values: Array, _runtime_id: String, _script_id: String,
		_report_id: int, _facts, _recursion: bool) -> Dictionary:
	return {"success": false, "fatal": true, "message": "declare_profit() foi aposentada. Use enviar_rota(rota)."}

func mark_completed(_persist := true) -> void:
	pass # Automation continues after the initial objective.

func debug_make_report_ready() -> bool:
	if not is_unlocked() or state in [State.MOVING, State.WAITING_DECLARATION]:
		return false
	_generate_report(false, false)
	return true
