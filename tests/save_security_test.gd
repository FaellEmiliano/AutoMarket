extends Node

const SaveCodec = preload("res://systems/SaveCodec.gd")
var _backups: Dictionary = {}
var _failures: Array[String] = []

func _ready() -> void:
	for slot in range(1, Saves.SLOT_COUNT + 1):
		for path in [Saves.get_save_path(slot), Saves.LEGACY_SLOT_PATH % slot]:
			_backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	_run_tests()
	for path in _backups:
		var bytes: PackedByteArray = _backups[path]
		if bytes.is_empty():
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(bytes)
			file.close()
	Saves.clear_current_slot()
	if _failures.is_empty():
		print("SAVE_SECURITY_TEST_OK")
	else:
		push_error("\n".join(_failures))
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)

func _run_tests() -> void:
	var data: Dictionary = Saves.create_new_save_data()
	data["meta"]["student_name"] = "Aluna ação 日本"
	data["game"]["dinheiro"] = 321
	data["shop"]["comprados"] = {"delivery_online": true}
	data["interpreter"]["script_text"] = "print('ação 日本')\n"
	var encoded := SaveCodec.encode(data)
	var decoded := SaveCodec.decode(encoded)
	_check(not encoded.is_empty(), "Save deve ser codificado.")
	_check(not encoded.contains("dinheiro") and not encoded.contains("delivery_online"), "Estado deve ficar criptografado.")
	_check(decoded == JSON.parse_string(JSON.stringify(data)), "Codec deve preservar todo o estado e Unicode.")
	_check(SaveCodec.encode(data) != encoded, "Cada gravacao deve usar IV aleatorio.")
	_check(SaveCodec.decode(JSON.stringify(data)).is_empty(), "JSON de progresso aberto deve ser rejeitado.")
	_check(SaveCodec.decode(encoded.left(encoded.length() - 5)).is_empty(), "Arquivo truncado deve ser rejeitado.")
	_check(SaveCodec.decode("x".repeat(SaveCodec.MAX_BYTES + 1)).is_empty(), "Arquivo grande deve ser rejeitado.")
	var envelope: Dictionary = JSON.parse_string(encoded)
	for field in ["iv", "payload", "hmac", "format", "version"]:
		var altered := envelope.duplicate(true)
		if field == "version":
			altered[field] = 2
		elif field == "format":
			altered[field] = "outro-jogo"
		else:
			var text: String = altered[field]
			altered[field] = ("A" if text[0] != "A" else "B") + text.substr(1)
		_check(SaveCodec.decode(JSON.stringify(altered)).is_empty(), "Alteracao em %s deve ser rejeitada." % field)
	var malformed := envelope.duplicate(true)
	malformed["payload"] = "!!!!"
	_check(SaveCodec.decode(JSON.stringify(malformed)).is_empty(), "Base64 invalido deve ser rejeitado.")
	for slot in range(1, Saves.SLOT_COUNT + 1):
		Saves.delete_save(slot)
	var result: Dictionary = Saves.import_save_text(1, encoded)
	_check(result.get("ok", false), "Importacao protegida deve funcionar.")
	Saves.load_game(1)
	_check(GameManager.money == 321, "Dinheiro deve sobreviver a importacao/carregamento.")
	_check(Saves.get_student_name() == data["meta"]["student_name"], "Nome deve sobreviver a importacao.")
	_check(Saves.import_save_text(2, encoded).get("ok", false), "Save portavel deve poder mudar de slot.")
	GameManager.money = 99
	Saves.save_game(2)
	Saves.load_game(2)
	_check(GameManager.money == 99, "Gravacao deve substituir arquivo protegido existente.")
	var original := FileAccess.get_file_as_string(Saves.get_save_path(1))
	var old_slot := Saves.current_slot
	var old_money := GameManager.money
	result = Saves.import_save_text(1, JSON.stringify(data))
	_check(not result.get("ok", false), "Importacao de JSON aberto deve ser recusada.")
	_check(FileAccess.get_file_as_string(Saves.get_save_path(1)) == original, "Importacao recusada deve preservar arquivo.")
	_check(Saves.current_slot == old_slot and GameManager.money == old_money, "Importacao recusada deve preservar runtime.")
	var bad := envelope.duplicate(true)
	bad["hmac"] = "0".repeat(64)
	_write_text(Saves.get_save_path(1), JSON.stringify(bad))
	var rejected := FileAccess.get_file_as_string(Saves.get_save_path(1))
	_check(Saves.get_slot_info(1)["corrupted"], "Menu deve identificar integridade invalida.")
	_check(Saves.load_game(1).is_empty(), "Carregamento adulterado deve falhar.")
	_check(Saves.current_slot == 0 and GameManager.money == old_money, "Falha nao deve aplicar estado nem manter autosave ativo.")
	Saves.save_game()
	_check(FileAccess.get_file_as_string(Saves.get_save_path(1)) == rejected, "Autosave nao deve sobrescrever arquivo rejeitado.")
	_write_text(Saves.get_save_path(1), JSON.stringify(data))
	_check(Saves._read_save_file(Saves.get_save_path(1)).is_empty(), "Substituir formato protegido por JSON aberto deve falhar.")
	# Legacy migration has a separate local-only entry point; retained files are backups.
	var legacy_path := Saves.LEGACY_SLOT_PATH % 3
	var legacy_text := JSON.stringify(data)
	_write_text(legacy_path, legacy_text)
	Saves._migrate_legacy_slots()
	_check(FileAccess.get_file_as_string(legacy_path) == legacy_text, "Migracao deve preservar arquivo antigo.")
	_check(Saves._read_save_file(Saves.get_save_path(3))["game"]["dinheiro"] == 321, "Migracao deve preservar progresso.")
	data["game"]["dinheiro"] = 999999
	_write_text(legacy_path, JSON.stringify(data))
	Saves._migrate_legacy_slots()
	_check(Saves._read_save_file(Saves.get_save_path(3))["game"]["dinheiro"] == 321, "Save protegido existente deve prevalecer sobre legado alterado.")
	Saves.delete_save(3)
	Saves._migrate_legacy_slots()
	_check(not Saves.has_save(3) and not FileAccess.file_exists(legacy_path), "Apagar slot nao deve ressuscitar legado.")

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
