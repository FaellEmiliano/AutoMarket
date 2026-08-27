extends Node
class_name ScriptRuntimeManager

const BackendFactory = preload("res://interpreter/runtime/language_backend_factory.gd")

signal runtime_started(runtime_id, script_id)
signal runtime_stopped(runtime_id, script_id)
signal runtime_finished(runtime_id, script_id)
signal runtime_error(runtime_id, script_id, message)
signal runtimes_changed

const STATUS_RUNNING := "running"
const STATUS_SLEEPING := "sleeping"
const STATUS_WAITING_INPUT := "waiting_input"
const STATUS_STOPPED := "stopped"
const STATUS_ERROR := "error"
const STATUS_FINISHED := "finished"
const OPERATIONS_PER_FRAME_PER_SCRIPT := 200
const GLOBAL_OPERATIONS_PER_FRAME := 1000

var _runtimes_by_id := {}
var _running_runtime_by_script_id := {}
var _runtime_order: Array[String] = []
var _next_runtime_number := 1
var operations_per_frame_per_script := OPERATIONS_PER_FRAME_PER_SCRIPT
var global_operations_per_frame := GLOBAL_OPERATIONS_PER_FRAME


func start_script(script_id: String, source: String, script_name: String, context: Variant = null,
		language_id: String = BackendFactory.DEFAULT_LANGUAGE_ID) -> String:
	var display_name := script_name.strip_edges()
	if display_name.is_empty():
		display_name = script_id

	var backend: Node = BackendFactory.create(language_id)
	if backend == null:
		var message := "Linguagem sem backend: '%s'." % language_id
		push_warning(message)
		EventBus.emit_signal("send_debug", "[%s] %s" % [display_name, message])
		return ""
	if is_script_running(script_id):
		backend.free()
		return str(_running_runtime_by_script_id[script_id])

	_clear_inactive_runtime_outputs()
	_clear_previous_runtimes_for_script(script_id)

	var runtime_id := _generate_runtime_id()
	backend.configure_runtime(runtime_id, script_id, display_name)
	backend.sleep_requested.connect(_on_runtime_sleep_requested.bind(runtime_id))
	add_child(backend)

	var runtime := {
		"runtime_id": runtime_id,
		"script_id": script_id,
		"script_name": display_name,
		"language": language_id,
		"source": str(source),
		"status": STATUS_RUNNING,
		"backend": backend,
		"output": "",
		"error": "",
		"cancel_requested": false,
		"wake_time_msec": 0,
		"operations_total": 0,
		"operations_last_frame": 0,
		"started_at": Time.get_unix_time_from_system(),
		"finished_at": 0
	}

	_runtimes_by_id[runtime_id] = runtime
	_running_runtime_by_script_id[script_id] = runtime_id
	_runtime_order.append(runtime_id)

	backend.output_changed.connect(_on_runtime_output_changed.bind(runtime_id))
	backend.execution_finished.connect(_on_runtime_execution_finished.bind(runtime_id))
	backend.execution_error.connect(_on_runtime_execution_error.bind(runtime_id))

	emit_signal("runtime_started", runtime_id, script_id)
	emit_signal("runtimes_changed")
	backend.start_source(str(source), _clone_context(context))

	if not backend.is_execution_active() and runtime.get("status") == STATUS_RUNNING:
		if backend.has_errors():
			_mark_runtime_error(runtime_id, str(runtime.get("output", "")))
		else:
			_mark_runtime_finished(runtime_id)

	return runtime_id


func _clear_inactive_runtime_outputs() -> void:
	var changed := false
	for runtime_id in _runtime_order:
		var runtime: Dictionary = _runtimes_by_id.get(runtime_id, {})
		if _is_runtime_active(runtime):
			continue
		if str(runtime.get("output", "")).is_empty():
			continue
		runtime["output"] = ""
		changed = true
	if changed:
		_emit_combined_output()


func _clear_previous_runtimes_for_script(script_id: String) -> void:
	var removed := false
	for i in range(_runtime_order.size() - 1, -1, -1):
		var runtime_id := _runtime_order[i]
		var runtime: Dictionary = _runtimes_by_id.get(runtime_id, {})
		if str(runtime.get("script_id", "")) != script_id:
			continue
		if _is_runtime_active(runtime):
			continue
		var backend: Node = runtime.get("backend")
		if backend != null:
			backend.queue_free()
		_runtimes_by_id.erase(runtime_id)
		_runtime_order.remove_at(i)
		removed = true
	if removed:
		_emit_combined_output()


func stop_runtime(runtime_id: String) -> void:
	var runtime := get_runtime(runtime_id)
	if runtime.is_empty() or not _is_runtime_active(runtime):
		return

	runtime["cancel_requested"] = true
	_stop_runtime_now(runtime_id)


