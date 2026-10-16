extends Node

signal save_import_finished(slot: int, ok: bool, message: String)

const LEGACY_SAVE_PATH = "user://save.json"
const LEGACY_SLOT_PATH = "user://save_slot_%d.json"
const SAVE_SLOT_PATH = "user://save_slot_%d.protected.json"
const SAVE_VERSION = 5
const INITIAL_MONEY := 180
const INITIAL_STOCK := {"101": 5, "102": 5, "103": 5, "104": 5, "105": 5, "106": 5}
const SLOT_COUNT = 3
const MAX_STUDENT_NAME_LENGTH = 50
const MAX_IMPORT_BYTES = 1024 * 1024
const ScriptWorkspace = preload("res://systems/ScriptWorkspace.gd")
const DeliveryConfigData = preload("res://data/DeliveryConfig.gd")
const SaveCodec = preload("res://systems/SaveCodec.gd")

var dados: Dictionary = {}
var current_slot: int = 0
var _pending_import_slot := 0
var _web_import_callback = null

func _ready() -> void:
	_migrate_legacy_slots()
	migrate_legacy_save_if_needed()

func set_current_slot(slot: int) -> void:
	if not _is_valid_slot(slot):
		push_warning("Slot de save invalido: %d" % slot)
		return
	if current_slot != slot:
		dados.clear()
	current_slot = slot

func clear_current_slot() -> void:
	current_slot = 0
	dados.clear()

func get_current_slot() -> int:
	return current_slot

func get_save_path(slot: int) -> String:
	if not _is_valid_slot(slot):
		push_warning("Slot de save invalido: %d" % slot)
		return ""
	return SAVE_SLOT_PATH % slot

func has_save(slot: int) -> bool:
	var path := get_save_path(slot)
	return not path.is_empty() and FileAccess.file_exists(path)

func delete_save(slot: int) -> void:
	var path := get_save_path(slot)
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(path)
	# Explicit deletion must not resurrect an older unprotected slot on restart.
	var legacy_path := LEGACY_SLOT_PATH % slot
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(legacy_path)
	if current_slot == slot:
		current_slot = 0
		dados.clear()

func salvar(dinheiro: int = -1, mechanics: Dictionary = {}, upgrades: Array = []) -> void:
	_atualizar_estado_legacy(dinheiro, mechanics, upgrades)
	save_game()

func save_game(slot: int = 0) -> void:
	var target_slot := _resolve_slot(slot)
	if target_slot == 0:
		push_warning("Tentativa de salvar sem slot ativo.")
		return

	var save_data = _montar_save_data()
	save_data["meta"]["last_saved_unix"] = Time.get_unix_time_from_system()
	var path := get_save_path(target_slot)
	if not _write_save_file(path, save_data):
		push_error("Erro ao salvar o jogo no Slot %d" % target_slot)
		return
	dados = save_data
	current_slot = target_slot
	print("salvo slot %d" % target_slot)

func carregar() -> Dictionary:
	return load_game()

func load_game(slot: int = 0) -> Dictionary:
	var target_slot := _resolve_slot(slot)
	if target_slot == 0:
		push_warning("Tentativa de carregar sem slot ativo.")
		dados = create_new_save_data()
		_carregar_sistemas(dados)
		return _dados_compatibilidade(dados)

	current_slot = target_slot
	var path := get_save_path(target_slot)
	if not FileAccess.file_exists(path):
		dados = create_new_save_data()
		_carregar_sistemas(dados)
		save_game(target_slot)
		return _dados_compatibilidade(dados)

	var loaded_data := _read_save_file(path)
	if loaded_data.is_empty():
		push_error("Save do Slot %d corrompido ou invalido" % target_slot)
		# No active slot means subsequent autosaves cannot overwrite the rejected file.
		clear_current_slot()
		return {}

	dados = _validar_dados(loaded_data)
	_carregar_sistemas(dados)
	return _dados_compatibilidade(dados)

