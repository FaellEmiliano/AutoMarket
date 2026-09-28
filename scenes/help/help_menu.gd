extends Control

const HelpTopicsData = preload("res://data/HelpTopics.gd")
const HelpProgressData = preload("res://systems/HelpProgress.gd")
const HelpTopicButton = preload("res://scenes/help/help_topic_button.gd")
const UpgradeData = preload("res://data/UpgradeData.gd")

@onready var topics_container: VBoxContainer = %TopicsContainer
@onready var progress_label: Label = %ProgressLabel
@onready var category_label: Label = %CategoryLabel
@onready var title_label: Label = %TitleLabel
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

func _ready() -> void:
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
	category_label.text = str(topic.get("category", ""))
	title_label.text = str(topic.get("title", ""))

	if not HelpProgressData.is_requirement_met(topic.get("requirement", "")):
		status_label.text = "FECHADO"
		status_label.theme_type_variation = &"WarningLabel"
		body_label.text = _get_locked_body(topic)
		_current_hint = ""
		spoiler_button.visible = false
		_hide_hint()
		_reset_article_scroll()
		return

	status_label.text = "LIBERADO"
	status_label.theme_type_variation = &"SuccessLabel"
	body_label.text = str(topic.get("text", ""))

	_current_hint = str(topic.get("hint", ""))
	spoiler_button.visible = not _current_hint.is_empty()
	_hide_hint()
	_reset_article_scroll()

func _toggle_hint() -> void:
	if hint_panel.visible:
		_hide_hint()
		return

	hint_label.text = _current_hint
	hint_panel.visible = true
	spoiler_button.text = "FECHAR DICA"

func _hide_hint() -> void:
	hint_panel.visible = false
	hint_label.text = ""
	spoiler_button.text = "VER DICA"

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
	progress_label.text = "GUIAS %d/%d" % [
		_visible_topics.size(),
		HelpProgressData.get_active_topics(HelpTopicsData.TOPICS).size(),
	]

func _reset_article_scroll() -> void:
	article_scroll.scroll_vertical = 0
	article_scroll.set_deferred("scroll_vertical", 0)

func _get_locked_body(topic: Dictionary) -> String:
	return """[b]Ainda não chegou essa parte[/b]
Esse assunto aparece quando você liberar: [b]%s[/b].

[b]Por enquanto[/b]
Usa as páginas que já estão abertas. Quando o upgrade chegar, essa daqui aparece completa.""" % _get_locked_reason(topic)

func _get_locked_reason(topic: Dictionary) -> String:
	var requirement := str(topic.get("requirement", ""))
	match requirement:
		"troco":
			return "cliente com troco"
		"sentinela", "loops":
			return "compras variáveis"
		"desconto":
			return "desconto acima de R$50"
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
