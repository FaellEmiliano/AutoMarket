extends RefCounted

const WORKSPACE_VERSION := 4
const DEFAULT_LANGUAGE := "c_like"
const DEFAULT_SOURCE := "int main(){\n\n}\n"
const DEFAULT_TITLE := "Principal"
const DELIVERY_TITLE := "Delivery"
const DELIVERY_SOURCE := """int main() {
	// Leia o relatório do Delivery e declare os lucros.
}
"""

var active_script_id := ""
var main_script_id := ""
var stock_script_id := ""
var delivery_script_id := ""

var scripts: Array[Dictionary] = []
var _next_id_number := 1

func _init() -> void:
	_ensure_default_script()

func create_script(title: String = "", source: String = DEFAULT_SOURCE) -> String:
	return _create_script(title, source, DEFAULT_LANGUAGE)

func _create_script(title: String, source: String, language: String) -> String:
	var clean_title := title.strip_edges()
	if clean_title.is_empty():
		clean_title = _make_new_script_title()

	var now := Time.get_unix_time_from_system()
	var script := {
		"id": _generate_id(),
		"title": clean_title,
		"source": source,
		"language": language,
		"created_at": now,
		"updated_at": now
	}
	scripts.append(script)

	if active_script_id.is_empty():
		active_script_id = str(script["id"])
	if main_script_id.is_empty():
		main_script_id = str(script["id"])

	return str(script["id"])

func delete_script(id: String) -> bool:
	if id == delivery_script_id:
		return false
	if scripts.size() <= 1:
		return false

	var index := _find_script_index(id)
	if index == -1:
		return false

	var was_active := active_script_id == id
	scripts.remove_at(index)

	if main_script_id == id:
		main_script_id = str(scripts[0]["id"])
	if stock_script_id == id:
		stock_script_id = ""
	if delivery_script_id == id:
		delivery_script_id = ""
	if was_active:
		var next_index: int = mini(index, scripts.size() - 1)
		next_index = maxi(next_index, 0)
		active_script_id = str(scripts[next_index]["id"])
	elif _find_script_index(active_script_id) == -1:
		active_script_id = str(scripts[0]["id"])

	return true

func rename_script(id: String, new_title: String) -> void:
	if id == delivery_script_id:
		return
	var script := get_script_document(id)
	if script.is_empty():
		return

	var clean_title := new_title.strip_edges()
	if clean_title.is_empty():
		clean_title = "Sem nome"

	script["title"] = clean_title
	script["updated_at"] = Time.get_unix_time_from_system()

func duplicate_script(id: String) -> String:
	var script := get_script_document(id)
	if script.is_empty():
		return ""
	return _create_script(
		str(script.get("title", DEFAULT_TITLE)) + " copia",
		str(script.get("source", DEFAULT_SOURCE)),
		str(script.get("language", DEFAULT_LANGUAGE))
	)

func get_script_document(id: String) -> Dictionary:
	var index := _find_script_index(id)
	if index == -1:
		return {}
	return scripts[index]

func get_active_script() -> Dictionary:
	_ensure_valid_active_script()
	return get_script_document(active_script_id)

func set_active_script(id: String) -> void:
	if _find_script_index(id) == -1:
		return
	active_script_id = id

func update_active_source(source: String) -> void:
	var script := get_active_script()
	if script.is_empty():
		return
	script["source"] = source
	script["updated_at"] = Time.get_unix_time_from_system()

func get_active_source() -> String:
	var script := get_active_script()
	return str(script.get("source", ""))

func get_active_title() -> String:
	var script := get_active_script()
	return str(script.get("title", DEFAULT_TITLE))

func ensure_delivery_script() -> String:
	if not delivery_script_id.is_empty() and _find_script_index(delivery_script_id) != -1:
		return delivery_script_id
	delivery_script_id = create_script(DELIVERY_TITLE, DELIVERY_SOURCE)
	return delivery_script_id

func is_reserved_script(id: String) -> bool:
	return not delivery_script_id.is_empty() and id == delivery_script_id

func serialize() -> Dictionary:
	_ensure_default_script()
	_ensure_valid_active_script()
	return {
		"version": WORKSPACE_VERSION,
		"active_script_id": active_script_id,
		"main_script_id": main_script_id,
		"stock_script_id": stock_script_id,
		"delivery_script_id": delivery_script_id,
		"scripts": scripts.duplicate(true)
	}

