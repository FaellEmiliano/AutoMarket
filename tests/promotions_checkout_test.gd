extends Node
const Catalog = preload("res://data/PromotionCatalog.gd")
const Runtime = preload("res://systems/ScriptRuntimeManager.gd")
const GameScene = preload("res://scenes/game/game.tscn")
const ClientSpawnerScript = preload("res://systems/ClientSpawner.gd")
const A = {"tipo":"leve_pague","produto":104,"leve":3,"pague":2}
const B = {"tipo":"leve_pague","produto":101,"leve":2,"pague":1}
const C = {"tipo":"leve_pague","produto":103,"leve":4,"pague":3}
const P = {"tipo":"percentual","produto":102,"desconto":0.40}
const BOTH = [{"tipo":"leve_pague","produto":105,"leve":3,"pague":2}, P]
const SOLUTION = """produtos = tabela_produtos()
regras = promocoes()
pedido = input()
total = 0
for codigo in pedido["carrinho"]:
    quantidade = pedido["carrinho"][codigo]
    preco = produtos[codigo]["preco"]
    subtotal = quantidade * preco
    for regra in regras:
        if regra["produto"] == codigo:
            if regra["tipo"] == "leve_pague":
                pagas = (quantidade // regra["leve"]) * regra["pague"] + quantidade % regra["leve"]
                subtotal = pagas * preco
            elif regra["tipo"] == "percentual":
                subtotal = subtotal * (1 - regra["desconto"])
    total += subtotal
send(total, pedido["pagamento"] - total)
"""
class FakeClient extends Node:
	signal result_closed
	var result_ok := false
	var result_values: Array = []
	func show_request_dialog(_challenge) -> void: pass
	func show_result_dialog(ok: bool, values: Array) -> void:
		result_ok = ok
		result_values = values.duplicate(true)

class Draws extends RefCounted:
	var floats: Array
	var integers: Array
	var float_calls := 0
	var integer_calls := 0
	func _init(type_draws: Array, choices: Array = []) -> void:
		floats = type_draws.duplicate()
		integers = choices.duplicate()
	func randf() -> float:
		float_calls += 1
		assert(not floats.is_empty(), "Unexpected type draw")
		return float(floats.pop_front())
	func randi_range(minimum: int, maximum: int) -> int:
		integer_calls += 1
		var choice: int = minimum if integers.is_empty() else int(integers.pop_front())
		assert(choice >= minimum and choice <= maximum, "Choice must be in eligible range")
		return choice
var failures: Array[String] = []
var sales := 0
var spawner

