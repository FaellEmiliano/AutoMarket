extends Control

const ThemeFactory = preload("res://scenes/console/components/ide_theme.gd")
const Explorer = preload("res://scenes/console/components/ide_explorer.gd")
const Tabs = preload("res://scenes/console/components/ide_document_tabs.gd")
const Editor = preload("res://scenes/console/code_edit.gd")
const Documentation = preload("res://scenes/console/components/ide_documentation_view.gd")
const Find = preload("res://scenes/console/components/ide_find_bar.gd")
const Output = preload("res://scenes/console/components/ide_output_panel.gd")
const ICON_EXPLORER = preload("res://assets/icons/ide_explorer.svg")
const ICON_NEW = preload("res://assets/icons/ide_new.svg")
const ICON_RUN = preload("res://assets/icons/ide_running.svg")
const ICON_STOP = preload("res://assets/icons/ide_stop.svg")
const ICON_BACK = preload("res://assets/icons/ide_back.svg")
const ICON_MORE = preload("res://assets/icons/ide_more.svg")
const ICON_OUTPUT = preload("res://assets/icons/ide_output.svg")
enum LayoutMode { WIDE, MEDIUM, COMPACT }
var layout_mode_id := -1
var explorer: Tree
var tabs: TabBar
var code_edit: CodeEdit
var documentation: ScrollContainer
var empty_state: Label
var find_bar: HBoxContainer
var output: VBoxContainer
var language_button: OptionButton
var run_button: Button
var stop_button: Button
var close_button: Button
var explorer_button: Button
var output_button: Button
var menu_button: MenuButton
var new_button: Button
var status_label: Label
var caret_label: Label
var brand: Label
var horizontal: HSplitContainer
var vertical: VSplitContainer
var content_host: Control
var drawer_scrim: Button
var drawer_background: PanelContainer
var sidebar: VBoxContainer
var workspace: VBoxContainer
var documents: VBoxContainer
var _short_layout := false
var _saved_output_offset := 0
var _compact_explorer := false

func build() -> void:
	theme = ThemeFactory.create()
	var background := ColorRect.new()
	background.color = ThemeFactory.BG
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var identity_strip := ColorRect.new()
	identity_strip.color = ThemeFactory.SURFACE
	identity_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(identity_strip)
	identity_strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	identity_strip.offset_bottom = 54
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	# StudentIdentity remains above the workspace, with its own clear strip.
	margin.add_theme_constant_override("margin_top", 56)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var toolbar_panel := PanelContainer.new()
	toolbar_panel.theme_type_variation = &"IDEToolbar"
	column.add_child(toolbar_panel)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	toolbar_panel.add_child(top)
	explorer_button = button(top, "Scripts", "Abrir ou fechar scripts e documentação", ICON_EXPLORER)
	brand = Label.new()
	brand.text = "EDITOR DE SCRIPTS"
	brand.theme_type_variation = &"IDESectionLabel"
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(brand)
	language_button = OptionButton.new()
	language_button.tooltip_text = "Linguagem do script; alterar não converte o código"
	language_button.add_item("C-like")
	language_button.add_item("Python-like")
	top.add_child(language_button)
	run_button = button(top, "Rodar", "Executar o script visível · Ctrl+Enter", ICON_RUN)
	run_button.theme_type_variation = &"IDEPrimaryButton"
	stop_button = button(top, "Parar", "Interromper o script visível", ICON_STOP)
	stop_button.theme_type_variation = &"IDEDangerButton"
	close_button = button(top, "Mercado", "Salvar e voltar ao mercado · Escape", ICON_BACK)
	content_host = Control.new()
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content_host)
	horizontal = HSplitContainer.new()
	content_host.add_child(horizontal)
	horizontal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sidebar = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 240
	horizontal.add_child(sidebar)
	var heading := HBoxContainer.new()
	sidebar.add_child(heading)
	var label := Label.new()
	label.text = "WORKSPACE"
	label.theme_type_variation = &"IDESectionLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	new_button = button(heading, "Novo", "Criar script", ICON_NEW)
	menu_button = MenuButton.new()
	menu_button.text = "Ações"
	menu_button.icon = ICON_MORE
	menu_button.tooltip_text = "Ações do script selecionado"
	heading.add_child(menu_button)
	explorer = Explorer.new()
	explorer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(explorer)
	workspace = VBoxContainer.new()
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.custom_minimum_size.x = 240
	horizontal.add_child(workspace)
	drawer_scrim = Button.new()
	drawer_scrim.focus_mode = Control.FOCUS_NONE
	drawer_scrim.tooltip_text = "Fechar painel de scripts"
	var scrim_style := ThemeFactory.box(Color(0, 0, 0, 0.68), 0, Color.TRANSPARENT, 0)
	drawer_scrim.add_theme_stylebox_override("normal", scrim_style)
	drawer_scrim.add_theme_stylebox_override("hover", scrim_style)
	drawer_scrim.add_theme_stylebox_override("pressed", scrim_style)
	content_host.add_child(drawer_scrim)
	drawer_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drawer_scrim.pressed.connect(_close_compact_drawer)
	drawer_scrim.hide()
	drawer_background = PanelContainer.new()
	drawer_background.theme_type_variation = &"IDEDrawer"
	drawer_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_host.add_child(drawer_background)
	drawer_background.hide()
	tabs = Tabs.new()
	workspace.add_child(tabs)
	vertical = VSplitContainer.new()
	vertical.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(vertical)
	documents = VBoxContainer.new()
	documents.custom_minimum_size.y = 160
	documents.size_flags_vertical = Control.SIZE_EXPAND_FILL
	documents.size_flags_stretch_ratio = 4
	vertical.add_child(documents)
	find_bar = Find.new()
	documents.add_child(find_bar)
	code_edit = Editor.new()
	code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	documents.add_child(code_edit)
	find_bar.editor = code_edit
	documentation = Documentation.new()
	documentation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	documents.add_child(documentation)
	documentation.hide()
	empty_state = Label.new()
	empty_state.text = "Nenhum documento aberto"
	empty_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_state.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty_state.theme_type_variation = &"IDESectionLabel"
	documents.add_child(empty_state)
	empty_state.hide()
	output = Output.new()
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vertical.add_child(output)
	var status_panel := PanelContainer.new()
	status_panel.theme_type_variation = &"IDEStatus"
	column.add_child(status_panel)
	var status := HBoxContainer.new()
	status_panel.add_child(status)
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.clip_text = true
	status.add_child(status_label)
	caret_label = Label.new()
	caret_label.theme_type_variation = &"IDESectionLabel"
	status.add_child(caret_label)
	output_button = button(status, "Saída", "Mostrar ou recolher saída dos programas", ICON_OUTPUT)
	explorer_button.pressed.connect(toggle_explorer)
	output_button.pressed.connect(toggle_output)
	output.collapse_requested.connect(toggle_output)
	resized.connect(_on_view_resized)
	output.hide()
	update_layout(size.x)
	# Ctrl+Tab gives keyboard users an exit from CodeEdit's indenting Tab key.
	code_edit.focus_next = code_edit.get_path_to(run_button)
	code_edit.focus_previous = code_edit.get_path_to(explorer)

