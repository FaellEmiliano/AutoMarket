extends Node

const HelpMenuScene = preload("res://scenes/help/help_menu.tscn")
const HelpTopicsData = preload("res://data/HelpTopics.gd")
const HelpProgressData = preload("res://systems/HelpProgress.gd")
const UpgradeData = preload("res://data/UpgradeData.gd")
const LexerScript = preload("res://interpreter/python_like/lexer/python_like_lexer.gd")
const ParserScript = preload("res://interpreter/python_like/parser/python_like_parser.gd")
const ExecutorScript = preload("res://interpreter/python_like/runtime/python_like_executor.gd")
const FakeBridge = preload("res://tests/fake_python_like_automarket_bridge.gd")

func _ready() -> void:
	FeatureManager.reset_progression()

	var initial_topics := HelpProgressData.get_visible_topics(HelpTopicsData.TOPICS)
	var initial_ids := _topic_ids(initial_topics)
	for required_id in ["terminal", "sensor", "stock", "python_blocks", "python_lists", "python_dicts", "python_if", "python_loops", "input", "product_table", "send", "print", "wait", "stock_query", "budget", "stock_buy", "automation"]:
		assert(initial_ids.has(required_id), "Guia inicial ausente: %s" % required_id)
	for hidden_id in ["change_client", "promotions", "promotions_api", "discount", "sentinel_client", "delivery_overview"]:
		assert(not initial_ids.has(hidden_id), "Guia legado apareceu: %s" % hidden_id)
	assert(initial_ids.size() == 17, "A ajuda inicial deve incluir conceitos, comandos e desafios disponíveis")
	var categories := {}
	for topic in HelpProgressData.get_active_topics(HelpTopicsData.TOPICS):
		categories[str(topic.get("category", ""))] = true
	assert(categories.size() == 3, "A ajuda ativa deve manter conceitos, comandos e desafios")
	for category in ["Aprender a programar", "Comandos do jogo", "Desafios do mercado"]:
		assert(categories.has(category), "Seção ausente: %s" % category)
	var all_topic_ids := _topic_ids(HelpTopicsData.TOPICS)
	var unique_ids := {}
	for id in all_topic_ids:
		assert(not unique_ids.has(id), "ID duplicado na ajuda: %s" % id)
		unique_ids[id] = true

	var help_menu := HelpMenuScene.instantiate()
	add_child(help_menu)
	help_menu.open_menu()
	assert(help_menu.visible, "Menu não abriu")
	assert(not get_tree().paused, "Menu de ajuda pausou a execução do jogo")
	var body_label := help_menu.get_node("%BodyLabel") as RichTextLabel
	assert(body_label.get_theme_font_size("normal_font_size") >= 14, "O texto principal deve ter tamanho confortável para leitura")
	var sidebar := help_menu.get_node("WindowFrame/OuterMargin/Layout/Pages/SidebarFrame") as Control
	var page := help_menu.get_node("WindowFrame/OuterMargin/Layout/Pages/PageFrame") as Control
	help_menu.open_topic("input")
	assert(body_label.get_parsed_text().contains('{"carrinho": {101: 2, 102: 1}}'), "input() deve mostrar o pedido literal")
	assert(body_label.text.contains("uma vez por atendimento"), "A ajuda deve explicar que input() consome a entrada")
	help_menu.open_topic("product_table")
	assert(body_label.get_parsed_text().contains('produtos[101]["preco"]'), "O catálogo deve explicar o dicionário aninhado")
	help_menu.open_topic("promotions_api")
	assert(body_label.text.contains("Sistema de promoções") and not body_label.text.contains("leve_pague"),
		"Página bloqueada deve mostrar o upgrade sem revelar seu conteúdo")
	assert(help_menu.get("_topic_buttons").has("promotions_api"), "Comando futuro deve permanecer na navegação")
	help_menu.open_topic("input")
	for resolution in [Vector2i(960, 540), Vector2i(1152, 648), Vector2i(1280, 720)]:
		get_window().size = resolution
		await get_tree().process_frame
		await get_tree().process_frame
		var viewport_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		var window_frame := help_menu.get_node("WindowFrame") as Control
		assert(viewport_rect.encloses(window_frame.get_global_rect()), "A ajuda deve caber em %s" % resolution)
		assert(page.size.x > sidebar.size.x, "O artigo deve ter mais largura que a navegação em %s" % resolution)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://help_%dx%d.png" % [resolution.x, resolution.y])

	help_menu.close_menu()
	UpgradeManager.upgrade_comprado.emit("lang_if")
	assert(help_menu.visible, "O sinal legado não deve quebrar a ajuda")
	assert(help_menu.get("_selected_topic_id") == initial_ids[0], "Tópico legado deve voltar ao primeiro guia ativo")

	UpgradeManager.upgrade_comprado.emit("gameplay_stock")
	assert(help_menu.get("_selected_topic_id") == "stock", "Upgrade de estoque não abriu o tópico principal de estoque")
	var all_ids := _topic_ids(help_menu.get("_visible_topics"))
	assert(all_ids.has("stock"), "Tópico de estoque não foi desbloqueado")
	var stock_body := help_menu.get_node("%BodyLabel") as RichTextLabel
	assert(stock_body.text.contains("recompensa de cada atendimento vale 1,5x"), "Ajuda de estoque não explicou o bônus sem alterar o total")
	assert(stock_body.text.contains("buy_stock") and stock_body.text.contains("get_stock"), "Guia de estoque não consolidou os comandos")
	DeliverySystem.unlock(false)
	var delivery_ids := _topic_ids(help_menu.get("_visible_topics"))
	assert(delivery_ids.has("delivery_overview") and delivery_ids.size() == initial_ids.size() + 6,
		"Delivery libera conceitos, três comandos e o desafio de navegação")
	for id in ["delivery_matrix", "delivery_search"]:
		assert(help_menu.call("_find_topic", id).category == "Aprender a programar", "Conceitos do delivery devem ficar em Aprender a programar")
	for id in ["delivery_api", "delivery_map_api", "delivery_route_api"]:
		assert(help_menu.call("_find_topic", id).category == "Comandos do jogo", "API do delivery deve ficar em Comandos do jogo")
	assert(help_menu.call("_find_topic", "delivery_overview").category == "Desafios do mercado", "Objetivo do delivery deve ficar nos desafios")
	FeatureManager.unlock_feature(FeatureManager.FEATURE_CHANGE)
	var change_ids := _topic_ids(help_menu.get("_visible_topics"))
	assert(change_ids.has("change_client"), "A ajuda de troco deve aparecer após o upgrade.")
	var change_topic: Dictionary = help_menu.call("_find_topic", "change_client")
	assert(change_topic["text"].contains("pedido[\"pagamento\"]") and not change_topic["text"].contains("-1"),
		"A ajuda ativa deve explicar o pagamento no pedido, sem sentinela.")
	FeatureManager.unlock_feature(FeatureManager.FEATURE_DISCOUNT)
	var promotion_ids := _topic_ids(help_menu.get("_visible_topics"))
	assert(promotion_ids.has("promotions"), "A ajuda de promocoes deve aparecer apos o upgrade.")
	var promotion_topic: Dictionary = help_menu.call("_find_topic", "promotions")
	assert(promotion_topic["text"].contains("promocoes()") and not promotion_topic["text"].contains("send(total"),
		"A ajuda de promocoes deve explicar a regra sem fornecer o programa completo.")
	help_menu.open_topic("promotions_api")
	assert(body_label.text.contains("leve_pague") and body_label.text.contains("percentual") and not body_label.text.contains("Conteúdo bloqueado"),
		"O comando promocional deve liberar o conteúdo após o upgrade")
	for topic in HelpProgressData.get_active_topics(HelpTopicsData.TOPICS):
		help_menu.open_topic(str(topic.id))
		assert(not body_label.get_parsed_text().is_empty(), "Página vazia: %s" % topic.id)
		var readable_source := str(topic.text)
		for tag in ["[b]", "[/b]", "[u]", "[/u]", "[code]", "[/code]"]:
			readable_source = readable_source.replace(tag, "")
		assert(body_label.get_parsed_text() == readable_source,
			"A apresentação deve preservar o texto e o código copiável: %s" % topic.id)

	help_menu.call("_show_topic", "stock")
	var hint_panel := help_menu.get_node("%HintPanel") as PanelContainer
	var hint_label := help_menu.get_node("%HintLabel") as RichTextLabel
	assert(not hint_panel.visible, "A dica apareceu sem o jogador pedir")
	help_menu.call("_toggle_hint")
	assert(hint_panel.visible, "O botão não revelou a dica")
	assert(hint_label.text.contains("orçamento"), "A dica de estoque esperada não foi exibida")
	assert(not hint_label.text.contains("int main"), "A dica entregou um código completo")

	help_menu.close_menu()
	assert(not help_menu.visible, "Menu não fechou")
	_test_documentation_examples()

	print("HELP_MENU_SMOKE_TEST_OK")
	await get_tree().create_timer(5).timeout
	get_tree().quit()

