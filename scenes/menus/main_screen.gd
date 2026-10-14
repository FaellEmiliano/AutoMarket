extends Control


const REPOSITORY_URL := "https://github.com/FaellEmiliano/jogo-educativo"
const SAVE_PANEL_TEXTURE := preload("res://assets/sprites/menu2.png")
const SAVE_BUTTON_TEXTURE := preload("res://assets/sprites/menu.png")

@onready var save_menu: ColorRect = $SaveMenu
@onready var save_stack: VBoxContainer = $SaveMenu/SavePanel/SaveStack
@onready var save_title: Label = $SaveMenu/SavePanel/SaveStack/SaveTitle
@onready var legacy_save_box: Control = $SaveMenu/SavePanel/SaveStack/SaveBox
@onready var legacy_continue_button: Button = $SaveMenu/SavePanel/SaveStack/Continue
@onready var legacy_new_game_button: Button = $SaveMenu/SavePanel/SaveStack/NewGame
@onready var confirm_new_game: ConfirmationDialog = $ConfirmNewGame
@onready var start_button: TextureButton = $VBoxContainer/Start
@onready var help_button: TextureButton = $VBoxContainer/Help
@onready var github_button: TextureButton = $Github

var _slot_rows := {}
var _delete_slot := 0
var _import_slot := 0
var _confirm_action := ""
var _actions_slot := 0
var _actions_popup: NinePatchRect
var _popup_export_frame: Control
var _popup_import_button: Button
var _popup_export_button: Button
var _student_prompt: ColorRect
var _student_prompt_title: Label
var _student_prompt_description: Label
var _student_name_input: LineEdit
var _student_name_error: Label
var _student_name_counter: Label
var _student_confirm_button: Button
var _pending_student_slot := 0
var _pending_student_is_new := false

const MENU_BUTTON_NORMAL := Color(1, 1, 1, 0.92)
const MENU_BUTTON_HOVER := Color(1.08, 1.08, 1.08, 1)
const MENU_BUTTON_PRESSED := Color(0.82, 0.82, 0.82, 1)


func _ready() -> void:
	StudentIdentity.clear_student()
	Saves.clear_current_slot()
	Saves.migrate_legacy_save_if_needed()
	Saves.save_import_finished.connect(_on_save_import_finished)
	_setup_menu_button_feedback(start_button)
	_setup_menu_button_feedback(help_button)
	_setup_menu_button_feedback(github_button)
	_setup_slot_menu()
	_create_student_name_prompt()
	save_menu.visible = false


func _setup_menu_button_feedback(button: TextureButton) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.self_modulate = MENU_BUTTON_NORMAL
	button.mouse_entered.connect(func(): _refresh_menu_button_feedback(button))
	button.mouse_exited.connect(func(): _refresh_menu_button_feedback(button))
	button.focus_entered.connect(func(): _refresh_menu_button_feedback(button))
	button.focus_exited.connect(func(): _refresh_menu_button_feedback(button))
	button.button_down.connect(func(): _refresh_menu_button_feedback(button, true))
	button.button_up.connect(func(): _refresh_menu_button_feedback(button))


func _refresh_menu_button_feedback(button: TextureButton, pressed := false) -> void:
	if pressed:
		button.self_modulate = MENU_BUTTON_PRESSED
	elif button.has_focus() or button.get_global_rect().has_point(get_global_mouse_position()):
		button.self_modulate = MENU_BUTTON_HOVER
	else:
		button.self_modulate = MENU_BUTTON_NORMAL


func _setup_slot_menu() -> void:
	save_title.text = "ESCOLHER SAVE"
	legacy_save_box.hide()
	legacy_continue_button.hide()
	legacy_new_game_button.hide()
	confirm_new_game.title = "Apagar esse save?"
	confirm_new_game.ok_button_text = "Apagar"
	confirm_new_game.dialog_text = "Tem certeza que quer apagar este slot?"
	confirm_new_game.confirmed.connect(_on_confirm_save_action_confirmed)
	_create_slot_actions_popup()

	for slot in range(1, Saves.SLOT_COUNT + 1):
		var row := _create_slot_row(slot)
		_slot_rows[slot] = row
		save_stack.add_child(row["panel"])
		save_stack.move_child(row["panel"], save_stack.get_child_count() - 2)


