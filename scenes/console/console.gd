extends Control
const Workspace = preload("res://systems/ScriptWorkspace.gd")

var context
@onready var code_edit: CodeEdit = $Panel/VBoxContainer/EditorFrame/CodeEdit
@onready var status_label: Label = $Panel/VBoxContainer/Header/StatusLabel
@onready var run_button: Button = $Panel/VBoxContainer/Header/Run
@onready var stop_button: Button = $Panel/VBoxContainer/Header/Stop
@onready var stop_all_button: Button = $Panel/VBoxContainer/Header/StopAll
@onready var language_button: OptionButton = $Panel/VBoxContainer/Header/Language
@onready var new_tab_button: Button = $Panel/VBoxContainer/TabsRow/NewTab
@onready var tab_bar: TabBar = $Panel/VBoxContainer/TabsRow/TabBar
@onready var rename_tab_button: Button = $Panel/VBoxContainer/TabsRow/RenameTab
@onready var delete_tab_button: Button = $Panel/VBoxContainer/TabsRow/DeleteTab

var _script_ids_by_tab: Array[String] = []
var _is_loading_source := false
var _is_refreshing_tabs := false
var _rename_dialog: ConfirmationDialog
var _rename_line_edit: LineEdit
var _delete_dialog: ConfirmationDialog

func _ready() -> void:
	EventBus.update_context.connect(context_updt)
	context = GameManager.current_context
	_setup_tab_controls()
	_setup_language_selector()
	_setup_dialogs()
	_refresh_tabs()
	_load_active_script_into_editor()
	code_edit.text_changed.connect(_on_code_text_changed)
	code_edit.focus_exited.connect(_on_code_focus_exited)
	_connect_execution_signals()
	FeatureManager.feature_unlocked.connect(_on_feature_unlocked)
	_update_status()

func _setup_tab_controls() -> void:
	new_tab_button.pressed.connect(_on_new_tab_pressed)
	rename_tab_button.pressed.connect(_on_rename_tab_pressed)
	delete_tab_button.pressed.connect(_on_delete_tab_pressed)
	tab_bar.tab_changed.connect(_on_tab_changed)

func _setup_language_selector() -> void:
	language_button.clear()
	language_button.add_item("C-like", 0)
	language_button.set_item_metadata(0, Workspace.DEFAULT_LANGUAGE)
	language_button.add_item("Python", 1)
	language_button.set_item_metadata(1, Workspace.PYTHON_LIKE_LANGUAGE)
	language_button.item_selected.connect(_on_language_selected)
	_refresh_language_selector()

func _setup_dialogs() -> void:
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = "Renomear script"
	_rename_line_edit = LineEdit.new()
	_rename_line_edit.custom_minimum_size = Vector2(280, 28)
	_rename_dialog.add_child(_rename_line_edit)
	_rename_dialog.confirmed.connect(_on_rename_confirmed)
	add_child(_rename_dialog)

	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Apagar script"
	_delete_dialog.dialog_text = "Apagar este script?"
	_delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(_delete_dialog)

func _connect_execution_signals() -> void:
	var changed := Callable(self, "_on_runtimes_changed")
	if not InterpreterSystem.runtime_manager.is_connected("runtimes_changed", changed):
		InterpreterSystem.runtime_manager.connect("runtimes_changed", changed)
	if not InterpreterSystem.is_connected("execution_stopped", changed):
		InterpreterSystem.connect("execution_stopped", changed)

func _on_fechar_pressed() -> void:
	get_window().hide()

func _on_minimizar_toggled(toggled_on: bool) -> void:
	if toggled_on:
		get_window().size.y = 37
	else:
		get_window().size.y = 252


func _on_run_pressed() -> void:
	var active_id := str(InterpreterSystem.get_active_script().get("id", ""))
	if InterpreterSystem.is_script_running(active_id):
		return
	_save_editor_to_active_script()
	var runtime_id := InterpreterSystem.start_active_script(context)
	if runtime_id.is_empty():
		return
	Saves.solicitar_save("script_executado")
	code_edit.release_focus()


func _on_stop_pressed() -> void:
	InterpreterSystem.stop_active_script()

func _on_stop_all_pressed() -> void:
	InterpreterSystem.stop_all()

func context_updt(ctx):
	context = ctx.env_context

func _on_runtimes_changed() -> void:
	_refresh_tabs()
	_update_status()

func _update_status() -> void:
	var active_id := str(InterpreterSystem.get_active_script().get("id", ""))
	var is_active := InterpreterSystem.is_script_running(active_id)
	var has_running := not InterpreterSystem.get_running_runtimes().is_empty()
	if is_active:
		var runtime := InterpreterSystem.get_runtime_by_script_id(active_id)
		if str(runtime.get("status", "")) == "sleeping":
			status_label.text = "DORMINDO"
			status_label.theme_type_variation = &"SleepingLabel"
		else:
			status_label.text = "RODANDO"
			status_label.theme_type_variation = &"SuccessLabel"
		run_button.disabled = true
		stop_button.disabled = false
	else:
		var runtime := InterpreterSystem.get_runtime_by_script_id(active_id)
		if str(runtime.get("status", "")) == "error":
			status_label.text = "ERRO"
			status_label.theme_type_variation = &"ErrorLabel"
		else:
			status_label.text = "PARADO"
			status_label.theme_type_variation = &"WarningLabel"
		run_button.disabled = false
		stop_button.disabled = true
	stop_all_button.disabled = not has_running

