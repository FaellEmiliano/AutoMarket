extends Node
class_name LanguageRuntimeBackend

signal output_changed(text)
signal execution_finished
signal execution_error(text)
signal sleep_requested(seconds)

func configure_runtime(_runtime_id: String, _script_id: String, _source_name: String) -> void:
	push_error("Backend de linguagem sem configure_runtime().")

func start_source(_source: String, _context: Variant) -> void:
	push_error("Backend de linguagem sem start_source().")

func begin_scheduler_frame() -> void:
	push_error("Backend de linguagem sem begin_scheduler_frame().")

func end_scheduler_frame() -> void:
	push_error("Backend de linguagem sem end_scheduler_frame().")

func execute_operation_budget(_max_operations: int) -> int:
	push_error("Backend de linguagem sem execute_operation_budget().")
	return 0

func stop_execution() -> void:
	push_error("Backend de linguagem sem stop_execution().")

func consume_sleep_request() -> bool:
	push_error("Backend de linguagem sem consume_sleep_request().")
	return false

func has_errors() -> bool:
	push_error("Backend de linguagem sem has_errors().")
	return true

func is_execution_active() -> bool:
	push_error("Backend de linguagem sem is_execution_active().")
	return false

func is_finished() -> bool:
	push_error("Backend de linguagem sem is_finished().")
	return true
