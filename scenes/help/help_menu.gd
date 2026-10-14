extends Control

const HelpTopicsData = preload("res://data/HelpTopics.gd")
const HelpProgressData = preload("res://systems/HelpProgress.gd")
const HelpTopicButton = preload("res://scenes/help/help_topic_button.gd")
const UpgradeData = preload("res://data/UpgradeData.gd")
const CodeFont = preload("res://assets/fonts/JetBrainsMono-VariableFont_wght.ttf")
const PixelFont = preload("res://assets/fonts/PublicPixel-rv0pA.ttf")

const HEADING_COLOR := "#f4cd86"
const EXAMPLE_COLOR := "#a7ddb5"
const INPUT_COLOR := "#9bd5ef"
const WARNING_COLOR := "#f0ae97"
const CODE_COLOR := "#e6ddca"

@onready var topics_container: VBoxContainer = %TopicsContainer
@onready var progress_label: Label = %ProgressLabel
@onready var category_label: Label = %CategoryLabel
@onready var title_label: Label = %TitleLabel
@onready var command_label: Label = %CommandLabel
@onready var status_label: Label = %StatusLabel
@onready var body_label: RichTextLabel = %BodyLabel
@onready var article_scroll: ScrollContainer = %ArticleScroll
@onready var spoiler_button: Button = %SpoilerButton
@onready var hint_panel: PanelContainer = %HintPanel
@onready var hint_label: RichTextLabel = %HintLabel
@onready var close_button: Button = %CloseButton

var _visible_topics: Array = []
var _selected_topic_id := ""
var _current_hint := ""
var _topic_buttons := {}
var _headings := RegEx.new()
var _code_blocks := RegEx.new()
var _code_tokens := RegEx.new()

func _ready() -> void:
	_configure_article_style()
	_configure_menu_chrome()
	close_button.pressed.connect(close_menu)
	spoiler_button.pressed.connect(_toggle_hint)
	FeatureManager.feature_unlocked.connect(_on_progress_changed)
	UpgradeManager.upgrade_comprado.connect(_on_upgrade_comprado)
	hide()

func open_menu(topic_id := "") -> void:
	if topic_id != "":
		_selected_topic_id = str(topic_id)
	show()
	move_to_front()
	_refresh_topics()
	close_button.grab_focus()

func open_topic(topic_id: String) -> void:
	open_menu(topic_id)

func close_menu() -> void:
	hide()

func _refresh_topics() -> void:
	_visible_topics = HelpProgressData.get_visible_topics(HelpTopicsData.TOPICS)
	_rebuild_topic_list()
	_update_progress_label()

	if _visible_topics.is_empty():
		_clear_content()
		return

	if not _has_topic(_selected_topic_id):
		_selected_topic_id = str(_visible_topics[0].get("id", ""))
	_show_topic(_selected_topic_id)

func _rebuild_topic_list() -> void:
	for child in topics_container.get_children():
		child.free()
	_topic_buttons.clear()

	var topics_by_category := {}
	var category_order := []
	for topic in HelpProgressData.get_active_topics(HelpTopicsData.TOPICS):
		var topic_category := str(topic.get("category", "Outros"))
		if not topics_by_category.has(topic_category):
			topics_by_category[topic_category] = []
			category_order.append(topic_category)
		topics_by_category[topic_category].append(topic)

	for category_name in category_order:
		topics_container.add_child(_create_category_label(category_name))
		for topic in topics_by_category[category_name]:
			var topic_id := str(topic.get("id", ""))
			var unlocked := HelpProgressData.is_requirement_met(topic.get("requirement", ""))
			var topic_button := HelpTopicButton.new()
			topic_button.setup(topic, unlocked, topic_id == _selected_topic_id, _get_locked_reason(topic))
			topic_button.topic_selected.connect(_show_topic)
			topics_container.add_child(topic_button)
			_topic_buttons[topic_id] = topic_button

func _create_category_label(category_name: String) -> Label:
	var label := Label.new()
	label.text = category_name.to_upper()
	label.theme_type_variation = &"CategoryLabel"
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(0, 26)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return label

func _show_topic(topic_id: String) -> void:
	var topic := _find_topic(topic_id)
	if topic.is_empty():
		return

	_selected_topic_id = topic_id
	_refresh_button_selection()
	category_label.text = str(topic.get("category", "")).to_upper()
	var full_title := str(topic.get("title", ""))
	var title_parts := full_title.split(" — ", true, 1)
	title_label.text = title_parts[0]
	title_label.tooltip_text = full_title
	command_label.text = title_parts[1] if title_parts.size() > 1 else ""
	command_label.visible = not command_label.text.is_empty()

	if not HelpProgressData.is_requirement_met(topic.get("requirement", "")):
		status_label.text = "FECHADO"
		status_label.theme_type_variation = &"WarningLabel"
		_style_status(false)
		body_label.text = _format_article(_get_locked_body(topic))
		_current_hint = ""
		spoiler_button.visible = false
		_hide_hint()
		_reset_article_scroll()
		return

	status_label.text = "LIBERADO"
	status_label.theme_type_variation = &"SuccessLabel"
	_style_status(true)
	body_label.text = _format_article(str(topic.get("text", "")))

	_current_hint = str(topic.get("hint", ""))
	spoiler_button.visible = not _current_hint.is_empty()
	_hide_hint()
	_reset_article_scroll()

