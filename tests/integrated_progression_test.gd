extends Node

const UpgradeData = preload("res://data/UpgradeData.gd")
const ClientSpawnerScript = preload("res://systems/ClientSpawner.gd")

class FakeClient extends Node:
	signal result_closed
	var result_ok := false

	func show_request_dialog(_challenge) -> void:
		pass

	func show_result_dialog(ok: bool, _values: Array) -> void:
		result_ok = ok

var _failures: Array[String] = []

func _ready() -> void:
	if not EventBus.update_money.is_connected(_on_update_money):
		EventBus.update_money.connect(_on_update_money)
	_test_new_save_and_economy()
	_test_upgrade_progression()
	_test_manual_and_fixed_purchase_evidence()
	_test_empty_stock_recovery()
	await _test_real_integrated_challenge()
	_test_progress_persistence()
	if _failures.is_empty():
		print("INTEGRATED_PROGRESSION_TEST_OK")
	else:
		push_error("\n".join(_failures))
	InterpreterSystem.stop_integrated_automation()
	await get_tree().process_frame
	get_tree().quit()

func _test_new_save_and_economy() -> void:
	var save := Saves.create_new_save_data()
	_check(int(save["meta"]["save_version"]) == 5, "Novo save deve usar a progressão versão 5.")
	_check(int(save["game"]["dinheiro"]) == 180, "Novo mercado deve começar com R$180.")
	for feature in ["if", "cart", "discount", "sensor", "stock"]:
		_check(bool(save["game"]["unlocked_mechanics"].get(feature, false)), "Feature inicial ausente: %s." % feature)
	var quantities: Dictionary = save["stock"]["quantities"]
	_check(quantities.size() == 6, "Todos os produtos devem ter configuração inicial.")
	for code in quantities:
		_check(int(quantities[code]) == 5, "Estoque inicial deve ser parcial e alinhado ao lote.")
	var workspace: Dictionary = save["interpreter"]["script_workspace"]
	_check(workspace.get("scripts", []).size() == 1, "Novo save deve trazer somente o arquivo Principal.")
	_check(str(workspace["scripts"][0].get("source", "")) == "print(\"Hello, World!\")\n", "Principal deve começar com um Hello World simples.")

	GameManager.money = 180
	StockSystem.load_save_data(save["stock"])
	var one_lot_each := {}
	for code in ProductCatalog.PRODUCTS:
		one_lot_each[code] = int(ProductCatalog.PRODUCTS[code]["lote"])
	var result := StockSystem.try_buy_stock(one_lot_each, "manual")
	_check(bool(result.get("ok", false)) and int(result.get("total", 0)) == 135 and GameManager.money == 45,
		"R$180 deve permitir um lote de cada produto, sem compra gratuita.")
	_check(not StockSystem.is_stock_full(), "Compra economicamente viável não deve encher todo o estoque.")

func _test_upgrade_progression() -> void:
	UpgradeManager.load_save_data({"comprados": {}})
	for retired in ["lang_if", "lang_while", "lang_sensor", "gameplay_stock"]:
		_check(not UpgradeManager.upgrades_liberados.has(retired), "Upgrade básico aposentado não deve aparecer: %s." % retired)
	_check(UpgradeData.UPGRADES["marketing_2"]["requer"] == ["marketing_1"], "Progressão posterior não pode depender de sensor já liberado.")
	_check(UpgradeData.UPGRADES["premium_3"]["requer"] == ["premium_2"], "Progressão posterior não pode depender de Abrir estoque.")

func _test_manual_and_fixed_purchase_evidence() -> void:
	ChallengeSystem.load_save_data({})
	_set_all_quantities(5)
	GameManager.money = 180
	var manual := StockSystem.try_buy_stock({101: 5}, "manual")
	_check(bool(manual.get("ok", false)), "Compra manual válida deve continuar permitida.")
	_check(int(ChallengeSystem.integrated_progress["script_purchases"]) == 0, "Compra manual não pode provar automação do Estoque.")
	_set_all_quantities(5)
	GameManager.money = 180
	var fixed := {101: 10, 102: 10, 103: 10, 104: 10, 105: 10, 106: 10}
	var before := StockSystem.get_stock_snapshot()
	var refused := StockSystem.try_buy_stock_from_script(fixed)
	_check(not bool(refused.get("ok", false)) and refused.get("erro", "") == StockSystem.ERROR_BUDGET,
		"Comprar dez de tudo deve falhar pelo orçamento no cenário inicial.")
	_check(StockSystem.get_stock_snapshot() == before and int(ChallengeSystem.integrated_progress["script_purchases"]) == 0,
		"Compra fixa recusada deve ser atômica e não contar como reposição.")

