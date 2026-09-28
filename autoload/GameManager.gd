extends Node

const DeliveryConfigData = preload("res://data/DeliveryConfig.gd")

# Contexto atual do interpretador (ChallengeData)
var current_context = null

# Estado financeiro do jogador
var money: int = 180
var diamonds: int = 0
var game_completed := false
var upgrades: Array = []
var secret_menu_unlocked := false

signal diamonds_changed(value)
signal game_completed_changed(completed)

# Mecânicas desbloqueadas (substitui state_of_game)
var unlocked_mechanics = {
	"sum": true,
	"cart": true,
	"discount": true,
	"change": false,
	"stock": true,
	"if": true,
	"sensor": true,
	"delivery": false
}

func get_save_data() -> Dictionary:
	return {
		"dinheiro": money,
		"diamonds": diamonds,
		"game_completed": game_completed,
		"unlocked_mechanics": unlocked_mechanics.duplicate(true),
		"upgrades": upgrades.duplicate(),
		"secret_menu_unlocked": secret_menu_unlocked
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("dinheiro") and (data["dinheiro"] is int or data["dinheiro"] is float):
		money = int(data["dinheiro"])

	diamonds = clampi(int(data.get("diamonds", 0)), 0, DeliveryConfigData.MAX_DIAMONDS)
	game_completed = bool(data.get("game_completed", false))

	if data.has("upgrades") and data["upgrades"] is Array:
		upgrades = data["upgrades"].duplicate()

	secret_menu_unlocked = bool(data.get("secret_menu_unlocked", false))

	if data.has("unlocked_mechanics") and data["unlocked_mechanics"] is Dictionary:
		for key in unlocked_mechanics:
			if data["unlocked_mechanics"].has(key):
				unlocked_mechanics[key] = bool(data["unlocked_mechanics"][key])
		FeatureManager.load_legacy_features(unlocked_mechanics)

func add_diamonds(amount: int, maximum: int = DeliveryConfigData.MAX_DIAMONDS) -> int:
	var previous := diamonds
	diamonds = clampi(diamonds + amount, 0, maxi(0, maximum))
	if diamonds != previous:
		diamonds_changed.emit(diamonds)
	return diamonds - previous

func spend_diamonds(amount: int) -> bool:
	var cost := maxi(0, amount)
	if diamonds < cost:
		return false
	diamonds -= cost
	diamonds_changed.emit(diamonds)
	return true

func complete_game(emit_feedback := true) -> bool:
	if game_completed:
		return false
	game_completed = true
	if emit_feedback:
		game_completed_changed.emit(true)
	return true

func unlock_secret_menu() -> bool:
	if secret_menu_unlocked:
		return false
	secret_menu_unlocked = true
	EventBus.emit_signal("secret_menu_unlocked")
	return true