func _ready() -> void:
	EventBus.update_money.connect(func(amount): GameManager.money += amount)
	TransactionManager.sale_completed.connect(func(_sale): sales += 1)
	spawner = ClientSpawnerScript.new()
	spawner.spawn_bloqueado = true
	EventBus.end_client.connect(spawner.end_client)
	Saves._carregar_sistemas(Saves.create_new_save_data())
	var initial := ChallengeSystem.generate_stock_challenge([P])
	check(initial.promotions.is_empty(), "Antes do upgrade, até o hook forçado mantém snapshot vazio.")
	var initial_client := FakeClient.new()
	add_child(initial_client)
	check(TransactionManager.start_transaction(initial_client,initial), "Atendimento antes do upgrade inicia.")
	check((await script("before", "print(len(promocoes()))\n"))["output"].contains("[before] 0"), "API vazia antes do upgrade.")
	initial_client.result_closed.emit()
	initial_client.queue_free()
	check(UpgradeManager.get_upgrades_visiveis().map(func(u): return u["id"]) == ["gameplay_change"], "Troco é primeiro upgrade.")
	for _i in range(3): serve(make_challenge([item(101,1)]))
	UpgradeManager.comprar_upgrade("gameplay_change")
	check(GameManager.money == 132, "Troco custa R$120.")
	serve(make_challenge([item(101,1)]))
	check((await script("restock", "buy_stock({101: 5})\n"))["ok"], "Reposição por script.")
	for _i in range(6): serve(make_challenge([item(101,1)]))
	check(GameManager.money == 313 and UpgradeManager.can_buy("gameplay_promotions"), "Economia permite segundo upgrade.")
	UpgradeManager.comprar_upgrade("gameplay_promotions")
	check(GameManager.money == 153 and FeatureManager.has_feature(FeatureManager.FEATURE_DISCOUNT), "Compra de Promoções ativa feature.")
	var saved: Dictionary = Saves._montar_save_data()
	UpgradeManager.load_save_data({"comprados":{"gameplay_change":true}})
	check(not FeatureManager.has_feature(FeatureManager.FEATURE_DISCOUNT), "Save sem Promoções desativa feature.")
	UpgradeManager.load_save_data(saved["shop"])
	check(FeatureManager.has_feature(FeatureManager.FEATURE_DISCOUNT), "Save restaura feature de Promoções.")
	check((await script("restock_after_upgrade", "buy_stock({101: 5})\n"))["ok"], "Reposição após upgrade mantém o produto elegível disponível.")
	test_catalog()
	test_cart_modes()
	test_percentages_and_money()
	await test_snapshot()
	await test_multi_snapshot()
	await test_sales()
	if failures.is_empty(): print("PROMOTIONS_CHECKOUT_TEST_OK")
	else: push_error("\n".join(failures))
	spawner.free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func test_catalog() -> void:
	check(Catalog.validate_configuration()["ok"], "Combinações geráveis válidas.")
	for code in ProductCatalog.PRODUCTS:
		for fmt in Catalog.FORMATS:
			check(Catalog.validate_rules([{"tipo":"leve_pague","produto":code,"leve":fmt["leve"],"pague":fmt["pague"]}])["ok"], "Produto e formato válidos.")
		for discount in [0.20, 0.30, 0.40]:
			var rule := {"tipo":"percentual","produto":code,"desconto":discount}
			check(Catalog.validate_rules([rule])["ok"], "Percentual em qualquer produto válido.")
			var generated := Catalog.generate_percentual([code], Draws.new([], [0, Catalog.PERCENTUAL_DISCOUNTS.find(discount)]))
			check(generated == rule, "Gerador usa cada produto e desconto oficial.")
	for rules in [[{"tipo":"leve_pague","produto":999,"leve":2,"pague":1}], [{"tipo":"leve_pague","produto":"104","leve":2,"pague":1}], [{"tipo":"leve_pague","produto":104,"leve":1,"pague":0}], [A,A]]:
		check(not Catalog.validate_rules(rules)["ok"], "Inválidos e duplicados rejeitados.")
	for discount in [0, -0.2, 1, 1.2, 0.25, "0.40", true, NAN, INF]:
		check(not Catalog.validate_rules([{"tipo":"percentual","produto":102,"desconto":discount}])["ok"], "Percentual inválido rejeitado.")
	for rules in [[{"tipo":"percentual","produto":999,"desconto":0.4}], [{"tipo":"percentual","produto":"102","desconto":0.4}], [{"tipo":"percentual","produto":102}], [{"tipo":"outro","produto":102}], [P,P], [A,{"tipo":"percentual","produto":104,"desconto":0.4}]]:
		check(not Catalog.validate_rules(rules)["ok"], "Tipos, produtos e duplicatas inválidos rejeitados.")
	for spec in [{"draws":[0.0,0.99],"choices":[],"types":["leve_pague"]}, {"draws":[0.99,0.0],"choices":[],"types":["percentual"]}, {"draws":[0.0,0.0],"choices":[],"types":["leve_pague","percentual"]}, {"draws":[0.99,0.99],"choices":[0],"types":["leve_pague"]}, {"draws":[0.99,0.99],"choices":[1],"types":["percentual"]}, {"draws":[0.60,0.59],"choices":[],"types":["percentual"]}]:
		var draws := Draws.new(spec["draws"],spec["choices"])
		var rules := Catalog.generate_promotions(draws)
		check(rules.map(func(r): return r["tipo"]) == spec["types"] and draws.float_calls == 2, "Dois sorteios independentes e fallback controlados.")
		check(not rules.is_empty() and Catalog.validate_rules(rules)["ok"], "Sempre uma ou duas regras válidas.")
		check(draws.integer_calls == rules.size() * 2 + (1 if spec["draws"] == [0.99,0.99] else 0), "Cada parâmetro sorteado uma vez; conflitos não usam repetição.")
		if rules.size() == 2:
			check(rules[0]["produto"] != rules[1]["produto"], "Produtos distintos sem repetir sorteio.")