func _topic_ids(topics: Array) -> Array:
	var ids: Array = []
	for topic in topics:
		ids.append(str(topic.get("id", "")))
	return ids

func _test_documentation_examples() -> void:
	# Execute the snippets displayed to the player, not duplicated test versions.
	var code_blocks := RegEx.new()
	code_blocks.compile("\\[code\\]([\\s\\S]*?)\\[/code\\]")
	for topic in HelpProgressData.get_active_topics(HelpTopicsData.TOPICS):
		if topic.category == "Desafios do mercado":
			continue
		var source := "valor = 2\ntotal = 10\n"
		for block in code_blocks.search_all(str(topic.text)):
			source += block.get_string(1) + "\n"
		var bridge := FakeBridge.new()
		bridge.set_response("enviar_rota", true)
		bridge.set_response("mapa_entrega", [[1, 1, 1], [2, 0, 1], [1, 1, 1]])
		bridge.set_response("entrega_atual", {"id": 1, "origem": [0, 0], "destino": [2, 2]})
		bridge.set_response("input", {"carrinho": {101: 2, 102: 1}})
		bridge.set_response("tabela_produtos", ProductCatalog.snapshot())
		bridge.set_response("get_stock", {101: 5, 102: 10, 103: 0, 104: 5, 105: 0, 106: 5})
		bridge.set_response("get_budget", 30)
		bridge.set_response("buy_stock", {"ok": true, "total": 55, "saldo": 45})
		bridge.set_response("send", true)
		bridge.set_response("sensor", true)
		bridge.set_response("promocoes", [{"tipo": "leve_pague", "produto": 104, "leve": 3, "pague": 2}, {"tipo": "percentual", "produto": 102, "desconto": 0.40}])
		bridge.set_suspension("wait", 1.0)
		var lexer := LexerScript.new(source)
		var tokens := lexer.tokenize()
		assert(lexer.errors.is_empty(), "Erro léxico em exemplo: %s" % topic.id)
		var parser := ParserScript.new(tokens)
		var program := parser.parse()
		assert(parser.errors.is_empty(), "Erro de sintaxe em exemplo: %s — %s" % [topic.id, parser.errors])
		var executor := ExecutorScript.new()
		executor.set_automarket_bridge(bridge)
		executor.load_program(program)
		var steps := 0
		while executor.is_active() and steps < 10000:
			if executor.is_suspended():
				var request = executor.pending_suspension()
				assert(executor.resume_suspension(int(request.token)), "Exemplo de wait() deve retomar")
			else:
				executor.step()
			steps += 1
		assert(steps < 10000 and not executor.has_failure() and executor.is_finished(),
			"Exemplo deve concluir sem falha: %s" % topic.id)
		var lines = executor.output_lines()
		match str(topic.id):
			"python_lists":
				assert(lines == ["2", "[2, 3, 4]", "3", "2", "3", "4", "[10, 20, 30]", "None", "30", "10", "[20]"], "Lista deve produzir os valores documentados")
			"python_if":
				assert(lines == ["Poucas unidades", "True"], "Condição deve produzir o ramo documentado")
			"product_table":
				assert(lines == ["3", "6", "15", "30", "True", "True"], "Preço, espaço, custo e lote devem bater com o catálogo real")
			"promotions_api":
				assert(lines[-2] == "leve_pague 104" and lines[-1] == "percentual 102", "Ambos os tipos devem ser acessíveis como lista de dicionários")
	# Check the worked examples against current gameplay prices and rules.
	var catalog := ProductCatalog.snapshot()
	assert(2 * catalog[101]["preco"] + catalog[102]["preco"] == 10, "Exemplo do total deve usar preços reais")
	var promotional_total := PromotionCatalog.calculate_total([
		{"code": 104, "quantity": 7, "unit_price": catalog[104]["preco"]},
		{"code": 101, "quantity": 2, "unit_price": catalog[101]["preco"]},
	], [{"tipo": "leve_pague", "produto": 104, "leve": 3, "pague": 2}])
	assert(promotional_total == 31 and 50 - promotional_total == 19, "Exemplo promocional deve bater com o gameplay")
