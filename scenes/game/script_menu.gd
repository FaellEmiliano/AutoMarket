extends Control

@onready var toggle_button: Button = $ColorRect2/Button
@onready var workspace_layer: CanvasLayer = $WorkspaceLayer
@onready var console = $WorkspaceLayer/Console
enum WindowState { CLOSED, DOCKED, FULLSCREEN }
var window_state := WindowState.CLOSED
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
	_set_window_state(
		(WindowState.FULLSCREEN if tutorial_fullscreen else WindowState.DOCKED)
		if value else WindowState.CLOSED
	)

func _set_window_state(next_state: WindowState) -> void:
	if next_state == window_state:
		return
	if next_state == WindowState.CLOSED and window_state != WindowState.CLOSED:
		console.persist_source()
	window_state = next_state
	var open := window_state != WindowState.CLOSED
	console.visible = open
	console.set_minimized_window(window_state == WindowState.DOCKED)
	if StudentIdentity.has_method("set_editor_mode"):
		StudentIdentity.set_editor_mode(open)
	_fit_workspace()
	toggle_button.set_pressed_no_signal(open)
	$ColorRect2.visible = not open
	if open:
		console._sync_documents()
		if console.tabs.active_kind == "script":
			console.code_edit.grab_focus()
	else:
		get_viewport().gui_release_focus()

func set_minimizado(value: bool) -> void:
	if window_state == WindowState.CLOSED:
		return
	_set_window_state(WindowState.DOCKED if value else WindowState.FULLSCREEN)

func is_minimizado() -> bool:
	return window_state == WindowState.DOCKED

func set_tutorial_fullscreen(value: bool) -> void:
	tutorial_fullscreen = value
	if is_aberto():
		set_minimizado(not value)

func is_aberto() -> bool:
	return window_state != WindowState.CLOSED

func get_window_state() -> WindowState:
	return window_state

func _on_button_toggled(value: bool) -> void:
	set_aberto(value)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED and is_node_ready():
		_sync_layer.call_deferred()

func _sync_layer() -> void:
	# Tutorial reparents this Control into its highlight CanvasLayer.
	workspace_layer.layer = get_parent().layer if get_parent() is CanvasLayer else 5

func _fit_workspace() -> void:
	# Keep this overlay responsive in physical window space without imposing a
	# different logical resolution on the rest of the game.
	var stretch := get_viewport().get_stretch_transform().get_scale()
	if stretch.x <= 0.0 or stretch.y <= 0.0:
		return
	var usable_size := Vector2(get_window().size)
	var workspace_size := usable_size
	var workspace_position := Vector2.ZERO
	if window_state == WindowState.DOCKED:
		workspace_size = docked_size_for(usable_size)
		workspace_position = (usable_size - workspace_size) / stretch
	console.set_anchors_preset(Control.PRESET_TOP_LEFT)
	console.position = workspace_position
	console.scale = Vector2.ONE / stretch
	console.size = workspace_size
	console.update_layout(workspace_size.x)

func docked_size_for(usable_size: Vector2) -> Vector2:
	var desired := usable_size * Vector2(0.45, 0.60)
	return Vector2(
		clampf(desired.x, minf(520.0, usable_size.x), usable_size.x),
		clampf(desired.y, minf(380.0, usable_size.y), usable_size.y)
	)
