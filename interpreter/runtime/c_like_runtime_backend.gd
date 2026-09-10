extends "res://interpreter/runtime/language_runtime_backend.gd"
class_name CLikeRuntimeBackend

const DeliveryAnalyzer = preload("res://interpreter/analysis/c_like_delivery_program_analyzer.gd")

var _interpreter: Interpreter

func _init() -> void:
	_interpreter = Interpreter.new()
	_interpreter.emit_debug_to_eventbus = false
	_interpreter.scheduler_managed = true
	_interpreter.output_changed.connect(_on_output_changed)
	_interpreter.execution_finished.connect(_on_execution_finished)
	_interpreter.execution_error.connect(_on_execution_error)
	_interpreter.sleep_requested.connect(_on_sleep_requested)
	add_child(_interpreter)

func configure_runtime(runtime_id: String, script_id: String, source_name: String) -> void:
	_interpreter.set_source_name(source_name)
	_interpreter.executor.runtime_id = runtime_id
	_interpreter.executor.script_id = script_id

func start_source(source: String, context: Variant) -> void:
	_interpreter.run(source, context)
	_interpreter.executor.delivery_program_facts = null
	if not _interpreter.tem_erros() and _interpreter.executor.program_ast != null:
		_interpreter.executor.delivery_program_facts = DeliveryAnalyzer.analyze(
			_interpreter.executor.program_ast
		)

func begin_scheduler_frame() -> void:
	_interpreter.begin_scheduler_frame()

func end_scheduler_frame() -> void:
	_interpreter.end_scheduler_frame()

func execute_operation_budget(max_operations: int) -> int:
	return _interpreter.execute_operation_budget(max_operations)

func stop_execution() -> void:
	_interpreter.stop_execution()
	_interpreter.executor.delivery_program_facts = null

func consume_sleep_request() -> bool:
	return _interpreter.consume_sleep_request()

func has_errors() -> bool:
	return _interpreter.tem_erros()

func is_execution_active() -> bool:
	return _interpreter.executor_flag

func is_finished() -> bool:
	return _interpreter.executor.is_finished

func _on_output_changed(text: String) -> void:
	output_changed.emit(text)

func _on_execution_finished() -> void:
	_interpreter.executor.delivery_program_facts = null
	execution_finished.emit()

func _on_execution_error(text: String) -> void:
	_interpreter.executor.delivery_program_facts = null
	execution_error.emit(text)

func _on_sleep_requested(seconds: float) -> void:
	sleep_requested.emit(seconds)