func _stop_runtime_now(runtime_id: String) -> void:
	var runtime := get_runtime(runtime_id)
	if runtime.is_empty():
		return

	runtime["status"] = STATUS_STOPPED
	runtime["finished_at"] = Time.get_unix_time_from_system()
	_running_runtime_by_script_id.erase(str(runtime.get("script_id", "")))

	var backend: Node = runtime.get("backend")
	if backend != null:
		backend.stop_execution()

	_set_runtime_output(runtime_id, "[%s] Automacao parada" % str(runtime.get("script_name", "")))
	emit_signal("runtime_stopped", runtime_id, str(runtime.get("script_id", "")))
	emit_signal("runtimes_changed")


func stop_script(script_id: String) -> void:
	if not _running_runtime_by_script_id.has(script_id):
		return
	stop_runtime(str(_running_runtime_by_script_id[script_id]))


func stop_all() -> void:
	var running_ids := []
	for runtime_id in _runtime_order:
		var runtime: Dictionary = _runtimes_by_id.get(runtime_id, {})
		if _is_runtime_active(runtime):
			running_ids.append(runtime_id)

	for runtime_id in running_ids:
		stop_runtime(runtime_id)


func reset() -> void:
	stop_all()
	for runtime_id in _runtime_order:
		var runtime: Dictionary = _runtimes_by_id.get(runtime_id, {})
		var backend: Node = runtime.get("backend")
		if backend != null:
			backend.queue_free()
	_runtimes_by_id.clear()
	_running_runtime_by_script_id.clear()
	_runtime_order.clear()
	_emit_combined_output()
	emit_signal("runtimes_changed")


func is_script_running(script_id: String) -> bool:
	if not _running_runtime_by_script_id.has(script_id):
		return false
	var runtime_id := str(_running_runtime_by_script_id[script_id])
	var runtime: Dictionary = _runtimes_by_id.get(runtime_id, {})
	return _is_runtime_active(runtime)


func get_runtime(runtime_id: String) -> Dictionary:
	return _runtimes_by_id.get(runtime_id, {})


func get_runtime_by_script_id(script_id: String) -> Dictionary:
	if _running_runtime_by_script_id.has(script_id):
		return get_runtime(str(_running_runtime_by_script_id[script_id]))

	for i in range(_runtime_order.size() - 1, -1, -1):
		var runtime: Dictionary = _runtimes_by_id.get(_runtime_order[i], {})
		if str(runtime.get("script_id", "")) == script_id:
			return runtime
	return {}


func get_all_runtimes() -> Array:
	var result := []
	for runtime_id in _runtime_order:
		result.append(_runtime_view(_runtimes_by_id[runtime_id]))
	return result


func get_running_runtimes() -> Array:
	var result := []
	for runtime_id in _runtime_order:
		var runtime: Dictionary = _runtimes_by_id.get(runtime_id, {})
		if _is_runtime_active(runtime):
			result.append(_runtime_view(runtime))
	return result


func _process(_delta: float) -> void:
	var operations_left: int = maxi(1, global_operations_per_frame)
	var now_msec := Time.get_ticks_msec()
	for runtime_id in _runtime_order:
		if operations_left <= 0:
			break

		var runtime: Dictionary = _runtimes_by_id.get(runtime_id, {})
		if runtime.get("status") == STATUS_SLEEPING:
			if now_msec >= int(runtime.get("wake_time_msec", 0)):
				runtime["status"] = STATUS_RUNNING
				runtime["wake_time_msec"] = 0
				emit_signal("runtimes_changed")
			else:
				continue

		if runtime.get("status") != STATUS_RUNNING:
			continue

		if bool(runtime.get("cancel_requested", false)):
			_stop_runtime_now(runtime_id)
			continue

		var backend: Node = runtime.get("backend")
		if backend == null:
			_mark_runtime_error(runtime_id, "Runtime sem backend ativo.")
			continue

		var budget: int = mini(maxi(1, operations_per_frame_per_script), operations_left)
		backend.begin_scheduler_frame()
		var operations: int = backend.execute_operation_budget(budget)
		backend.end_scheduler_frame()
		var requested_sleep: bool = backend.consume_sleep_request()

		runtime["operations_last_frame"] = operations
		runtime["operations_total"] = int(runtime.get("operations_total", 0)) + operations
		operations_left -= operations

		if runtime.get("status") != STATUS_RUNNING:
			continue

		if backend.has_errors():
			_mark_runtime_error(runtime_id, str(runtime.get("output", "")))
		elif requested_sleep:
			continue
		elif not backend.is_execution_active() or backend.is_finished():
			_mark_runtime_finished(runtime_id)


