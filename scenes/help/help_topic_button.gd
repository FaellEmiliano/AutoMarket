extends Button

signal topic_selected(topic_id: String)

var topic_id := ""
var _topic_title := ""
var _locked_reason := ""
var _unlocked := true
var _selected := false

func _ready() -> void:
	pressed.connect(_on_pressed)

func setup(topic: Dictionary, unlocked: bool, selected: bool, locked_reason: String) -> void:
	topic_id = str(topic.get("id", ""))
	_topic_title = str(topic.get("title", "Tópico"))
	_locked_reason = locked_reason
	_unlocked = unlocked
	_selected = selected
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 48)
	tooltip_text = "Disponível" if _unlocked else locked_reason
	_update_visuals()

func set_selected(selected: bool) -> void:
	_selected = selected
	_update_visuals()

func set_unlocked(unlocked: bool, locked_reason: String) -> void:
	_unlocked = unlocked
	_locked_reason = locked_reason
	_update_visuals()

func _on_pressed() -> void:
	topic_selected.emit(topic_id)

func _update_visuals() -> void:
	var marker := "◆ " if _selected else "  "
	text = "%s%s" % [marker, _topic_title.replace(" — ", "\n   ")]
	tooltip_text = "Disponível" if _unlocked else "Bloqueado: %s" % _locked_reason

	if _selected and _unlocked:
		theme_type_variation = &"HelpTopicSelectedButton"
	elif _selected:
		theme_type_variation = &"HelpTopicLockedSelectedButton"
	elif _unlocked:
		theme_type_variation = &"HelpTopicButton"
	else:
		theme_type_variation = &"HelpTopicLockedButton"