func _on_code_text_changed() -> void:
	if _is_loading_source:
		return
	InterpreterSystem.update_active_source(code_edit.text)

func _on_code_focus_exited() -> void:
	_save_editor_to_active_script()
	Saves.solicitar_save("script_editado")

func _on_language_selected(index: int) -> void:
	var language := str(language_button.get_item_metadata(index))
	if not InterpreterSystem.set_active_script_language(language):
		_refresh_language_selector()
		return
	Saves.solicitar_save("script_linguagem_alterada")

func _refresh_language_selector() -> void:
	var active_script := InterpreterSystem.get_active_script()
	var language := str(active_script.get("language", Workspace.DEFAULT_LANGUAGE))
	for index in range(language_button.get_item_count()):
		if str(language_button.get_item_metadata(index)) == language:
			language_button.select(index)
			return
	language_button.select(0)

func set_code_text(text: String) -> void:
	_is_loading_source = true
	code_edit.text = text
	_is_loading_source = false
	InterpreterSystem.update_active_source(text)
	Saves.solicitar_save("script_tutorial")

func get_code_text() -> String:
	return code_edit.text

func _save_editor_to_active_script() -> void:
	if _is_loading_source:
		return
	InterpreterSystem.update_active_source(code_edit.text)

func _load_active_script_into_editor() -> void:
	_is_loading_source = true
	code_edit.text = InterpreterSystem.get_active_source()
	_is_loading_source = false
	_refresh_language_selector()

func _refresh_tabs() -> void:
	_is_refreshing_tabs = true
	_script_ids_by_tab.clear()
	tab_bar.clear_tabs()

	var scripts := InterpreterSystem.get_scripts()
	var active_id := str(InterpreterSystem.get_active_script().get("id", ""))
	var active_index := 0

	for index in range(scripts.size()):
		var script: Dictionary = scripts[index]
		var id := str(script.get("id", ""))
		var title := str(script.get("title", "Sem nome"))
		_script_ids_by_tab.append(id)
		if InterpreterSystem.is_script_running(id):
			var runtime := InterpreterSystem.get_runtime_by_script_id(id)
			if str(runtime.get("status", "")) == "sleeping":
				title += " ~"
			else:
				title += " *"
		else:
			var runtime := InterpreterSystem.get_runtime_by_script_id(id)
			if str(runtime.get("status", "")) == "error":
				title += " !"
		tab_bar.add_tab(title)
		if id == active_id:
			active_index = index

	if tab_bar.get_tab_count() > 0:
		tab_bar.current_tab = active_index

	var active_reserved := InterpreterSystem.is_reserved_script(active_id)
	delete_tab_button.disabled = scripts.size() <= 1 or active_reserved
	rename_tab_button.disabled = active_reserved
	_is_refreshing_tabs = false

func _on_feature_unlocked(feature_id: String) -> void:
	if feature_id != FeatureManager.FEATURE_DELIVERY:
		return
	InterpreterSystem.ensure_delivery_script()
	_refresh_tabs()

func _on_tab_changed(tab: int) -> void:
	if _is_refreshing_tabs:
		return
	if tab < 0 or tab >= _script_ids_by_tab.size():
		return
	_save_editor_to_active_script()
	InterpreterSystem.set_active_script(_script_ids_by_tab[tab])
	_load_active_script_into_editor()
	_update_status()

func _on_new_tab_pressed() -> void:
	_save_editor_to_active_script()
	var id := InterpreterSystem.create_script()
	InterpreterSystem.set_active_script(id)
	_refresh_tabs()
	_load_active_script_into_editor()
	Saves.solicitar_save("script_criado")

func _on_rename_tab_pressed() -> void:
	if InterpreterSystem.is_reserved_script(str(InterpreterSystem.get_active_script().get("id", ""))):
		return
	_save_editor_to_active_script()
	_rename_line_edit.text = InterpreterSystem.get_active_script_title()
	_rename_line_edit.select_all()
	_rename_dialog.popup_centered()
	_rename_line_edit.grab_focus()

func _on_rename_confirmed() -> void:
	var active_id := str(InterpreterSystem.get_active_script().get("id", ""))
	InterpreterSystem.rename_script(active_id, _rename_line_edit.text)
	_refresh_tabs()
	Saves.solicitar_save("script_renomeado")

func _on_delete_tab_pressed() -> void:
	if InterpreterSystem.is_reserved_script(str(InterpreterSystem.get_active_script().get("id", ""))):
		EventBus.emit_signal("send_debug", "A aba Delivery faz parte da automação final e não pode ser apagada.")
		return
	if InterpreterSystem.get_scripts().size() <= 1:
		EventBus.emit_signal("send_debug", "Não dá para apagar o último script.")
		return
	_save_editor_to_active_script()
	_delete_dialog.popup_centered()

func _on_delete_confirmed() -> void:
	var active_id := str(InterpreterSystem.get_active_script().get("id", ""))
	if not InterpreterSystem.delete_script(active_id):
		EventBus.emit_signal("send_debug", "Não consegui apagar esse script.")
		return
	_refresh_tabs()
	_load_active_script_into_editor()
	Saves.solicitar_save("script_apagado")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if code_edit.has_focus() and not code_edit.get_global_rect().has_point(event.position):
			code_edit.release_focus()
