extends "res://scenes/console/components/ide_workspace_view.gd"

const ActiveExperienceData = preload("res://data/ActiveExperience.gd")

signal close_requested
signal window_mode_requested(minimized: bool)
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
	InterpreterSystem.runtime_manager.runtime_started.connect(_on_runtime_started)
	InterpreterSystem.runtime_manager.runtime_error.connect(_on_runtime_error)
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
	run_all_button.pressed.connect(_on_run_all_pressed)
	close_button.pressed.connect(func(): close_requested.emit())
	window_mode_button.pressed.connect(func(): window_mode_requested.emit(not _minimized_window))
	output.stop_all_requested.connect(InterpreterSystem.stop_all)
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
		status_label.text = "Consulte os comandos e desafios na guia Ajuda."
		return
	if kind == "script" and _is_hidden_legacy_script(id):
		return
	empty_state.hide()
	if kind == "script":
		_save_editor_to_active_script()
		_remember_caret()
		InterpreterSystem.set_active_script(id)
		_load_active_script_into_editor()
		code_edit.show()
	else:
		_save_editor_to_active_script()
		_remember_caret()
		code_edit.hide()
		find_bar.hide()
		empty_state.show()
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
	_select_visible_active_script()
	explorer.refresh_scripts()
	var id := str(InterpreterSystem.get_active_script().id)
	if _loaded_id != id:
		_load_active_script_into_editor()
		code_edit.show()
		empty_state.hide()
		tabs.active_kind = "script"
		tabs.active_id = id
	elif code_edit.text != InterpreterSystem.get_active_source():
		_load_active_script_into_editor()
	tabs.refresh()
	explorer.select_document(tabs.active_kind, tabs.active_id)
	_update_status()

func _select_visible_active_script() -> void:
	var active_id := str(InterpreterSystem.get_active_script().get("id", ""))
	if not _is_hidden_legacy_script(active_id):
		return
	for document in InterpreterSystem.get_scripts():
		var document_id := str(document.get("id", ""))
		if not _is_hidden_legacy_script(document_id):
			InterpreterSystem.set_active_script(document_id)
			return

func _is_hidden_legacy_script(id: String) -> bool:
	return not ActiveExperienceData.SHOW_DELIVERY and id == InterpreterSystem.get_delivery_script_id()

func _load_active_script_into_editor() -> void:
	_loading = true
	_loaded_id = str(InterpreterSystem.get_active_script().id)
	if code_edit.text != InterpreterSystem.get_active_source():
		code_edit.text = InterpreterSystem.get_active_source()
	_loading = false
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
	code_edit.clear_diagnostics()
	Saves.solicitar_save("script_tutorial")

func get_code_text() -> String:
	return code_edit.text

func _on_code_text_changed() -> void:
	code_edit.clear_diagnostics()
	_save_editor_to_active_script()
	find_bar.refresh()

func _on_run_pressed() -> void:
	if tabs.active_kind != "script" or InterpreterSystem.is_script_running(_loaded_id) \
			or InterpreterSystem.is_legacy_script(_loaded_id):
		return
	_save_editor_to_active_script()
	code_edit.clear_diagnostics()
	show_output()
	if not InterpreterSystem.start_active_script(context).is_empty():
		Saves.solicitar_save("script_executado")
	_update_status()

func _on_stop_pressed() -> void:
	if tabs.active_kind == "script":
		InterpreterSystem.stop_active_script()

func _on_run_all_pressed() -> void:
	_save_editor_to_active_script()
	code_edit.clear_diagnostics()
	show_output()
	InterpreterSystem.start_all_scripts(context)
	Saves.solicitar_save("automacao_integrada_executada")
	_update_status()

func _update_status() -> void:
	var running := InterpreterSystem.is_script_running(_loaded_id)
	var script_active: bool = tabs.active_kind == "script"
	var legacy_active := script_active and InterpreterSystem.is_legacy_script(_loaded_id)
	run_button.disabled = not script_active or running or legacy_active
	stop_button.disabled = not script_active or not running
	var runnable_count := 0
	for script in InterpreterSystem.get_scripts():
		if not InterpreterSystem.is_legacy_script(str(script.get("id", ""))):
			runnable_count += 1
	var running_count := InterpreterSystem.get_running_runtimes().size()
	run_all_button.disabled = runnable_count == 0 or running_count >= runnable_count
	menu_button.disabled = not script_active
	output.stop_all_button.disabled = InterpreterSystem.get_running_runtimes().is_empty()
	var state := str(InterpreterSystem.get_runtime_by_script_id(_loaded_id).get("status", "stopped"))
	var runtime := InterpreterSystem.get_runtime_by_script_id(_loaded_id)
	if legacy_active:
		status_label.text = "C-like legado · reescreva em Python-like para executar"
	elif script_active:
		status_label.text = "Python-like   ·   %s" % Explorer.STATES.get(state, "PARADO")
	else:
		status_label.text = "Nenhum documento aberto"
	status_label.theme_type_variation = &"Label"
	if state == "error":
		status_label.theme_type_variation = &"IDEError"
	elif state == "sleeping":
		status_label.theme_type_variation = &"IDESleeping"
	elif running:
		status_label.theme_type_variation = &"IDEWorking"
	if not script_active or state != "error" or str(runtime.get("source", "")) != code_edit.text:
		code_edit.clear_diagnostics()
	else:
		code_edit.set_diagnostics(runtime.get("diagnostics", []))
	explorer.refresh_states()
	for index in range(tabs.get_tab_count()):
		var data: Dictionary = tabs.get_tab_metadata(index)
		if data.kind == "script":
			var runtime_state := str(InterpreterSystem.get_runtime_by_script_id(data.id).get("status", "stopped"))
			tabs.set_tab_icon(index, tabs.STATE_ICONS.get(runtime_state))
			tabs.set_tab_tooltip(index, tabs.get_tab_title(index) + " — " + Explorer.STATES.get(runtime_state, "PARADO"))
	_update_caret()

func _on_runtime_error(_runtime_id: String, _script_id: String, _message: String) -> void:
	show_output()
	_update_status()

func _on_runtime_started(_runtime_id: String, _script_id: String) -> void:
	show_output()

func _update_caret() -> void:
	caret_label.text = "" if tabs.active_kind != "script" else "Ln %d, Col %d" % [code_edit.get_caret_line() + 1, code_edit.get_caret_column() + 1]

func context_updt(ctx) -> void:
	context = ctx.env_context

func _on_progress_changed(_id: String) -> void:
	if ActiveExperienceData.SHOW_DELIVERY and FeatureManager.has_feature(FeatureManager.FEATURE_DELIVERY):
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
			if _script_source(_dialog_script_id).strip_edges().is_empty():
				_on_delete_confirmed()
			else:
				_delete_dialog.dialog_text = 'Excluir "%s"? Esta ação remove seu código.' % InterpreterSystem.get_active_script_title()
				_delete_dialog.popup_centered(Vector2i(400, 160))

func _script_source(id: String) -> String:
	for document in InterpreterSystem.get_scripts():
		if str(document.get("id", "")) == id:
			return str(document.get("source", ""))
	return ""

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