func resetar() -> void:
	var target_slot := _resolve_slot(0)
	if target_slot == 0:
		push_warning("Tentativa de criar novo jogo sem slot ativo.")
		return
	dados = create_new_save_data()
	_carregar_sistemas(dados)
	save_game(target_slot)

func create_new_save(slot: int, student_name: String) -> bool:
	var clean_name := normalize_student_name(student_name)
	if not is_valid_student_name(clean_name) or not _is_valid_slot(slot) or has_save(slot):
		return false

	current_slot = slot
	dados = create_new_save_data()
	dados["meta"]["student_name"] = clean_name
	_carregar_sistemas(dados)
	save_game(slot)
	return true

func set_student_name(student_name: String) -> bool:
	var clean_name := normalize_student_name(student_name)
	if not is_valid_student_name(clean_name) or current_slot == 0:
		return false
	if dados.is_empty():
		load_game(current_slot)
	if has_valid_student_name():
		return get_student_name() == clean_name
	dados["meta"]["student_name"] = clean_name
	save_game(current_slot)
	return true

func get_student_name() -> String:
	if dados.is_empty():
		return ""
	return normalize_student_name(str(dados.get("meta", {}).get("student_name", "")))

func has_valid_student_name() -> bool:
	return is_valid_student_name(get_student_name())

func normalize_student_name(student_name: String) -> String:
	return student_name.strip_edges()

func is_valid_student_name(student_name: String) -> bool:
	var clean_name := normalize_student_name(student_name)
	return not clean_name.is_empty() and clean_name.length() <= MAX_STUDENT_NAME_LENGTH

func create_new_save_data() -> Dictionary:
	return _save_padrao()

func get_slot_info(slot: int) -> Dictionary:
	var info := {
		"slot": slot,
		"exists": false,
		"corrupted": false,
		"money": 0,
		"last_saved_unix": 0,
		"last_saved_text": "",
		"summary": "Slot vazio",
		"student_name": ""
	}
	if not _is_valid_slot(slot):
		info["summary"] = "Slot invalido"
		return info

	var path := get_save_path(slot)
	if not FileAccess.file_exists(path):
		return info

	var loaded_data := _read_save_file(path)
	if loaded_data.is_empty():
		info["exists"] = true
		info["corrupted"] = true
		info["summary"] = "Save corrompido"
		return info

	var valid_data := _validar_dados(loaded_data)
	var game: Dictionary = valid_data.get("game", {})
	var meta: Dictionary = valid_data.get("meta", {})
	var upgrades: Dictionary = valid_data.get("shop", {}).get("comprados", {})
	var last_saved := int(meta.get("last_saved_unix", 0))
	var money := int(game.get("dinheiro", 0))
	var student_name := normalize_student_name(str(meta.get("student_name", "")))

	info["exists"] = true
	info["money"] = money
	info["last_saved_unix"] = last_saved
	info["last_saved_text"] = _format_timestamp(last_saved)
	info["student_name"] = student_name
	info["summary"] = "Dinheiro: R$ %d\nUpgrades: %d" % [money, upgrades.size()]
	if is_valid_student_name(student_name):
		info["summary"] = "Aluno: %s\n%s" % [student_name, info["summary"]]
	if last_saved > 0:
		info["summary"] += "\nUltimo save: " + str(info["last_saved_text"])
	return info

func migrate_legacy_save_if_needed() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	for slot in range(1, SLOT_COUNT + 1):
		if has_save(slot):
			return

	var loaded_data := _read_legacy_save_file(LEGACY_SAVE_PATH)
	if loaded_data.is_empty():
		push_warning("Save antigo encontrado, mas nao foi possivel migrar.")
		return

	var migrated_data := _validar_dados(loaded_data)
	migrated_data["meta"]["last_saved_unix"] = Time.get_unix_time_from_system()
	if not _write_save_file(get_save_path(1), migrated_data):
		push_error("Erro ao migrar save antigo para Slot 1")
		return
	print("Save antigo migrado para Slot 1")