func test_cart_modes() -> void:
	for rule in [A,B,C]:
		for mode in [0,1,2]:
			var entries := StockSystem.pick_requestable_items(2,[rule],mode)
			var promoted = entries.filter(func(e): return e["code"] == rule["produto"])
			for e in entries: check(e["quantity"] <= StockSystem.get_stock_snapshot()[e["code"]], "Carrinho respeita estoque.")
			if mode == 0: check(promoted.size() == 1 and promoted[0]["quantity"] == rule["leve"], "Promoção aplicada: %s / %s" % [str(rule), str(entries)])
			elif mode == 1: check(promoted.size() == 1 and promoted[0]["quantity"] < rule["leve"], "Abaixo do limite.")
			else: check(promoted.is_empty(), "Produto ausente.")
	var stock_item = StockSystem.get_stock().filter(func(e): return e.code == C["produto"])[0]
	var old: int = stock_item.quantity
	stock_item.quantity = 2
	check(StockSystem.pick_requestable_items(2,[C],0)[0]["quantity"] <= 2, "Estoque baixo limita carrinho.")
	stock_item.quantity = old
	for modes in [{105:0,102:0}, {105:0,102:2}, {105:2,102:0}, {105:1,102:0}, {105:2,102:2}]:
		var entries := StockSystem.pick_requestable_items(2,BOTH,modes)
		var cart := {}
		for e in entries:
			cart[e["code"]] = e["quantity"]
			check(e["quantity"] > 0 and e["quantity"] <= StockSystem.get_stock_snapshot()[e["code"]], "Duas ofertas respeitam estoque físico.")
		check(cart.has(102) == (modes[102] == 0), "Percentual pode estar presente ou ausente.")
		if modes[105] == 2: check(not cart.has(105), "Leve_pague ausente independentemente do percentual.")
		elif modes[105] == 0: check(cart.get(105) == 3, "Leve_pague aplicado independentemente do percentual.")
		else: check(cart.get(105,0) > 0 and cart[105] < 3, "Abaixo do grupo com percentual ativo.")
	check(StockSystem.pick_requestable_items(2,[P],0).any(func(e): return e["code"] == 102 and e["quantity"] >= 1), "Percentual não exige grupo mínimo.")
	check(not StockSystem.pick_requestable_items(2,[P],2).any(func(e): return e["code"] == 102), "Percentual ausente não afeta carrinho.")

