extends VBoxContainer

signal collapse_requested
signal stop_all_requested
var text_label: RichTextLabel
var stop_all_button: Button
var clear_button: Button
var collapse_button: Button
const ICON_STOP = preload("res://assets/icons/ide_stop.svg")
const ICON_CLEAR = preload("res://assets/icons/ide_clear.svg")
const ICON_COLLAPSE = preload("res://assets/icons/ide_collapse.svg")

func _ready() -> void:
	custom_minimum_size.y = 96
	var header := HBoxContainer.new()
	add_child(header)
	var title := Label.new()
	title.text = "SAÍDA"
	title.theme_type_variation = &"IDESectionLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	stop_all_button = Button.new()
	stop_all_button.text = "Parar todos"
	stop_all_button.icon = ICON_STOP
	stop_all_button.tooltip_text = "Interromper todos os scripts em execução"
	stop_all_button.pressed.connect(func(): stop_all_requested.emit())
	header.add_child(stop_all_button)
	clear_button = Button.new()
	clear_button.text = "Limpar"
	clear_button.icon = ICON_CLEAR
	clear_button.tooltip_text = "Limpar a apresentação; a próxima atualização do runtime volta a aparecer"
	clear_button.pressed.connect(func(): display_output(""))
	header.add_child(clear_button)
	collapse_button = Button.new()
	collapse_button.text = "Recolher"
	collapse_button.icon = ICON_COLLAPSE
	collapse_button.tooltip_text = "Recolher o painel de saída"
	collapse_button.pressed.connect(func(): collapse_requested.emit())
	header.add_child(collapse_button)
	text_label = RichTextLabel.new()
	text_label.theme_type_variation = &"IDEOutput"
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.selection_enabled = true
	text_label.scroll_following = true
	add_child(text_label)
	EventBus.send_debug.connect(display_output)
	display_output("")

func display_output(value) -> void:
	# send_debug already provides the complete current output, never append a second log.
	var text := str(value)
	text_label.text = text if not text.is_empty() else "A saída do programa aparecerá aqui."

func update_layout(compact: bool) -> void:
	stop_all_button.text = "" if compact else "Parar todos"
	clear_button.text = "" if compact else "Limpar"
	collapse_button.text = "" if compact else "Recolher"
	for control in [stop_all_button, clear_button, collapse_button]:
		control.custom_minimum_size = Vector2(40, 40)