func solicitar_save(_motivo := "") -> void:
	salvar()

func export_save(slot: int) -> Dictionary:
	if not _is_valid_slot(slot):
		return {"ok": false, "message": "Slot invalido."}
	if not OS.has_feature("web"):
		return {"ok": false, "message": "Exportacao disponivel apenas no navegador."}
	if not has_save(slot):
		return {"ok": false, "message": "Nao ha save para exportar."}

	var path := get_save_path(slot)
	if _read_save_file(path).is_empty():
		return {"ok": false, "message": "Save corrompido ou com integridade invalida."}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "Nao foi possivel ler o save."}

	var buffer := file.get_buffer(file.get_length())
	file.close()
	var file_name := "jogo_educativo_slot_%d.protected.json" % slot
	JavaScriptBridge.download_buffer(buffer, file_name, "application/json")
	return {"ok": true, "message": "Download do Slot %d iniciado." % slot}

func import_save_from_browser(slot: int) -> Dictionary:
	if not _is_valid_slot(slot):
		return {"ok": false, "message": "Slot invalido."}
	if not OS.has_feature("web"):
		return {"ok": false, "message": "Importacao disponivel apenas no navegador."}
	if _pending_import_slot != 0:
		return {"ok": false, "message": "Ja existe uma importacao em andamento."}

	_pending_import_slot = slot
	_web_import_callback = JavaScriptBridge.create_callback(_on_web_import_file_loaded)
	var window = JavaScriptBridge.get_interface("window")
	window.__godotImportSaveCallback = _web_import_callback
	JavaScriptBridge.eval("""
(function () {
	const callback = window.__godotImportSaveCallback;
	if (typeof callback !== "function") {
		return;
	}

	const input = document.createElement("input");
	input.type = "file";
	input.accept = "application/json,.json";
	input.style.display = "none";

	const cleanup = function () {
		input.remove();
		delete window.__godotImportSaveCallback;
	};

	input.onchange = function () {
		const file = input.files && input.files[0];
		if (!file) {
			callback("", "cancel");
			cleanup();
			return;
		}
		if (file.size > 1048576) {
			callback("", "too_large");
			cleanup();
			return;
		}

		const reader = new FileReader();
		reader.onload = function () {
			callback(String(reader.result || ""), "ok");
			cleanup();
		};
		reader.onerror = function () {
			callback("", "error");
			cleanup();
		};
		reader.readAsText(file);
	};
	input.oncancel = function () {
		callback("", "cancel");
		cleanup();
	};

	document.body.appendChild(input);
	input.click();
})();
""", true)
	return {"ok": true, "message": "Escolha o arquivo de save do Slot %d." % slot}

func import_save_text(slot: int, texto: String) -> Dictionary:
	if not _is_valid_slot(slot):
		return {"ok": false, "message": "Slot invalido."}
	if texto.strip_edges().is_empty():
		return {"ok": false, "message": "Arquivo de save vazio."}
	if texto.to_utf8_buffer().size() > MAX_IMPORT_BYTES:
		return {"ok": false, "message": "Arquivo de save muito grande."}

	var imported_data := SaveCodec.decode(texto)
	if imported_data.is_empty() or not _looks_like_save_data(imported_data):
		return {"ok": false, "message": "Save sem protecao, corrompido ou com integridade invalida. Exporte novamente pelo jogo atualizado."}

	imported_data = _validar_dados(imported_data)
	imported_data["meta"]["last_saved_unix"] = Time.get_unix_time_from_system()
	if not _write_save_file(get_save_path(slot), imported_data):
		return {"ok": false, "message": "Nao foi possivel gravar o save importado."}
	dados = imported_data
	current_slot = slot
	_carregar_sistemas(dados)
	return {"ok": true, "message": "Slot %d importado com sucesso." % slot}