func _test_empty_stock_recovery() -> void:
	var host := Control.new()
	add_child(host)
	var spawner := ClientSpawnerScript.new()
	host.add_child(spawner)
	spawner.liberar_spawn()
	_set_all_quantities(0)
	GameManager.money = 30
	spawner._pausar_por_estoque_vazio()
	_check(spawner.spawn_bloqueado, "Fluxo deve pausar quando não existe produto vendável.")
	var purchase := StockSystem.try_buy_stock({101: 5}, "manual")
	_check(bool(purchase.get("ok", false)) and not spawner.spawn_bloqueado,
		"Compra válida deve retomar clientes sem reiniciar a partida.")
	host.queue_free()

func _test_real_integrated_challenge() -> void:
	ChallengeSystem.load_save_data({})
	_set_all_quantities(0)
	_set_quantity(101, 6)
	GameManager.money = 100
	InterpreterSystem.load_save_data({"script_workspace": {"version": 7, "scripts": [
		{"id": "script_unico", "title": "Minha Loja", "source": "", "language": "python_like"}
	], "active_script_id": "script_unico", "main_script_id": "script_unico"}})
	var script_id := "script_unico"
	InterpreterSystem.script_workspace.get_script_document(script_id)["source"] = """produtos = tabela_produtos()
while True:
    estoque = get_stock()
    if estoque[101] < 5:
        buy_stock({101: 5})
    if sensor("cliente_na_tela") == True:
        compra = input()
        total = 0
        for codigo in compra:
            total = total + produtos[codigo]["preco"] * compra[codigo]
        send(total)
    wait(0)
"""
	InterpreterSystem.start_all_scripts(EnvContext.new([], 0, []))
	for sale_index in range(3):
		var client := FakeClient.new()
		add_child(client)
		var challenge := _single_rice_challenge()
		_check(TransactionManager.start_transaction(client, challenge), "Venda %d deve iniciar." % (sale_index + 1))
		var guard := 0
		while not client.result_ok and guard < 120:
			guard += 1
			await get_tree().process_frame
		_check(client.result_ok, "Caixa real deve concluir a venda %d." % (sale_index + 1))
		client.result_closed.emit()
		for _frame in range(4):
			await get_tree().process_frame
		client.queue_free()
	var status := ChallengeSystem.get_integrated_challenge_status()
	_check(bool(status.get("completed", false)), "Mercado Automatizado deve concluir por comportamento real.")
	_check(int(status.get("valid_sales", 0)) == 3, "Validador deve registrar três vendas com qualquer automação ativa.")
	_check(int(status.get("script_purchases", 0)) >= 1 and int(status.get("recoveries", 0)) >= 1,
		"Estoque deve recalcular e recuperar produto abaixo do mínimo após venda.")
	_check(_quantity(101) == 8, "Após três vendas e uma reposição de lote, o saldo de Arroz deve ser 8.")
	_check(GameManager.money == 85, "Reposição real deve alterar o orçamento compartilhado pelo custo do lote.")

func _test_progress_persistence() -> void:
	var saved := ChallengeSystem.get_save_data()
	ChallengeSystem.load_save_data({})
	_check(not bool(ChallengeSystem.integrated_progress["completed"]), "Reset de teste deve limpar o desafio.")
	ChallengeSystem.load_save_data(saved)
	_check(bool(ChallengeSystem.integrated_progress["completed"]) and int(ChallengeSystem.integrated_progress["valid_sales"]) == 3,
		"Progresso do desafio deve sobreviver ao round-trip.")

func _single_rice_challenge() -> ChallengeData:
	var challenge := ChallengeData.new()
	challenge.type = "estoque"
	challenge.requires_stock = true
	challenge.cart = {101: 1}
	challenge.price_snapshot = {101: 3.0}
	challenge.requested_items = [{"code": 101, "name": "Arroz", "quantity": 1, "unit_price": 3.0}]
	challenge.expected_output = [3.0]
	challenge.reward = 24
	challenge.env_context = EnvContext.new([{101: 1}], 0, [3.0])
	return challenge

func _set_all_quantities(amount: int) -> void:
	for item in StockSystem.get_stock():
		item.quantity = amount

func _set_quantity(code: int, amount: int) -> void:
	for item in StockSystem.get_stock():
		if item.code == code:
			item.quantity = amount

func _quantity(code: int) -> int:
	return int(StockSystem.get_stock_snapshot().get(code, 0))

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _on_update_money(amount: int) -> void:
	GameManager.money += amount