func _create_slot_row(slot: int) -> Dictionary:
	var panel := _create_panel_frame(Vector2(0, 96))

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 14.0
	hbox.offset_top = 12.0
	hbox.offset_right = -42.0
	hbox.offset_bottom = -12.0
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var summary := Label.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.theme_type_variation = &"BodyText"
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(summary)

	var actions := HBoxContainer.new()
	actions.custom_minimum_size = Vector2(142, 0)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(actions)

	var main_actions := VBoxContainer.new()
	main_actions.custom_minimum_size = Vector2(142, 0)
	main_actions.add_theme_constant_override("separation", 6)
	actions.add_child(main_actions)

	var play_control := _create_button_frame("JOGAR", Vector2(142, 34))
	var play_button: Button = play_control["button"]
	play_button.pressed.connect(func(): _on_slot_play_pressed(slot))
	main_actions.add_child(play_control["frame"])

	var delete_control := _create_button_frame("APAGAR", Vector2(142, 30), true)
	var delete_button: Button = delete_control["button"]
	delete_button.pressed.connect(func(): _on_delete_slot_pressed(slot))
	main_actions.add_child(delete_control["frame"])

	var options_button := _create_options_button()
	options_button.pressed.connect(func(): _on_slot_options_pressed(slot, options_button))
	panel.add_child(options_button)

	return {
		"panel": panel,
		"summary": summary,
		"play_button": play_button,
		"delete_button": delete_button,
		"options_button": options_button
	}


func _create_panel_frame(minimum_size: Vector2) -> NinePatchRect:
	var panel := NinePatchRect.new()
	panel.texture = SAVE_PANEL_TEXTURE
	panel.region_rect = Rect2(4, 4, 42, 43)
	panel.patch_margin_left = 5
	panel.patch_margin_top = 5
	panel.patch_margin_right = 5
	panel.patch_margin_bottom = 5
	panel.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	panel.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	panel.custom_minimum_size = minimum_size
	return panel


func _create_button_frame(text: String, minimum_size: Vector2, danger := false) -> Dictionary:
	var frame := NinePatchRect.new()
	frame.custom_minimum_size = minimum_size
	frame.texture = SAVE_BUTTON_TEXTURE
	frame.region_rect = Rect2(1, 1, 48, 49)
	frame.patch_margin_left = 7
	frame.patch_margin_top = 7
	frame.patch_margin_right = 7
	frame.patch_margin_bottom = 6
	frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT

	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.text = text
	button.flat = true
	if danger:
		button.theme_type_variation = &"DangerButton"
	frame.add_child(button)

	return {"frame": frame, "button": button}


func _create_options_button() -> Button:
	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -34.0
	button.offset_top = 6.0
	button.offset_right = -6.0
	button.offset_bottom = 34.0
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_add_options_dots(button)
	return button


func _add_options_dots(button: Button) -> void:
	var dots := VBoxContainer.new()
	dots.set_anchors_preset(Control.PRESET_CENTER)
	dots.offset_left = -2.0
	dots.offset_top = -8.0
	dots.offset_right = 2.0
	dots.offset_bottom = 8.0
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.add_theme_constant_override("separation", 2)
	button.add_child(dots)

	for _i in range(3):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(3, 3)
		dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.color = Color(0, 0, 0, 0.86)
		dots.add_child(dot)


func _create_slot_actions_popup() -> void:
	_actions_popup = _create_panel_frame(Vector2(154, 92))
	_actions_popup.name = "SlotActionsPopup"
	_actions_popup.visible = false
	_actions_popup.z_index = 100
	_actions_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	save_menu.add_child(_actions_popup)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10.0
	box.offset_top = 10.0
	box.offset_right = -10.0
	box.offset_bottom = -10.0
	box.add_theme_constant_override("separation", 6)
	_actions_popup.add_child(box)

	var export_control := _create_button_frame("EXPORTAR", Vector2(134, 32))
	_popup_export_frame = export_control["frame"]
	_popup_export_button = export_control["button"]
	_popup_export_button.pressed.connect(_on_popup_export_pressed)
	box.add_child(_popup_export_frame)

	var import_control := _create_button_frame("IMPORTAR", Vector2(134, 32))
	_popup_import_button = import_control["button"]
	_popup_import_button.pressed.connect(_on_popup_import_pressed)
	box.add_child(import_control["frame"])