func get_tutorial_data() -> Dictionary:
	if dados.is_empty():
		if current_slot == 0:
			return create_new_save_data().get("tutorial", {}).duplicate(true)
		carregar()
	dados = _validar_dados(dados)
	return dados.get("tutorial", {}).duplicate(true)

func set_tutorial_step(step: int) -> void:
	if dados.is_empty():
		if current_slot == 0:
			return
		carregar()
	dados = _validar_dados(dados)
	dados["tutorial"]["step"] = max(0, step)
	salvar()

func complete_tutorial() -> void:
	if dados.is_empty():
		if current_slot == 0:
			return
		carregar()
	dados = _validar_dados(dados)
	dados["tutorial"]["completed"] = true
	salvar()

func _read_save_file(path: String) -> Dictionary:
	return SaveCodec.decode(_read_save_text(path))

func _read_save_text(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	if file.get_length() > MAX_IMPORT_BYTES:
		file.close()
		return ""
	var texto = file.get_as_text()
	file.close()
	return texto

func _write_save_file(path: String, save_data: Dictionary) -> bool:
	# Encode completely before opening a file. Never truncate a working save on failure.
	var text := SaveCodec.encode(save_data)
	if text.is_empty():
		return false
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or _read_save_file(temporary_path).is_empty():
		DirAccess.remove_absolute(temporary_path)
		return false
	var replaced := DirAccess.rename_absolute(temporary_path, path) == OK
	if not replaced:
		DirAccess.remove_absolute(temporary_path)
	return replaced

func _read_legacy_save_file(path: String) -> Dictionary:
	var texto := _read_save_text(path)
	var json = JSON.new()
	var erro = json.parse(texto)
	if erro != OK or not (json.data is Dictionary):
		return {}
	var legacy: Dictionary = json.data
	# A damaged protected envelope must never be treated as legacy progress.
	if legacy.has("format") or legacy.has("payload") or legacy.has("hmac") or not _looks_like_save_data(legacy):
		return {}
	return legacy

func _migrate_legacy_slots() -> void:
	for slot in range(1, SLOT_COUNT + 1):
		var legacy_path := LEGACY_SLOT_PATH % slot
		if has_save(slot) or not FileAccess.file_exists(legacy_path):
			continue
		var legacy_data := _read_legacy_save_file(legacy_path)
		if legacy_data.is_empty():
			push_warning("Save antigo do Slot %d invalido; arquivo preservado." % slot)
			continue
		if not _write_save_file(get_save_path(slot), _validar_dados(legacy_data)):
			push_warning("Nao foi possivel proteger o Slot %d; arquivo antigo preservado." % slot)

func _resolve_slot(slot: int) -> int:
	if slot == 0:
		slot = current_slot
	if not _is_valid_slot(slot):
		return 0
	return slot

func _is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT

func _on_web_import_file_loaded(args: Array) -> void:
	var slot := _pending_import_slot
	_pending_import_slot = 0
	_web_import_callback = null

	if args.size() < 2 or str(args[1]) != "ok":
		save_import_finished.emit(slot, false, "Importacao cancelada.")
		return

	var result := import_save_text(slot, str(args[0]))
	save_import_finished.emit(slot, bool(result.get("ok", false)), str(result.get("message", "")))

func _looks_like_save_data(data: Dictionary) -> bool:
	for key in ["meta", "game", "shop", "stock", "delivery", "interpreter", "tutorial"]:
		if data.has(key):
			return true
	for legacy_key in ["dinheiro", "unlocked_mechanics", "upgrades", "script_text"]:
		if data.has(legacy_key):
			return true
	return false

func _format_timestamp(unix_time: int) -> String:
	if unix_time <= 0:
		return ""
	var date := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%02d/%02d/%04d %02d:%02d" % [
		int(date.get("day", 1)),
		int(date.get("month", 1)),
		int(date.get("year", 1970)),
		int(date.get("hour", 0)),
		int(date.get("minute", 0))
	]

