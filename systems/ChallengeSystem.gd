extends Node

signal integrated_challenge_progress(progress: Dictionary)
signal integrated_challenge_completed(progress: Dictionary)

const ProductCatalogData = preload("res://data/ProductCatalog.gd")
const PromotionCatalogData = preload("res://data/PromotionCatalog.gd")
const INTEGRATED_CHALLENGE_ID := "mercado_automatizado"
const REQUIRED_VALID_SALES := 3
const RECOVERY_WINDOW_SALES := 2

var integrated_progress := {
	"id": INTEGRATED_CHALLENGE_ID,
	"completed": false,
	"valid_sales": 0,
	"script_purchases": 0,
	"recoveries": 0
}
var _pending_recovery_codes := {}

func _ready() -> void:
	if not TransactionManager.sale_completed.is_connected(_on_integrated_sale_completed):
		TransactionManager.sale_completed.connect(_on_integrated_sale_completed)
	if not StockSystem.stock_purchase_completed.is_connected(_on_stock_purchase_completed):
		StockSystem.stock_purchase_completed.connect(_on_stock_purchase_completed)

func get_integrated_challenge_status() -> Dictionary:
	var result := integrated_progress.duplicate(true)
	result["title"] = "Mercado Automatizado"
	result["required_valid_sales"] = REQUIRED_VALID_SALES
	result["pending_recovery_codes"] = _pending_recovery_codes.keys()
	return result

func get_save_data() -> Dictionary:
	return integrated_progress.duplicate(true)

func load_save_data(data: Dictionary) -> void:
	integrated_progress = {
		"id": INTEGRATED_CHALLENGE_ID,
		"completed": bool(data.get("completed", false)),
		"valid_sales": maxi(0, int(data.get("valid_sales", 0))),
		"script_purchases": maxi(0, int(data.get("script_purchases", 0))),
		"recoveries": maxi(0, int(data.get("recoveries", 0)))
	}
	_pending_recovery_codes.clear()

func _on_integrated_sale_completed(_sale: Dictionary) -> void:
	if bool(integrated_progress.get("completed", false)):
		return
	if not _automation_is_running():
		return
	integrated_progress["valid_sales"] = int(integrated_progress["valid_sales"]) + 1
	var current_sale := int(integrated_progress["valid_sales"])
	for code in _pending_recovery_codes.keys():
		if current_sale > int(_pending_recovery_codes[code]):
			_pending_recovery_codes.erase(code)
	var stock := StockSystem.get_stock_snapshot()
	for code in ProductCatalogData.PRODUCTS:
		var minimum := int(ProductCatalogData.PRODUCTS[code].get("minimo", 0))
		if int(stock.get(code, 0)) < minimum:
			_pending_recovery_codes[code] = current_sale + RECOVERY_WINDOW_SALES
	_emit_integrated_progress()

func _on_stock_purchase_completed(event: Dictionary) -> void:
	if bool(integrated_progress.get("completed", false)) or str(event.get("source", "")) != "script":
		return
	integrated_progress["script_purchases"] = int(integrated_progress["script_purchases"]) + 1
	var after: Dictionary = event.get("stock_after", {})
	var before: Dictionary = event.get("stock_before", {})
	var recovered := false
	# O estoque pode reagir logo após send(), antes de o cliente fechar o diálogo e
	# sale_completed ser emitido. Esse ainda é um efeito da venda válida em curso.
	if TransactionManager.transaction_closing and TransactionManager.pending_result:
		for code in ProductCatalogData.PRODUCTS:
			var minimum := int(ProductCatalogData.PRODUCTS[code].get("minimo", 0))
			if int(before.get(code, 0)) < minimum and int(after.get(code, 0)) >= minimum:
				recovered = true
	for code in _pending_recovery_codes.keys():
		var minimum := int(ProductCatalogData.PRODUCTS.get(code, {}).get("minimo", 0))
		if int(after.get(code, 0)) >= minimum:
			_pending_recovery_codes.erase(code)
			recovered = true
	if recovered:
		integrated_progress["recoveries"] = int(integrated_progress["recoveries"]) + 1
	_emit_integrated_progress()

func _emit_integrated_progress() -> void:
	var completed_now := (
		int(integrated_progress.get("valid_sales", 0)) >= REQUIRED_VALID_SALES
		and int(integrated_progress.get("script_purchases", 0)) > 0
		and int(integrated_progress.get("recoveries", 0)) > 0
		and _automation_is_running()
	)
	if completed_now:
		integrated_progress["completed"] = true
		integrated_challenge_completed.emit(get_integrated_challenge_status())
		EventBus.emit_signal("player_notification", "Desafio Mercado Automatizado concluído!")
	integrated_challenge_progress.emit(get_integrated_challenge_status())
	Saves.solicitar_save("mercado_automatizado_progresso")

