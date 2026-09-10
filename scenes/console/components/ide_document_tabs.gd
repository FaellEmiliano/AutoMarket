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
var active_kind := "script"
var active_id := ""
var _syncing := false

func _ready() -> void:
	clip_tabs = true
	max_tab_width = 220
	tab_changed.connect(_selected)
	tab_button_pressed.connect(close_help_tab)

func refresh() -> void:
	_syncing = true
	clear_tabs()
	for document in InterpreterSystem.get_scripts():
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
	if kind == "help":
		set_tab_button_icon(index, CLOSE)
	if kind == active_kind and id == active_id:
		current_tab = index

func activate(kind: String, id: String) -> void:
	active_kind = kind
	active_id = id
	if kind == "help" and not help_ids.has(id):
		help_ids.append(id)
		refresh()
	_syncing = true
	for index in range(get_tab_count()):
		var data: Dictionary = get_tab_metadata(index)
		if data.kind == kind and data.id == id:
			current_tab = index
	_syncing = false

func close_help_tab(index: int) -> void:
	var data: Dictionary = get_tab_metadata(index)
	if data.kind != "help":
		return
	help_ids.erase(data.id)
	if active_kind == "help" and active_id == data.id:
		active_kind = "script"
		active_id = str(InterpreterSystem.get_active_script().id)
		refresh()
		document_selected.emit(active_kind, active_id)
	else:
		refresh()

func _selected(index: int) -> void:
	if not _syncing and index >= 0:
		var data: Dictionary = get_tab_metadata(index)
		document_selected.emit(data.kind, data.id)