func _toggle_hint() -> void:
	if hint_panel.visible:
		_hide_hint()
		return

	hint_label.text = _format_article(_current_hint)
	hint_panel.visible = true
	spoiler_button.text = "FECHAR DICA"

func _hide_hint() -> void:
	hint_panel.visible = false
	hint_label.text = ""
	spoiler_button.text = "VER DICA"

func _configure_article_style() -> void:
	# Keep the game's pixel font in its chrome; use reading/code fonts in articles.
	var bold_font := FontVariation.new()
	bold_font.base_font = ThemeDB.fallback_font
	bold_font.variation_embolden = 0.7
	for label in [body_label, hint_label]:
		label.add_theme_font_override("normal_font", ThemeDB.fallback_font)
		label.add_theme_font_override("bold_font", bold_font)
		label.add_theme_font_override("mono_font", CodeFont)
		label.add_theme_font_size_override("normal_font_size", 16)
		label.add_theme_font_size_override("bold_font_size", 16)
		label.add_theme_font_size_override("mono_font_size", 14)
		label.add_theme_color_override("default_color", Color("#e3dbc9"))
	var article_panel := article_scroll.get_parent() as PanelContainer
	var panel_style := article_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	panel_style.bg_color = Color("#1c1914", 0.9)
	panel_style.border_color = Color("#655034")
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	article_panel.add_theme_stylebox_override("panel", panel_style)
	_headings.compile("(?m)^\\[b\\]([^\\n]+?)\\[/b\\]")
	_code_blocks.compile("\\[code\\]([\\s\\S]*?)\\[/code\\]")
	_code_tokens.compile("#[^\\n]*|\"[^\"\\n]*\"|'[^'\\n]*'|\\b(?:if|elif|else|for|while|in|not|and|or|break|continue|def|return|True|False|None)\\b|\\b[0-9]+(?:\\.[0-9]+)?\\b|\\b[A-Za-z_][A-Za-z_0-9]*(?=\\()")

func _configure_menu_chrome() -> void:
	var interior := get_node("WindowFrame/Interior") as Panel
	var interior_style := StyleBoxFlat.new()
	# Blend the original wood texture with a warm tint instead of hiding it.
	interior_style.bg_color = Color("#2a2218", 0.55)
	interior.add_theme_stylebox_override("panel", interior_style)
	var menu_title := get_node("WindowFrame/OuterMargin/Layout/Header/TitleBlock/MenuTitle") as Label
	menu_title.add_theme_font_size_override("font_size", 18)
	var subtitle := get_node("WindowFrame/OuterMargin/Layout/Header/TitleBlock/MenuSubtitle") as Label
	subtitle.add_theme_font_override("font", ThemeDB.fallback_font)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("#cbb997"))
	title_label.add_theme_font_override("font", PixelFont)
	title_label.add_theme_font_size_override("font_size", 14)
	category_label.add_theme_font_override("font", CodeFont)
	category_label.add_theme_font_size_override("font_size", 11)
	category_label.add_theme_color_override("font_color", Color("#c4b08b"))
	command_label.add_theme_font_override("font", CodeFont)
	command_label.add_theme_font_size_override("font_size", 14)
	command_label.add_theme_color_override("font_color", Color("#e0c99c"))
	progress_label.add_theme_font_override("font", CodeFont)
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.add_theme_color_override("font_color", Color("#cbb997"))
	close_button.tooltip_text = "Fechar ajuda · Esc"
	_style_scrollbar(article_scroll)
	_style_scrollbar(get_node("WindowFrame/OuterMargin/Layout/Pages/SidebarFrame/SidebarMargin/SidebarLayout/TopicsScroll"))

func _style_status(unlocked: bool) -> void:
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color("#293322") if unlocked else Color("#3b281c")
	badge.border_color = Color("#60744b") if unlocked else Color("#a57542")
	badge.set_border_width_all(1)
	badge.content_margin_left = 10
	badge.content_margin_right = 10
	badge.content_margin_top = 8
	badge.content_margin_bottom = 8
	status_label.add_theme_stylebox_override("normal", badge)
	status_label.add_theme_font_override("font", CodeFont)
	status_label.add_theme_font_size_override("font_size", 11)

