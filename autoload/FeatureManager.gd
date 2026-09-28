extends Node

signal feature_unlocked(feature_id)

const FEATURE_IF := "if"
const FEATURE_CART := "cart"
const FEATURE_DISCOUNT := "discount"
const FEATURE_SENSOR := "sensor"
const FEATURE_STOCK := "stock"
const FEATURE_CHANGE := "change"
const FEATURE_DELIVERY := "delivery"
const INITIAL_FEATURES := [FEATURE_IF, FEATURE_CART, FEATURE_DISCOUNT, FEATURE_SENSOR, FEATURE_STOCK]

var _features := {
	FEATURE_IF: false,
	FEATURE_CART: false,
	FEATURE_DISCOUNT: false,
	FEATURE_SENSOR: false,
	FEATURE_STOCK: false,
	FEATURE_CHANGE: false,
	FEATURE_DELIVERY: false
}

func _ready() -> void:
	_apply_initial_features()

func has_feature(feature_id: String) -> bool:
	return bool(_features.get(feature_id, false))

func unlock_feature(feature_id: String) -> void:
	if not _features.has(feature_id):
		push_warning("Feature inexistente: %s" % feature_id)
		return
	if _features[feature_id]:
		return
	_features[feature_id] = true
	_sync_legacy_game_state(feature_id, true)
	feature_unlocked.emit(feature_id)
	if feature_id == FEATURE_IF:
		unlock_feature(FEATURE_DISCOUNT)

func lock_feature(feature_id: String) -> void:
	if not _features.has(feature_id):
		return
	_features[feature_id] = false
	_sync_legacy_game_state(feature_id, false)

func get_all_features() -> Dictionary:
	return _features.duplicate(true)

func load_legacy_features(features: Dictionary) -> void:
	if features.has("change"):
		_features[FEATURE_CHANGE] = bool(features["change"])
	if features.has("stock"):
		_features[FEATURE_STOCK] = bool(features["stock"])
	if features.has(FEATURE_IF):
		_features[FEATURE_IF] = bool(features[FEATURE_IF])
	if features.has(FEATURE_CART):
		_features[FEATURE_CART] = bool(features[FEATURE_CART])
	if features.has(FEATURE_DISCOUNT):
		_features[FEATURE_DISCOUNT] = bool(features[FEATURE_DISCOUNT])
	if features.has(FEATURE_SENSOR):
		_features[FEATURE_SENSOR] = bool(features[FEATURE_SENSOR])
	if features.has(FEATURE_DELIVERY):
		_features[FEATURE_DELIVERY] = bool(features[FEATURE_DELIVERY])

	if _features[FEATURE_IF]:
		_features[FEATURE_DISCOUNT] = true
	_apply_initial_features()

	for feature_id in _features:
		_sync_legacy_game_state(feature_id, _features[feature_id])

func reset_progression() -> void:
	for feature_id in _features:
		_features[feature_id] = false
		_sync_legacy_game_state(feature_id, false)
	_apply_initial_features()

func _apply_initial_features() -> void:
	for feature_id in INITIAL_FEATURES:
		_features[feature_id] = true
		_sync_legacy_game_state(feature_id, true)

func locked_message(feature_id: String) -> String:
	match feature_id:
		FEATURE_IF:
			return "Você ainda não liberou if()."
		FEATURE_CART:
			return "Você ainda não liberou compras com vários itens."
		FEATURE_DISCOUNT:
			return "Você ainda não liberou a regra de desconto."
		FEATURE_SENSOR:
			return "Você ainda não liberou sensor()."
		FEATURE_STOCK:
			return "Você ainda não abriu o estoque."
		FEATURE_CHANGE:
			return "Você ainda não liberou clientes com troco."
		FEATURE_DELIVERY:
			return "Você ainda não liberou o Delivery Online."
		_:
			return "Ainda falta liberar: %s" % feature_id

func _sync_legacy_game_state(feature_id: String, value: bool) -> void:
	if GameManager == null:
		return
	match feature_id:
		FEATURE_CART:
			GameManager.unlocked_mechanics["cart"] = value
		FEATURE_DISCOUNT:
			GameManager.unlocked_mechanics["discount"] = value
		FEATURE_CHANGE:
			GameManager.unlocked_mechanics["change"] = value
		FEATURE_STOCK:
			GameManager.unlocked_mechanics["stock"] = value
		FEATURE_DELIVERY:
			GameManager.unlocked_mechanics["delivery"] = value
