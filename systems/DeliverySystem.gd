extends Node

signal report_available(report_id, deliveries)
signal state_changed()
signal declaration_accepted(result)
signal declaration_rejected(message)

enum State {
	LOCKED,
	WAITING_DECLARATION,
	COOLDOWN,
	COMPLETED
}

const Config = preload("res://data/DeliveryConfig.gd")
const DeliveryValidator = preload("res://systems/DeliveryProgramValidator.gd")
const ProgramFacts = preload("res://interpreter/analysis/delivery_program_facts.gd")

var state: State = State.LOCKED
var next_report_id := 1
var active_report_id := 0
var active_deliveries: Array = []
var last_rewarded_report_id := 0
var next_report_unix := 0
var last_result: Dictionary = {}
var last_feedback := ""
var last_feedback_kind := ""

var _last_generated_deliveries: Array = []
var _lease_runtime_id := ""
var _lease_script_id := ""
var _lease_report_id := 0
var _last_rejection_key := ""
var _suppress_unlock_feedback := false


func _ready() -> void:
	FeatureManager.feature_unlocked.connect(_on_feature_unlocked)


func _process(_delta: float) -> void:
	if GameManager.game_completed:
		if state != State.COMPLETED:
			mark_completed(false)
		return
	if not is_unlocked():
		return
	if state == State.LOCKED:
		_activate(false, false)
	elif state == State.COOLDOWN and get_cooldown_remaining() <= 0:
		_generate_report(true, true)


func is_unlocked() -> bool:
	return FeatureManager.has_feature(FeatureManager.FEATURE_DELIVERY)


func unlock(emit_feedback := true) -> void:
	_suppress_unlock_feedback = not emit_feedback
	FeatureManager.unlock_feature(FeatureManager.FEATURE_DELIVERY)
	_suppress_unlock_feedback = false
	_activate(emit_feedback, emit_feedback)


func _on_feature_unlocked(feature_id: String) -> void:
	if feature_id != FeatureManager.FEATURE_DELIVERY:
		return
	_activate(not _suppress_unlock_feedback, not _suppress_unlock_feedback)


func _activate(emit_feedback: bool, persist: bool) -> void:
	if GameManager.game_completed:
		mark_completed(false)
		return
	InterpreterSystem.ensure_delivery_script()
	if state == State.LOCKED:
		if emit_feedback:
			_notify("Delivery Online desbloqueado!\nA plataforma de entregas já está disponível.")
		_generate_report(emit_feedback, persist)
	else:
		state_changed.emit()


func request_deliveries(runtime_id: String, script_id: String) -> Dictionary:
	var context_error := _validate_runtime_context(runtime_id, script_id)
	if not context_error.is_empty():
		return _failure(context_error, true)
	if GameManager.game_completed or state == State.COMPLETED:
		return _failure("O jogo já foi concluído. O Delivery não gera novos relatórios.", true)
	if not is_unlocked():
		return _failure("Você ainda não liberou o Delivery Online.", true)
	if state == State.COOLDOWN:
		var remaining := get_cooldown_remaining()
		if remaining > 0:
			return _failure("Ainda não há relatório disponível. Aguarde %ds." % remaining, true)
		_generate_report(true, true)
	if state != State.WAITING_DECLARATION or active_report_id <= 0 or not _is_valid_deliveries(active_deliveries):
		return _failure("Ainda não há relatório para declarar.", true)

	if _lease_runtime_id != runtime_id:
		if not _lease_runtime_id.is_empty() and _is_runtime_active(_lease_runtime_id):
			return _failure("Este relatório já está sendo processado por outro script do Delivery.", true)
		_lease_runtime_id = runtime_id
		_lease_script_id = script_id
		_lease_report_id = active_report_id
		_last_rejection_key = ""

	return {
		"success": true,
		"report_id": active_report_id,
		"deliveries": active_deliveries.duplicate()
	}


