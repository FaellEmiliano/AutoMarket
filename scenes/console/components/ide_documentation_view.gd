extends ScrollContainer

const Topics = preload("res://data/HelpTopics.gd")
const Progress = preload("res://systems/HelpProgress.gd")
var topic_id := ""
var heading: Label
var category: Label
var body: RichTextLabel
var hint: RichTextLabel
var hint_button: Button
var _column: VBoxContainer

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.use_top_left = false
	margin.add_child(center)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 16)
	center.add_child(_column)
	category = Label.new()
	category.theme_type_variation = &"IDESectionLabel"
	_column.add_child(category)
	heading = Label.new()
	heading.theme_type_variation = &"IDETitle"
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(heading)
	body = _text()
	hint_button = Button.new()
	hint_button.text = "Mostrar dica"
	hint_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hint_button.pressed.connect(_toggle_hint)
	_column.add_child(hint_button)
	hint = _text()
	resized.connect(_resize_column)
	_resize_column()

func _text() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.selection_enabled = true
	_column.add_child(label)
	return label

func _resize_column() -> void:
	_column.custom_minimum_size.x = clampf(size.x - 64, 160, 800)

func show_topic(id: String) -> bool:
	for topic in Topics.TOPICS:
		if str(topic.id) != id:
			continue
		if not Progress.is_requirement_met(topic.get("requirement", "")):
			return false
		topic_id = id
		category.text = str(topic.category).to_upper() + " / DOCUMENTAÇÃO"
		heading.text = str(topic.title)
		body.text = _style_code(str(topic.text))
		hint.text = _style_code(str(topic.get("hint", "")))
		hint.hide()
		hint_button.visible = not hint.text.is_empty()
		hint_button.text = "Mostrar dica"
		scroll_vertical = 0
		return true
	return false

func _toggle_hint() -> void:
	hint.visible = not hint.visible
	hint_button.text = "Ocultar dica" if hint.visible else "Mostrar dica"

func _style_code(text: String) -> String:
	return text.replace("[code]", "[bgcolor=#243139][color=#d5bc80][code]").replace("[/code]", "[/code][/color][/bgcolor]")
