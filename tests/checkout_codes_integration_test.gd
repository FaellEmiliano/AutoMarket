extends Node

const ScriptRuntimeManagerScript = preload("res://systems/ScriptRuntimeManager.gd")
const ClientSpawnerScript = preload("res://systems/ClientSpawner.gd")

class FakeClient extends Node:
	signal result_closed
	var request_challenge = null
	var result_ok := false
	var result_values: Array = []

	func show_request_dialog(challenge) -> void:
		request_challenge = challenge

	func show_result_dialog(ok: bool, values: Array) -> void:
		result_ok = ok
		result_values = values.duplicate(true)

var _failures: Array[String] = []
var _sale_events: Array = []
var _economy_spawner

func _ready() -> void:
	if not EventBus.update_money.is_connected(_on_update_money):
		EventBus.update_money.connect(_on_update_money)
	_economy_spawner = ClientSpawnerScript.new()
	_economy_spawner.spawn_bloqueado = true
	EventBus.end_client.connect(_economy_spawner.end_client)
	if not TransactionManager.sale_completed.is_connected(_on_sale_completed):
		TransactionManager.sale_completed.connect(_on_sale_completed)
	FeatureManager.unlock_feature(FeatureManager.FEATURE_STOCK)
	_test_cart_input_copy_and_single_consumption()
	_test_totals_discount_change_and_special_customer()
	_test_customer_cart_text()
	await _test_python_like_full_sale()
	_test_rejected_and_duplicate_sales()
	_test_empty_stock_and_legacy_compatibility()
	_test_persistence()
	await _test_change_upgrade_checkout()
	if _failures.is_empty():
		print("CHECKOUT_CODES_INTEGRATION_TEST_OK")
	else:
		push_error("\n".join(_failures))
	_economy_spawner.free()
	await get_tree().process_frame
	get_tree().quit()

func _test_cart_input_copy_and_single_consumption() -> void:
	_reset_state()
	_set_quantity(101, 5)
	var challenge := _stock_challenge([{"code": 101, "name": "Arroz", "quantity": 2, "unit_price": 3.0}])
	var client := FakeClient.new()
	add_child(client)
	_check(TransactionManager.start_transaction(client, challenge), "Transacao por codigo deve iniciar.")
	var pedido = TransactionManager.next_input()
	_check(pedido is Dictionary and pedido.keys() == ["carrinho"], "input deve entregar somente o pedido com carrinho.")
	var cart = pedido.get("carrinho", {})
	_check(cart is Dictionary and cart == {101: 2} and cart.keys()[0] is int, "Carrinho deve manter codigos inteiros e quantidades.")
	cart[101] = 999
	_check(challenge.cart == {101: 2} and challenge.env_context.inputs[0]["carrinho"] == {101: 2}, "Carrinho retornado deve ser copia profunda independente.")
	_check(TransactionManager.next_input() == 0, "Carrinho deve ser consumido uma unica vez.")
	TransactionManager.submit([6])
	client.result_closed.emit()
	client.queue_free()

func _test_totals_discount_change_and_special_customer() -> void:
	var discount := _stock_challenge([{"code": 101, "name": "Arroz", "quantity": 20, "unit_price": 3.0}], true)
	_check(discount.expected_output == [54.0], "Compras acima de R$50 devem manter desconto de 10%.")
	var change := _stock_challenge([{"code": 106, "name": "Chocolate", "quantity": 10, "unit_price": 6.0}], true, true)
	_check(change.expected_output.size() == 2 and change.expected_output[0] == 54.0 and change.expected_output[1] > 0.0, "Cliente com troco deve esperar total com desconto e troco.")
	var golden := ChallengeData.new()
	golden.type = "estoque"
	golden.requires_stock = true
	golden.requested_items = [{"code": 101, "name": "Arroz", "quantity": 2, "unit_price": 3.0}]
	ChallengeSystem._apply_customer_tier(golden, {"golden": true})
	ChallengeSystem._finalize_challenge(golden)
	_check(golden.is_golden and golden.expected_output == [6.0] and golden.reward == 32, "Cliente especial deve preservar preco e bonus de recompensa.")

