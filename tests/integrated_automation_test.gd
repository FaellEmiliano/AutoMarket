extends Node

const BridgeScript = preload("res://interpreter/runtime/godot_automarket_python_bridge.gd")

class FakeClient extends Node:
	signal result_closed
	var result_ok := false

	func show_request_dialog(_challenge) -> void:
		pass

	func show_result_dialog(ok: bool, _values: Array) -> void:
		result_ok = ok

var _failures: Array[String] = []

func _ready() -> void:
	FeatureManager.unlock_feature(FeatureManager.FEATURE_STOCK)
	_reset_state()
	await _test_free_program_flow()
	if _failures.is_empty():
		print("INTEGRATED_AUTOMATION_TEST_OK")
	else:
		push_error("\n".join(_failures))
	InterpreterSystem.stop_all()
	await get_tree().process_frame
	get_tree().quit()

func _test_free_program_flow() -> void:
	InterpreterSystem.load_save_data({"script_workspace": {"version": 7, "scripts": [
		{"id": "script_livre", "title": "Automação Livre", "source": "", "language": "python_like"}
	], "active_script_id": "script_livre", "main_script_id": "script_livre"}})
	var script_id := "script_livre"
	var script := InterpreterSystem.script_workspace.get_script_document(script_id)
	script["source"] = """buy_stock({101: 5})
produtos = tabela_produtos()
compra = input()
total = 0
for codigo in compra:
    total = total + produtos[codigo]["preco"] * compra[codigo]
send(total)
"""

	var challenge := ChallengeData.new()
	challenge.type = "estoque"
	challenge.requires_stock = true
	challenge.cart = {101: 2}
	challenge.price_snapshot = {101: 3.0}
	challenge.requested_items = [{"code": 101, "name": "Arroz", "quantity": 2, "unit_price": 3.0}]
	challenge.expected_output = [6.0]
	challenge.env_context = EnvContext.new([{101: 2}], 0, [6.0])
	var client := FakeClient.new()
	add_child(client)
	_check(TransactionManager.start_transaction(client, challenge), "Transação integrada deve iniciar.")

	var sales_before := InterpreterSystem.completed_sale_count
	var runtimes := InterpreterSystem.start_all_scripts(EnvContext.new([], 0, []))
	var runtime_id := str(runtimes.get(script_id, ""))
	_check(not runtime_id.is_empty(), "Rodar todos deve iniciar um arquivo de nome arbitrário.")
	var repeated := InterpreterSystem.start_all_scripts(EnvContext.new([], 0, []))
	_check(repeated == runtimes, "Início coordenado repetido não pode duplicar runtimes.")

	var guard := 0
	while InterpreterSystem.is_script_running(script_id) and guard < 120:
		guard += 1
		await get_tree().process_frame
	_check(guard < 120, "O programa real deve concluir dentro do limite.")
	_check(client.result_ok, "O mesmo arquivo deve poder repor e concluir a venda sem def main().")
	_check(_quantity(101) == 3, "Um arquivo livre deve acessar estoque e caixa na mesma execução.")
	client.result_closed.emit()
	_check(InterpreterSystem.completed_sale_count == sales_before + 1, "Integração deve consumir sale_completed uma única vez.")
	_check(InterpreterSystem.last_completed_sale.get("cart", {}) == {101: 2}, "Evento integrado deve preservar o carrinho vendido.")
	client.queue_free()

func _reset_state() -> void:
	if TransactionManager.has_active_transaction():
		TransactionManager.active_client = null
		TransactionManager.active_challenge = null
		TransactionManager.active_inputs.clear()
		TransactionManager.transaction_closing = false
	for item in StockSystem.get_stock():
		item.quantity = 0
	GameManager.money = 100

func _quantity(code: int) -> int:
	return int(StockSystem.get_stock_snapshot().get(code, 0))

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
