extends Control

const ThemeFactory = preload("res://scenes/console/components/ide_theme.gd")
const Explorer = preload("res://scenes/console/components/ide_explorer.gd")
const Tabs = preload("res://scenes/console/components/ide_document_tabs.gd")
const Editor = preload("res://scenes/console/code_edit.gd")
const Documentation = preload("res://scenes/console/components/ide_documentation_view.gd")
const Find = preload("res://scenes/console/components/ide_find_bar.gd")
const Output = preload("res://scenes/console/components/ide_output_panel.gd")
enum LayoutMode { WIDE, MEDIUM, COMPACT }
var layout_mode_id := -1
var explorer: Tree
var tabs: TabBar
var code_edit: CodeEdit
var documentation: ScrollContainer
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
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	# StudentIdentity remains above the workspace, with its own clear strip.
	margin.add_theme_constant_override("margin_top", 56)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	explorer_button = button(top, "Explorer", "Mostrar ou recolher scripts e documentação")
	brand = Label.new()
	brand.text = "AUTOMARKET / AUTOMAÇÃO"
	brand.theme_type_variation = &"IDESectionLabel"
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(brand)
	language_button = OptionButton.new()
	language_button.tooltip_text = "Linguagem do script; alterar não converte o código"
	language_button.add_item("C-like")
	language_button.add_item("Python-like")
	top.add_child(language_button)
	run_button = button(top, "Rodar", "Executar o script visível · Ctrl+Enter")
	run_button.theme_type_variation = &"IDEPrimaryButton"
	stop_button = button(top, "Parar", "Interromper o script visível")
	close_button = button(top, "Mercado", "Salvar e voltar ao mercado · Escape")
	horizontal = HSplitContainer.new()
	horizontal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(horizontal)
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
	new_button = button(heading, "+", "Criar script")
	menu_button = MenuButton.new()
	menu_button.text = "Ações"
	menu_button.tooltip_text = "Ações do script selecionado"
	heading.add_child(menu_button)
	explorer = Explorer.new()
	explorer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(explorer)
	workspace = VBoxContainer.new()
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.custom_minimum_size.x = 240
	horizontal.add_child(workspace)
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
	output_button = button(status, "Saída", "Mostrar ou recolher saída dos programas")
	explorer_button.pressed.connect(toggle_explorer)
	output_button.pressed.connect(toggle_output)
	output.collapse_requested.connect(toggle_output)
	resized.connect(_on_view_resized)
	update_layout(size.x)
	# Ctrl+Tab gives keyboard users an exit from CodeEdit's indenting Tab key.
	code_edit.focus_next = code_edit.get_path_to(run_button)
	code_edit.focus_previous = code_edit.get_path_to(explorer)

func button(parent: Node, text: String, tip: String) -> Button:
	var result := Button.new()
	result.text = text
	result.tooltip_text = tip
	result.custom_minimum_size.y = 32
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
		return
	layout_mode_id = next
	brand.visible = next == LayoutMode.WIDE
	sidebar.custom_minimum_size.x = 240 if next == LayoutMode.WIDE else 192
	sidebar.visible = next != LayoutMode.COMPACT
	workspace.visible = true
	_compact_explorer = false
	if next != LayoutMode.WIDE:
		output.hide()
		documents.show()
	horizontal.dragger_visibility = SplitContainer.DRAGGER_HIDDEN_COLLAPSED if next == LayoutMode.COMPACT else SplitContainer.DRAGGER_VISIBLE
	close_button.text = "Voltar" if next == LayoutMode.COMPACT else "Mercado"

func toggle_explorer() -> void:
	if layout_mode_id == LayoutMode.COMPACT:
		_compact_explorer = not _compact_explorer
		sidebar.visible = _compact_explorer
		workspace.visible = not _compact_explorer
	else:
		sidebar.visible = not sidebar.visible

func reveal_document() -> void:
	if layout_mode_id == LayoutMode.COMPACT and _compact_explorer:
		toggle_explorer()

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
		output.show()
		vertical.split_offset = _saved_output_offset
	documents.visible = not output.visible if size.y < 480 else true