func _montar_save_data() -> Dictionary:
	return _validar_dados({
		"meta": {
			"save_version": SAVE_VERSION,
			"student_name": get_student_name()
		},
		"game": _coletar_dados_sistema(GameManager),
		"shop": _coletar_dados_sistema(UpgradeManager),
		"stock": _coletar_dados_sistema(StockSystem),
		"challenge": _coletar_dados_sistema(ChallengeSystem),
		"delivery": _coletar_dados_sistema(DeliverySystem),
		"interpreter": _coletar_dados_sistema(InterpreterSystem),
		"tutorial": _validar_tutorial(dados.get("tutorial", {}))
	})

func _coletar_dados_sistema(system: Object) -> Dictionary:
	if system != null and system.has_method("get_save_data"):
		var save_data = system.get_save_data()
		if save_data is Dictionary:
			return save_data
	return {}

func _carregar_sistemas(save_data: Dictionary) -> void:
	_carregar_sistema(GameManager, save_data.get("game", {}))
	_carregar_sistema(StockSystem, save_data.get("stock", {}))
	_carregar_sistema(ChallengeSystem, save_data.get("challenge", {}))
	_carregar_sistema(InterpreterSystem, save_data.get("interpreter", {}))
	_carregar_sistema(DeliverySystem, save_data.get("delivery", {}))
	_carregar_sistema(UpgradeManager, save_data.get("shop", {}))

func _carregar_sistema(system: Object, system_data: Variant) -> void:
	if system != null and system.has_method("load_save_data") and system_data is Dictionary:
		system.load_save_data(system_data)

func _atualizar_estado_legacy(dinheiro: int, mechanics: Dictionary, upgrades: Array) -> void:
	if dinheiro >= 0:
		GameManager.money = dinheiro

	if not mechanics.is_empty():
		for key in GameManager.unlocked_mechanics:
			if mechanics.has(key):
				GameManager.unlocked_mechanics[key] = bool(mechanics[key])

	if not upgrades.is_empty():
		GameManager.upgrades = upgrades.duplicate()

func _save_padrao() -> Dictionary:
	var default_workspace := ScriptWorkspace.new().serialize()
	return {
		"meta": {
			"save_version": SAVE_VERSION,
			"last_saved_unix": 0,
			"student_name": ""
		},
		"game": {
			"dinheiro": INITIAL_MONEY,
			"diamonds": 0,
			"game_completed": false,
			"secret_menu_unlocked": false,
			"unlocked_mechanics": {
				"sum": true,
				"cart": true,
				"discount": false,
				"change": false,
				"stock": true,
				"if": true,
				"sensor": true,
				"delivery": false
			},
			"upgrades": []
		},
		"shop": {
			"comprados": {}
		},
		"stock": {
			"schema_version": 2,
			"quantities": INITIAL_STOCK.duplicate(true)
		},
		"challenge": {
			"id": "mercado_automatizado",
			"completed": false,
			"valid_sales": 0,
			"script_purchases": 0,
			"recoveries": 0
		},
		"delivery": {
			"state": 0,
			"next_report_id": 1,
			"active_report_id": 0,
			"active_deliveries": [],
			"last_rewarded_report_id": 0,
			"next_report_unix": 0,
			"last_result": {},
			"last_generated_deliveries": []
		},
		"interpreter": {
			"script_text": "",
			"script_workspace": default_workspace
		},
		"tutorial": {
			"completed": false,
			"step": 0
		}
	}