func _test_customer_cart_text() -> void:
	var customer = preload("res://scenes/Client/cliente.tscn").instantiate()
	var challenge := ChallengeData.new()
	challenge.requires_stock = true
	challenge.requested_items = [
		{"code": 101, "name": "Arroz", "quantity": 2, "unit_price": 3.0}
	]
	customer.challenge = challenge
	var text: String = customer.gerar_texto_pedido([])
	_check(text.contains("[101] 2x Arroz") and text.contains("R$ 3,00 cada"), "UI do cliente deve mostrar codigo, nome, quantidade e preco do snapshot.")
	_check(not text.contains("Tenho um pedido aqui"), "Pedido por códigos não pode cair no texto genérico.")
	customer.free()

func _test_python_like_full_sale() -> void:
	_reset_state()
	_set_quantity(101, 5)
	_set_quantity(103, 4)
	var challenge := _stock_challenge([
		{"code": 101, "name": "Arroz", "quantity": 2, "unit_price": 3.0},
		{"code": 103, "name": "Farinha", "quantity": 3, "unit_price": 4.0}
	])
	GameManager.current_context = challenge
	var client := FakeClient.new()
	add_child(client)
	_check(TransactionManager.start_transaction(client, challenge), "Fluxo integrado deve iniciar transacao.")
	var manager := ScriptRuntimeManagerScript.new()
	add_child(manager)
	manager.start_script("checkout_codes", """
produtos = tabela_produtos()
pedido = input()
carrinho = pedido["carrinho"]
total = 0
for codigo in carrinho:
    total = total + produtos[codigo]["preco"] * carrinho[codigo]
send(total)
""", "CaixaCodigos", null, "python_like")
	await _wait_until_not_running(manager, "checkout_codes")
	var runtime: Dictionary = manager.get_runtime_by_script_id("checkout_codes")
	_check(runtime.get("status", "") == ScriptRuntimeManager.STATUS_FINISHED and client.result_ok, "Programa Python-like real deve calcular e enviar o total correto.")
	_check(_quantity(101) == 3 and _quantity(103) == 1, "Venda aceita deve baixar todos os produtos atomicamente.")
	client.result_closed.emit()
	_check(GameManager.money == challenge.reward, "Economia deve creditar apenas a recompensa existente, nao o total da venda.")
	_check(_sale_events.size() == 1 and _sale_events[0]["cart"] == {101: 2, 103: 3}, "Venda concluida deve emitir um unico evento de dominio.")
	manager.queue_free()
	client.queue_free()

func _test_rejected_and_duplicate_sales() -> void:
	_reset_state()
	_set_quantity(101, 1)
	var unavailable := _stock_challenge([{"code": 101, "name": "Arroz", "quantity": 2, "unit_price": 3.0}])
	GameManager.current_context = unavailable
	var client := FakeClient.new()
	add_child(client)
	TransactionManager.start_transaction(client, unavailable)
	var before_money := GameManager.money
	_check(not TransactionManager.submit([6]), "Venda deve falhar se o estoque mudou antes do send.")
	_check(_quantity(101) == 1 and GameManager.money == before_money, "Venda recusada nao pode consumir estoque nem creditar dinheiro.")
	_check(not TransactionManager.submit([6]), "Segundo send durante fechamento nao pode duplicar venda.")
	client.result_closed.emit()
	_check(_sale_events.is_empty(), "Venda recusada nao pode emitir evento de venda concluida.")
	client.queue_free()

func _test_empty_stock_and_legacy_compatibility() -> void:
	_reset_state()
	_check(ChallengeSystem.generate_stock_challenge() == null, "Estoque vazio deve manter geracao em estado recuperavel.")
	var legacy := ChallengeSystem.generate_sum_challenge()
	var client := FakeClient.new()
	add_child(client)
	TransactionManager.start_transaction(client, legacy)
	_check(TransactionManager.next_input() is float, "Desafio legado deve preservar entrada numerica.")
	TransactionManager.submit([0])
	client.result_closed.emit()
	client.queue_free()

func _test_persistence() -> void:
	_reset_state()
	_set_quantity(101, 7)
	GameManager.money = 42
	var stock_save := StockSystem.get_save_data()
	var game_save := GameManager.get_save_data()
	_set_quantity(101, 0)
	GameManager.money = 0
	StockSystem.load_save_data(stock_save)
	GameManager.load_save_data(game_save)
	_check(_quantity(101) == 7 and GameManager.money == 42, "Saldo e estoque devem sobreviver ao round-trip de persistencia.")

