extends Node

const UpgradeData = preload("res://data/UpgradeData.gd")
const ActiveExperienceData = preload("res://data/ActiveExperience.gd")

signal upgrade_liberado(id, data)
signal upgrade_comprado(id)
signal upgrade_aplicado(id)
signal upgrades_atualizados()

var upgrades_liberados = []
var upgrades_comprados = {}
var reward_multiplier := 1.0
var spawn_delay_min := 5.0
var spawn_delay_max := 8.0

const CURRENCY_MONEY := "money"
const CURRENCY_DIAMONDS := "diamonds"

func _ready() -> void:
	verificar_desbloqueios()

func verificar_desbloqueios() -> void:
	for id in UpgradeData.UPGRADES:
		if not ActiveExperienceData.is_upgrade_active(str(id)):
			continue
		var data = UpgradeData.UPGRADES[id]
		if bool(data.get("retired", false)):
			continue
		var requisitos = data.get("requer", [])

		if _requisitos_comprados(requisitos) and not upgrades_liberados.has(id):
			upgrades_liberados.append(id)
			upgrade_liberado.emit(id, data)
	upgrades_atualizados.emit()

func _requisitos_comprados(requisitos: Array) -> bool:
	for requisito in requisitos:
		if not upgrades_comprados.has(str(requisito)):
			return false
	return true

func get_upgrades_visiveis() -> Array:
	var upgrades_visiveis = []

	for id in upgrades_liberados:
		if not ActiveExperienceData.is_upgrade_active(str(id)):
			continue
		if not UpgradeData.UPGRADES.has(id):
			continue
		if upgrades_comprados.has(id):
			continue

		upgrades_visiveis.append({
			"id": id,
			"data": UpgradeData.UPGRADES[id],
			"comprado": upgrades_comprados.has(id)
		})

	return upgrades_visiveis

func has_upgrade(id: String) -> bool:
	return upgrades_comprados.has(id)

func can_buy(id: String) -> bool:
	if not ActiveExperienceData.is_upgrade_active(id):
		return false
	if not UpgradeData.UPGRADES.has(id):
		return false
	if not upgrades_liberados.has(id) or upgrades_comprados.has(id):
		return false
	if id == "zerar" and GameManager.game_completed:
		return false
	return get_currency_balance(get_upgrade_currency(id)) >= _required_balance(id)

func _required_balance(id: String) -> int:
	var data: Dictionary = UpgradeData.UPGRADES[id]
	return maxi(int(data.get("preco", 0)), int(data.get("saldo_minimo_compra", 0)))

func get_upgrade_currency(id: String) -> String:
	if not UpgradeData.UPGRADES.has(id):
		return CURRENCY_MONEY
	return str(UpgradeData.UPGRADES[id].get("currency", CURRENCY_MONEY))

func get_currency_balance(currency: String) -> int:
	if currency == CURRENCY_DIAMONDS:
		return GameManager.diamonds
	return GameManager.money

func format_price(id: String) -> String:
	if not UpgradeData.UPGRADES.has(id):
		return "0"
	var price := int(UpgradeData.UPGRADES[id].get("preco", 0))
	if get_upgrade_currency(id) == CURRENCY_DIAMONDS:
		return "%d diamantes" % price
	return "R$ %d" % price

func get_missing_currency_text(id: String) -> String:
	if not UpgradeData.UPGRADES.has(id):
		return "indisponível"
	var currency := get_upgrade_currency(id)
	var price := int(UpgradeData.UPGRADES[id].get("preco", 0))
	var required := _required_balance(id)
	var missing := maxi(0, required - get_currency_balance(currency))
	if missing <= 0:
		return "dá para comprar"
	if currency == CURRENCY_DIAMONDS:
		return "faltam %d diamantes" % missing
	if required > price:
		return "junte R$ %d para comprar e manter reserva de estoque" % required
	return "falta grana"

func comprar_upgrade(id: String) -> void:
	if not ActiveExperienceData.is_upgrade_active(id):
		push_warning("Upgrade fora da experiência ativa: %s" % id)
		return
	if not UpgradeData.UPGRADES.has(id):
		push_warning("Upgrade inexistente: %s" % id)
		return

	if not upgrades_liberados.has(id):
		push_warning("Upgrade ainda nao liberado: %s" % id)
		return

	if upgrades_comprados.has(id):
		return
	
	var preco = int(UpgradeData.UPGRADES[id].get("preco", 0))
	var currency := get_upgrade_currency(id)
	if get_currency_balance(currency) < _required_balance(id):
		push_warning("Moeda insuficiente para comprar: %s" % id)
		return

	upgrades_comprados[id] = true
	if not GameManager.upgrades.has(id):
		GameManager.upgrades.append(id)
	if currency == CURRENCY_DIAMONDS and not GameManager.spend_diamonds(preco):
		upgrades_comprados.erase(id)
		GameManager.upgrades.erase(id)
		return
	print("Upgrade comprado: ", id)
	aplicar_upgrade(id, true)
	if currency == CURRENCY_MONEY:
		EventBus.emit_signal("update_money", -preco)
	upgrade_comprado.emit(id)
	verificar_desbloqueios()
	Saves.solicitar_save("upgrade_%s" % id)

func aplicar_upgrade(id: String, emit_feedback := true) -> void:
	if not UpgradeData.UPGRADES.has(id):
		return
	print("Aplicando upgrade: ", id)
	var efeito = UpgradeData.UPGRADES[id].get("efeito", {})
	match efeito.get("tipo", ""):
		"unlock_feature":
			FeatureManager.unlock_feature(str(efeito.get("feature", "")))
		"reward_multiplier":
			reward_multiplier += float(efeito.get("valor", 0.0))
		"spawn_delay":
			spawn_delay_min = float(efeito.get("min", spawn_delay_min))
			spawn_delay_max = float(efeito.get("max", spawn_delay_max))
		"unlock_delivery":
			DeliverySystem.unlock(emit_feedback)
		"complete_game":
			GameManager.complete_game(emit_feedback)
			DeliverySystem.mark_completed(false)
			if emit_feedback:
				EventBus.emit_signal("player_notification", "Jogo concluído!\nSua loja chegou ao nível máximo de automação.")
	if emit_feedback and UpgradeData.UPGRADES[id].has("notification"):
		EventBus.emit_signal("player_notification", str(UpgradeData.UPGRADES[id]["notification"]))
	upgrade_aplicado.emit(id)

func calcular_recompensa(valor_base: int) -> int:
	return max(1, int(round(valor_base * reward_multiplier)))

func get_spawn_delay_range() -> Vector2:
	return Vector2(spawn_delay_min, spawn_delay_max)

func get_save_data() -> Dictionary:
	return {
		"comprados": upgrades_comprados.duplicate(true)
	}

func load_save_data(data: Dictionary) -> void:
	upgrades_comprados.clear()
	upgrades_liberados.clear()
	reward_multiplier = 1.0
	spawn_delay_min = 5.0
	spawn_delay_max = 8.0
	FeatureManager.reset_progression()

	if not data.has("comprados"):
		verificar_desbloqueios()
		return

	var comprados = data["comprados"]
	if comprados is Dictionary:
		for id in comprados:
			if bool(comprados[id]):
				upgrades_comprados[id] = true
	elif comprados is Array:
		for id in comprados:
			upgrades_comprados[str(id)] = true

	for id in upgrades_comprados:
		if ActiveExperienceData.is_upgrade_active(str(id)):
			aplicar_upgrade(id, false)

	verificar_desbloqueios()