func test_percentages_and_money() -> void:
	for discount in [0.20,0.30,0.40]:
		var rules := [{"tipo":"percentual","produto":102,"desconto":discount}]
		check(Catalog.calculate_total([item(102,3)],rules) == Catalog.round_money(12.0 * (1.0 - discount)), "Percentual afeta todas as unidades.")
		check(Catalog.calculate_total([item(101,2)],rules) == 6.0, "Percentual ausente não afeta outros produtos.")
		check(Catalog.calculate_total([item(102,1),item(101,2)],rules) == Catalog.round_money(4.0 * (1.0 - discount) + 6.0), "Uma unidade basta; outros produtos mantêm preço.")
	check(Catalog.calculate_total([item(102,3),item(105,3)],BOTH) == 17.2, "Exemplo misto soma R$17,20.")
	check(Catalog.calculate_total([item(102,3),item(105,3)],[P,BOTH[0]]) == 17.2, "Total independe da ordem das regras.")
	var entries := [{"code":102,"quantity":1,"unit_price":0.01},{"code":105,"quantity":3,"unit_price":0.003}]
	check(Catalog.calculate_total(entries,BOTH) == 0.01, "Arredonda depois de somar: 0.006 + 0.006 vira 0.01, não 0.02.")
	var challenge := make_challenge(entries,BOTH)
	check(challenge.expected_output == [0.01,9.99] and challenge.order.total == 0.01 and challenge.order.change == 9.99, "Total, pagamento, pedido e troco usam centavos.")
	check(ChallengeSystem.arredondar(17.199999999,2) == 17.2 and Catalog.round_money(20.0 - 17.2) == 2.8, "Erros binários não alteram centavos.")

func test_snapshot() -> void:
	var random_challenge := ChallengeSystem.generate_stock_challenge()
	check(random_challenge.promotions.size() in [1,2] and Catalog.validate_rules(random_challenge.promotions)["ok"], "Produção garante uma ou duas regras válidas.")
	var challenge := ChallengeSystem.generate_stock_challenge(C)
	check(challenge.promotions == [C], "ChallengeData guarda snapshot forçado.")
	var client := FakeClient.new()
	add_child(client)
	check(TransactionManager.start_transaction(client,challenge), "Atendimento inicia.")
	var response: Dictionary = await script("snapshot", "a = promocoes()\na[0][\"leve\"] = 999\nprint(promocoes()[0][\"leve\"])\n")
	check(response["ok"] and response["output"].contains("[snapshot] 4") and challenge.promotions == [C], "API devolve cópia estável.")
	var game := GameScene.instantiate()
	game.promotion_panel = game.get_node("VBoxContainer/PromotionPanel")
	game.promotion_label = game.get_node("VBoxContainer/PromotionPanel/Margin/PromotionLabel")
	game._update_promotion_panel(challenge)
	check(game.promotion_panel.visible and game.promotion_label.text.contains("Farinha") and game.promotion_label.text.contains("Leve 4, pague 3"), "UI mostra snapshot.")
	game._on_client_ended(false)
	check(not game.promotion_panel.visible, "Painel oculto entre clientes.")
	var next := ChallengeSystem.generate_stock_challenge(B)
	game._on_context_updated(next)
	check(game.promotion_label.text.contains("Arroz") and game.promotion_label.text.contains("Leve 2, pague 1"), "Painel troca junto com o contexto do próximo cliente.")
	game.free()
	check(TransactionManager.submit(challenge.expected_output.duplicate()), "Venda com snapshot conclui.")
	client.result_closed.emit()
	client.queue_free()
	check(next.promotions == [B] and challenge.promotions == [C], "Novo cliente recebe outro snapshot.")

