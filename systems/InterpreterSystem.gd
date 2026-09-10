extends Node

signal execution_stopped
signal workspace_changed

const ScriptWorkspace = preload("res://systems/ScriptWorkspace.gd")
const ScriptRuntimeManagerScript = preload("res://systems/ScriptRuntimeManager.gd")

var interpretador := Interpreter.new()
var runtime_manager := ScriptRuntimeManagerScript.new()
var current_execution_context = null
var script_text = ""
var script_workspace := ScriptWorkspace.new()


func _ready():
	add_child(interpretador)
	add_child(runtime_manager)


func execute(code, context):
	set_script_text(str(code))
	if context == null:
		context = EnvContext.new([], 0, [])
	current_execution_context = context
	var script := script_workspace.get_active_script()
	runtime_manager.start_script(
		str(script.get("id", "")),
		str(code),
		str(script.get("title", "Sem nome")),
		context,
		str(script.get("language", ScriptWorkspace.DEFAULT_LANGUAGE))
	)

func execute_active(context) -> void:
	execute(script_workspace.get_active_source(), context)

func start_script(script_id: String, source: String, script_name: String, context = null,
		language_id: String = ScriptWorkspace.DEFAULT_LANGUAGE) -> String:
	if context == null:
		context = current_execution_context
	if context == null:
		context = EnvContext.new([], 0, [])
	current_execution_context = context
	return runtime_manager.start_script(script_id, source, script_name, context, language_id)

func start_active_script(context = null) -> String:
	if context == null:
		context = current_execution_context
	if context == null:
		context = EnvContext.new([], 0, [])
	current_execution_context = context
	var script := script_workspace.get_active_script()
	return runtime_manager.start_script(
		str(script.get("id", "")),
		str(script.get("source", "")),
		str(script.get("title", "Sem nome")),
		context,
		str(script.get("language", ScriptWorkspace.DEFAULT_LANGUAGE))
	)


func stop() -> void:
	stop_active_script()

func stop_runtime(runtime_id: String) -> void:
	runtime_manager.stop_runtime(runtime_id)
	emit_signal("execution_stopped")

func stop_script(script_id: String) -> void:
	runtime_manager.stop_script(script_id)
	emit_signal("execution_stopped")

func stop_active_script() -> void:
	var active_id := str(script_workspace.get_active_script().get("id", ""))
	runtime_manager.stop_script(active_id)
	emit_signal("execution_stopped")

func stop_all() -> void:
	runtime_manager.stop_all()
	emit_signal("execution_stopped")


func is_running(script_id: String = "") -> bool:
	if script_id.is_empty():
		script_id = str(script_workspace.get_active_script().get("id", ""))
	return runtime_manager.is_script_running(script_id)

func is_script_running(script_id: String) -> bool:
	return runtime_manager.is_script_running(script_id)

func get_runtime_by_script_id(script_id: String) -> Dictionary:
	return runtime_manager.get_runtime_by_script_id(script_id)

func get_all_runtimes() -> Array:
	return runtime_manager.get_all_runtimes()

func get_running_runtimes() -> Array:
	return runtime_manager.get_running_runtimes()

func set_script_text(text: String) -> void:
	script_text = text
	script_workspace.update_active_source(text)

func get_script_text() -> String:
	script_text = script_workspace.get_active_source()
	return script_text

func create_script(title: String = "") -> String:
	var id := script_workspace.create_script(title)
	workspace_changed.emit()
	return id

func delete_script(id: String) -> bool:
	runtime_manager.stop_script(id)
	var deleted := script_workspace.delete_script(id)
	script_text = script_workspace.get_active_source()
	workspace_changed.emit()
	return deleted

func rename_script(id: String, new_title: String) -> void:
	script_workspace.rename_script(id, new_title)
	workspace_changed.emit()

func set_active_script(id: String) -> void:
	script_workspace.set_active_script(id)
	script_text = script_workspace.get_active_source()
	workspace_changed.emit()

func update_active_source(source: String) -> void:
	set_script_text(source)

func set_active_script_language(language: String) -> bool:
	var changed := script_workspace.set_active_language(language)
	if changed:
		workspace_changed.emit()
	return changed

func get_active_source() -> String:
	return get_script_text()

func get_active_script() -> Dictionary:
	return script_workspace.get_active_script()

func get_active_script_title() -> String:
	return script_workspace.get_active_title()

func get_scripts() -> Array:
	return script_workspace.scripts.duplicate(true)

func ensure_delivery_script() -> String:
	var previous := script_workspace.delivery_script_id
	var id := script_workspace.ensure_delivery_script()
	if previous != id:
		workspace_changed.emit()
	return id

func get_delivery_script_id() -> String:
	return script_workspace.delivery_script_id

func is_reserved_script(id: String) -> bool:
	return script_workspace.is_reserved_script(id)

func get_script_workspace_data() -> Dictionary:
	return script_workspace.serialize()

func get_save_data() -> Dictionary:
	script_text = script_workspace.get_active_source()
	return {
		"script_text": script_text,
		"script_workspace": script_workspace.serialize()
	}

func load_save_data(data: Dictionary) -> void:
	runtime_manager.reset()
	script_workspace.deserialize(data)
	script_text = script_workspace.get_active_source()
	workspace_changed.emit()

func duplicate_script(id: String) -> String:
	var duplicate_id := script_workspace.duplicate_script(id)
	workspace_changed.emit()
	return duplicate_id
