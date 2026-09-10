extends Tree

signal document_selected(kind: String, id: String)
signal script_menu_requested(id: String)
const Topics = preload("res://data/HelpTopics.gd")
const Progress = preload("res://systems/HelpProgress.gd")
const STATES := {"running": "RODANDO", "sleeping": "DORMINDO", "waiting_input": "AGUARDANDO", "error": "ERRO", "finished": "FINALIZADO", "stopped": "PARADO"}
var script_items := {}
var topic_items := {}
var _syncing := false
var _scripts_root: TreeItem

func _ready() -> void:
	hide_root = true
	select_mode = Tree.SELECT_ROW
	allow_rmb_select = true
	item_selected.connect(_selected)
	item_mouse_selected.connect(_mouse_selected)
	var root := create_item()
	_scripts_root = create_item(root)
	_scripts_root.set_text(0, "SCRIPTS")
	_scripts_root.set_selectable(0, false)
	var docs := create_item(root)
	docs.set_text(0, "DOCUMENTAÇÃO")
	docs.set_selectable(0, false)
	var categories := {}
	for topic in Topics.TOPICS:
		var category := str(topic.category)
		if not categories.has(category):
			var item := create_item(docs)
			item.set_text(0, category)
			item.set_selectable(0, false)
			item.collapsed = true
			categories[category] = item
		var item := create_item(categories[category])
		item.set_metadata(0, {"kind": "help", "id": str(topic.id)})
		topic_items[str(topic.id)] = item
	refresh_topics()

func refresh_scripts() -> void:
	_syncing = true
	var ids := []
	for document in InterpreterSystem.get_scripts():
		var id := str(document.id)
		ids.append(id)
		if not script_items.has(id):
			var item := create_item(_scripts_root)
			item.set_metadata(0, {"kind": "script", "id": id})
			script_items[id] = item
		var item: TreeItem = script_items[id]
		item.set_text(0, str(document.title))
		item.set_tooltip_text(0, str(document.title))
	for id in script_items.keys():
		if not ids.has(id):
			script_items[id].free()
			script_items.erase(id)
	_syncing = false
	refresh_states()

func refresh_states() -> void:
	for document in InterpreterSystem.get_scripts():
		var id := str(document.id)
		if not script_items.has(id):
			continue
		var state := str(InterpreterSystem.get_runtime_by_script_id(id).get("status", "stopped"))
		var item: TreeItem = script_items[id]
		var title := str(document.title)
		item.set_text(0, title + ("  · " + STATES.get(state, "PARADO") if state not in ["stopped", "finished"] else ""))
		item.set_tooltip_text(0, title + " — " + STATES.get(state, "PARADO"))
		item.set_custom_color(0, Color("e9a28e") if state == "error" else Color("dce4e8"))

func refresh_topics(_arg = null) -> void:
	for topic in Topics.TOPICS:
		var item: TreeItem = topic_items[str(topic.id)]
		var unlocked := Progress.is_requirement_met(topic.get("requirement", ""))
		item.set_text(0, str(topic.title) + ("" if unlocked else " · Bloqueado"))
		item.set_tooltip_text(0, str(topic.title) + ("" if unlocked else " — disponível ao avançar no mercado"))
		item.set_custom_color(0, Color("dce4e8") if unlocked else Color("8d9da7"))

func select_document(kind: String, id: String) -> void:
	var items := script_items if kind == "script" else topic_items
	if items.has(id):
		_syncing = true
		items[id].select(0)
		_syncing = false

func _selected() -> void:
	if _syncing or get_selected() == null:
		return
	var data = get_selected().get_metadata(0)
	if data is Dictionary:
		document_selected.emit(data.kind, data.id)

func _mouse_selected(_position: Vector2, button: int) -> void:
	if button != MOUSE_BUTTON_RIGHT or get_selected() == null:
		return
	var data = get_selected().get_metadata(0)
	if data is Dictionary and data.kind == "script":
		script_menu_requested.emit(data.id)
