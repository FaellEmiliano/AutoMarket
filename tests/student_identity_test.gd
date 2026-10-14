extends Node

var _backups := {}
var _failures: Array[String] = []


func _ready() -> void:
	_backup_slot_files()
	_run_tests()
	_restore_slot_files()

	if _failures.is_empty():
		print("STUDENT_IDENTITY_TEST_OK")
	else:
		push_error("\n".join(_failures))

	await get_tree().process_frame
	get_tree().quit()


func _run_tests() -> void:
	for slot in range(1, Saves.SLOT_COUNT + 1):
		Saves.delete_save(slot)

	_check(not Saves.is_valid_student_name(""), "Nome vazio deve ser rejeitado.")
	_check(not Saves.is_valid_student_name("   "), "Nome somente com espacos deve ser rejeitado.")
	_check(Saves.is_valid_student_name("N".repeat(50)), "Nome com 50 caracteres deve ser aceito.")
	_check(not Saves.is_valid_student_name("N".repeat(51)), "Nome acima de 50 caracteres deve ser rejeitado.")
	_check(not Saves.create_new_save(1, "   "), "Save novo nao deve ser criado sem nome valido.")
	_check(not Saves.has_save(1), "Tentativa invalida nao pode criar arquivo de save.")

	_check(Saves.create_new_save(1, "  Ana Silva  "), "Save novo deve aceitar nome valido.")
	GameManager.money = 87
	Saves.solicitar_save("student_identity_test")
	Saves.load_game(1)
	_check(Saves.get_student_name() == "Ana Silva", "Nome deve persistir sem espacos nas bordas.")
	_check(GameManager.money == 87, "Recarregar nome nao pode perder progresso.")
	_check(not Saves.set_student_name("Outro Nome"), "Nome valido ja associado nao deve poder ser alterado.")

	_check(Saves.create_new_save(2, "Bruno Souza"), "Segundo slot deve aceitar nome proprio.")
	Saves.load_game(1)
	StudentIdentity.show_student(Saves.get_student_name())
	_check(StudentIdentity.get_student_name() == "Ana Silva", "Placa deve mostrar o nome do Slot 1.")
	Saves.load_game(2)
	StudentIdentity.show_student(Saves.get_student_name())
	_check(StudentIdentity.get_student_name() == "Bruno Souza", "Troca de slot deve atualizar a placa.")

	_check(Saves.create_new_save(3, "C".repeat(50)), "Nome de 50 caracteres deve ser salvo.")
	Saves.load_game(3)
	_check(Saves.get_student_name().length() == 50, "Nome de 50 caracteres deve persistir.")
	_check(not Saves.set_student_name("X".repeat(51)), "Alteracao acima do limite deve ser rejeitada.")

	_remove_student_name_from_slot(1)
	Saves.load_game(1)
	_check(not Saves.has_valid_student_name(), "Save antigo sem student_name deve continuar carregavel.")
	_check(GameManager.money == 87, "Save antigo deve preservar o progresso ao carregar.")
	_check(Saves.set_student_name("Aluno Legado"), "Save antigo deve aceitar identificacao obrigatoria.")
	Saves.load_game(1)
	_check(Saves.get_student_name() == "Aluno Legado", "Nome do save antigo deve persistir.")
	_check(GameManager.money == 87, "Adicionar nome ao save antigo nao pode apagar progresso.")

	StudentIdentity.show_student(Saves.get_student_name())
	_check(StudentIdentity.visible, "Placa deve ficar visivel durante a partida.")
	_check(StudentIdentity.layer > 22, "Placa deve ficar acima das CanvasLayers existentes.")
	_check(_tree_ignores_mouse(StudentIdentity), "Placa nao deve capturar input do mouse.")
	var top_center := StudentIdentity.get_node("TopCenter") as Control
	_check(top_center.anchor_left == 0.0 and top_center.anchor_right == 1.0, "Container da placa deve acompanhar toda a largura da viewport.")
	_check(top_center is CenterContainer, "Placa deve usar um container que centraliza o conteudo horizontalmente.")
	StudentIdentity.clear_student()
	_check(not StudentIdentity.visible and StudentIdentity.get_student_name().is_empty(), "Voltar ao menu deve limpar a identificacao anterior.")


func _tree_ignores_mouse(node: Node) -> bool:
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not _tree_ignores_mouse(child):
			return false
	return true


func _remove_student_name_from_slot(slot: int) -> void:
	var path := Saves.get_save_path(slot)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("Nao foi possivel preparar o save legado.")
		return
	var data = Saves.SaveCodec.decode(file.get_as_text())
	file.close()
	if not (data is Dictionary):
		_failures.append("Save invalido ao preparar compatibilidade legada.")
		return
	data.get("meta", {}).erase("student_name")
	file = FileAccess.open(Saves.LEGACY_SLOT_PATH % slot, FileAccess.WRITE)
	if file == null:
		_failures.append("Nao foi possivel gravar o save legado.")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	DirAccess.remove_absolute(path)
	Saves._migrate_legacy_slots()


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