func button(parent: Node, text: String, tip: String, icon: Texture2D = null) -> Button:
	var result := Button.new()
	result.text = text
	result.icon = icon
	result.tooltip_text = tip
	result.custom_minimum_size.y = 40
	parent.add_child(result)
	return result

func update_layout(width: float) -> void:
	var next := LayoutMode.WIDE if width >= 1120 else LayoutMode.MEDIUM
	if width < 760:
		next = LayoutMode.COMPACT
	# Hysteresis prevents repeated toggles around breakpoints.
	if layout_mode_id == LayoutMode.COMPACT and width < 792:
		next = LayoutMode.COMPACT
	elif layout_mode_id == LayoutMode.WIDE and width > 1088:
		next = LayoutMode.WIDE
	if next == layout_mode_id:
		if next == LayoutMode.COMPACT:
			_update_compact_drawer_geometry()
		return
	layout_mode_id = next
	brand.visible = next == LayoutMode.WIDE
	sidebar.custom_minimum_size.x = 240 if next == LayoutMode.WIDE else 192
	workspace.visible = true
	if next == LayoutMode.COMPACT:
		_enter_compact_layout()
	else:
		_leave_compact_layout()
	if next != LayoutMode.WIDE:
		output.hide()
		documents.show()
	horizontal.dragger_visibility = SplitContainer.DRAGGER_HIDDEN_COLLAPSED if next == LayoutMode.COMPACT else SplitContainer.DRAGGER_VISIBLE
	close_button.text = "Voltar" if next == LayoutMode.COMPACT else "Mercado"
	explorer_button.text = "Scripts"
	find_bar.update_layout(next == LayoutMode.COMPACT)
	output.update_layout(next == LayoutMode.COMPACT)

func toggle_explorer() -> void:
	if layout_mode_id == LayoutMode.COMPACT:
		_set_compact_drawer(not _compact_explorer)
	else:
		sidebar.visible = not sidebar.visible

func reveal_document() -> void:
	if layout_mode_id == LayoutMode.COMPACT and _compact_explorer:
		_set_compact_drawer(false)

func _enter_compact_layout() -> void:
	if sidebar.get_parent() != content_host:
		sidebar.reparent(content_host)
	content_host.move_child(sidebar, content_host.get_child_count() - 1)
	_update_compact_drawer_geometry()
	_set_compact_drawer(false)
	_sync_focus_paths()

func _leave_compact_layout() -> void:
	_compact_explorer = false
	drawer_scrim.hide()
	drawer_background.hide()
	if sidebar.get_parent() != horizontal:
		sidebar.reparent(horizontal)
		horizontal.move_child(sidebar, 0)
	sidebar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sidebar.visible = true
	_sync_focus_paths()

func _set_compact_drawer(open: bool) -> void:
	_compact_explorer = open
	drawer_scrim.visible = open
	drawer_background.visible = open
	sidebar.visible = open
	explorer_button.text = "Fechar" if open else "Scripts"
	if open:
		explorer.grab_focus()
	elif code_edit.visible:
		code_edit.grab_focus()

func _close_compact_drawer() -> void:
	_set_compact_drawer(false)

func _update_compact_drawer_geometry() -> void:
	var drawer_width := minf(340.0, maxf(280.0, size.x * 0.86))
	for control in [drawer_background, sidebar]:
		control.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		control.offset_left = 0
		control.offset_top = 0
		control.offset_right = drawer_width
		control.offset_bottom = 0

func _sync_focus_paths() -> void:
	code_edit.focus_next = code_edit.get_path_to(run_button)
	code_edit.focus_previous = code_edit.get_path_to(explorer)

func _on_view_resized() -> void:
	update_layout(size.x)
	var short_now := size.y < 480
	if short_now != _short_layout:
		_short_layout = short_now
		documents.show()
		if short_now:
			output.hide()

func toggle_output() -> void:
	if output.visible:
		_saved_output_offset = vertical.split_offset
		output.hide()
	else:
		show_output()
	documents.visible = not output.visible if size.y < 480 else true

func show_output() -> void:
	output.show()
	vertical.split_offset = _saved_output_offset
	documents.visible = size.y >= 480
