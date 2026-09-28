extends Control

var estoque = []
@onready var grid_container: GridContainer = %GridContainer
@onready var botao_comprar: Button = %Comprar
@onready var limpar_button: Button = %Limpar
@onready var purchase_summary_panel: TextureRect = %PurchaseSummaryPanel
@onready var purchase_summary_label: Label = %PurchaseSummaryLabel
@onready var money_label: Label = %MoneyLabel
@onready var bonus_banner: PanelContainer = %BonusBanner
@onready var bonus_label: Label = %BonusLabel
@onready var message_panel: PanelContainer = %MessagePanel
@onready var aviso_label: Label = %AvisoLabel

var item_template = preload("res://scenes/stock/item.tscn")
var selected_quantities = {}
var item_cards = {}

func _on_button_pressed() -> void:
	queue_free()

func _ready() -> void:
	EventBus.send_estoque.connect(draw_estoque)
	EventBus.update_money.connect(_on_money_changed)
	_load_receipt_note_texture()
	bonus_label.text = "ESTOQUE CHEIO: recompensas valem 1,5x"
	_clear_message()
	_refresh_money_label()
	EventBus.emit_signal("get_estoque")

func draw_estoque(est):
	estoque = est
	selected_quantities = _sanitize_selected_quantities()
	item_cards.clear()

	# limpa antes (IMPORTANTE)
	for child in grid_container.get_children():
		child.queue_free()

	for item in estoque:
		var item_instancia = item_template.instantiate()
		grid_container.add_child(item_instancia)

		item_instancia.setup(item, get_selected_quantity(item.name))
		item_cards[item.name] = item_instancia

		item_instancia.connect("adicionar", Callable(self, "_on_add"))
		item_instancia.connect("remover", Callable(self, "_on_remove"))
	_refresh_bonus_label()
	refresh_stock_ui()

func _on_add(nome):
	increase_selected_quantity(str(nome))

func _on_remove(nome):
	decrease_selected_quantity(str(nome))

func increase_selected_quantity(item_id: String) -> void:
	var current_amount = get_selected_quantity(item_id)
	var remaining_capacity = get_remaining_capacity(item_id)
	var lot_size := _get_lot_size(item_id)
	if current_amount + lot_size > remaining_capacity:
		_show_message("Já não cabe mais " + item_id + ".")
		return

	selected_quantities[item_id] = current_amount + lot_size
	_clear_message()
	refresh_stock_ui()

func decrease_selected_quantity(item_id: String) -> void:
	var current_amount = get_selected_quantity(item_id)
	if current_amount <= 0:
		return

	var new_amount = current_amount - _get_lot_size(item_id)
	if new_amount <= 0:
		selected_quantities.erase(item_id)
	else:
		selected_quantities[item_id] = new_amount
	_clear_message()
	refresh_stock_ui()

func get_selected_quantity(item_id: String) -> int:
	return max(0, int(selected_quantities.get(item_id, 0)))

func get_remaining_capacity(item_id: String) -> int:
	return StockSystem.get_available_space(item_id)

func get_preco(nome):
	for item in estoque:
		if item.name == nome:
			return item.acquisition_cost
	return 0

func _get_lot_size(nome: String) -> int:
	for item in estoque:
		if item.name == nome:
			return item.lot_size
	return 1

func calculate_total_purchase_cost() -> int:
	var total_preco = 0
	selected_quantities = _sanitize_selected_quantities()

	for nome in selected_quantities:
		total_preco += int(selected_quantities[nome]) * int(get_preco(str(nome)))

	return total_preco

func calculate_purchase_total() -> int:
	return calculate_total_purchase_cost()