func submit_declaration(values: Array, runtime_id: String, script_id: String,
		report_id: int, program_facts, runtime_recursion_ok: bool) -> Dictionary:
	var context_error := _validate_runtime_context(runtime_id, script_id)
	if not context_error.is_empty():
		return _failure(context_error, true)
	if GameManager.game_completed or state == State.COMPLETED:
		return _failure("O jogo já foi concluído. O Delivery não gera novos relatórios.", true)
	if state == State.COOLDOWN or active_report_id <= last_rewarded_report_id:
		return _failure("Este relatório já foi aprovado. Aguarde o próximo.", true)
	if state != State.WAITING_DECLARATION or active_report_id <= 0:
		return _failure("Ainda não há relatório para declarar.", true)
	if report_id != active_report_id or _lease_report_id != active_report_id:
		return _failure("Esta execução do Delivery não está mais ativa. Rode o script novamente.", true)
	if runtime_id != _lease_runtime_id or script_id != _lease_script_id:
		return _failure("Esta execução do Delivery não está mais ativa. Rode o script novamente.", true)
	if values.size() != Config.REPORT_SIZE:
		return _reject("declare_profit() precisa receber exatamente 3 lucros inteiros.", runtime_id, active_report_id, "invalid_size")
	for value in values:
		if not (value is int or value is float) or float(value) != float(int(value)):
			return _reject("declare_profit() aceita apenas lucros inteiros.", runtime_id, active_report_id, "invalid_type")

	var expected := calculate_profits(active_deliveries)
	for index in range(Config.REPORT_SIZE):
		if int(values[index]) != int(expected[index]):
			var category := str(Config.CATEGORY_NAMES[index])
			return _reject(
				"Declaração rejeitada. O lucro das entregas %s não corresponde ao relatório." % category,
				runtime_id,
				active_report_id,
				"category_%d" % index
			)

	if not program_facts is ProgramFacts:
		var missing := _failure(
			"Não consegui acessar os fatos do programa desta execução.", true
		)
		missing["code"] = "AUTOMARKET_PROGRAM_FACTS_UNAVAILABLE"
		return missing
	var program_validation := DeliveryValidator.validate(program_facts)
	if not bool(program_validation.get("valid", false)):
		var errors: Array = program_validation.get("errors", [])
		var message := "O programa ainda não atende aos requisitos do Delivery."
		if not errors.is_empty():
			message = str(errors[0])
		return _reject(message, runtime_id, active_report_id, "pedagogy_" + message)
	if not runtime_recursion_ok:
		return _reject(
			"A função recursiva existe, mas não foi usada no cálculo deste relatório.",
			runtime_id,
			active_report_id,
			"runtime_recursion"
		)

	var rewarded_report_id := active_report_id
	var rewarded_deliveries := active_deliveries.duplicate()
	var profits := expected.duplicate()
	var total := 0
	for value in profits:
		total += int(value)

	last_rewarded_report_id = rewarded_report_id
	state = State.COOLDOWN
	active_report_id = 0
	active_deliveries.clear()
	next_report_unix = int(Time.get_unix_time_from_system()) + Config.REPORT_COOLDOWN_SECONDS
	_clear_lease()
	last_feedback_kind = "accepted"
	last_feedback = "Declaração aprovada"

	var diamonds_before := GameManager.diamonds
	GameManager.add_diamonds(Config.DIAMONDS_PER_APPROVAL, Config.MAX_DIAMONDS)
	var diamonds_awarded := GameManager.diamonds - diamonds_before
	last_result = {
		"report_id": rewarded_report_id,
		"deliveries": rewarded_deliveries,
		"profits": profits,
		"total": total,
		"diamond_awarded": diamonds_awarded,
		"approved": true
	}

	# O relatório é fechado antes do crédito para qualquer save disparado pelo HUD
	# já conter a marca anti-duplicação e os diamantes.
	EventBus.emit_signal("update_money", total)
	Saves.solicitar_save("delivery_aprovado")
	state_changed.emit()
	declaration_accepted.emit(last_result.duplicate(true))

	var notification_text := "Declaração aprovada!\n+%d moedas no caixa" % total
	if diamonds_awarded > 0:
		notification_text += "\n+%d diamante" % diamonds_awarded
	else:
		notification_text += "\nDiamantes no máximo"
	_notify(notification_text)
	if diamonds_before < Config.MAX_DIAMONDS and GameManager.diamonds >= Config.MAX_DIAMONDS:
		_notify("Você juntou 5 diamantes!\nO upgrade Zerar já pode ser comprado.")

	return {
		"success": true,
		"fatal": false,
		"result": last_result.duplicate(true),
		"message": _format_approved_output(last_result)
	}


func calculate_profit(quantity: int, base_value: int) -> int:
	var profit := 0
	for _index in range(clampi(quantity, Config.MIN_DELIVERIES, Config.MAX_DELIVERIES)):
		profit = Config.PROFIT_MULTIPLIER * profit + base_value
	return profit


