extends CanvasLayer

const MAX_STUDENT_NAME_LENGTH := 50
const GLOBAL_UI_LAYER := 100
const DEFAULT_FONT_SIZE := 10
const MIN_FONT_SIZE := 7
const HORIZONTAL_SAFE_MARGIN := 32.0

@onready var name_plate: PanelContainer = $TopCenter/NamePlate
@onready var student_name_label: Label = $TopCenter/NamePlate/Margin/StudentName
@onready var top_center: CenterContainer = $TopCenter

var _student_name := ""
var _editor_mode := false


func _ready() -> void:
	layer = GLOBAL_UI_LAYER
	get_viewport().size_changed.connect(_fit_label_to_viewport)
	clear_student()


func show_student(student_name: String) -> void:
	var clean_name := student_name.strip_edges()
	if clean_name.is_empty() or clean_name.length() > MAX_STUDENT_NAME_LENGTH:
		clear_student()
		return

	_student_name = clean_name
	student_name_label.text = "Aluno: %s" % clean_name
	visible = true
	_fit_label_to_viewport()


func clear_student() -> void:
	_student_name = ""
	visible = false


func get_student_name() -> String:
	return _student_name

func set_editor_mode(enabled: bool) -> void:
	_editor_mode = enabled
	if get_viewport() != null:
		_fit_label_to_viewport()


func _fit_label_to_viewport() -> void:
	if student_name_label == null:
		return
	if _editor_mode:
		var stretch := get_viewport().get_stretch_transform().get_scale()
		top_center.set_anchors_preset(Control.PRESET_TOP_LEFT)
		top_center.scale = Vector2.ONE / stretch
		top_center.position = Vector2(0, 10)
		top_center.size = Vector2(get_viewport().get_visible_rect().size.x * stretch.x, 42)
	else:
		top_center.scale = Vector2.ONE
		top_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
		top_center.offset_top = 10
		top_center.offset_bottom = 52
	if not visible:
		return

	var available_width := maxf(160.0, get_viewport().get_visible_rect().size.x - HORIZONTAL_SAFE_MARGIN)
	var font := student_name_label.get_theme_font("font")
	var font_size := DEFAULT_FONT_SIZE
	while font_size > MIN_FONT_SIZE and font.get_string_size(student_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 28.0 > available_width:
		font_size -= 1
	student_name_label.add_theme_font_size_override("font_size", font_size)
	name_plate.custom_minimum_size.x = minf(190.0, available_width)
