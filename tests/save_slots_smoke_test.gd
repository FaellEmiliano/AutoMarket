extends Node

var _backups := {}
var _failures: Array[String] = []

func _ready() -> void:
	_backup_slot_files()
	_run_tests()
	_restore_slot_files()

	if _failures.is_empty():
		print("SAVE_SLOTS_SMOKE_TEST_OK")
	else:
		push_error("\n".join(_failures))

	await get_tree().process_frame
	get_tree().quit()

func _run_tests() -> void:
	for slot in range(1, Saves.SLOT_COUNT + 1):
		Saves.delete_save(slot)
	_check(not Saves.has_save(1), "Slot 1 deve iniciar vazio no teste.")
	_check(not Saves.has_save(2), "Slot 2 deve iniciar vazio no teste.")
	_check(not Saves.has_save(3), "Slot 3 deve iniciar vazio no teste.")

	_create_slot_with_money(1, 10, 1)
	_create_slot_with_money(2, 20, 2)
	_create_slot_with_money(3, 30, 3)

	Saves.load_game(1)
	_check(GameManager.money == 10, "Slot 1 deve carregar dinheiro proprio.")
	_check(GameManager.diamonds == 1, "Slot 1 deve carregar diamantes próprios.")

	Saves.load_game(2)
	_check(GameManager.money == 20, "Slot 2 deve carregar dinheiro proprio.")
	_check(GameManager.diamonds == 2, "Slot 2 deve carregar diamantes próprios.")
	GameManager.money = 25
	Saves.solicitar_save("teste_slot_2")

	Saves.load_game(1)
	_check(GameManager.money == 10, "Salvar Slot 2 nao pode alterar Slot 1.")

	Saves.load_game(3)
	_check(GameManager.money == 30, "Slot 3 deve carregar dinheiro proprio.")
	_check(GameManager.diamonds == 3, "Slot 3 deve carregar diamantes próprios.")
	GameManager.money = 35
	Saves.solicitar_save("teste_slot_3")

	Saves.load_game(3)
	_check(GameManager.money == 35, "Autosave deve alterar apenas o slot ativo.")

	Saves.load_game(1)
	FeatureManager.unlock_feature(FeatureManager.FEATURE_DELIVERY)
	UpgradeManager.upgrades_comprados["delivery_online"] = true
	GameManager.upgrades = ["delivery_online"]
	DeliverySystem.unlock(false)
	_check(DeliverySystem.debug_set_report([0, 3, 2]), "Relatório ativo deve ser configurável no teste de save.")
	Saves.solicitar_save("teste_delivery_slot_1")
	Saves.load_game(2)
	Saves.load_game(1)
	var delivery_active := ActiveExperience.is_upgrade_active("delivery_online")
	_check(FeatureManager.has_feature(FeatureManager.FEATURE_DELIVERY) == delivery_active, "Save deve restaurar Delivery conforme a experiencia ativa.")
	_check(DeliverySystem.state == DeliverySystem.State.WAITING_DECLARATION, "Save deve restaurar o estado do relatório ativo.")
	_check(DeliverySystem.active_deliveries == [0, 3, 2], "Save deve restaurar as entregas do relatório ativo.")

	Saves.delete_save(2)
	_check(not Saves.has_save(2), "Apagar Slot 2 deve deixar o slot vazio.")
	_check(Saves.has_save(1), "Apagar Slot 2 nao pode apagar Slot 1.")
	_check(Saves.has_save(3), "Apagar Slot 2 nao pode apagar Slot 3.")

func _create_slot_with_money(slot: int, money: int, diamonds: int) -> void:
	Saves.set_current_slot(slot)
	Saves.resetar()
	GameManager.money = money
	GameManager.diamonds = diamonds
	Saves.solicitar_save("teste_slot_%d" % slot)
	_check(Saves.has_save(slot), "Slot %d deve existir apos salvar." % slot)

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
	Saves.current_slot = 0
	Saves.dados.clear()

func _read_file_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes
