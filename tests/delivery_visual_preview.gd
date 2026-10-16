extends Control

const PanelScene = preload("res://scenes/delivery/delivery_panel.tscn")
const EditorScene = preload("res://scenes/game/script_menu.tscn")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://.tmp")
	get_window().size = Vector2i(1280, 720)
	FeatureManager.unlock_feature(FeatureManager.FEATURE_DELIVERY)
	var id := InterpreterSystem.ensure_delivery_script()
	var source := FileAccess.get_file_as_string("res://docs/examples/delivery_bfs.py")
	InterpreterSystem.script_workspace.get_script_document(id).source = source
	InterpreterSystem.script_workspace.set_active_script(id)
	var panel := PanelScene.instantiate()
	add_child(panel)
	panel.open_panel()
	var editor := EditorScene.instantiate()
	add_child(editor)
	editor.set_aberto(true)
	await get_tree().create_timer(1).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.tmp/delivery_preview.png")
	InterpreterSystem.runtime_manager.start_script(id, source, "Delivery BFS", null, "python_like")
	await get_tree().create_timer(3).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.tmp/delivery_moving.png")
	print("DELIVERY_VISUAL_PREVIEW_READY")
	await get_tree().create_timer(25).timeout
	print("DELIVERY_VISUAL_ARRIVALS ", DeliverySystem.completed_deliveries)
	InterpreterSystem.stop_all()
	get_tree().quit()