func _test_change_upgrade_checkout() -> void:
	var new_save := Saves.create_new_save_data()
	_check(not bool(new_save["game"]["unlocked_mechanics"]["change"]) and new_save["shop"]["comprados"].is_empty(),
		"Novo save deve comecar sem troco e sem upgrade comprado.")
	UpgradeManager.load_save_data({"comprados": {}})
	_check(not FeatureManager.has_feature(FeatureManager.FEATURE_CHANGE), "Troco deve iniciar desativado.")
	GameManager.money = 180
	_check(not UpgradeManager.can_buy("gameplay_change"), "Upgrade nao deve ser comprado com o saldo inicial.")
	UpgradeManager.comprar_upgrade("gameplay_change")
	_check(GameManager.money == 180 and not UpgradeManager.has_upgrade("gameplay_change"),
		"Compra direta tambem deve respeitar a reserva de caixa.")
	GameManager.money = 252
	_check(UpgradeManager.can_buy("gameplay_change"), "Tres recompensas basicas devem permitir a compra.")
	UpgradeManager.comprar_upgrade("gameplay_change")
	_check(GameManager.money == 132 and UpgradeManager.has_upgrade("gameplay_change"), "Compra deve descontar R$120 e preservar reserva.")
	_check(FeatureManager.has_feature(FeatureManager.FEATURE_CHANGE), "Compra deve liberar FEATURE_CHANGE.")
	var full_save := Saves._montar_save_data()
	_check(bool(full_save["shop"]["comprados"].get("gameplay_change", false))
		and bool(full_save["game"]["unlocked_mechanics"].get("change", false)),
		"Save completo deve registrar compra e feature de troco.")
	var purchased := UpgradeManager.get_save_data()
	UpgradeManager.load_save_data({"comprados": {"premium_1": true}})
	_check(not FeatureManager.has_feature(FeatureManager.FEATURE_CHANGE) and UpgradeManager.reward_multiplier == 1.0,
		"Upgrade legado oculto nao pode ativar troco nem multiplicar recompensa.")
	UpgradeManager.load_save_data(purchased)
	_check(FeatureManager.has_feature(FeatureManager.FEATURE_CHANGE), "Save/load deve restaurar troco comprado.")
	_check(ChallengeSystem._escolher_pagamento(13.0) == 20.0
		and ChallengeSystem._escolher_pagamento(27.0) == 30.0
		and ChallengeSystem._escolher_pagamento(64.0) == 100.0
		and ChallengeSystem._escolher_pagamento(100.0) == 150.0,
		"Pagamento deve usar valores plausiveis mesmo para carrinhos grandes.")

	_reset_state()
	_set_quantity(101, 5)
	_set_quantity(103, 4)
	var generated := ChallengeSystem.set_context()
	_check(generated != null and generated.requires_stock and generated.expected_output.size() == 2,
		"Desafio ativo deve permanecer de estoque e passar a exigir total e troco.")
	var challenge := _stock_challenge([
		{"code": 101, "name": "Arroz", "quantity": 2, "unit_price": 3.0},
		{"code": 103, "name": "Farinha", "quantity": 2, "unit_price": 4.0}
	], false, true)
	var pedido: Dictionary = challenge.env_context.inputs[0]
	var total := float(challenge.expected_output[0])
	var troco := float(challenge.expected_output[1])
	_check(pedido.keys().size() == 2 and pedido.has("carrinho") and pedido.has("pagamento") and challenge.env_context.inputs.size() == 1,
		"Troco deve vir no mesmo pedido, sem input separado.")
	_check(pedido["carrinho"] == {101: 2, 103: 2} and pedido["pagamento"] is float and float(pedido["pagamento"]) >= total,
		"Pedido deve manter codigos inteiros e pagamento suficiente.")
	_check(float(pedido["pagamento"]) == challenge.order.payment and abs(troco - (float(pedido["pagamento"]) - total)) < 0.01,
		"Dialogo, input e resposta esperada devem usar o mesmo pagamento.")
	_test_change_dialog(challenge, pedido)
	for rejected in [[total], [total, troco + 1.0], [troco, total]]:
		var rejected_client := FakeClient.new()
		add_child(rejected_client)
		_check(TransactionManager.start_transaction(rejected_client, challenge), "Tentativa de resposta deve iniciar.")
		_check(not TransactionManager.submit(rejected), "Resposta incompleta, incorreta ou invertida deve falhar.")
		rejected_client.result_closed.emit()
		rejected_client.queue_free()
	_check(_quantity(101) == 5 and _quantity(103) == 4 and _sale_events.is_empty(),
		"Respostas rejeitadas nao podem consumir estoque nem registrar venda.")
	GameManager.current_context = challenge
	var client := FakeClient.new()
	add_child(client)
	_check(TransactionManager.start_transaction(client, challenge), "Venda com troco deve iniciar.")
	var manager := ScriptRuntimeManagerScript.new()
	add_child(manager)
	manager.start_script("checkout_change", """produtos = tabela_produtos()
pedido = input()
carrinho = pedido["carrinho"]
total = 0
for codigo in carrinho:
    total = total + produtos[codigo]["preco"] * carrinho[codigo]
pagamento = pedido["pagamento"]
troco = pagamento - total
send(total, troco)
""", "CaixaTroco", null, "python_like")
	await _wait_until_not_running(manager, "checkout_change")
	var runtime: Dictionary = manager.get_runtime_by_script_id("checkout_change")
	_check(runtime.get("status", "") == ScriptRuntimeManager.STATUS_FINISHED and client.result_ok,
		"Executor Python-like deve ler o pagamento aninhado e concluir a venda.")
	_check(_quantity(101) == 3 and _quantity(103) == 2, "Venda com troco deve consumir o estoque real.")
	client.result_closed.emit()
	_check(GameManager.money == challenge.reward and _sale_events.size() == 1,
		"Venda com troco deve creditar a recompensa e emitir um evento de venda.")
	manager.queue_free()
	client.queue_free()