func _validar_dados(data: Dictionary) -> Dictionary:
	var resultado = _save_padrao()
	var normalizado = _normalizar_formato(data)

	if normalizado.has("meta") and normalizado["meta"] is Dictionary:
		var meta = normalizado["meta"]
		if meta.has("save_version") and (meta["save_version"] is int or meta["save_version"] is float):
			resultado["meta"]["save_version"] = int(meta["save_version"])
		if meta.has("last_saved_unix") and (meta["last_saved_unix"] is int or meta["last_saved_unix"] is float):
			resultado["meta"]["last_saved_unix"] = int(meta["last_saved_unix"])
		if meta.has("student_name") and meta["student_name"] is String:
			var student_name := normalize_student_name(meta["student_name"])
			if is_valid_student_name(student_name):
				resultado["meta"]["student_name"] = student_name

	if normalizado.has("game") and normalizado["game"] is Dictionary:
		resultado["game"] = _validar_game(normalizado["game"])

	if normalizado.has("shop") and normalizado["shop"] is Dictionary:
		resultado["shop"] = _validar_shop(normalizado["shop"])

	if normalizado.has("stock") and normalizado["stock"] is Dictionary:
		resultado["stock"] = _validar_stock(normalizado["stock"])
	elif not data.is_empty():
		# Dados antigos sem estoque não recebem produtos silenciosamente durante a migração.
		resultado["stock"]["quantities"] = {}

	if normalizado.has("challenge") and normalizado["challenge"] is Dictionary:
		resultado["challenge"] = normalizado["challenge"].duplicate(true)

	if normalizado.has("delivery") and normalizado["delivery"] is Dictionary:
		resultado["delivery"] = _validar_delivery(normalizado["delivery"])

	if normalizado.has("interpreter") and normalizado["interpreter"] is Dictionary:
		resultado["interpreter"] = _validar_interpreter(normalizado["interpreter"])

	if normalizado.has("tutorial") and normalizado["tutorial"] is Dictionary:
		resultado["tutorial"] = _validar_tutorial(normalizado["tutorial"])

	return resultado

func _normalizar_formato(data: Dictionary) -> Dictionary:
	if data.has("game") or data.has("meta"):
		return data

	var convertido = _save_padrao()
	convertido["game"]["dinheiro"] = data.get("dinheiro", convertido["game"]["dinheiro"])
	convertido["game"]["unlocked_mechanics"] = data.get("unlocked_mechanics", convertido["game"]["unlocked_mechanics"])
	convertido["game"]["upgrades"] = data.get("upgrades", convertido["game"]["upgrades"])
	if data.has("script_text") and data["script_text"] is String:
		convertido["interpreter"]["script_text"] = data["script_text"]
	return convertido

func _validar_game(data: Dictionary) -> Dictionary:
	var resultado = _save_padrao()["game"]

	if data.has("dinheiro") and (data["dinheiro"] is int or data["dinheiro"] is float):
		resultado["dinheiro"] = int(data["dinheiro"])

	if data.has("secret_menu_unlocked"):
		resultado["secret_menu_unlocked"] = bool(data["secret_menu_unlocked"])

	if data.has("diamonds") and (data["diamonds"] is int or data["diamonds"] is float):
		resultado["diamonds"] = clampi(int(data["diamonds"]), 0, DeliveryConfigData.MAX_DIAMONDS)

	if data.has("game_completed"):
		resultado["game_completed"] = bool(data["game_completed"])

	if data.has("unlocked_mechanics") and data["unlocked_mechanics"] is Dictionary:
		for key in resultado["unlocked_mechanics"]:
			if data["unlocked_mechanics"].has(key):
				resultado["unlocked_mechanics"][key] = bool(data["unlocked_mechanics"][key])

	if data.has("upgrades") and data["upgrades"] is Array:
		resultado["upgrades"] = data["upgrades"].duplicate()

	return resultado

func _validar_shop(data: Dictionary) -> Dictionary:
	var resultado = _save_padrao()["shop"]

	if data.has("comprados"):
		if data["comprados"] is Dictionary:
			for id in data["comprados"]:
				resultado["comprados"][str(id)] = bool(data["comprados"][id])
		elif data["comprados"] is Array:
			for id in data["comprados"]:
				resultado["comprados"][str(id)] = true

	return resultado