func _create_student_name_prompt() -> void:
	_student_prompt = ColorRect.new()
	_student_prompt.name = "StudentNamePrompt"
	_student_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_student_prompt.color = Color(0, 0, 0, 0.76)
	_student_prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	_student_prompt.z_index = 200
	_student_prompt.hide()
	add_child(_student_prompt)

	var frame := _create_panel_frame(Vector2(480, 290))
	frame.name = "StudentNameFrame"
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -240.0
	frame.offset_top = -145.0
	frame.offset_right = 240.0
	frame.offset_bottom = 145.0
	_student_prompt.add_child(frame)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	frame.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	_student_prompt_title = Label.new()
	_student_prompt_title.theme_type_variation = &"TitleLabel"
	_student_prompt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_student_prompt_title)

	_student_prompt_description = Label.new()
	_student_prompt_description.theme_type_variation = &"BodyText"
	_student_prompt_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_student_prompt_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_student_prompt_description)

	_student_name_input = LineEdit.new()
	_student_name_input.name = "StudentNameInput"
	_student_name_input.custom_minimum_size = Vector2(0, 42)
	_student_name_input.max_length = Saves.MAX_STUDENT_NAME_LENGTH
	_student_name_input.placeholder_text = "Nome do aluno"
	_student_name_input.text_changed.connect(_on_student_name_changed)
	_student_name_input.text_submitted.connect(func(_text: String):
		if not _student_confirm_button.disabled:
			_on_student_name_confirmed()
	)
	content.add_child(_student_name_input)

	var feedback_row := HBoxContainer.new()
	feedback_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(feedback_row)

	_student_name_error = Label.new()
	_student_name_error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_student_name_error.theme_type_variation = &"ErrorLabel"
	feedback_row.add_child(_student_name_error)

	_student_name_counter = Label.new()
	_student_name_counter.theme_type_variation = &"SubtitleLabel"
	feedback_row.add_child(_student_name_counter)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	content.add_child(buttons)

	var back_control := _create_button_frame("VOLTAR", Vector2(160, 40))
	var back_button: Button = back_control["button"]
	back_button.pressed.connect(_hide_student_name_prompt)
	buttons.add_child(back_control["frame"])

	var confirm_control := _create_button_frame("CONTINUAR", Vector2(190, 40))
	_student_confirm_button = confirm_control["button"]
	_student_confirm_button.pressed.connect(_on_student_name_confirmed)
	buttons.add_child(confirm_control["frame"])


func _refresh_slot_menu() -> void:
	for slot in range(1, Saves.SLOT_COUNT + 1):
		var info := Saves.get_slot_info(slot)
		var row: Dictionary = _slot_rows.get(slot, {})
		if row.is_empty():
			continue

		var summary: Label = row["summary"]
		var play_button: Button = row["play_button"]
		var delete_button: Button = row["delete_button"]

		if bool(info.get("corrupted", false)):
			summary.text = "Slot %d\nSave com problema" % slot
			play_button.text = "COMEÇAR"
			delete_button.disabled = false
		elif bool(info.get("exists", false)):
			summary.text = "Slot %d\n%s" % [slot, str(info.get("summary", ""))]
			play_button.text = "CONTINUAR"
			delete_button.disabled = false
		else:
			summary.text = "Slot %d\nVazio" % slot
			play_button.text = "COMEÇAR"
			delete_button.disabled = true


func _go_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_start_pressed() -> void:
	_refresh_slot_menu()
	save_menu.visible = true


func _on_github_pressed() -> void:
	OS.shell_open(REPOSITORY_URL)


func _on_continue_pressed() -> void:
	pass


func _on_new_game_pressed() -> void:
	pass


func _on_back_pressed() -> void:
	_hide_slot_actions_popup()
	save_menu.visible = false


func _on_confirm_new_game_confirmed() -> void:
	pass


func _on_slot_play_pressed(slot: int) -> void:
	_hide_slot_actions_popup()
	StudentIdentity.clear_student()
	Saves.set_current_slot(slot)
	if Saves.has_save(slot):
		if Saves.load_game(slot).is_empty():
			_refresh_slot_menu()
			return
		if Saves.has_valid_student_name():
			StudentIdentity.show_student(Saves.get_student_name())
			_go_to_game()
			return
		_show_student_name_prompt(slot, false)
		return
	_show_student_name_prompt(slot, true)


func _show_student_name_prompt(slot: int, is_new_save: bool) -> void:
	_pending_student_slot = slot
	_pending_student_is_new = is_new_save
	_student_prompt_title.text = "IDENTIFICACAO DO ALUNO"
	if is_new_save:
		_student_prompt_description.text = "Informe o nome que ficara associado permanentemente a este save."
	else:
		_student_prompt_description.text = "Este save foi criado antes da identificacao. Informe o nome do aluno para continuar."
	_student_name_input.clear()
	_on_student_name_changed("")
	_student_prompt.show()
	_student_prompt.move_to_front()
	_student_name_input.grab_focus()


func _hide_student_name_prompt() -> void:
	_student_prompt.hide()
	_pending_student_slot = 0
	_pending_student_is_new = false
	Saves.clear_current_slot()
	StudentIdentity.clear_student()


func _on_student_name_changed(student_name: String) -> void:
	var clean_name := Saves.normalize_student_name(student_name)
	var valid := Saves.is_valid_student_name(student_name)
	_student_confirm_button.disabled = not valid
	_student_name_counter.text = "%d/%d" % [student_name.length(), Saves.MAX_STUDENT_NAME_LENGTH]
	if clean_name.is_empty():
		_student_name_error.text = "Informe um nome para continuar."
	elif student_name.length() > Saves.MAX_STUDENT_NAME_LENGTH:
		_student_name_error.text = "Use no maximo %d caracteres." % Saves.MAX_STUDENT_NAME_LENGTH
	else:
		_student_name_error.text = ""


