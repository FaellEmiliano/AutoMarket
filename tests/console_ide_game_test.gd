extends Node

class QuietDialog extends DialogScreen:
	func _ready() -> void:
		pass

class TestSaves extends "res://autoload/SaveManager.gd":
	func get_save_path(slot: int) -> String:
		return "user://ide_qa_slot_%d.json" % slot

const GameScene = preload("res://scenes/game/game.tscn")
var failures: Array[String] = []
var _original_save_script: Script
var game
var menu
var ide

func _ready() -> void:
	# Exercise real save serialization in a dedicated test namespace.
	_original_save_script = Saves.get_script()
	Saves.set_script(TestSaves)
	Saves.delete_save(3)
	Saves.create_new_save(3, "QA da IDE")
	game = GameScene.instantiate()
	add_child(game)
	await get_tree().process_frame
	menu = game.script_menu
	ide = menu.get_console_editor()
	var tutorial = game.get_node("TutorialOverlay")
	_check(tutorial.console_editor == ide, "Tutorial resolve IDE")
	tutorial._enter_step(1)
	menu.toggle_button.button_pressed = true
	await get_tree().process_frame
	_check(tutorial.current_step == 2 and menu.is_aberto(), "Botão Scripts avança tutorial")
	_check(menu.workspace_layer.layer == 21, "IDE acompanha highlight do tutorial")
	tutorial._enter_step(3)
	_check(ide.get_code_text().contains("Ola mundo"), "Tutorial insere código")
	ide._on_run_pressed()
	await get_tree().create_timer(0.2).timeout
	_check(tutorial.current_step == 4, "Execução avança tutorial")
	await _capture("tutorial")
	tutorial._finish_tutorial()
	await get_tree().process_frame
	_check(menu.workspace_layer.layer == 5, "Highlight restaura layer")
	menu.set_aberto(true)
	ide.find_bar.open()
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	_check(menu.is_aberto() and not ide.find_bar.visible and not game.pause_menu.visible, "Escape Find não abre Pause")
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	_check(not menu.is_aberto() and not game.pause_menu.visible, "Escape IDE não abre Pause")
	menu.set_aberto(true)
	ide.set_code_text("int main(){\n    float total = 0;\n    for(int i = 0; i < 5; i++){\n        total = total + i;\n    }\n    print(total);\n}\n")
	ide._on_run_pressed()
	await get_tree().create_timer(0.1).timeout
	_check(ide.output.text_label.text.contains("10"), "C-like executa no jogo")
	var c_source: String = ide.get_code_text()
	ide.code_edit.set_line(1, "    pr")
	ide.code_edit.set_caret_line(1)
	ide.code_edit.set_caret_column(6)
	ide.code_edit.request_code_completion(true)
	await get_tree().process_frame
	_check(ide.code_edit.get_code_completion_selected_index() >= 0, "Popup C visível")
	await _capture("completion_c")
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	_check(menu.is_aberto(), "Escape autocomplete não fecha IDE")
	ide.set_code_text(c_source)
	ide.open_document("help", "input")
	await get_tree().process_frame
	await _capture("documentation")
	ide.open_document("script", str(InterpreterSystem.get_active_script().id))
	ide._on_language_selected(1)
	FeatureManager.unlock_feature(FeatureManager.FEATURE_STOCK)
	ide.set_code_text("def somar(valores):\n    total = 0\n    for valor in valores:\n        total = total + valor\n    return total\n\nprint(somar([12, 8, 15]))\nwait(30)\n")
	ide._on_run_pressed()
	await get_tree().create_timer(0.1).timeout
	_check(ide.output.text_label.text.contains("35"), "Python executa no jogo")
	await _capture("python_wait")
	ide._on_stop_pressed()
	var python_source: String = ide.get_code_text()
	ide.code_edit.set_line(8, "wai")
	ide.code_edit.set_caret_line(8)
	ide.code_edit.set_caret_column(3)
	ide.code_edit.request_code_completion(true)
	await get_tree().process_frame
	_check(ide.code_edit.get_code_completion_selected_index() >= 0, "Popup Python visível")
	await _capture("completion_python")
	ide.code_edit.cancel_code_completion()
	ide.set_code_text(python_source)
	ide.set_code_text("print(desconhecido)\n")
	ide._on_run_pressed()
	await get_tree().create_timer(0.1).timeout
	_check(ide.status_label.text.contains("ERRO"), "Erro aparece no status")
	await _capture("error")
	menu.set_aberto(true)
	var dialogue := QuietDialog.new()
	dialogue._dialog = RichTextLabel.new()
	dialogue._dialog.text = "Diálogo de teste"
	dialogue._dialog.visible_ratio = 0.2
	dialogue.add_child(dialogue._dialog)
	add_child(dialogue)
	Input.action_press("ui_accept")
	dialogue._process(0)
	_check(dialogue._id == 0 and dialogue._step == 0.05, "Enter não avança cliente na IDE")
	Input.action_release("ui_accept")
	dialogue.queue_free()
	menu.set_aberto(false)
	var source := InterpreterSystem.get_active_source()
	Saves.load_game(3)
	_check(InterpreterSystem.get_active_source() == source, "Save preserva código")
	game.queue_free()
	await get_tree().process_frame
	Saves.clear_current_slot()
	Saves.delete_save(3)
	Saves.set_script(_original_save_script)
	if failures.is_empty():
		print("CONSOLE_IDE_GAME_TEST_OK")
	else:
		push_error("\n".join(failures))
	await get_tree().create_timer(3).timeout
	get_tree().quit(0 if failures.is_empty() else 1)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)

func _capture(label: String) -> void:
	_check(menu.is_aberto() and ide.is_visible_in_tree(), "IDE visível na captura " + label)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://ide_game_%s.png" % label)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
