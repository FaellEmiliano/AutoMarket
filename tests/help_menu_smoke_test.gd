extends Node

const HelpMenuScene = preload("res://scenes/help/help_menu.tscn")
const HelpTopicsData = preload("res://data/HelpTopics.gd")
const HelpProgressData = preload("res://systems/HelpProgress.gd")
const UpgradeData = preload("res://data/UpgradeData.gd")

func _ready() -> void:
	FeatureManager.reset_progression()

	var initial_topics := HelpProgressData.get_visible_topics(HelpTopicsData.TOPICS)
	var initial_ids := _topic_ids(initial_topics)
	for required_id in ["terminal", "sensor", "stock"]:
		assert(initial_ids.has(required_id), "Guia inicial ausente: %s" % required_id)
	for hidden_id in ["change_client", "discount", "sentinel_client", "delivery_overview"]:
		assert(not initial_ids.has(hidden_id), "Guia legado apareceu: %s" % hidden_id)
	assert(initial_ids.size() == 3, "A experiência ativa deve mostrar somente três guias")
	var categories := {}
	for topic in HelpProgressData.get_active_topics(HelpTopicsData.TOPICS):
		categories[str(topic.get("category", ""))] = true
	assert(categories.size() == 3, "A ajuda ativa deve usar três categorias")

	var help_menu := HelpMenuScene.instantiate()
	add_child(help_menu)
	help_menu.open_menu()
	assert(help_menu.visible, "Menu não abriu")
	assert(not get_tree().paused, "Menu de ajuda pausou a execução do jogo")
	var body_label := help_menu.get_node("%BodyLabel") as RichTextLabel
	assert(body_label.get_theme_font_size("normal_font_size") >= 14, "O texto principal deve ter tamanho confortável para leitura")
	var sidebar := help_menu.get_node("WindowFrame/OuterMargin/Layout/Pages/SidebarFrame") as Control
	var page := help_menu.get_node("WindowFrame/OuterMargin/Layout/Pages/PageFrame") as Control
	for resolution in [Vector2i(960, 540), Vector2i(1152, 648), Vector2i(1280, 720)]:
		get_window().size = resolution
		await get_tree().process_frame
		await get_tree().process_frame
		var viewport_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		var window_frame := help_menu.get_node("WindowFrame") as Control
		assert(viewport_rect.encloses(window_frame.get_global_rect()), "A ajuda deve caber em %s" % resolution)
		assert(page.size.x > sidebar.size.x, "O artigo deve ter mais largura que a navegação em %s" % resolution)

	help_menu.close_menu()
	UpgradeManager.upgrade_comprado.emit("lang_if")
	assert(help_menu.visible, "O sinal legado não deve quebrar a ajuda")
	assert(help_menu.get("_selected_topic_id") == "terminal", "Tópico legado deve voltar ao primeiro guia ativo")

	UpgradeManager.upgrade_comprado.emit("gameplay_stock")
	assert(help_menu.get("_selected_topic_id") == "stock", "Upgrade de estoque não abriu o tópico principal de estoque")
	var all_ids := _topic_ids(help_menu.get("_visible_topics"))
	assert(all_ids.has("stock"), "Tópico de estoque não foi desbloqueado")
	var stock_body := help_menu.get_node("%BodyLabel") as RichTextLabel
	assert(stock_body.text.contains("recompensa de cada atendimento vale 1,5x"), "Ajuda de estoque não explicou o bônus sem alterar o total")
	assert(stock_body.text.contains("buy_stock") and stock_body.text.contains("get_stock"), "Guia de estoque não consolidou os comandos")
	DeliverySystem.unlock(false)
	var delivery_ids := _topic_ids(help_menu.get("_visible_topics"))
	assert(not delivery_ids.has("delivery_overview") and delivery_ids.size() == 3,
		"Delivery legado deve continuar oculto mesmo se a feature existir no save")

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

	print("HELP_MENU_SMOKE_TEST_OK")
	await get_tree().process_frame
	get_tree().quit()

func _topic_ids(topics: Array) -> Array:
	var ids: Array = []
	for topic in topics:
		ids.append(str(topic.get("id", "")))
	return ids