func calculate_profits(deliveries: Array) -> Array:
	var profits := []
	for index in range(Config.REPORT_SIZE):
		profits.append(calculate_profit(int(deliveries[index]), int(Config.BASE_VALUES[index])))
	return profits


func get_cooldown_remaining() -> int:
	return maxi(0, int(ceil(float(next_report_unix) - Time.get_unix_time_from_system())))


func get_view_data() -> Dictionary:
	return {
		"state": int(state),
		"unlocked": is_unlocked(),
		"active_report_id": active_report_id,
		"deliveries": active_deliveries.duplicate(),
		"cooldown_remaining": get_cooldown_remaining(),
		"last_result": last_result.duplicate(true),
		"last_feedback": last_feedback,
		"last_feedback_kind": last_feedback_kind
	}


func mark_completed(persist := true) -> void:
	state = State.COMPLETED
	active_report_id = 0
	active_deliveries.clear()
	next_report_unix = 0
	last_feedback_kind = "completed"
	last_feedback = "Jogo concluído"
	_clear_lease()
	state_changed.emit()
	if persist:
		Saves.solicitar_save("delivery_concluido")


func debug_set_report(deliveries: Array) -> bool:
	if not is_unlocked() or not _is_valid_deliveries(deliveries):
		return false
	active_report_id = next_report_id
	next_report_id += 1
	active_deliveries = _sanitize_deliveries(deliveries)
	_last_generated_deliveries = active_deliveries.duplicate()
	state = State.WAITING_DECLARATION
	next_report_unix = 0
	last_feedback = ""
	last_feedback_kind = ""
	_clear_lease()
	state_changed.emit()
	report_available.emit(active_report_id, active_deliveries.duplicate())
	return true


func debug_make_report_ready() -> bool:
	if not is_unlocked() or GameManager.game_completed:
		return false
	_generate_report(false, false)
	return true


func get_save_data() -> Dictionary:
	return {
		"state": int(state),
		"next_report_id": next_report_id,
		"active_report_id": active_report_id,
		"active_deliveries": active_deliveries.duplicate(),
		"last_rewarded_report_id": last_rewarded_report_id,
		"next_report_unix": next_report_unix,
		"last_result": last_result.duplicate(true),
		"last_generated_deliveries": _last_generated_deliveries.duplicate()
	}


func load_save_data(data: Dictionary) -> void:
	state = State.LOCKED
	next_report_id = 1
	active_report_id = 0
	active_deliveries.clear()
	last_rewarded_report_id = 0
	next_report_unix = 0
	last_result.clear()
	last_feedback = ""
	last_feedback_kind = ""
	_last_generated_deliveries.clear()
	_clear_lease()

	last_rewarded_report_id = maxi(0, int(data.get("last_rewarded_report_id", 0)))
	next_report_id = maxi(last_rewarded_report_id + 1, int(data.get("next_report_id", 1)))
	next_report_unix = maxi(0, int(data.get("next_report_unix", 0)))
	if data.get("last_result") is Dictionary:
		last_result = data["last_result"].duplicate(true)
	if data.get("last_generated_deliveries") is Array and _is_valid_deliveries(data["last_generated_deliveries"]):
		_last_generated_deliveries = _sanitize_deliveries(data["last_generated_deliveries"])

	var loaded_state := int(data.get("state", State.LOCKED))
	if loaded_state == State.COMPLETED or GameManager.game_completed:
		state = State.COMPLETED
		return
	if loaded_state == State.WAITING_DECLARATION:
		var loaded_report_id := maxi(0, int(data.get("active_report_id", 0)))
		var loaded_deliveries = data.get("active_deliveries", [])
		if loaded_report_id > last_rewarded_report_id and loaded_deliveries is Array and _is_valid_deliveries(loaded_deliveries):
			state = State.WAITING_DECLARATION
			active_report_id = loaded_report_id
			active_deliveries = _sanitize_deliveries(loaded_deliveries)
			next_report_id = maxi(next_report_id, active_report_id + 1)
			return
	if loaded_state == State.COOLDOWN:
		state = State.COOLDOWN
	else:
		state = State.LOCKED


