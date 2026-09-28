extends Node

signal stock_purchase_completed(purchase: Dictionary)

const ProductCatalogData = preload("res://data/ProductCatalog.gd")
const ERROR_PRODUCT := "PRODUTO_INVALIDO"
const ERROR_QUANTITY := "QUANTIDADE_INVALIDA"
const ERROR_LOT := "LOTE_INVALIDO"
const ERROR_CAPACITY := "CAPACIDADE_EXCEDIDA"
const ERROR_BUDGET := "ORCAMENTO_INSUFICIENTE"

var estoque: Array = []

func _ready() -> void:
	_initialize_stock()

func _initialize_stock() -> void:
	if not estoque.is_empty():
		return
	var validation := ProductCatalogData.validate()
	assert(bool(validation.get("ok", false)), str(validation.get("erro", "Catalogo invalido.")))
	for code in ProductCatalogData.PRODUCTS:
		estoque.append(StockItem.new(int(code), ProductCatalogData.PRODUCTS[code]))

# API interna: objetos mutaveis usados pela UI e pelos sistemas existentes.
func get_stock() -> Array:
	_initialize_stock()
	return estoque

# Contrato Python-like: copia independente indexada por codigo.
func get_stock_snapshot() -> Dictionary:
	_initialize_stock()
	var snapshot := {}
	for item in estoque:
		snapshot[item.code] = int(item.quantity)
	return snapshot

func get_product_table() -> Dictionary:
	return ProductCatalogData.snapshot()

func get_script_stock_size() -> int:
	return ProductCatalogData.PRODUCTS.size()

func get_budget() -> int:
	return int(GameManager.money)

func try_buy_stock(purchase: Dictionary, source := "manual") -> Dictionary:
	_initialize_stock()
	var before := get_stock_snapshot()
	var budget_before := get_budget()
	var validation := _validate_stock_purchase(purchase)
	if not bool(validation.get("ok", false)):
		return validation
	var normalized: Dictionary = validation["pedido"]
	var total := int(validation["total"])
	for code in normalized:
		_get_item_by_code(int(code)).quantity += int(normalized[code])
	if total > 0:
		EventBus.emit_signal("update_money", -total)
	EventBus.emit_signal("get_estoque")
	Saves.solicitar_save("estoque_comprado")
	stock_purchase_completed.emit({
		"source": str(source),
		"pedido": normalized.duplicate(true),
		"total": total,
		"budget_before": budget_before,
		"budget_after": get_budget(),
		"stock_before": before,
		"stock_after": get_stock_snapshot()
	})
	return {"ok": true, "total": total, "saldo": get_budget()}

func try_buy_stock_from_script(purchase: Variant) -> Dictionary:
	if not purchase is Dictionary:
		return _purchase_error(ERROR_PRODUCT, "buy_stock() espera um dicionario indexado por codigo.")
	return try_buy_stock(purchase.duplicate(true), "script")

func add_item(item_name: String, amount: int) -> int:
	_initialize_stock()
	var item = _get_item_by_name(item_name)
	if item == null:
		return 0
	var added = min(max(amount, 0), get_available_space(item_name))
	item.quantity += added
	return added

func is_stock_full() -> bool:
	_initialize_stock()
	if estoque.is_empty():
		return false
	for item in estoque:
		if item.quantity < item.max_quantity:
			return false
	return true

func is_item_full(item_name: String) -> bool:
	return get_available_space(item_name) <= 0

func get_available_space(item_name: String) -> int:
	_initialize_stock()
	var item = _get_item_by_name(item_name)
	return 0 if item == null else max(0, item.max_quantity - item.quantity)

func has_items(items: Array) -> bool:
	for requested in items:
		var item = _resolve_requested_item(requested)
		if item == null or item.quantity < int(requested.get("quantity", 0)):
			return false
	return true

func has_any_items() -> bool:
	_initialize_stock()
	for item in estoque:
		if item.quantity > 0:
			return true
	return false

func try_emergency_restock() -> bool:
	_initialize_stock()
	if has_any_items() or GameManager.money > 0 or estoque.is_empty():
		return false
	estoque[0].quantity = min(estoque[0].quantity + 1, estoque[0].max_quantity)
	Saves.solicitar_save("estoque_emergencial")
	return true

