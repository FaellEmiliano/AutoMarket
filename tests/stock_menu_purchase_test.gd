extends Node

var menu: Control

func _ready() -> void:
	EventBus.update_money.connect(_on_update_money)
	_reset_stock()
	_run_tests()
	print("STOCK_MENU_PURCHASE_TEST_OK")
	await get_tree().process_frame
	get_tree().quit()

func _run_tests() -> void:
	menu = preload("res://scenes/stock/estoque.tscn").instantiate()
	add_child(menu)
	menu.draw_estoque(StockSystem.get_stock())
	assert(menu.purchase_summary_label.text == "Nada selecionado ainda.", "A lista deve aparecer vazia ao abrir.")
	assert(not menu.botao_comprar.text.contains("Total"), "O botao de compra nao deve mostrar o valor total.")

	var first_item = StockSystem.get_stock()[0]
	first_item.quantity = 7
	GameManager.money = 200
	menu.draw_estoque(StockSystem.get_stock())
	assert(menu.purchase_summary_label.text == "Nada selecionado ainda.", "Sem itens selecionados, a lista deve informar vazio.")

	menu.increase_selected_quantity(first_item.name)
	assert(menu.get_selected_quantity(first_item.name) == first_item.lot_size, "O + deve aumentar um lote do item selecionado.")
	assert(menu.get_selected_quantity(StockSystem.get_stock()[1].name) == 0, "Outros itens nao devem mudar.")
	assert(not menu.purchase_summary_label.text.contains("Nada selecionado"), "A lista deve sair do estado vazio quando houver seleção.")
	assert(menu.purchase_summary_label.text.contains("%s x%d - R$ %d" % [first_item.name, first_item.lot_size, int(first_item.acquisition_cost) * first_item.lot_size]), "A lista deve mostrar item, quantidade e subtotal.")

	menu.decrease_selected_quantity(first_item.name)
	assert(menu.get_selected_quantity(first_item.name) == 0, "O - deve diminuir a quantidade selecionada.")
	assert(menu.purchase_summary_label.text == "Nada selecionado ainda.", "Item com quantidade 0 deve sumir da lista.")
	menu.decrease_selected_quantity(first_item.name)
	assert(menu.get_selected_quantity(first_item.name) == 0, "A quantidade selecionada nao pode ficar negativa.")

	for i in range(3):
		menu.increase_selected_quantity(first_item.name)
	assert(menu.get_selected_quantity(first_item.name) == 10, "A selecao nao pode passar da capacidade restante e deve respeitar lotes.")
	assert(menu.purchase_summary_label.text.contains("%s x10 - R$ %d" % [first_item.name, int(first_item.acquisition_cost) * 10]), "A lista deve atualizar quantidade e subtotal.")

	var second_item = StockSystem.get_stock()[1]
	menu.increase_selected_quantity(second_item.name)
	var expected_total = int(first_item.acquisition_cost) * 10 + int(second_item.acquisition_cost) * second_item.lot_size
	assert(menu.calculate_total_purchase_cost() == expected_total, "O total deve somar todos os itens selecionados.")
	assert(menu.calculate_purchase_total() == expected_total, "A funcao de total da lista deve retornar o mesmo total.")
	assert(menu.purchase_summary_label.text.contains("%s x%d - R$ %d" % [second_item.name, second_item.lot_size, int(second_item.acquisition_cost) * second_item.lot_size]), "Produtos diferentes devem aparecer juntos na lista.")
	assert(menu.purchase_summary_label.text.contains("Total: R$ %d" % expected_total), "A lista deve mostrar o total geral correto.")

	menu.confirm_purchase()
	assert(GameManager.money == 200 - expected_total, "O dinheiro deve ser descontado pelo total correto.")
	assert(first_item.quantity == 17, "O estoque do primeiro item deve aumentar corretamente.")
	assert(second_item.quantity == second_item.lot_size, "O estoque do segundo item deve aumentar corretamente.")
	assert(menu.get_selected_quantity(first_item.name) == 0, "A selecao deve zerar depois da compra.")
	assert(menu.get_selected_quantity(second_item.name) == 0, "Todas as selecoes devem zerar depois da compra.")
	assert(menu.purchase_summary_label.text == "Nada selecionado ainda.", "A lista deve voltar ao estado vazio depois da compra.")

	GameManager.money = 0
	var before_quantity = second_item.quantity
	menu.increase_selected_quantity(second_item.name)
	menu.confirm_purchase()
	assert(second_item.quantity == before_quantity, "Sem dinheiro suficiente, a compra nao deve ser aplicada.")
	assert(menu.get_selected_quantity(second_item.name) == second_item.lot_size, "Compra recusada deve preservar a seleção para correção.")
	assert(not menu.purchase_summary_label.text.contains("Nada selecionado"), "Compra recusada deve preservar a lista para correção.")
	assert(menu.aviso_label.visible, "A tentativa de compra deve mostrar feedback na tela.")
	assert(menu.aviso_label.text.contains("saldo"), "Dinheiro insuficiente deve informar que a compra foi recusada.")

	GameManager.money = 1000
	for item in StockSystem.get_stock():
		item.quantity = item.max_quantity
	menu.draw_estoque(StockSystem.get_stock())
	assert(menu.bonus_label.visible, "O informativo de bonus deve aparecer quando o estoque estiver cheio.")

	StockSystem.get_stock()[0].quantity = StockSystem.get_stock()[0].max_quantity - 1
	menu.draw_estoque(StockSystem.get_stock())
	assert(not menu.bonus_label.visible, "O informativo de bonus deve sumir quando o estoque nao estiver cheio.")

func _reset_stock() -> void:
	for item in StockSystem.get_stock():
		item.quantity = 0
		item.max_quantity = int(StockSystem.get_product_table()[item.code]["capacidade"])
	GameManager.money = 0

func _on_update_money(amount: int) -> void:
	GameManager.money += amount