func test_multi_snapshot() -> void:
	var game := GameScene.instantiate()
	game.promotion_panel = game.get_node("VBoxContainer/PromotionPanel")
	game.promotion_label = game.get_node("VBoxContainer/PromotionPanel/Margin/PromotionLabel")
	for rules in [[A],[P],BOTH,[P,BOTH[0]]]:
		var forced: Array = rules.duplicate(true)
		var challenge := ChallengeSystem.generate_stock_challenge(forced)
		check(challenge.promotions == rules, "Hook aceita snapshots completos de cada combinação.")
		forced[0]["produto"] = 999
		check(challenge.promotions == rules, "Snapshot independente da lista forçada.")
		var client := FakeClient.new()
		add_child(client)
		check(TransactionManager.start_transaction(client,challenge), "Atendimento de snapshot inicia.")
		var response: Dictionary = await script("multi_snapshot", "a = promocoes()\nb = promocoes()\nprint(len(a) == len(b))\nfor i in range(len(a)):\n    print(a[i][\"tipo\"] == b[i][\"tipo\"])\n    print(a[i][\"produto\"] == b[i][\"produto\"])\n    if a[i][\"tipo\"] == \"percentual\":\n        print(a[i][\"desconto\"] == b[i][\"desconto\"])\n        a[i][\"desconto\"] = 0.99\n    else:\n        print(a[i][\"leve\"] == b[i][\"leve\"])\n        print(a[i][\"pague\"] == b[i][\"pague\"])\n        a[i][\"leve\"] = 999\na[0][\"produto\"] = 999\nprint(promocoes()[0][\"produto\"])\n")
		check(response["ok"] and response["output"].contains("True") and not response["output"].contains("False") and response["output"].contains(str(rules[0]["produto"])) and challenge.promotions == rules, "Chamadas equivalentes; mutação não altera snapshot.")
		game._update_promotion_panel(challenge)
		check(game.promotion_panel.visible and game.promotion_label.text.begins_with("PROMOÇÃO ATIVA" if rules.size() == 1 else "PROMOÇÕES ATIVAS"), "UI deriva título da quantidade de regras.")
		for rule in rules:
			check(game.promotion_label.text.contains(ProductCatalog.PRODUCTS[rule["produto"]]["nome"]), "UI identifica cada produto do snapshot.")
			check(game.promotion_label.text.contains("40% OFF" if rule["tipo"] == "percentual" else "Leve %d, pague %d" % [rule["leve"],rule["pague"]]), "UI mostra parâmetros de cada tipo.")
		# Close without consuming stock: these checks concern the API, not a sale.
		client.result_closed.emit()
		client.queue_free()
	var hud := game.get_node("VBoxContainer").duplicate()
	add_child(hud)
	await get_tree().process_frame
	var panel: Control = hud.get_node("PromotionPanel")
	var label: Label = hud.get_node("PromotionPanel/Margin/PromotionLabel")
	check(panel.size.y >= label.get_minimum_size().y + 8.0, "Painel expande para duas ofertas sem cortar linhas.")
	for resolution in [Vector2i(1280,720),Vector2i(640,360)]:
		get_window().size = resolution
		await get_tree().process_frame
		check(hud.size.x <= resolution.x and hud.size.y <= resolution.y, "HUD com duas ofertas cabe em %s: %s" % [str(resolution),str(hud.size)])
	hud.queue_free()
	game.free()