func _on_student_name_confirmed() -> void:
	if _pending_student_slot == 0:
		return
	var clean_name := Saves.normalize_student_name(_student_name_input.text)
	if not Saves.is_valid_student_name(clean_name):
		_on_student_name_changed(_student_name_input.text)
		return

	var saved := false
	if _pending_student_is_new:
		saved = Saves.create_new_save(_pending_student_slot, clean_name)
	else:
		saved = Saves.set_student_name(clean_name)
	if not saved:
		_student_name_error.text = "Nao foi possivel salvar o nome. Tente novamente."
		return

	_student_prompt.hide()
	_pending_student_slot = 0
	_pending_student_is_new = false
	StudentIdentity.show_student(clean_name)
	_go_to_game()


func _on_delete_slot_pressed(slot: int) -> void:
	if not Saves.has_save(slot):
		return
	_hide_slot_actions_popup()
	_delete_slot = slot
	_confirm_action = "delete"
	confirm_new_game.dialog_text = "Apagar o Slot %d? Esta acao nao pode ser desfeita." % slot
	confirm_new_game.title = "Apagar esse save?"
	confirm_new_game.ok_button_text = "Apagar"
	confirm_new_game.popup_centered()


func _on_export_slot_pressed(slot: int) -> void:
	_hide_slot_actions_popup()
	var result := Saves.export_save(slot)
	if not bool(result.get("ok", false)):
		push_warning(str(result.get("message", "")))


func _on_import_slot_pressed(slot: int) -> void:
	_hide_slot_actions_popup()
	if Saves.has_save(slot):
		_import_slot = slot
		_confirm_action = "import"
		confirm_new_game.dialog_text = "Importar um arquivo vai substituir o Slot %d. Continuar?" % slot
		confirm_new_game.title = "Substituir esse save?"
		confirm_new_game.ok_button_text = "Importar"
		confirm_new_game.popup_centered()
		return
	_start_import_slot(slot)


func _start_import_slot(slot: int) -> void:
	var result := Saves.import_save_from_browser(slot)
	if not bool(result.get("ok", false)):
		push_warning(str(result.get("message", "")))


func _on_slot_options_pressed(slot: int, button: Button) -> void:
	if _actions_popup.visible and _actions_slot == slot:
		_hide_slot_actions_popup()
		return

	_actions_slot = slot
	var can_export := Saves.has_save(slot)
	_popup_export_frame.visible = can_export
	var popup_size := Vector2(154, 92 if can_export else 54)
	_actions_popup.custom_minimum_size = popup_size
	_actions_popup.size = popup_size
	var button_rect := button.get_global_rect()
	var menu_rect := save_menu.get_global_rect()
	var popup_gap := 8.0
	var popup_position := Vector2(button_rect.end.x + popup_gap, button_rect.position.y)
	if popup_position.x + popup_size.x > menu_rect.end.x - 8.0:
		popup_position.x = button_rect.position.x - popup_size.x - popup_gap
	popup_position.x = clampf(popup_position.x, menu_rect.position.x + 8.0, menu_rect.end.x - popup_size.x - 8.0)
	popup_position.y = clampf(popup_position.y, menu_rect.position.y + 8.0, menu_rect.end.y - popup_size.y - 8.0)
	_actions_popup.global_position = popup_position
	_actions_popup.visible = true


func _on_popup_export_pressed() -> void:
	if _actions_slot == 0:
		return
	_on_export_slot_pressed(_actions_slot)


func _on_popup_import_pressed() -> void:
	if _actions_slot == 0:
		return
	_on_import_slot_pressed(_actions_slot)


func _hide_slot_actions_popup() -> void:
	_actions_slot = 0
	if _actions_popup != null:
		_actions_popup.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _student_prompt != null and _student_prompt.visible:
		if event.is_action_pressed("ui_cancel"):
			_hide_student_name_prompt()
			get_viewport().set_input_as_handled()
		return
	if _actions_popup == null or not _actions_popup.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _actions_popup.get_global_rect().has_point(get_global_mouse_position()):
			_hide_slot_actions_popup()


func _on_confirm_save_action_confirmed() -> void:
	if _confirm_action == "import":
		var slot := _import_slot
		_import_slot = 0
		_confirm_action = ""
		if slot != 0:
			_start_import_slot(slot)
		return

	if _delete_slot == 0:
		return
	Saves.delete_save(_delete_slot)
	_delete_slot = 0
	_confirm_action = ""
	_refresh_slot_menu()


func _on_save_import_finished(_slot: int, ok: bool, message: String) -> void:
	if not ok:
		push_warning(message)
		return
	_refresh_slot_menu()
