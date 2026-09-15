extends Node

const MainScreenScene = preload("res://scenes/menus/main_screen.tscn")
const BASE_RESOLUTION := Vector2i(1920, 1080)
const SUPPORTED_RESOLUTIONS := [
	BASE_RESOLUTION,
	Vector2i(1280, 720),
	Vector2i(960, 540),
]

var _failures: Array[String] = []


func _ready() -> void:
	_check(
		ProjectSettings.get_setting("display/window/size/viewport_width", 0) == BASE_RESOLUTION.x,
		"O canvas logico deve ter largura 1920.",
	)
	_check(
		ProjectSettings.get_setting("display/window/size/viewport_height", 0) == BASE_RESOLUTION.y,
		"O canvas logico deve ter altura 1080.",
	)
	_check(
		ProjectSettings.get_setting("display/window/stretch/mode", "") == "canvas_items",
		"A UI deve continuar usando canvas_items.",
	)
	_check(
		ProjectSettings.get_setting("display/window/stretch/aspect", "") == "keep",
		"A politica de aspecto deve preservar o canvas 16:9.",
	)
	_check(
		ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", -1) == 0,
		"A pixel art deve continuar usando filtro nearest.",
	)

	for resolution in SUPPORTED_RESOLUTIONS:
		get_window().size = resolution
		await get_tree().process_frame
		await get_tree().process_frame
		_check(get_window().size == resolution, "A janela deve aceitar %s." % resolution)
		_check(not get_viewport().get_visible_rect().size.is_zero_approx(), "A viewport deve continuar valida em %s." % resolution)
		await _check_main_screen(resolution)

	if _failures.is_empty():
		print("UI_VIEWPORT_CONTRACT_TEST_OK")
	else:
		push_error("\n".join(_failures))
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _check_main_screen(resolution: Vector2i) -> void:
	var main_screen := MainScreenScene.instantiate() as Control
	add_child(main_screen)
	await get_tree().process_frame
	var viewport_size := get_viewport().get_visible_rect().size
	_check(main_screen.get_global_rect().size.is_equal_approx(viewport_size), "A tela inicial deve preencher a viewport em %s." % resolution)
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	for path in ["VBoxContainer/Start", "VBoxContainer/Help", "Github"]:
		var control := main_screen.get_node(path) as Control
		_check(control != null and viewport_rect.encloses(control.get_global_rect()), "%s deve permanecer visivel em %s." % [path, resolution])
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var screenshot_path := "user://ui_viewport_%dx%d.png" % [resolution.x, resolution.y]
		_check(image.save_png(screenshot_path) == OK, "A captura visual deve ser salva em %s." % resolution)
	main_screen.queue_free()
	await get_tree().process_frame
