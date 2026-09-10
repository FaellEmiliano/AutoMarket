extends Control
class_name DialogScreen

var _step :float = 0.05

var _id :int = 0
var data :Dictionary = {}
var auto_advance := false
var auto_advance_delay := 1.2
var _advancing := false
var _auto_advance_serial := 0

const AUTO_ADVANCE_MIN_DELAY := 1.4
const AUTO_ADVANCE_MAX_DELAY := 4.0
const AUTO_ADVANCE_SECONDS_PER_CHAR := 0.025

signal end_dialog()



@export_category("Objects")
@export var _name :Label = null
@export var _dialog :RichTextLabel = null
@export var _faceset :TextureRect = null

func _ready() -> void:
	_initialize_dialog()

func _process(_delta: float) -> void:
	for menu in get_tree().get_nodes_in_group("script_menu"):
		if menu.is_aberto():
			_step = 0.05
			return
	if Input.is_action_pressed("ui_accept") and _dialog.visible_ratio < 1:
		_step = 0.01
		return
	_step = 0.05
	if Input.is_action_just_pressed("ui_accept"):
		_advance()

func _initialize_dialog() -> void:
	_auto_advance_serial += 1
	var dialog_serial := _auto_advance_serial
	_advancing = false
	if data.is_empty() or not data.has(_id):
		push_error("DialogScreen recebeu dados invalidos.")
		queue_free()
		return

	var dialog_data = data[_id]
	_name.text = dialog_data["title"]
	_dialog.text = dialog_data["dialog"]
	_faceset.texture = load(dialog_data["faceset"])
	
	_dialog.visible_ratio = 0.0
	_dialog.visible_characters = 0
	visible = true
	while is_inside_tree() and dialog_serial == _auto_advance_serial and _dialog.visible_ratio < 1:
		await get_tree().create_timer(_step).timeout
		if not is_inside_tree() or dialog_serial != _auto_advance_serial:
			return
		_dialog.visible_characters += 1
	if not is_inside_tree() or dialog_serial != _auto_advance_serial:
		return
	if auto_advance:
		_auto_advance_after_delay()


func _auto_advance_after_delay() -> void:
	if _advancing:
		return
	_advancing = true
	var auto_advance_serial := _auto_advance_serial
	await get_tree().create_timer(_get_auto_advance_delay()).timeout
	if is_inside_tree() and auto_advance_serial == _auto_advance_serial:
		_advance()


func _get_auto_advance_delay() -> float:
	var base_delay = maxf(auto_advance_delay, AUTO_ADVANCE_MIN_DELAY)
	var text_delay = float(_dialog.text.length()) * AUTO_ADVANCE_SECONDS_PER_CHAR
	return clampf(base_delay + text_delay, AUTO_ADVANCE_MIN_DELAY, AUTO_ADVANCE_MAX_DELAY)


func _advance() -> void:
	_auto_advance_serial += 1
	if _dialog.visible_ratio < 1:
		_dialog.visible_ratio = 1
		return
	_id += 1
	if _id == data.size():
		emit_signal("end_dialog")
		queue_free()
		return
	_initialize_dialog()