func _validar_interpreter(data: Dictionary) -> Dictionary:
	var resultado = _save_padrao()["interpreter"]
	var workspace := ScriptWorkspace.new()

	if data.has("script_workspace") and data["script_workspace"] is Dictionary:
		var workspace_data: Dictionary = data["script_workspace"]
		if workspace_data.has("scripts") and workspace_data["scripts"] is Array and not workspace_data["scripts"].is_empty():
			workspace.deserialize(workspace_data)
		elif data.has("script_text") and data["script_text"] is String:
			workspace.migrate_old_save_if_needed(data)
		else:
			workspace.deserialize(workspace_data)
	elif data.has("scripts") and data["scripts"] is Array:
		workspace.deserialize(data)
	elif data.has("script_text") and data["script_text"] is String:
		workspace.migrate_old_save_if_needed(data)
	else:
		workspace.deserialize({})

	resultado["script_workspace"] = workspace.serialize()
	resultado["script_text"] = workspace.get_active_source()

	return resultado

func _validar_stock(data: Dictionary) -> Dictionary:
	var resultado = _save_padrao()["stock"]

	if data.has("quantities") and data["quantities"] is Dictionary:
		for item_name in data["quantities"]:
			var quantity = data["quantities"][item_name]
			if quantity is int or quantity is float:
				resultado["quantities"][str(item_name)] = max(0, int(quantity))

	return resultado

func _validar_tutorial(data: Dictionary) -> Dictionary:
	var resultado = _save_padrao()["tutorial"]

	if data.has("completed"):
		resultado["completed"] = bool(data["completed"])

	if data.has("step") and (data["step"] is int or data["step"] is float):
		resultado["step"] = max(0, int(data["step"]))

	return resultado

func _validar_delivery(data: Dictionary) -> Dictionary:
	if int(data.get("schema_version", 0)) == 2:
		# Structural map validation and interrupted-trip recovery live in DeliverySystem.
		return data.duplicate(true)
	var resultado = _save_padrao()["delivery"]
	resultado["state"] = clampi(int(data.get("state", 0)), 0, 3)
	resultado["next_report_id"] = maxi(1, int(data.get("next_report_id", 1)))
	resultado["active_report_id"] = maxi(0, int(data.get("active_report_id", 0)))
	resultado["last_rewarded_report_id"] = maxi(0, int(data.get("last_rewarded_report_id", 0)))
	resultado["next_report_unix"] = maxi(0, int(data.get("next_report_unix", 0)))

	for key in ["active_deliveries", "last_generated_deliveries"]:
		var raw_values = data.get(key, [])
		if raw_values is Array and raw_values.size() == DeliveryConfigData.REPORT_SIZE:
			var values := []
			var valid := true
			for raw_value in raw_values:
				if not (raw_value is int or raw_value is float) or float(raw_value) != float(int(raw_value)):
					valid = false
					break
				values.append(clampi(int(raw_value), DeliveryConfigData.MIN_DELIVERIES, DeliveryConfigData.MAX_DELIVERIES))
			if valid:
				resultado[key] = values

	if data.get("last_result") is Dictionary:
		resultado["last_result"] = data["last_result"].duplicate(true)

	if int(resultado["active_report_id"]) <= int(resultado["last_rewarded_report_id"]):
		resultado["active_report_id"] = 0
		resultado["active_deliveries"] = []
		if int(resultado["state"]) == 1:
			resultado["state"] = 2
	resultado["next_report_id"] = maxi(
		int(resultado["next_report_id"]),
		maxi(int(resultado["active_report_id"]), int(resultado["last_rewarded_report_id"])) + 1
	)
	return resultado

func _dados_compatibilidade(save_data: Dictionary) -> Dictionary:
	var game = save_data.get("game", {})
	var compat = save_data.duplicate(true)
	compat["dinheiro"] = game.get("dinheiro", 0)
	compat["unlocked_mechanics"] = game.get("unlocked_mechanics", {})
	compat["upgrades"] = game.get("upgrades", [])
	return compat
