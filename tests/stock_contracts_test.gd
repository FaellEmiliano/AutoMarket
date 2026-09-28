extends Node

const ScriptRuntimeManagerScript = preload("res://systems/ScriptRuntimeManager.gd")

var _failures: Array[String] = []

func _ready() -> void:
	if not EventBus.update_money.is_connected(_on_update_money):
		EventBus.update_money.connect(_on_update_money)
	_test_catalog()
	_test_stock_snapshot_copy()
	_test_purchase_contract()
	_test_atomic_failures()
	_test_save_compatibility()
	await _test_python_like_contract()
	await _test_manual_purchase()
	if _failures.is_empty():
		print("STOCK_CONTRACTS_TEST_OK")
	else:
		push_error("\n".join(_failures))
	await get_tree().process_frame
	get_tree().quit()

func _test_catalog() -> void:
	var table := StockSystem.get_product_table()
	_check(table.keys() == [101, 102, 103, 104, 105, 106], "Catalogo deve manter codigos estaveis.")
	_check(table[101]["nome"] == "Arroz" and table[106]["nome"] == "Chocolate", "Catalogo deve manter os seis produtos.")
	var original_name := str(table[101]["nome"])
	table[101]["nome"] = "Alterado"
	_check(StockSystem.get_product_table()[101]["nome"] == original_name, "tabela_produtos deve retornar copia profunda.")
	_check(ProductCatalog.validate().get("ok", false), "Catalogo configurado deve respeitar seus invariantes.")

func _test_stock_snapshot_copy() -> void:
	_reset_stock()
	StockSystem.get_stock()[0].quantity = 5
	var snapshot := StockSystem.get_stock_snapshot()
	snapshot[101] = 999
	_check(StockSystem.get_stock()[0].quantity == 5, "get_stock do jogador deve retornar copia.")

func _test_purchase_contract() -> void:
	_reset_stock()
	GameManager.money = 200
	var result := StockSystem.try_buy_stock({101: 10})
	_check(result == {"ok": true, "total": 30, "saldo": 170}, "Compra de multiplos lotes deve retornar total e saldo.")
	_check(StockSystem.get_stock()[0].quantity == 10, "Compra valida deve adicionar todo o pedido.")
	result = StockSystem.try_buy_stock({102: 5, 103: 10})
	_check(result.get("ok", false) and result.get("total", 0) == 60, "Compra de multiplos produtos deve somar custos.")
	_check(StockSystem.get_stock()[1].quantity == 5 and StockSystem.get_stock()[2].quantity == 10, "Compra multiproduto deve adicionar todas as quantidades.")
	result = StockSystem.try_buy_stock({})
	_check(result == {"ok": true, "total": 0, "saldo": 110}, "Pedido vazio deve ser sucesso sem movimentacao.")

func _test_atomic_failures() -> void:
	var cases := [
		[{999: 5}, StockSystem.ERROR_PRODUCT],
		[{101: -5}, StockSystem.ERROR_QUANTITY],
		[{101: 3}, StockSystem.ERROR_LOT],
		[{101: 25}, StockSystem.ERROR_CAPACITY],
	]
	for test_case in cases:
		_reset_stock()
		GameManager.money = 1000
		var before := StockSystem.get_stock_snapshot()
		var result := StockSystem.try_buy_stock(test_case[0])
		_check(not result.get("ok", true) and result.get("erro", "") == test_case[1], "Falha deve retornar codigo estruturado %s." % test_case[1])
		_check(StockSystem.get_stock_snapshot() == before and GameManager.money == 1000, "Falha %s precisa ser atomica." % test_case[1])
	_reset_stock()
	GameManager.money = 34
	var result := StockSystem.try_buy_stock({101: 5, 102: 5})
	_check(result.get("erro", "") == StockSystem.ERROR_BUDGET, "Orcamento insuficiente deve ser identificado.")
	_check(StockSystem.get_stock_snapshot().values().all(func(value): return value == 0) and GameManager.money == 34, "Orcamento insuficiente nao pode aplicar compra parcial.")
	result = StockSystem.try_buy_stock({101: 5.0})
	_check(result.get("erro", "") == StockSystem.ERROR_QUANTITY, "Quantidade de tipo invalido deve ser recusada.")

func _test_save_compatibility() -> void:
	_reset_stock()
	StockSystem.load_save_data({"quantities": {"Arroz": 7, "Feijao": 3}, "max_quantities": {"Arroz": 12, "Feijao": 11}})
	_check(StockSystem.get_stock()[0].quantity == 7 and StockSystem.get_stock()[0].max_quantity == 12, "Save antigo deve migrar quantidade e capacidade pelo nome.")
	_check(StockSystem.get_stock()[1].quantity == 3 and StockSystem.get_stock()[1].max_quantity == 11, "Migracao por nome deve ser deterministica.")
	var saved := StockSystem.get_save_data()
	_reset_stock()
	StockSystem.load_save_data(saved)
	_check(StockSystem.get_stock()[0].quantity == 7 and StockSystem.get_stock()[0].max_quantity == 12, "Novo save por codigo deve persistir estoque e capacidade.")

func _test_python_like_contract() -> void:
	_reset_stock()
	GameManager.money = 100
	var manager := ScriptRuntimeManagerScript.new()
	add_child(manager)
	manager.start_script("stock_contract", """
produtos = tabela_produtos()
produtos[101]["nome"] = "Mudou"
print(get_budget())
print(buy_stock({101: 3})["erro"])
print("continua")
print(buy_stock({101: 5})["ok"])
print(get_stock()[101])
""", "StockContract", null, "python_like")
	await _wait_until_not_running(manager, "stock_contract")
	var runtime: Dictionary = manager.get_runtime_by_script_id("stock_contract")
	var output := str(runtime.get("output", ""))
	_check(runtime.get("status", "") == ScriptRuntimeManager.STATUS_FINISHED, "Compra recusada nao deve encerrar o runtime Python-like.")
	_check(output.contains("[StockContract] 100") and output.contains("[StockContract] LOTE_INVALIDO") and output.contains("[StockContract] continua") and output.contains("[StockContract] True") and output.contains("[StockContract] 5"), "Built-ins Python-like devem expor catalogo, saldo, falha estruturada e compra valida.")
	_check(StockSystem.get_product_table()[101]["nome"] == "Arroz", "Mutar tabela no script nao pode alterar o catalogo.")
	manager.queue_free()

func _test_manual_purchase() -> void:
	_reset_stock()
	GameManager.money = 100
	var menu = preload("res://scenes/stock/estoque.tscn").instantiate()
	add_child(menu)
	menu.draw_estoque(StockSystem.get_stock())
	var item = StockSystem.get_stock()[0]
	menu.increase_selected_quantity(item.name)
	_check(menu.get_selected_quantity(item.name) == item.lot_size, "Compra manual deve selecionar um lote inteiro.")
	menu.confirm_purchase()
	_check(item.quantity == item.lot_size and GameManager.money == 85, "Compra manual deve usar o mesmo validador e custo do script.")
	menu.queue_free()

func _wait_until_not_running(manager, script_id: String) -> void:
	var guard := 0
	while manager.is_script_running(script_id) and guard < 240:
		guard += 1
		await get_tree().process_frame
	_check(not manager.is_script_running(script_id), "Runtime de teste deve terminar dentro do limite.")

func _reset_stock() -> void:
	for item in StockSystem.get_stock():
		item.quantity = 0
		item.max_quantity = int(StockSystem.get_product_table()[item.code]["capacidade"])
	GameManager.money = 0

func _on_update_money(amount: int) -> void:
	GameManager.money += amount

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
