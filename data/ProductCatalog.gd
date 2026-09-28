class_name ProductCatalog
extends RefCounted

const PRODUCTS := {
	101: {"nome": "Arroz", "preco": 3, "custo": 3, "capacidade": 20, "lote": 5, "minimo": 5, "alvo": 15, "imagem": "res://assets/sprites/stock/arroz.png"},
	102: {"nome": "Feijao", "preco": 4, "custo": 4, "capacidade": 20, "lote": 5, "minimo": 5, "alvo": 15, "imagem": "res://assets/sprites/stock/feijao.png"},
	103: {"nome": "Farinha", "preco": 4, "custo": 4, "capacidade": 20, "lote": 5, "minimo": 5, "alvo": 15, "imagem": "res://assets/sprites/stock/farinha.png"},
	104: {"nome": "Morango", "preco": 5, "custo": 5, "capacidade": 20, "lote": 5, "minimo": 5, "alvo": 15, "imagem": "res://assets/sprites/stock/morango.png"},
	105: {"nome": "Uva", "preco": 5, "custo": 5, "capacidade": 20, "lote": 5, "minimo": 5, "alvo": 15, "imagem": "res://assets/sprites/stock/uva.png"},
	106: {"nome": "Chocolate", "preco": 6, "custo": 6, "capacidade": 20, "lote": 5, "minimo": 5, "alvo": 15, "imagem": "res://assets/sprites/stock/chocolate.png"}
}

static func snapshot() -> Dictionary:
	return PRODUCTS.duplicate(true)

static func validate() -> Dictionary:
	var seen_names := {}
	for raw_code in PRODUCTS:
		if not raw_code is int or int(raw_code) <= 0:
			return _error("Codigo de produto invalido: %s." % str(raw_code))
		var product: Dictionary = PRODUCTS[raw_code]
		var name := str(product.get("nome", ""))
		if name.is_empty() or seen_names.has(name):
			return _error("Nome de produto ausente ou duplicado: %s." % name)
		seen_names[name] = true
		var capacity := int(product.get("capacidade", 0))
		var lot := int(product.get("lote", 0))
		var minimum := int(product.get("minimo", -1))
		var target := int(product.get("alvo", -1))
		if capacity <= 0 or lot <= 0:
			return _error("Capacidade e lote de %s precisam ser maiores que zero." % name)
		if minimum < 0 or minimum > target or target > capacity:
			return _error("Os limites de estoque de %s sao invalidos." % name)
		if float(product.get("preco", -1)) < 0.0 or float(product.get("custo", -1)) < 0.0:
			return _error("Os valores financeiros de %s nao podem ser negativos." % name)
	return {"ok": true}

static func _error(message: String) -> Dictionary:
	return {"ok": false, "erro": message}