func _generate_report(emit_feedback: bool, persist: bool) -> void:
	if not is_unlocked() or GameManager.game_completed:
		return
	var candidate := []
	for attempt in range(16):
		candidate = []
		for _index in range(Config.REPORT_SIZE):
			candidate.append(randi_range(Config.MIN_DELIVERIES, Config.MAX_DELIVERIES))
		if next_report_id % 3 == 0:
			candidate[randi_range(0, Config.REPORT_SIZE - 1)] = 0
		if _all_values_equal(candidate) or _arrays_equal(candidate, _last_generated_deliveries):
			continue
		break
	if candidate.is_empty() or _all_values_equal(candidate):
		candidate = [0, 1, randi_range(2, Config.MAX_DELIVERIES)]

	active_report_id = next_report_id
	next_report_id += 1
	active_deliveries = candidate.duplicate()
	_last_generated_deliveries = candidate.duplicate()
	state = State.WAITING_DECLARATION
	next_report_unix = 0
	last_feedback = ""
	last_feedback_kind = ""
	_clear_lease()
	state_changed.emit()
	report_available.emit(active_report_id, active_deliveries.duplicate())
	if emit_feedback:
		_notify("Novo relatório de entregas disponível.")
	if persist:
		Saves.solicitar_save("delivery_novo_relatorio")


func _validate_runtime_context(runtime_id: String, script_id: String) -> String:
	if runtime_id.is_empty() or not _is_runtime_active(runtime_id):
		return "Esta execução do Delivery não está mais ativa. Rode o script novamente."
	var delivery_script_id := InterpreterSystem.get_delivery_script_id()
	if delivery_script_id.is_empty() or script_id != delivery_script_id:
		return "Use as funções do Delivery na aba Delivery."
	return ""


func _is_runtime_active(runtime_id: String) -> bool:
	var runtime := InterpreterSystem.runtime_manager.get_runtime(runtime_id)
	if runtime.is_empty():
		return false
	var status := str(runtime.get("status", ""))
	return status in [
		ScriptRuntimeManager.STATUS_RUNNING,
		ScriptRuntimeManager.STATUS_SLEEPING,
		ScriptRuntimeManager.STATUS_WAITING_INPUT
	]


func _reject(message: String, runtime_id: String, report_id: int, reason: String) -> Dictionary:
	var rejection_key := "%s:%d:%s" % [runtime_id, report_id, reason]
	var should_emit := rejection_key != _last_rejection_key
	_last_rejection_key = rejection_key
	last_feedback = message
	last_feedback_kind = "rejected"
	if should_emit:
		state_changed.emit()
		declaration_rejected.emit(message)
		_notify(message)
	return {
		"success": false,
		"fatal": false,
		"message": message,
		"emit_feedback": should_emit
	}


func _failure(message: String, fatal: bool) -> Dictionary:
	return {
		"success": false,
		"fatal": fatal,
		"message": message,
		"emit_feedback": true
	}


func _format_approved_output(result: Dictionary) -> String:
	var profits: Array = result.get("profits", [0, 0, 0])
	return "Declaração aprovada\nNormal: +%d moedas\nExpressa: +%d moedas\nVIP: +%d moedas\nLucro total: +%d moedas\nDiamantes: +%d" % [
		int(profits[0]),
		int(profits[1]),
		int(profits[2]),
		int(result.get("total", 0)),
		int(result.get("diamond_awarded", 0))
	]


func _clear_lease() -> void:
	_lease_runtime_id = ""
	_lease_script_id = ""
	_lease_report_id = 0
	_last_rejection_key = ""


func _notify(message: String) -> void:
	EventBus.emit_signal("player_notification", message)


func _is_valid_deliveries(values: Array) -> bool:
	if values.size() != Config.REPORT_SIZE:
		return false
	var has_positive := false
	for value in values:
		if not (value is int or value is float):
			return false
		if float(value) != float(int(value)):
			return false
		if int(value) < Config.MIN_DELIVERIES or int(value) > Config.MAX_DELIVERIES:
			return false
		has_positive = has_positive or int(value) > 0
	return has_positive


func _sanitize_deliveries(values: Array) -> Array:
	var sanitized := []
	for value in values:
		sanitized.append(clampi(int(value), Config.MIN_DELIVERIES, Config.MAX_DELIVERIES))
	return sanitized


func _all_values_equal(values: Array) -> bool:
	if values.is_empty():
		return true
	for value in values:
		if int(value) != int(values[0]):
			return false
	return true


func _arrays_equal(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if int(left[index]) != int(right[index]):
			return false
	return true
