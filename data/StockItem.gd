class_name StockItem

var code : int
var name : String
var quantity : int
var sale_price : float
var acquisition_cost : float
var max_quantity : int
var lot_size : int
var minimum_stock : int
var target_stock : int
var icon_path : String

var price : float:
	get:
		return sale_price

func _init(item_code: int, data: Dictionary, qtd := 0):
	code = item_code
	name = str(data["nome"])
	quantity = qtd
	sale_price = float(data["preco"])
	acquisition_cost = float(data["custo"])
	max_quantity = int(data["capacidade"])
	lot_size = int(data["lote"])
	minimum_stock = int(data["minimo"])
	target_stock = int(data["alvo"])
	icon_path = str(data["imagem"])
