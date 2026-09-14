extends TabBar

signal document_selected(kind: String, id: String)
const CLOSE = preload("res://assets/icons/ide_close.svg")
const STATE_ICONS := {
	"running": preload("res://assets/icons/ide_running.svg"),
	"sleeping": preload("res://assets/icons/ide_sleeping.svg"),
	"waiting_input": preload("res://assets/icons/ide_sleeping.svg"),
	"error": preload("res://assets/icons/ide_error.svg")
}
var help_ids: Array[String] = []
var open_script_ids: Array[String] = []
var active_kind := "script"
var active_id := ""
var _syncing := false

func _ready() -> void:
	clip_tabs = true
	max_tab_width = 220
	tab_changed.connect(_selected)
	tab_button_pressed.connect(close_tab)

func refresh() -> void:
	_syncing = true
	clear_tabs()
	var existing_ids: Array[String] = []
	for document in InterpreterSystem.get_scripts():
		existing_ids.append(str(document.id))
	for index in range(open_script_ids.size() - 1, -1, -1):
		if not existing_ids.has(open_script_ids[index]):
			open_script_ids.remove_at(index)
	if active_kind == "script" and existing_ids.has(active_id) and not open_script_ids.has(active_id):
		open_script_ids.append(active_id)
	for document in InterpreterSystem.get_scripts():
		if open_script_ids.has(str(document.id)):
			_add_document("script", str(document.id), str(document.title))
	for id in help_ids:
		for topic in HelpTopics.TOPICS:
			if str(topic.id) == id:
				_add_document("help", id, str(topic.title) + " — Documentação")
	_syncing = false

func _add_document(kind: String, id: String, title: String) -> void:
	add_tab(title)
	var index := get_tab_count() - 1
	set_tab_metadata(index, {"kind": kind, "id": id})
	set_tab_tooltip(index, title)
	set_tab_button_icon(index, CLOSE)
	set_tab_tooltip(index, title + (" — Fechar aba não exclui o script" if kind == "script" else " — Fechar documentação"))
	if kind == active_kind and id == active_id:
		current_tab = index

func activate(kind: String, id: String) -> void:
	active_kind = kind
	active_id = id
	if kind == "script" and not open_script_ids.has(id):
		open_script_ids.append(id)
		refresh()
	if kind == "help" and not help_ids.has(id):
		help_ids.append(id)
		refresh()
	_syncing = true
	for index in range(get_tab_count()):
		var data: Dictionary = get_tab_metadata(index)
		if data.kind == kind and data.id == id:
			current_tab = index
	_syncing = false

func close_tab(index: int) -> void:
	if index < 0 or index >= get_tab_count():
		return
	var data: Dictionary = get_tab_metadata(index)
	if data.kind == "script":
		if open_script_ids.size() <= 1:
			return
		open_script_ids.erase(str(data.id))
	else:
		help_ids.erase(str(data.id))
	if active_kind == data.kind and active_id == data.id:
		var fallback := _fallback_document(index, data)
		active_kind = str(fallback.kind)
		active_id = str(fallback.id)
		refresh()
		document_selected.emit(active_kind, active_id)
	else:
		refresh()

func close_help_tab(index: int) -> void:
	# Kept as a public compatibility wrapper for existing tests and callers.
	if index >= 0 and index < get_tab_count():
		var data: Dictionary = get_tab_metadata(index)
		if data.kind == "help":
			close_tab(index)

func _fallback_document(closing_index: int, closing_data: Dictionary) -> Dictionary:
	if closing_data.kind == "help":
		var current_script_id := str(InterpreterSystem.get_active_script().id)
		if not open_script_ids.has(current_script_id):
			open_script_ids.append(current_script_id)
		return {"kind": "script", "id": current_script_id}
	for candidate_index in [closing_index - 1, closing_index + 1]:
		if candidate_index >= 0 and candidate_index < get_tab_count():
			var candidate: Dictionary = get_tab_metadata(candidate_index)
			if candidate.kind != closing_data.kind or candidate.id != closing_data.id:
				return candidate
	if not open_script_ids.is_empty():
		return {"kind": "script", "id": open_script_ids[0]}
	return {"kind": "empty", "id": ""}

func _selected(index: int) -> void:
	if not _syncing and index >= 0:
		var data: Dictionary = get_tab_metadata(index)
		document_selected.emit(data.kind, data.id)