func _automation_is_running() -> bool:
	return not InterpreterSystem.get_running_runtimes().is_empty()

# ─── Helpers matemáticos ──────────────────────────────────────────────────────

func arredondar(valor, casas):
	if casas == 2:
		return PromotionCatalogData.round_money(float(valor))
	var fator = pow(10, casas)
	return round(valor * fator) / fator

func _calcular_total(args) -> float:
	var soma: float = 0.0
	for arg in args:
		soma += arg
	return soma

func _calcular_total_carrinho(items: Array) -> float:
	var total := 0.0
	for requested in items:
		total += float(requested.get("unit_price", 0.0)) * int(requested.get("quantity", 0))
	return total

func _calcular_troco(pagamento: float, total: float) -> float:
	return pagamento - total

func _aplicar_desconto_carrinho(total: float) -> float:
	if total > 50.0:
		return total * 0.9
	return total

# ─── Recompensa por tipo de desafio ──────────────────────────────────────────

func get_reward(type: String) -> int:
	match type:
		"soma": return 8
		"cliente_ouro": return 16
		"compra_variavel": return 12
		"troco": return 16
		"estoque": return 24
		_: return 8

# ─── Entry point ─────────────────────────────────────────────────────────────

func set_context() -> ChallengeData:
	return _build_challenge({"base": "estoque", "stock_only": true})

# ─── Pipeline de geração ─────────────────────────────────────────────────────

func _build_challenge(options := {}) -> ChallengeData:
	var promotions: Array = []
	if bool(options.get("stock_only", false)) and FeatureManager.has_feature(FeatureManager.FEATURE_DISCOUNT):
		var forced: Variant = options.get("promotion", null)
		if forced != null:
			# Accept the previous single-rule hook as well as complete forced snapshots.
			assert(forced is Dictionary or forced is Array)
			var forced_rules: Array = [forced] if forced is Dictionary else forced
			assert(not forced_rules.is_empty() and bool(PromotionCatalogData.validate_rules(forced_rules).get("ok", false)))
			promotions = forced_rules.duplicate(true)
		else:
			promotions = PromotionCatalogData.generate_promotions()
	var challenge = _create_base_challenge(options, promotions)
	if challenge == null:
		return null
	challenge.promotions = promotions.duplicate(true)

	if bool(options.get("stock_only", false)):
		_apply_change_modifier(challenge, {})
	else:
		_apply_customer_tier(challenge, options)
		_apply_discount_modifier(challenge, options)
		_apply_change_modifier(challenge, options)
	_finalize_challenge(challenge)
	return challenge

func _create_base_challenge(options: Dictionary, promotions: Array = []) -> ChallengeData:
	var forced_base = str(options.get("base", ""))
	if forced_base == "estoque":
		return _create_stock_base(promotions)
	if forced_base == "compra_variavel":
		return _create_variable_base()
	if forced_base == "soma":
		return _create_sum_base()

	if FeatureManager.has_feature(FeatureManager.FEATURE_STOCK):
		return _create_stock_base(promotions)
	if FeatureManager.has_feature(FeatureManager.FEATURE_CART):
		return _create_variable_base()
	return _create_sum_base()

func _create_sum_base() -> ChallengeData:
	var challenge = ChallengeData.new()
	challenge.type = "soma"
	challenge.values = [
		arredondar(randf_range(10.0, 20.0), 2),
		arredondar(randf_range(10.0, 20.0), 2)
	]
	return challenge

func _create_variable_base() -> ChallengeData:
	var challenge = ChallengeData.new()
	challenge.type = "compra_variavel"
	var item_count = randi_range(3, 5)
	for _i in range(item_count):
		challenge.values.append(arredondar(randf_range(8.0, 28.0), 2))
	return challenge

func _create_stock_base(promotions: Array = []) -> ChallengeData:
	var requested_items = StockSystem.pick_requestable_items(2, promotions)
	if requested_items.is_empty():
		return null

	var challenge = ChallengeData.new()
	challenge.type = "estoque"
	challenge.requires_stock = true
	challenge.requested_items = requested_items.duplicate(true)
	for requested in requested_items:
		var code := int(requested.get("code", 0))
		var quantity := int(requested.get("quantity", 0))
		challenge.cart[code] = quantity
		challenge.price_snapshot[code] = float(requested.get("unit_price", 0.0))
	return challenge

func _apply_customer_tier(challenge: ChallengeData, options: Dictionary) -> void:
	var force_golden = bool(options.get("golden", false))
	var can_roll_golden = FeatureManager.has_feature(FeatureManager.FEATURE_DISCOUNT)
	if force_golden or (can_roll_golden and randf() < 0.12):
		challenge.is_golden = true
		challenge.difficulty += 1
		if not challenge.requires_stock:
			for i in range(challenge.values.size()):
				challenge.values[i] = arredondar(float(challenge.values[i]) * 1.25, 2)