func consume_items(items: Array, request_save := true) -> bool:
	if not has_items(items):
		return false
	for requested in items:
		var item = _resolve_requested_item(requested)
		if item != null:
			item.quantity -= int(requested.get("quantity", 0))
	if request_save:
		Saves.solicitar_save("estoque_consumido")
	EventBus.emit_signal("get_estoque")
	return true

func pick_requestable_items(max_kinds: int) -> Array:
	_initialize_stock()
	var available = estoque.filter(func(item): return item.quantity > 0)
	if available.is_empty():
		return []
	available.shuffle()
	var requested = []
	for i in range(min(max_kinds, available.size())):
		var item = available[i]
		requested.append({
			"code": item.code,
			"name": item.name,
			"quantity": randi_range(1, min(2, item.quantity)),
			"unit_price": item.sale_price
		})
	return requested

func _resolve_requested_item(requested: Dictionary):
	if requested.has("code") and requested["code"] is int:
		return _get_item_by_code(int(requested["code"]))
	return _get_item_by_name(str(requested.get("name", "")))

func _validate_stock_purchase(purchase: Dictionary) -> Dictionary:
	var normalized := {}
	var total := 0
	for raw_code in purchase:
		if not raw_code is int:
			return _purchase_error(ERROR_PRODUCT, "O codigo do produto precisa ser inteiro.")
		var code := int(raw_code)
		var item = _get_item_by_code(code)
		if item == null:
			return _purchase_error(ERROR_PRODUCT, "O produto %d nao existe." % code)
		var raw_amount = purchase[raw_code]
		if not raw_amount is int:
			return _purchase_error(ERROR_QUANTITY, "A quantidade de %d precisa ser inteira." % code)
		var amount := int(raw_amount)
		if amount < 0:
			return _purchase_error(ERROR_QUANTITY, "A quantidade de %d nao pode ser negativa." % code)
		if amount % item.lot_size != 0:
			return _purchase_error(ERROR_LOT, "A quantidade de %d precisa respeitar lotes de %d." % [code, item.lot_size])
		if item.quantity + amount > item.max_quantity:
			return _purchase_error(ERROR_CAPACITY, "A compra de %d excede a capacidade do produto." % code)
		normalized[code] = amount
		total += amount * int(item.acquisition_cost)
	if total > get_budget():
		return _purchase_error(ERROR_BUDGET, "O saldo e insuficiente para esta compra.")
	return {"ok": true, "pedido": normalized, "total": total}

func _purchase_error(code: String, message: String) -> Dictionary:
	return {"ok": false, "erro": code, "mensagem": message}

func _get_item_by_code(code: int):
	for item in estoque:
		if item.code == code:
			return item
	return null

func _get_item_by_name(item_name: String):
	for item in estoque:
		if item.name == item_name:
			return item
	return null

func _get_quantity(item_name: String) -> int:
	var item = _get_item_by_name(item_name)
	return 0 if item == null else item.quantity

func get_save_data() -> Dictionary:
	_initialize_stock()
	var quantities := {}
	var capacities := {}
	for item in estoque:
		quantities[str(item.code)] = item.quantity
		capacities[str(item.code)] = item.max_quantity
	return {"schema_version": 2, "quantities": quantities, "max_quantities": capacities}

func load_save_data(data: Dictionary) -> void:
	_initialize_stock()
	var quantities = data.get("quantities", {})
	var capacities = data.get("max_quantities", {})
	if not quantities is Dictionary:
		return
	for item in estoque:
		var saved_capacity = _saved_value(capacities, item)
		if saved_capacity != null and (saved_capacity is int or saved_capacity is float):
			item.max_quantity = max(1, int(saved_capacity))
		var saved_quantity = _saved_value(quantities, item)
		if saved_quantity != null and (saved_quantity is int or saved_quantity is float):
			item.quantity = clamp(int(saved_quantity), 0, item.max_quantity)
		else:
			item.quantity = 0

func _saved_value(values: Variant, item):
	if not values is Dictionary:
		return null
	for key in [item.code, str(item.code), item.name]:
		if values.has(key):
			return values[key]
	return null