func _style_scrollbar(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#17140f")
	track.content_margin_left = 4
	track.content_margin_right = 4
	bar.add_theme_stylebox_override("scroll", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grip := StyleBoxFlat.new()
		grip.bg_color = Color("#957346") if state == "grabber" else Color("#cba060")
		grip.set_border_width_all(1)
		grip.border_color = Color("#d0ae75")
		grip.content_margin_left = 4
		grip.content_margin_right = 4
		bar.add_theme_stylebox_override(state, grip)

func _format_article(source: String) -> String:
	var formatted := ""
	var cursor := 0
	for block in _code_blocks.search_all(source):
		formatted += _format_prose(source.substr(cursor, block.get_start() - cursor))
		formatted += "[bgcolor=#343027][color=%s][code]%s[/code][/color][/bgcolor]" % [
			CODE_COLOR, _highlight_code(block.get_string(1)),
		]
		cursor = block.get_end()
	return formatted + _format_prose(source.substr(cursor))

func _format_prose(source: String) -> String:
	var formatted := ""
	var cursor := 0
	for heading in _headings.search_all(source):
		formatted += _format_emphasis(source.substr(cursor, heading.get_start() - cursor))
		var title := heading.get_string(1)
		var heading_color := HEADING_COLOR
		if title.begins_with("Exemplo") or title.begins_with("Saída") or title == "Como conferir":
			heading_color = EXAMPLE_COLOR
		elif title.begins_with("Entrada") or title.begins_with("Formato"):
			heading_color = INPUT_COLOR
		elif title in ["Cuidados", "Erros comuns", "Conteúdo bloqueado"]:
			heading_color = WARNING_COLOR
		formatted += "[font_size=19][color=%s][b]%s[/b][/color][/font_size]" % [heading_color, title]
		cursor = heading.get_end()
	return formatted + _format_emphasis(source.substr(cursor))

func _format_emphasis(source: String) -> String:
	return source.replace("[b]", "[color=#f4dfb1][b]").replace("[/b]", "[/b][/color]")

func _highlight_code(source: String) -> String:
	var formatted := ""
	var cursor := 0
	for token in _code_tokens.search_all(source):
		formatted += source.substr(cursor, token.get_start() - cursor)
		var value := token.get_string()
		var token_color := "#bbddeb"
		if value.begins_with("#"):
			token_color = "#9faeb6"
		elif value.begins_with('"') or value.begins_with("'"):
			token_color = "#b8dfad"
		elif value[0].is_valid_int():
			token_color = "#f0cf89"
		elif value in ["if", "elif", "else", "for", "while", "in", "not", "and", "or", "break", "continue", "def", "return", "True", "False", "None"]:
			token_color = "#d5b5ee"
		formatted += "[color=%s]%s[/color]" % [token_color, value]
		cursor = token.get_end()
	return formatted + source.substr(cursor)

func _find_topic(topic_id: String) -> Dictionary:
	for topic in HelpTopicsData.TOPICS:
		if HelpProgressData.is_topic_active(topic) and str(topic.get("id", "")) == topic_id:
			return topic
	return {}

func _has_topic(topic_id: String) -> bool:
	return not _find_topic(topic_id).is_empty()

func _clear_content() -> void:
	_selected_topic_id = ""
	category_label.text = ""
	title_label.text = "Nada liberado ainda"
	command_label.hide()
	status_label.text = ""
	body_label.text = ""
	_current_hint = ""
	spoiler_button.visible = false
	_hide_hint()

func _on_progress_changed(_arg = null, _extra = null) -> void:
	if visible:
		_refresh_topics()

func _on_upgrade_comprado(id: String) -> void:
	_on_progress_changed(id)

	var upgrade_data: Dictionary = UpgradeData.UPGRADES.get(id, {})
	var topic_id := str(upgrade_data.get("help_topic", ""))
	if topic_id.is_empty():
		return
	open_topic(topic_id)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()

func _refresh_button_selection() -> void:
	for topic_id in _topic_buttons:
		var button = _topic_buttons[topic_id]
		if is_instance_valid(button):
			button.set_selected(str(topic_id) == _selected_topic_id)

func _update_progress_label() -> void:
	if progress_label == null:
		return
	progress_label.text = "PÁGINAS %d/%d" % [
		_visible_topics.size(),
		HelpProgressData.get_active_topics(HelpTopicsData.TOPICS).size(),
	]

func _reset_article_scroll() -> void:
	article_scroll.scroll_vertical = 0
	article_scroll.set_deferred("scroll_vertical", 0)

func _get_locked_body(topic: Dictionary) -> String:
	return """[b]Conteúdo bloqueado[/b]
Para acessar esta página, compre o upgrade [b]%s[/b].

[b]Continue aprendendo[/b]
As páginas já liberadas ensinam as estruturas e os comandos disponíveis. O conteúdo desta página será liberado quando a mecânica estiver ativa.""" % _get_locked_reason(topic)

func _get_locked_reason(topic: Dictionary) -> String:
	var requirement := str(topic.get("requirement", ""))
	match requirement:
		"troco":
			return "Troco automático"
		"sentinela", "loops":
			return "compras variáveis"
		"desconto":
			return "Sistema de promoções"
		"estoque":
			return "estoque"
		"if":
			return "if()"
		"sensor":
			return "sensor()"
		"delivery":
			return "Delivery Online"
		"if_sensor":
			return "if() e sensor()"
		"", "start":
			return "início do jogo"
		_:
			return requirement
