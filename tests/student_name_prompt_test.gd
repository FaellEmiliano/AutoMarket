extends Node

const MainScreenScene = preload("res://scenes/menus/main_screen.tscn")

var _backups := {}
var _failures: Array[String] = []


func _ready() -> void:
	_backup_slot_files()
	for slot in range(1, Saves.SLOT_COUNT + 1):
		Saves.delete_save(slot)

	var main_screen := MainScreenScene.instantiate()
	add_child(main_screen)
	await get_tree().process_frame

	main_screen.call("_on_start_pressed")
	main_screen.call("_on_slot_play_pressed", 1)
	await get_tree().process_frame

	var prompt := main_screen.get_node("StudentNamePrompt") as Control
	var input := prompt.find_child("StudentNameInput", true, false) as LineEdit
	var confirm_button := _find_button(prompt, "CONTINUAR")
	_check(prompt.visible, "Save novo deve abrir a identificacao antes do mercado.")
	_check(input.max_length == Saves.MAX_STUDENT_NAME_LENGTH, "Campo deve limitar o nome a 50 caracteres.")
	_check(confirm_button != null and confirm_button.disabled, "Nome vazio deve bloquear CONTINUAR.")

	input.text = "   "
	main_screen.call("_on_student_name_changed", input.text)
	await get_tree().process_frame
	_check(confirm_button.disabled, "Nome somente com espacos deve bloquear CONTINUAR.")

	input.text = "X".repeat(51)
	main_screen.call("_on_student_name_changed", input.text)
	await get_tree().process_frame
	_check(input.text.length() == Saves.MAX_STUDENT_NAME_LENGTH, "Campo deve impedir a entrada do caractere 51.")
	input.text = "X".repeat(50)
	main_screen.call("_on_student_name_changed", input.text)
	await get_tree().process_frame
	_check(not confirm_button.disabled, "Nome com exatamente 50 caracteres deve poder continuar.")

	main_screen.call("_hide_student_name_prompt")
	Saves.set_current_slot(2)
	Saves.resetar()
	GameManager.money = 321
	Saves.solicitar_save("legacy_prompt_test")
	Saves.clear_current_slot()
	main_screen.call("_on_slot_play_pressed", 2)
	await get_tree().process_frame
	_check(prompt.visible, "Save antigo sem student_name deve abrir a mesma identificacao.")
	_check(GameManager.money == 321, "Solicitar nome em save antigo deve preservar o progresso carregado.")

	var frame := prompt.find_child("StudentNameFrame", true, false) as Control
	for resolution in [Vector2i(800, 600), Vector2i(1280, 720)]:
		get_window().size = resolution
		await get_tree().process_frame
		var frame_rect := frame.get_global_rect()
		var viewport_width := get_viewport().get_visible_rect().size.x
		_check(absf(frame_rect.get_center().x - viewport_width * 0.5) <= 1.0, "Dialogo deve ficar centralizado em %s." % resolution)

	main_screen.queue_free()
	_restore_slot_files()
	if _failures.is_empty():
		print("STUDENT_NAME_PROMPT_TEST_OK")
	else:
		push_error("\n".join(_failures))
	await get_tree().process_frame
	get_tree().quit()


func _find_button(root: Node, button_text: String) -> Button:
	for child in root.find_children("*", "Button", true, false):
		if child.text == button_text:
			return child as Button
	return null


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _backup_slot_files() -> void:
	for slot in range(1, Saves.SLOT_COUNT + 1):
		var path := Saves.get_save_path(slot)
		_backups[path] = _read_file_bytes(path)
		var legacy_path := Saves.LEGACY_SLOT_PATH % slot
		_backups[legacy_path] = _read_file_bytes(legacy_path)


func _restore_slot_files() -> void:
	for path in _backups:
		var bytes: PackedByteArray = _backups[path]
		if bytes.is_empty():
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
			continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(bytes)
			file.close()
	Saves.clear_current_slot()
	StudentIdentity.clear_student()


func _read_file_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes
