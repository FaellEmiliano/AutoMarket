extends Node

const ScriptWorkspace = preload("res://systems/ScriptWorkspace.gd")

func _ready() -> void:
	_test_workspace_documents()
	_test_legacy_migration()
	_test_delivery_document()
	_test_language_migration()
	_test_language_round_trip_is_idempotent()
	print("SCRIPT_WORKSPACE_SMOKE_TEST_OK")
	await get_tree().process_frame
	get_tree().quit()

func _test_workspace_documents() -> void:
	var workspace := ScriptWorkspace.new()
	assert(workspace.scripts.size() == 1, "Workspace deve iniciar com uma aba.")
	assert(workspace.get_active_title() == "Principal", "A primeira aba deve ser Principal.")
	assert(workspace.get_active_script().get("language") == "c_like", "A aba Principal deve iniciar como C-like.")

	var principal_id := workspace.active_script_id
	workspace.update_active_source("codigo principal")

	var new_id := workspace.create_script()
	assert(new_id != principal_id, "Nova aba deve receber id diferente.")
	assert(workspace.get_script_document(new_id).get("language") == "c_like", "Nova aba deve iniciar como C-like.")
	workspace.set_active_script(new_id)
	assert(workspace.get_active_source().contains("int main"), "Nova aba deve iniciar com codigo base.")
	assert(workspace.set_active_language("python_like"), "Deve permitir selecionar Python-like na aba ativa.")
	assert(workspace.get_active_script().get("language") == "python_like", "A troca de linguagem deve afetar somente a aba ativa.")
	assert(not workspace.set_active_language("desconhecida"), "Nao deve aceitar uma linguagem sem backend.")
	workspace.set_active_language("c_like")

	workspace.update_active_source("codigo novo")
	workspace.set_active_script(principal_id)
	assert(workspace.get_active_source() == "codigo principal", "Trocar de aba nao pode perder o codigo Principal.")
	workspace.set_active_script(new_id)
	assert(workspace.get_active_source() == "codigo novo", "Trocar de volta nao pode perder o codigo da aba nova.")

	workspace.rename_script(new_id, "Principal")
	assert(workspace.get_script_document(new_id).get("title") == "Principal", "Renomear deve permitir nomes repetidos.")
	assert(workspace.get_script_document(new_id).get("id") == new_id, "Renomear nao pode alterar o id interno.")

	var serialized := workspace.serialize()
	assert(serialized.get("version") == 4, "Workspace serializado deve usar a versao 4.")
	assert(serialized["scripts"][1].get("language") == "c_like", "Serializacao deve preservar a linguagem da aba.")
	var loaded := ScriptWorkspace.new()
	loaded.deserialize(serialized)
	assert(loaded.scripts.size() == 2, "Load deve restaurar todas as abas.")
	assert(loaded.scripts[0].get("id") == principal_id, "Load deve preservar a ordem visual.")
	assert(loaded.active_script_id == new_id, "Load deve restaurar a aba ativa.")
	assert(loaded.get_active_source() == "codigo novo", "Load deve restaurar o texto da aba ativa.")

	assert(loaded.delete_script(principal_id), "Deve apagar uma aba quando ainda existe outra.")
	assert(loaded.active_script_id == new_id, "Apagar outra aba nao pode invalidar a aba ativa.")
	assert(not loaded.delete_script(new_id), "Nao deve apagar a ultima aba.")

func _test_legacy_migration() -> void:
	var migrated := ScriptWorkspace.new()
	migrated.deserialize({"script_text": "codigo antigo"})
	assert(migrated.scripts.size() == 1, "Save antigo deve virar uma aba.")
	assert(migrated.get_active_title() == "Principal", "Save antigo deve migrar para Principal.")
	assert(migrated.get_active_source() == "codigo antigo", "Migracao nao pode perder o codigo antigo.")
	assert(migrated.get_active_script().get("language") == "c_like", "Save legado com script_text deve migrar para C-like.")

func _test_delivery_document() -> void:
	var workspace := ScriptWorkspace.new()
	var delivery_id := workspace.ensure_delivery_script()
	assert(not delivery_id.is_empty(), "Delivery deve receber um id próprio.")
	assert(workspace.get_script_document(delivery_id).get("title") == "Delivery", "A aba reservada deve se chamar Delivery.")
	assert(workspace.get_script_document(delivery_id).get("language") == "c_like", "A aba reservada Delivery deve iniciar como C-like.")
	workspace.rename_script(delivery_id, "Outro nome")
	assert(workspace.get_script_document(delivery_id).get("title") == "Delivery", "A aba Delivery não pode ser renomeada.")
	assert(not workspace.delete_script(delivery_id), "A aba Delivery não pode ser apagada.")
	workspace.set_active_script(delivery_id)
	workspace.update_active_source("codigo delivery")
	var loaded := ScriptWorkspace.new()
	loaded.deserialize(workspace.serialize())
	assert(loaded.delivery_script_id == delivery_id, "O save deve preservar o id da aba Delivery.")
	assert(loaded.get_script_document(delivery_id).get("source") == "codigo delivery", "O save deve preservar o código do Delivery.")

func _test_language_migration() -> void:
	var old_document := {
		"version": 3,
		"active_script_id": "script_001",
		"main_script_id": "script_001",
		"stock_script_id": "script_002",
		"delivery_script_id": "",
		"scripts": [
			{"id": "script_001", "title": "Principal", "source": "codigo principal"},
			{"id": "script_002", "title": "Estoque", "source": "codigo estoque"}
		]
	}
	var migrated := ScriptWorkspace.new()
	migrated.deserialize(old_document)
	assert(migrated.get_script_document("script_001").get("language") == "c_like", "Documento antigo deve receber C-like.")
	assert(migrated.get_script_document("script_002").get("language") == "c_like", "Aba reservada antiga de Estoque deve receber C-like.")

	var existing_language := old_document.duplicate(true)
	existing_language["scripts"][0]["language"] = "python_like"
	var preserved := ScriptWorkspace.new()
	preserved.deserialize(existing_language)
	assert(preserved.get_script_document("script_001").get("language") == "python_like", "Desserializacao deve preservar uma linguagem existente.")

func _test_language_round_trip_is_idempotent() -> void:
	var workspace := ScriptWorkspace.new()
	var serialized := workspace.serialize()
	serialized["scripts"][0]["language"] = "python_like"

	var first_load := ScriptWorkspace.new()
	first_load.deserialize(serialized)
	var first_serialization := first_load.serialize()
	assert(first_serialization["scripts"][0].get("language") == "python_like", "Round-trip deve preservar a linguagem.")

	var second_load := ScriptWorkspace.new()
	second_load.deserialize(first_serialization)
	var second_serialization := second_load.serialize()
	assert(second_serialization == first_serialization, "Normalizacao repetida deve ser idempotente.")