func _test_change_dialog(challenge: ChallengeData, pedido: Dictionary) -> void:
	var customer = preload("res://scenes/Client/cliente.tscn").instantiate()
	var hud := CanvasLayer.new()
	add_child(hud)
	customer._hud = hud
	customer.show_request_dialog(challenge)
	var dialog: Dictionary = customer.active_dialog.data
	_check(str(dialog[2]["dialog"]).contains("R$ " + customer.formatar(pedido["pagamento"])),
		"Dialogo deve mostrar exatamente o pagamento entregue por input.")
	customer.dialogo_erro([challenge.expected_output[0]])
	var feedback: Dictionary = customer.active_dialog.data
	_check(str(feedback[1]["dialog"]).contains("total e troco"), "Script antigo deve receber feedback sobre a resposta incompleta.")
	hud.queue_free()
	customer.free()

func _stock_challenge(items: Array, discount := false, with_change := false) -> ChallengeData:
	var challenge := ChallengeData.new()
	challenge.type = "estoque"
	challenge.requires_stock = true
	challenge.requested_items = items.duplicate(true)
	for item in items:
		challenge.cart[int(item["code"])] = int(item["quantity"])
		challenge.price_snapshot[int(item["code"])] = float(item["unit_price"])
	challenge.applies_discount = discount
	challenge.payment = 1.0 if with_change else 0.0
	ChallengeSystem._finalize_challenge(challenge)
	return challenge

func _reset_state() -> void:
	if TransactionManager.has_active_transaction():
		TransactionManager.active_client = null
		TransactionManager.active_challenge = null
		TransactionManager.active_inputs.clear()
		TransactionManager.transaction_closing = false
	for item in StockSystem.get_stock():
		item.quantity = 0
	GameManager.money = 0
	_sale_events.clear()

func _set_quantity(code: int, amount: int) -> void:
	for item in StockSystem.get_stock():
		if item.code == code:
			item.quantity = amount

func _quantity(code: int) -> int:
	return int(StockSystem.get_stock_snapshot().get(code, 0))

func _wait_until_not_running(manager, script_id: String) -> void:
	var guard := 0
	while manager.is_script_running(script_id) and guard < 240:
		guard += 1
		await get_tree().process_frame
	_check(not manager.is_script_running(script_id), "Runtime de caixa deve terminar dentro do limite.")

func _on_update_money(amount: int) -> void:
	GameManager.money += amount

func _on_sale_completed(sale: Dictionary) -> void:
	_sale_events.append(sale.duplicate(true))

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
