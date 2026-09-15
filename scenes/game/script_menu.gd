extends Control

@onready var toggle_button: Button = $ColorRect2/Button
@onready var workspace_layer: CanvasLayer = $WorkspaceLayer
@onready var console = $WorkspaceLayer/Console
var aberto := false
var minimizado := false
var tutorial_fullscreen := false

func _ready() -> void:
	add_to_group("script_menu")
	get_viewport().size_changed.connect(_fit_workspace)
	console.close_requested.connect(func(): set_aberto(false))
	console.window_mode_requested.connect(set_minimizado)
	set_aberto(false)
	_sync_layer()

func get_console_editor() -> Control:
	return console

func set_aberto(value: bool) -> void:
	if not value and aberto:
		console.persist_source()
	aberto = value
	if value:
		set_minimizado(not tutorial_fullscreen)
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

func set_minimizado(value: bool) -> void:
	minimizado = value
	console.set_minimized_window(value)
	_fit_workspace()

func is_minimizado() -> bool:
	return minimizado

func set_tutorial_fullscreen(value: bool) -> void:
	tutorial_fullscreen = value
	if aberto:
		set_minimizado(not value)

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
	# Compensate canvas_items stretch locally so the IDE stays legible on small windows.
	var stretch := get_viewport().get_stretch_transform().get_scale()
	if stretch.x <= 0.0 or stretch.y <= 0.0:
		return
	var usable_size := get_viewport().get_visible_rect().size * stretch
	var workspace_size := usable_size
	var workspace_position := Vector2.ZERO
	if minimizado:
		workspace_size = usable_size * Vector2(1.0 / 3.0, 1.0 / 2.0)
		workspace_position = (usable_size - workspace_size) / stretch
	console.set_anchors_preset(Control.PRESET_TOP_LEFT)
	console.position = workspace_position
	console.scale = Vector2.ONE / stretch
	console.size = workspace_size
	console.update_layout(workspace_size.x)
