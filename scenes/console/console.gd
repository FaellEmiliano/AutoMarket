extends "res://scenes/console/components/ide_workspace_view.gd"

signal close_requested
var context
var _loading := false
var _loaded_id := ""
var _caret_by_script := {}
var _rename_dialog: ConfirmationDialog
var _rename_line_edit: LineEdit
var _delete_dialog: ConfirmationDialog
var _dialog_script_id := ""

func _ready() -> void:
	build()
	context = GameManager.current_context
	EventBus.update_context.connect(context_updt)
	InterpreterSystem.workspace_changed.connect(_sync_documents)
	InterpreterSystem.runtime_manager.runtimes_changed.connect(_update_status)
	FeatureManager.feature_unlocked.connect(_on_progress_changed)
	UpgradeManager.upgrade_comprado.connect(_on_progress_changed)
	explorer.document_selected.connect(open_document)
	explorer.script_menu_requested.connect(_show_script_menu)
	tabs.document_selected.connect(open_document)
	code_edit.text_changed.connect(_on_code_text_changed)
	code_edit.caret_changed.connect(_update_caret)
	code_edit.focus_exited.connect(persist_source)
	new_button.pressed.connect(_on_new_tab_pressed)
	run_button.pressed.connect(_on_run_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	close_button.pressed.connect(func(): close_requested.emit())
	output.stop_all_requested.connect(InterpreterSystem.stop_all)
	language_button.item_selected.connect(_on_language_selected)
	_setup_dialogs()
	_sync_documents()

func _setup_dialogs() -> void:
	var popup := menu_button.get_popup()
	popup.add_item("Renomear", 0)
	popup.add_item("Duplicar", 1)
	popup.add_separator()
	popup.add_item("Excluir…", 2)
	popup.id_pressed.connect(_script_action)
	menu_button.about_to_popup.connect(_update_menu)
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = "Renomear script"
	_rename_dialog.transient = true
	_rename_line_edit = LineEdit.new()
	_rename_line_edit.custom_minimum_size = Vector2(280, 40)
	_rename_line_edit.text_submitted.connect(func(_text): _on_rename_confirmed(); _rename_dialog.hide())
	_rename_dialog.add_child(_rename_line_edit)
	_rename_dialog.confirmed.connect(_on_rename_confirmed)
	add_child(_rename_dialog)
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Excluir script"
	_delete_dialog.dialog_autowrap = true
	_delete_dialog.min_size = Vector2i(300, 140)
	_delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(_delete_dialog)

func open_document(kind: String, id: String) -> void:
	if kind == "help":
		if not documentation.show_topic(id):
			status_label.text = "Documentação bloqueada · avance no mercado para liberar."
			return
		_save_editor_to_active_script()
		_remember_caret()
		code_edit.hide()
		documentation.show()
		find_bar.hide()
	else:
		_save_editor_to_active_script()
		_remember_caret()
		InterpreterSystem.set_active_script(id)
		_load_active_script_into_editor()
		code_edit.show()
		documentation.hide()
	tabs.activate(kind, id)
	explorer.select_document(kind, id)
	documents.show()
	if size.y < 480:
		output.hide()
	reveal_document()
	_update_status()
	if kind == "script" and is_visible_in_tree():
		code_edit.grab_focus()

func _sync_documents() -> void:
	explorer.refresh_scripts()
	var id := str(InterpreterSystem.get_active_script().id)
	if _loaded_id != id:
		_load_active_script_into_editor()
		code_edit.show()
		documentation.hide()
		tabs.active_kind = "script"
		tabs.active_id = id
	elif code_edit.text != InterpreterSystem.get_active_source():
		_load_active_script_into_editor()
	else:
		_refresh_language_selector()
	tabs.refresh()
	explorer.select_document(tabs.active_kind, tabs.active_id)
	_update_status()

func _load_active_script_into_editor() -> void:
	_loading = true
	_loaded_id = str(InterpreterSystem.get_active_script().id)
	if code_edit.text != InterpreterSystem.get_active_source():
		code_edit.text = InterpreterSystem.get_active_source()
	_loading = false
	_refresh_language_selector()
	if _caret_by_script.has(_loaded_id):
		var position: Vector3 = _caret_by_script[_loaded_id]
		code_edit.set_caret_line(int(position.x))
		code_edit.set_caret_column(int(position.y))
		code_edit.scroll_vertical = position.z
	find_bar.refresh()

func _remember_caret() -> void:
	if not _loaded_id.is_empty():
		_caret_by_script[_loaded_id] = Vector3(code_edit.get_caret_line(), code_edit.get_caret_column(), code_edit.scroll_vertical)

func _save_editor_to_active_script() -> void:
	if not _loading and _loaded_id == str(InterpreterSystem.get_active_script().id):
		InterpreterSystem.update_active_source(code_edit.text)

func persist_source() -> void:
	_save_editor_to_active_script()
	_remember_caret()
	Saves.solicitar_save("script_editado")

func set_code_text(text: String) -> void:
	open_document("script", str(InterpreterSystem.get_active_script().id))
	code_edit.text = text
	_save_editor_to_active_script()
	Saves.solicitar_save("script_tutorial")

func get_code_text() -> String:
	return code_edit.text

func _on_code_text_changed() -> void:
	_save_editor_to_active_script()
	find_bar.refresh()

func _refresh_language_selector() -> void:
	var language := str(InterpreterSystem.get_active_script().get("language", "c_like"))
	language_button.select(1 if language == "python_like" else 0)
	if code_edit.language_id != language or code_edit.profile.is_empty():
		code_edit.configure_for_language(language)

func _on_language_selected(index: int) -> void:
	if tabs.active_kind != "script" or InterpreterSystem.is_script_running(_loaded_id):
		_refresh_language_selector()
		return
	_save_editor_to_active_script()
	InterpreterSystem.set_active_script_language("python_like" if index == 1 else "c_like")
	Saves.solicitar_save("script_linguagem_alterada")

func _on_run_pressed() -> void:
	if tabs.active_kind != "script" or InterpreterSystem.is_script_running(_loaded_id):
		return
	_save_editor_to_active_script()
	if size.y >= 480:
		output.show()
	if not InterpreterSystem.start_active_script(context).is_empty():
		Saves.solicitar_save("script_executado")
	_update_status()

func _on_stop_pressed() -> void:
	if tabs.active_kind == "script":
		InterpreterSystem.stop_active_script()

func _update_status() -> void:
	var running := InterpreterSystem.is_script_running(_loaded_id)
	var help_active: bool = tabs.active_kind == "help"
	run_button.disabled = help_active or running
	stop_button.disabled = help_active or not running
	language_button.disabled = help_active or running
	menu_button.disabled = help_active
	output.stop_all_button.disabled = InterpreterSystem.get_running_runtimes().is_empty()
	var state := str(InterpreterSystem.get_runtime_by_script_id(_loaded_id).get("status", "stopped"))
	status_label.text = "Documentação · somente leitura" if help_active else "%s   ·   %s" % [language_button.get_item_text(language_button.selected), Explorer.STATES.get(state, "PARADO")]
	status_label.theme_type_variation = &"Label"
	if not help_active:
		if state == "error":
			status_label.theme_type_variation = &"IDEError"
		elif state == "sleeping":
			status_label.theme_type_variation = &"IDESleeping"
		elif running:
			status_label.theme_type_variation = &"IDEWorking"
	explorer.refresh_states()
	for index in range(tabs.get_tab_count()):
		var data: Dictionary = tabs.get_tab_metadata(index)
		if data.kind == "script":
			var runtime_state := str(InterpreterSystem.get_runtime_by_script_id(data.id).get("status", "stopped"))
			tabs.set_tab_icon(index, tabs.STATE_ICONS.get(runtime_state))
			tabs.set_tab_tooltip(index, tabs.get_tab_title(index) + " — " + Explorer.STATES.get(runtime_state, "PARADO"))
	_update_caret()

func _update_caret() -> void:
	caret_label.text = "" if tabs.active_kind == "help" else "Ln %d, Col %d" % [code_edit.get_caret_line() + 1, code_edit.get_caret_column() + 1]

func context_updt(ctx) -> void:
	context = ctx.env_context

func _on_progress_changed(_id: String) -> void:
	if FeatureManager.has_feature(FeatureManager.FEATURE_DELIVERY):
		InterpreterSystem.ensure_delivery_script()
	explorer.refresh_topics()
	_sync_documents()

func _on_new_tab_pressed() -> void:
	persist_source()
	var id := InterpreterSystem.create_script()
	open_document("script", id)
	Saves.solicitar_save("script_criado")

func _update_menu() -> void:
	var reserved := InterpreterSystem.is_reserved_script(_loaded_id)
	menu_button.get_popup().set_item_disabled(0, reserved)
	menu_button.get_popup().set_item_disabled(3, reserved or InterpreterSystem.get_scripts().size() <= 1)

func _show_script_menu(id: String) -> void:
	open_document("script", id)
	_update_menu()
	menu_button.get_popup().position = Vector2i(get_global_mouse_position())
	menu_button.get_popup().popup()

func _script_action(action: int) -> void:
	_dialog_script_id = _loaded_id
	match action:
		0:
			if InterpreterSystem.is_reserved_script(_dialog_script_id):
				return
			_rename_line_edit.text = InterpreterSystem.get_active_script_title()
			_rename_dialog.popup_centered()
			_rename_line_edit.grab_focus()
			_rename_line_edit.select_all()
		1:
			persist_source()
			open_document("script", InterpreterSystem.duplicate_script(_loaded_id))
			Saves.solicitar_save("script_duplicado")
		2:
			if InterpreterSystem.is_reserved_script(_dialog_script_id):
				return
			_delete_dialog.dialog_text = 'Excluir "%s"? Esta ação remove seu código.' % InterpreterSystem.get_active_script_title()
			_delete_dialog.popup_centered(Vector2i(400, 160))

func _on_rename_confirmed() -> void:
	InterpreterSystem.rename_script(_dialog_script_id, _rename_line_edit.text)
	Saves.solicitar_save("script_renomeado")

func _on_delete_confirmed() -> void:
	InterpreterSystem.delete_script(_dialog_script_id)
	_caret_by_script.erase(_dialog_script_id)
	Saves.solicitar_save("script_apagado")

func handle_escape() -> void:
	if code_edit.get_code_completion_selected_index() >= 0:
		code_edit.cancel_code_completion()
		return
	if menu_button.get_popup().visible:
		menu_button.get_popup().hide()
	elif code_edit.get_menu().visible:
		code_edit.get_menu().hide()
	elif _rename_dialog.visible:
		_rename_dialog.hide()
	elif _delete_dialog.visible:
		_delete_dialog.hide()
	elif find_bar.visible:
		find_bar.close()
	elif _compact_explorer:
		toggle_explorer()
	else:
		close_requested.emit()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed:
		return
	if event.is_action_pressed("ui_cancel"):
		handle_escape()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed or event.meta_pressed:
		match event.keycode:
			KEY_F:
				if tabs.active_kind == "script":
					find_bar.open()
				get_viewport().set_input_as_handled()
			KEY_S:
				persist_source()
				get_viewport().set_input_as_handled()
			KEY_ENTER:
				_on_run_pressed()
				get_viewport().set_input_as_handled()
			KEY_TAB:
				explorer.grab_focus()
				get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey:
		get_viewport().set_input_as_handled()