func test_sales() -> void:
	for spec in [{"rules":[A],"items":[item(104,3)],"total":10.0},{"rules":[B],"items":[item(101,2)],"total":3.0}, {"rules":[P],"items":[item(102,3),item(101,1)],"total":10.2}, {"rules":BOTH,"items":[item(102,3),item(105,3)],"total":17.2}, {"rules":[P,BOTH[0]],"items":[item(102,3),item(105,3)],"total":17.2}, {"rules":[{"tipo":"percentual","produto":102,"desconto":0.20}],"items":[item(102,1)],"total":3.2}, {"rules":[{"tipo":"percentual","produto":102,"desconto":0.30}],"items":[item(102,1)],"total":2.8}]:
		var rules: Array = spec["rules"]
		var entries: Array = spec["items"]
		for e in entries:
			var stock_item = StockSystem.get_stock().filter(func(s): return s.code == e["code"])[0]
			stock_item.quantity = maxi(stock_item.quantity,e["quantity"])
		var before := StockSystem.get_stock_snapshot()
		var challenge := make_challenge(entries,rules)
		check(challenge.promotions == rules and challenge.expected_output[0] == spec["total"], "Total usa snapshot de todos os tipos.")
		check(challenge.payment == ChallengeSystem._escolher_pagamento(spec["total"]) and challenge.expected_output[1] == Catalog.round_money(challenge.payment - spec["total"]), "Pagamento e troco usam total após todas as ofertas.")
		if rules == [A]:
			var rejected := FakeClient.new()
			add_child(rejected)
			check(TransactionManager.start_transaction(rejected,challenge), "Venda para rejeição inicia.")
			check(not TransactionManager.submit([15,5]), "Preço e troco sem promoção são rejeitados.")
			check(StockSystem.get_stock_snapshot() == before, "Resposta errada não consome estoque.")
			rejected.result_closed.emit()
			rejected.queue_free()
		var client := FakeClient.new()
		add_child(client)
		check(TransactionManager.start_transaction(client,challenge), "Venda inicia.")
		var response: Dictionary = await script("generic",SOLUTION)
		check(response["ok"] and client.result_ok, "Mesmo algoritmo resolve somente leve_pague, somente percentual e ambas.")
		check(is_equal_approx(client.result_values[0],spec["total"]) and is_equal_approx(client.result_values[1],challenge.expected_output[1]), "Executor acessa ambos os contratos e calcula total/troco.")
		for e in entries:
			check(StockSystem.get_stock_snapshot()[e["code"]] == before[e["code"]] - e["quantity"], "Cada produto consome quantidade física integral.")
		check(challenge.promotions == rules, "Venda preserva snapshot.")
		if rules == BOTH:
			check(challenge.payment == 20.0 and challenge.expected_output == [17.2,2.8], "Integração principal: R$17,20, pagamento R$20 e troco R$2,80.")
		client.result_closed.emit()
		client.queue_free()
	check(sales >= 12 and GameManager.money >= 0, "Recompensa sem saldo negativo.")
	check(Catalog.calculate_total([item(104,2)],[A]) == 10.0, "Abaixo do grupo sem desconto.")
	check(Catalog.calculate_total([item(101,2)],[A]) == 6.0, "Produto ausente sem desconto.")
	check(Catalog.calculate_total([item(104,7)],[A]) == 25.0, "Grupos e resto corretos.")
	check(Catalog.calculate_total([item(103,4)],[C]) == 12.0 and Catalog.calculate_total([item(103,3)],[C]) == 12.0, "Leve quatro funciona no limite e abaixo dele.")

func serve(challenge: ChallengeData) -> void:
	var client := FakeClient.new()
	add_child(client)
	check(TransactionManager.start_transaction(client,challenge), "Venda direta inicia.")
	check(TransactionManager.submit(challenge.expected_output.duplicate()), "Venda direta aceita.")
	client.result_closed.emit()
	client.queue_free()

func make_challenge(entries: Array, promotions: Array = []) -> ChallengeData:
	var challenge := ChallengeData.new()
	challenge.type = "estoque"
	challenge.requires_stock = true
	challenge.requested_items = entries.duplicate(true)
	challenge.promotions = promotions.duplicate(true)
	for e in entries:
		challenge.cart[e["code"]] = e["quantity"]
		challenge.price_snapshot[e["code"]] = e["unit_price"]
	if FeatureManager.has_feature(FeatureManager.FEATURE_CHANGE): challenge.payment = 1.0
	ChallengeSystem._finalize_challenge(challenge)
	return challenge

func item(code: int, quantity: int) -> Dictionary:
	var product: Dictionary = ProductCatalog.PRODUCTS[code]
	return {"code":code,"name":product["nome"],"quantity":quantity,"unit_price":float(product["preco"])}

func script(id: String, source: String) -> Dictionary:
	var manager := Runtime.new()
	add_child(manager)
	manager.start_script(id,source,id,null,"python_like")
	var guard := 0
	while manager.is_script_running(id) and guard < 240:
		guard += 1
		await get_tree().process_frame
	var runtime: Dictionary = manager.get_runtime_by_script_id(id)
	var result := {"ok":guard < 240 and runtime.get("status","") == ScriptRuntimeManager.STATUS_FINISHED,"output":str(runtime.get("output",""))}
	manager.queue_free()
	return result

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