func build_purchase_list_text() -> String:
	selected_quantities = _sanitize_selected_quantities()
	var lines: Array[String] = []
	var total = 0

	for item in estoque:
		var item_id = str(item.name)
		var quantity = get_selected_quantity(item_id)
		if quantity <= 0:
			continue

		var subtotal = int(item.acquisition_cost) * quantity
		total += subtotal
		lines.append("%s x%d - R$ %d" % [item.name, quantity, subtotal])

	if lines.is_empty():
		return "Nada selecionado ainda."

	return "%s\n\nTotal: R$ %d" % ["\n".join(lines), total]

func atualizar_ui():
	refresh_stock_ui()

func refresh_stock_ui() -> void:
	var total_itens = 0
	selected_quantities = _sanitize_selected_quantities()

	for nome in selected_quantities:
		total_itens += int(selected_quantities[nome])
		if item_cards.has(nome) and is_instance_valid(item_cards[nome]):
			item_cards[nome].set_selected_quantity(int(selected_quantities[nome]))

	for nome in item_cards:
		if not selected_quantities.has(nome) and is_instance_valid(item_cards[nome]):
			item_cards[nome].set_selected_quantity(0)

	botao_comprar.text = "COMPRAR"
	botao_comprar.disabled = total_itens == 0
	limpar_button.disabled = total_itens == 0
	refresh_purchase_summary()
	_refresh_bonus_label()
	_refresh_money_label()

func refresh_purchase_summary() -> void:
	if purchase_summary_label == null:
		return
	purchase_summary_label.text = build_purchase_list_text()

func _on_comprar_pressed() -> void:
	confirm_purchase()

func _on_limpar_pressed() -> void:
	selected_quantities.clear()
	_clear_message()
	refresh_stock_ui()

func confirm_purchase() -> void:
	selected_quantities = _sanitize_selected_quantities()
	var total_preco = calculate_total_purchase_cost()

	if total_preco <= 0:
		_show_message("Escolhe pelo menos um item antes de comprar.")
		refresh_stock_ui()
		return

	var purchase := {}
	for item in estoque:
		var amount := get_selected_quantity(str(item.name))
		if amount > 0:
			purchase[item.code] = amount

	var result := StockSystem.try_buy_stock(purchase)
	if not result.get("ok", false):
		_show_message(str(result.get("mensagem", result.get("erro", "Compra cancelada."))))
		refresh_stock_ui()
		return

	selected_quantities.clear()
	_show_message("Compra concluída.")
	draw_estoque(StockSystem.get_stock())
	refresh_purchase_summary()
	call_deferred("_refresh_money_label")

func _sanitize_selected_quantities() -> Dictionary:
	var valid_quantities := {}
	for nome in selected_quantities:
		var lot_size := _get_lot_size(str(nome))
		var amount = min(max(0, int(selected_quantities[nome])), StockSystem.get_available_space(str(nome)))
		amount -= amount % lot_size
		if amount > 0:
			valid_quantities[str(nome)] = amount
	return valid_quantities

func _refresh_bonus_label() -> void:
	if bonus_label == null or bonus_banner == null:
		return
	var is_full := StockSystem.is_stock_full()
	bonus_banner.visible = is_full
	bonus_label.visible = is_full

func _show_message(text: String) -> void:
	if aviso_label == null or message_panel == null:
		return
	aviso_label.text = text
	message_panel.visible = true
	aviso_label.visible = true
	EventBus.emit_signal("send_debug", text)

func _clear_message() -> void:
	if aviso_label == null or message_panel == null:
		return
	aviso_label.text = ""
	message_panel.visible = false
	aviso_label.visible = false

func _on_money_changed(_amount: int) -> void:
	_refresh_money_label()

func _refresh_money_label() -> void:
	if money_label == null:
		return
	money_label.text = "GRANA: R$ %d" % int(GameManager.money)

func _load_receipt_note_texture() -> void:
	if purchase_summary_panel == null:
		return
	var note_image := Image.new()
	if note_image.load("res://assets/sprites/nota.png") != OK:
		push_warning("Nao foi possivel carregar a textura da nota do estoque.")
		return
	purchase_summary_panel.texture = ImageTexture.create_from_image(note_image)