func deserialize(data: Dictionary) -> void:
	scripts.clear()
	active_script_id = ""
	main_script_id = ""
	stock_script_id = ""
	delivery_script_id = ""
	_next_id_number = 1

	if data.has("script_workspace") and data["script_workspace"] is Dictionary:
		var workspace_data: Dictionary = data["script_workspace"]
		if workspace_data.has("scripts") and workspace_data["scripts"] is Array and not workspace_data["scripts"].is_empty():
			data = workspace_data
		elif data.has("script_text") and data["script_text"] is String:
			data = {"script_text": data["script_text"]}
		else:
			data = workspace_data

	if data.has("scripts") and data["scripts"] is Array:
		for raw_script in data["scripts"]:
			if raw_script is Dictionary:
				var normalized := _normalize_script(raw_script)
				if not normalized.is_empty():
					scripts.append(normalized)

		active_script_id = str(data.get("active_script_id", ""))
		main_script_id = str(data.get("main_script_id", ""))
		stock_script_id = str(data.get("stock_script_id", ""))
		delivery_script_id = str(data.get("delivery_script_id", ""))
	elif data.has("script_text") and data["script_text"] is String:
		_migrate_old_save_if_needed(data)

	_update_next_id_number()
	_ensure_default_script()
	_ensure_valid_active_script()

	if main_script_id.is_empty() or _find_script_index(main_script_id) == -1:
		main_script_id = str(scripts[0]["id"])
	if not stock_script_id.is_empty() and _find_script_index(stock_script_id) == -1:
		stock_script_id = ""
	if not delivery_script_id.is_empty() and _find_script_index(delivery_script_id) == -1:
		delivery_script_id = ""

func migrate_old_save_if_needed(data: Dictionary) -> void:
	if data.has("scripts") or data.has("script_workspace"):
		deserialize(data)
		return
	_migrate_old_save_if_needed(data)
	_update_next_id_number()
	_ensure_default_script()
	_ensure_valid_active_script()

func _migrate_old_save_if_needed(data: Dictionary) -> void:
	scripts.clear()
	active_script_id = ""
	main_script_id = ""
	stock_script_id = ""
	delivery_script_id = ""
	_next_id_number = 1

	var old_source := ""
	if data.has("script_text") and data["script_text"] is String:
		old_source = str(data["script_text"])

	var id := create_script(DEFAULT_TITLE, old_source)
	active_script_id = id
	main_script_id = id

func _normalize_script(raw_script: Dictionary) -> Dictionary:
	var id := str(raw_script.get("id", "")).strip_edges()
	if id.is_empty() or _find_script_index(id) != -1:
		id = _generate_id()

	var title := str(raw_script.get("title", DEFAULT_TITLE)).strip_edges()
	if title.is_empty():
		title = "Sem nome"

	var now := Time.get_unix_time_from_system()
	var created_at: Variant = raw_script.get("created_at", now)
	var updated_at: Variant = raw_script.get("updated_at", created_at)

	return {
		"id": id,
		"title": title,
		"source": str(raw_script.get("source", "")),
		"language": str(raw_script.get("language", DEFAULT_LANGUAGE)),
		"created_at": created_at,
		"updated_at": updated_at
	}

func _ensure_default_script() -> void:
	if not scripts.is_empty():
		return
	var id := create_script(DEFAULT_TITLE, "")
	active_script_id = id
	main_script_id = id

func _ensure_valid_active_script() -> void:
	if scripts.is_empty():
		_ensure_default_script()
	if _find_script_index(active_script_id) == -1:
		active_script_id = str(scripts[0]["id"])

func _find_script_index(id: String) -> int:
	for index in range(scripts.size()):
		if str(scripts[index].get("id", "")) == id:
			return index
	return -1

func _generate_id() -> String:
	var id := ""
	while id.is_empty() or _find_script_index(id) != -1:
		id = "script_%03d" % _next_id_number
		_next_id_number += 1
	return id

func _update_next_id_number() -> void:
	var max_number := 0
	for script in scripts:
		var id := str(script.get("id", ""))
		if id.begins_with("script_"):
			var number := id.substr(7).to_int()
			max_number = maxi(max_number, number)
	_next_id_number = maxi(max_number + 1, _next_id_number)

func _make_new_script_title() -> String:
	var used_titles := {}
	for script in scripts:
		used_titles[str(script.get("title", ""))] = true

	if not used_titles.has("Novo Script"):
		return "Novo Script"

	var number := 2
	while used_titles.has("Novo Script %d" % number):
		number += 1
	return "Novo Script %d" % number