func _apply_discount_modifier(challenge: ChallengeData, options: Dictionary) -> void:
	var force_discount = bool(options.get("discount", false))
	if force_discount or FeatureManager.has_feature(FeatureManager.FEATURE_DISCOUNT):
		challenge.applies_discount = true

func _apply_change_modifier(challenge: ChallengeData, options: Dictionary) -> void:
	if bool(options.get("change", false)) or FeatureManager.has_feature(FeatureManager.FEATURE_CHANGE):
		challenge.payment = 1.0

func _finalize_challenge(challenge: ChallengeData) -> void:
	var bruto = _calcular_total_carrinho(challenge.requested_items) if challenge.requires_stock else _calcular_total(challenge.values)
	var total_final = bruto
	if challenge.requires_stock:
		total_final = PromotionCatalogData.calculate_total(challenge.requested_items, challenge.promotions)
	if challenge.applies_discount:
		total_final = _aplicar_desconto_carrinho(total_final)
	total_final = arredondar(total_final, 2)

	challenge.expected_output = [total_final]
	challenge.reward = _calculate_reward(challenge)
	if StockSystem.is_stock_full():
		challenge.stock_bonus_active = true
		challenge.stock_bonus_multiplier = 1.5

	var order = ClientOrder.new()
	order.total = total_final
	order.items = challenge.requested_items.duplicate(true) if challenge.requires_stock else challenge.values.duplicate()

	if challenge.payment > 0:
		challenge.payment = _escolher_pagamento(total_final) if challenge.requires_stock else arredondar(total_final + randf_range(10.0, 30.0), 2)
		var troco = arredondar(_calcular_troco(challenge.payment, total_final), 2)
		challenge.expected_output.append(troco)
		order.payment = challenge.payment
		order.change = troco

	var inputs: Array = []
	if challenge.requires_stock:
		var pedido := {"carrinho": challenge.cart.duplicate(true)}
		if challenge.payment > 0:
			pedido["pagamento"] = challenge.payment
		inputs.append(pedido)
	else:
		inputs = challenge.values.duplicate()
		if challenge.type == "compra_variavel":
			inputs.append(-1)
		if challenge.payment > 0:
			inputs.append(challenge.payment)

	challenge.order = order
	challenge.env_context = EnvContext.new(
		inputs,
		challenge.expected_output.size(),
		challenge.expected_output
	)

	GameManager.current_context = challenge
	EventBus.emit_signal("update_context", challenge)

func _escolher_pagamento(total: float) -> float:
	for nota in [10.0, 20.0, 30.0, 50.0, 100.0]:
		if total < nota:
			return nota
	return ceilf((total + 0.01) / 50.0) * 50.0

func _calculate_reward(challenge: ChallengeData) -> int:
	var reward = get_reward(challenge.type)
	if challenge.payment > 0:
		reward += 4
	if challenge.is_golden:
		reward += 8
	return reward

# ─── Geradores públicos para tutorial/debug ──────────────────────────────────

func generate_sum_challenge() -> ChallengeData:
	return _build_challenge({"base": "soma"})

func generate_golden_challenge(item_values: Array = []) -> ChallengeData:
	var options = {"golden": true}
	if not item_values.is_empty():
		var challenge = ChallengeData.new()
		challenge.type = "compra_variavel" if item_values.size() > 2 else "soma"
		challenge.values = item_values.duplicate()
		_apply_customer_tier(challenge, options)
		_apply_discount_modifier(challenge, {})
		_apply_change_modifier(challenge, {})
		_finalize_challenge(challenge)
		return challenge
	return _build_challenge(options)

func generate_variable_purchase_challenge(item_values: Array = [], apply_discount := false) -> ChallengeData:
	if not item_values.is_empty():
		var challenge = ChallengeData.new()
		challenge.type = "compra_variavel"
		challenge.values = item_values.duplicate()
		_apply_customer_tier(challenge, {})
		_apply_discount_modifier(challenge, {"discount": apply_discount})
		_apply_change_modifier(challenge, {})
		_finalize_challenge(challenge)
		return challenge
	return _build_challenge({"base": "compra_variavel", "discount": apply_discount})

func generate_stock_challenge(promotion: Variant = null) -> ChallengeData:
	var options := {"base": "estoque", "stock_only": true}
	if promotion != null:
		options["promotion"] = promotion
	return _build_challenge(options)

func generate_change_challenge(apply_discount := false, is_golden := false) -> ChallengeData:
	return _build_challenge({"change": true, "discount": apply_discount, "golden": is_golden})
