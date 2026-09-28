extends Node

const ActiveExperienceData = preload("res://data/ActiveExperience.gd")
const GameScene = preload("res://scenes/game/game.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	for item in StockSystem.get_stock():
		item.quantity = maxi(item.quantity, 5)

	FeatureManager.unlock_feature(FeatureManager.FEATURE_CHANGE)
	FeatureManager.unlock_feature(FeatureManager.FEATURE_DELIVERY)
	var challenge := ChallengeSystem.set_context()
	_check(challenge != null, "A experiência ativa deve gerar um desafio quando há estoque.")
	if challenge != null:
		_check(challenge.type == ActiveExperienceData.ACTIVE_CHALLENGE_TYPE, "Somente o desafio de estoque deve ser gerado.")
		_check(challenge.requires_stock, "O desafio ativo deve consumir o estoque reformulado.")
		_check(not challenge.applies_discount, "O modificador legado de desconto não deve aparecer.")
		_check(challenge.payment == 0.0 and challenge.expected_output.size() == 1,
			"O fluxo legado de troco não deve aparecer.")
		_check(not challenge.is_golden, "Cliente especial legado não deve aparecer.")

	UpgradeManager.load_save_data({"comprados": {
		"premium_1": true,
		"marketing_1": true,
		"delivery_online": true,
	}})
	_check(UpgradeManager.get_upgrades_visiveis().is_empty(), "Upgrades antigos não devem aparecer.")
	_check(UpgradeManager.reward_multiplier == 1.0, "Upgrade antigo do save não deve alterar a recompensa ativa.")
	_check(UpgradeManager.get_spawn_delay_range() == Vector2(5.0, 8.0), "Upgrade antigo do save não deve alterar o fluxo ativo.")
	DeliverySystem._process(0.0)
	_check(DeliverySystem.state == DeliverySystem.State.LOCKED,
		"Delivery antigo deve permanecer travado e sem processamento em segundo plano.")

	var game := GameScene.instantiate()
	var shop := game.get_node("ShopMenu") as Control
	var delivery_button := game.get_node("VBoxContainer/Delivery") as Control
	var delivery_panel := game.get_node("HUD/DeliveryPanel") as Control
	var completion := game.get_node("HUD/CompletionOverlay") as Control
	_check(not shop.visible and shop.process_mode == Node.PROCESS_MODE_DISABLED, "A loja antiga deve ficar oculta e inativa.")
	_check(not delivery_button.visible and not delivery_panel.visible, "Delivery antigo não deve aparecer.")
	_check(not completion.visible, "Conclusão antiga não deve aparecer.")
	game.free()

	if _failures.is_empty():
		print("STOCK_ONLY_EXPERIENCE_TEST_OK")
	else:
		push_error("\n".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
