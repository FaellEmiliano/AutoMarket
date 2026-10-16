extends Node

const PanelScene = preload("res://scenes/delivery/delivery_panel.tscn")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://.tmp")
	DeliverySystem.set_process(false)
	DeliverySystem.unlock(false)
	var panel := PanelScene.instantiate()
	add_child(panel)
	panel.open_panel()
	await get_tree().process_frame
	check(panel.visible, "Delivery opens")
	check(panel.status_label.text.contains("PENDENTE"), "Pending indicator")
	check(panel.progress_label.text.contains("R$ 40"), "Reward visible")
	check(panel.map_renderer.get("_view").map.matrix == DeliverySystem.current_matrix(), "Renderer observes actual matrix")
	DeliverySystem.submit_route([], DeliverySystem.active_report_id)
	check(panel.feedback_label.text.contains("vazia"), "Navigation error visible")
	for resolution in [Vector2i(640, 480), Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = resolution
		await get_tree().process_frame
		await get_tree().process_frame
		panel._fit_panel()
		var bounds := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		check(bounds.encloses(panel.frame.get_global_rect()), "Map panel fits %s" % resolution)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://.tmp/delivery_%dx%d.png" % [resolution.x, resolution.y])
	panel.close_panel()
	check(not panel.visible and not get_tree().paused, "Closing does not pause market")
	panel.queue_free()
	await get_tree().process_frame
	await _test_close_in_game_hud()
	if failures.is_empty():
		print("DELIVERY_UI_TEST_OK")
	else:
		for message in failures:
			push_error(message)
	get_tree().quit(0 if failures.is_empty() else 1)


func _test_close_in_game_hud() -> void:
	# Preserve the actual instance overrides from game.tscn; a standalone panel
	# misses disabled input inherited from that scene.
	var game = load("res://scenes/game/game.tscn").instantiate()
	var hud = game.get_node("HUD")
	game.remove_child(hud)
	game.free()
	add_child(hud)
	var panel = hud.get_node("DeliveryPanel")
	panel.open_panel()
	await get_tree().process_frame
	await get_tree().process_frame
	var button: Button = panel.get_node("%CloseButton")
	var center := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = center
		click.global_position = center
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		get_viewport().push_input(click, true)
		await get_tree().process_frame
	check(not panel.visible, "Real click on Close must hide the Delivery panel inside game.tscn")
	check(not get_tree().paused, "Closing the integrated map must not pause gameplay")
	hud.queue_free()
	await get_tree().process_frame
