class_name PromotionCatalog
extends RefCounted

const ProductCatalogData = preload("res://data/ProductCatalog.gd")
const LEVE_PAGUE_CHANCE := 0.60
const PERCENTUAL_CHANCE := 0.60
const PERCENTUAL_DISCOUNTS := [0.20, 0.30, 0.40]

const FORMATS := [
	{"leve": 2, "pague": 1},
	{"leve": 3, "pague": 2},
	{"leve": 4, "pague": 3}
]


static func validate_rules(rules: Array) -> Dictionary:
	var seen := {}
	for rule in rules:
		if not rule is Dictionary or rule.get("tipo", "") not in ["leve_pague", "percentual"]:
			return {"ok": false, "erro": "Tipo de promocao invalido."}
		if not rule.get("produto") is int:
			return {"ok": false, "erro": "Codigo da promocao deve ser inteiro."}
		var code: int = rule["produto"]
		if not ProductCatalogData.PRODUCTS.has(code):
			return {"ok": false, "erro": "Produto invalido na promocao."}
		if rule["tipo"] == "leve_pague":
			if not rule.get("leve") is int or not rule.get("pague") is int:
				return {"ok": false, "erro": "Quantidades da promocao devem ser inteiras."}
			var take: int = rule["leve"]
			var pay: int = rule["pague"]
			if take < 2 or pay < 1 or pay >= take:
				return {"ok": false, "erro": "Quantidades invalidas na promocao."}
		else:
			var discount: Variant = rule.get("desconto")
			if not (discount is float or discount is int):
				return {"ok": false, "erro": "Desconto deve ser uma fracao numerica."}
			if not is_finite(float(discount)) or float(discount) <= 0.0 or float(discount) >= 1.0 or not PERCENTUAL_DISCOUNTS.has(discount):
				return {"ok": false, "erro": "Desconto deve ser 0.20, 0.30 ou 0.40."}
		if seen.has(code):
			return {"ok": false, "erro": "Promocao duplicada para o mesmo produto."}
		seen[code] = true
	return {"ok": true}


static func validate_configuration() -> Dictionary:
	if ProductCatalogData.PRODUCTS.size() < 2 or FORMATS.is_empty() or PERCENTUAL_DISCOUNTS.is_empty():
		return {"ok": false, "erro": "Catalogo promocional vazio."}
	for code in ProductCatalogData.PRODUCTS:
		for format in FORMATS:
			var result := validate_rules([{"tipo": "leve_pague", "produto": code, "leve": format["leve"], "pague": format["pague"]}])
			if not bool(result.get("ok", false)):
				return result
		for discount in PERCENTUAL_DISCOUNTS:
			var result := validate_rules([{"tipo": "percentual", "produto": code, "desconto": discount}])
			if not bool(result.get("ok", false)):
				return result
	return {"ok": true}


static func generate_rule() -> Dictionary:
	# Compatibility for callers that explicitly request one leve_pague rule.
	var validation := validate_configuration()
	assert(bool(validation.get("ok", false)), str(validation.get("erro", "Promocao invalida.")))
	return generate_leve_pague(ProductCatalogData.PRODUCTS.keys(), _random_source())


static func _random_source(rng: Variant = null) -> Variant:
	# The injected source implements randf() and randi_range(), allowing scripted draws in tests.
	if rng != null:
		return rng
	var source := RandomNumberGenerator.new()
	source.randomize()
	return source


static func generate_leve_pague(eligible_codes: Array, rng: Variant) -> Dictionary:
	assert(not eligible_codes.is_empty())
	var code: int = eligible_codes[rng.randi_range(0, eligible_codes.size() - 1)]
	var format: Dictionary = FORMATS[rng.randi_range(0, FORMATS.size() - 1)]
	return {"tipo": "leve_pague", "produto": code, "leve": format["leve"], "pague": format["pague"]}


static func generate_percentual(eligible_codes: Array, rng: Variant) -> Dictionary:
	assert(not eligible_codes.is_empty())
	var code: int = eligible_codes[rng.randi_range(0, eligible_codes.size() - 1)]
	var discount: float = PERCENTUAL_DISCOUNTS[rng.randi_range(0, PERCENTUAL_DISCOUNTS.size() - 1)]
	return {"tipo": "percentual", "produto": code, "desconto": discount}


static func generate_promotions(rng: Variant = null) -> Array:
	var validation := validate_configuration()
	assert(bool(validation.get("ok", false)), str(validation.get("erro", "Promocao invalida.")))
	var source: Variant = _random_source(rng)
	var take_pay: bool = source.randf() < LEVE_PAGUE_CHANCE
	var percentage: bool = source.randf() < PERCENTUAL_CHANCE
	if not take_pay and not percentage:
		take_pay = source.randi_range(0, 1) == 0
		percentage = not take_pay
	var eligible := ProductCatalogData.PRODUCTS.keys()
	var rules: Array = []
	if take_pay:
		var rule := generate_leve_pague(eligible, source)
		rules.append(rule)
		eligible.erase(rule["produto"])
	if percentage:
		rules.append(generate_percentual(eligible, source))
	assert(bool(validate_rules(rules).get("ok", false)))
	return rules


static func round_money(value: float) -> float:
	# Sum all subtotals first; round the final total and change to cents.
	return round(value * 100.0) / 100.0


static func calculate_total(items: Array, rules: Array) -> float:
	var total := 0.0
	for item in items:
		var code := int(item.get("code", 0))
		var quantity := int(item.get("quantity", 0))
		var price := float(item.get("unit_price", 0.0))
		var subtotal := quantity * price
		for rule in rules:
			if int(rule["produto"]) == code:
				match rule["tipo"]:
					"leve_pague":
						var group_size: int = rule["leve"]
						var charged := floori(float(quantity) / group_size) * int(rule["pague"]) + (quantity % group_size)
						subtotal = charged * price
					"percentual":
						subtotal *= 1.0 - float(rule["desconto"])
				break
		total += subtotal
	return round_money(total)
