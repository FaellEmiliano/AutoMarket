extends Control

@onready var toggle_button: Button = $ColorRect2/Button
@onready var workspace_layer: CanvasLayer = $WorkspaceLayer
@onready var console = $WorkspaceLayer/Console
var aberto := false

func _ready() -> void:
	add_to_group("script_menu")
	get_viewport().size_changed.connect(_fit_workspace)
	console.close_requested.connect(func(): set_aberto(false))
	set_aberto(false)
	_sync_layer()

func get_console_editor() -> Control:
	return console

func set_aberto(value: bool) -> void:
	if not value and aberto:
		console.persist_source()
	aberto = value
	console.visible = value
	if StudentIdentity.has_method("set_editor_mode"):
		StudentIdentity.set_editor_mode(value)
	_fit_workspace()
	toggle_button.set_pressed_no_signal(value)
	$ColorRect2.visible = not value
	if value:
		console._sync_documents()
		if console.tabs.active_kind == "script":
			console.code_edit.grab_focus()
	else:
		console.code_edit.release_focus()

func is_aberto() -> bool:
	return aberto

func _on_button_toggled(value: bool) -> void:
	set_aberto(value)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED and is_node_ready():
		_sync_layer.call_deferred()

func _sync_layer() -> void:
	# Tutorial reparents this Control into its highlight CanvasLayer.
	workspace_layer.layer = get_parent().layer if get_parent() is CanvasLayer else 5

func _fit_workspace() -> void:
	console.set_anchors_preset(Control.PRESET_TOP_LEFT)
	console.position = Vector2.ZERO
	console.scale = Vector2.ONE
	console.size = get_viewport().get_visible_rect().size
	# canvas_items already scales the logical canvas; breakpoints use the
	# physical window width so the IDE can select wide/medium/compact naturally.
	console.update_layout(get_window().size.x)