func _on_runtime_sleep_requested(seconds: float, runtime_id: String) -> void:
	var runtime := get_runtime(runtime_id)
	if runtime.is_empty() or runtime.get("status") != STATUS_RUNNING:
		return
	runtime["status"] = STATUS_SLEEPING
	runtime["wake_time_msec"] = Time.get_ticks_msec() + int(maxf(0.0, seconds) * 1000.0)
	emit_signal("runtimes_changed")


func _on_runtime_output_changed(text: String, runtime_id: String) -> void:
	_set_runtime_output(runtime_id, text)


func _on_runtime_execution_error(text: String, runtime_id: String) -> void:
	_mark_runtime_error(runtime_id, text)


func _on_runtime_execution_finished(runtime_id: String) -> void:
	var runtime := get_runtime(runtime_id)
	if runtime.is_empty() or runtime.get("status") != STATUS_RUNNING:
		return

	var backend: Node = runtime.get("backend")
	if backend != null and backend.has_errors():
		_mark_runtime_error(runtime_id, str(runtime.get("output", "")))
	else:
		_mark_runtime_finished(runtime_id)


func _mark_runtime_finished(runtime_id: String) -> void:
	var runtime := get_runtime(runtime_id)
	if runtime.is_empty() or runtime.get("status") != STATUS_RUNNING:
		return

	runtime["status"] = STATUS_FINISHED
	runtime["finished_at"] = Time.get_unix_time_from_system()
	_running_runtime_by_script_id.erase(str(runtime.get("script_id", "")))
	emit_signal("runtime_finished", runtime_id, str(runtime.get("script_id", "")))
	emit_signal("runtimes_changed")


func _mark_runtime_error(runtime_id: String, message: String) -> void:
	var runtime := get_runtime(runtime_id)
	if runtime.is_empty():
		return

	if runtime.get("status") == STATUS_ERROR:
		if not message.is_empty():
			runtime["error"] = message
		return

	runtime["status"] = STATUS_ERROR
	runtime["error"] = message
	runtime["finished_at"] = Time.get_unix_time_from_system()
	_running_runtime_by_script_id.erase(str(runtime.get("script_id", "")))
	emit_signal("runtime_error", runtime_id, str(runtime.get("script_id", "")), message)
	emit_signal("runtimes_changed")


func _set_runtime_output(runtime_id: String, text: String) -> void:
	var runtime := get_runtime(runtime_id)
	if runtime.is_empty():
		return
	runtime["output"] = text
	_emit_combined_output()


func _emit_combined_output() -> void:
	var blocks := []
	for runtime_id in _runtime_order:
		var output := str(_runtimes_by_id.get(runtime_id, {}).get("output", "")).strip_edges()
		if not output.is_empty():
			blocks.append(output)
	EventBus.emit_signal("send_debug", "\n".join(blocks))


func _clone_context(context: Variant) -> EnvContext:
	if context == null:
		return EnvContext.new([], 0, [])
	var inputs := []
	var expected := []
	var id = 0
	var raw_inputs = context.get("inputs")
	var raw_expected = context.get("expected")
	var raw_id = context.get("id")
	if raw_inputs is Array:
		inputs = raw_inputs.duplicate(true)
	if raw_expected is Array:
		expected = raw_expected.duplicate(true)
	if raw_id != null:
		id = raw_id
	return EnvContext.new(inputs, id, expected)


func _runtime_view(runtime: Dictionary) -> Dictionary:
	return {
		"runtime_id": str(runtime.get("runtime_id", "")),
		"script_id": str(runtime.get("script_id", "")),
		"script_name": str(runtime.get("script_name", "")),
		"language": str(runtime.get("language", BackendFactory.DEFAULT_LANGUAGE_ID)),
		"source": str(runtime.get("source", "")),
		"status": str(runtime.get("status", STATUS_STOPPED)),
		"output": str(runtime.get("output", "")),
		"error": str(runtime.get("error", "")),
		"wake_time_msec": runtime.get("wake_time_msec", 0),
		"operations_total": runtime.get("operations_total", 0),
		"operations_last_frame": runtime.get("operations_last_frame", 0),
		"started_at": runtime.get("started_at", 0),
		"finished_at": runtime.get("finished_at", 0)
	}


func _generate_runtime_id() -> String:
	var id := "runtime_%03d" % _next_runtime_number
	_next_runtime_number += 1
	return id


func _is_runtime_active(runtime: Dictionary) -> bool:
	var status := str(runtime.get("status", ""))
	return status == STATUS_RUNNING or status == STATUS_SLEEPING or status == STATUS_WAITING_INPUT
