extends CanvasLayer

@onready var text_label: RichTextLabel = $Root/Panel/VBoxContainer/Text
@onready var next_button: Button = $Root/Panel/VBoxContainer/Buttons/Next
@onready var skip_button: Button = $Root/Panel/VBoxContainer/Buttons/Skip
@onready var panel: Control = $Root/Panel

const SCRIPT_MENU_HIGHLIGHT_Z_INDEX := 30
const SHOP_MENU_HIGHLIGHT_Z_INDEX := 30
const SCRIPT_MENU_HIGHLIGHT_FIRST_STEP := 1
const SCRIPT_MENU_HIGHLIGHT_LAST_STEP := 8
const SHOP_MENU_HIGHLIGHT_STEP := 8
const SCRIPT_MENU_HIGHLIGHT_LAYER_OFFSET := 1
const TUTORIAL_PANEL_LAYER_OFFSET := 2
const EXECUTION_AUTO_ADVANCE_STEPS := [3, 6, 7]
const FINAL_STEP := 9

var game_ref: Node = null
var client_spawner: Node = null
var script_menu: CanvasItem = null
var shop_menu: CanvasItem = null
var console_editor: Node = null
var script_menu_toggle_button: Button = null
var current_step := 0
var _tutorial_client_spawned := false
var _script_menu_original_z_index := 0
var _script_menu_original_z_index_saved := false
var _script_menu_original_parent: Node = null
var _script_menu_original_index := -1
var _script_menu_highlight_layer: CanvasLayer = null
var _shop_menu_original_z_index := 0
var _shop_menu_original_z_index_saved := false
var _shop_menu_original_parent: Node = null
var _shop_menu_original_index := -1
var _panel_original_parent: Node = null
var _panel_original_index := -1
var _panel_highlight_layer: CanvasLayer = null
var _overlay_original_layer := 0

func _ready() -> void:
	_overlay_original_layer = layer

	next_button.pressed.connect(_on_next_pressed)
	skip_button.pressed.connect(_finish_tutorial)

	if not EventBus.end_client.is_connected(_on_end_client):
		EventBus.end_client.connect(_on_end_client)

	var finished := Callable(self, "_on_execution_finished")
	if InterpreterSystem.interpretador != null and not InterpreterSystem.interpretador.is_connected("execution_finished", finished):
		InterpreterSystem.interpretador.connect("execution_finished", finished)
	if not InterpreterSystem.is_connected("execution_stopped", finished):
		InterpreterSystem.connect("execution_stopped", finished)

func _on_runtime_finished(_runtime_id: String, script_id: String) -> void:
	if script_id == str(InterpreterSystem.get_active_script().get("id", "")):
		_on_execution_finished()

func setup(new_game_ref: Node) -> void:
	if not InterpreterSystem.runtime_manager.runtime_finished.is_connected(_on_runtime_finished):
		InterpreterSystem.runtime_manager.runtime_finished.connect(_on_runtime_finished)
	game_ref = new_game_ref
	_resolver_referencias()
	current_step = int(Saves.get_tutorial_data().get("step", 0))
	_enter_step(current_step)

func _resolver_referencias() -> void:
	if game_ref == null:
		push_error("TutorialOverlay: game_ref nao informado")
		return

	client_spawner = game_ref.get_node_or_null("Cliente_manager")
	script_menu = game_ref.get_node_or_null("ScriptMenu") as CanvasItem
	shop_menu = game_ref.get_node_or_null("ShopMenu") as CanvasItem

	if client_spawner == null:
		push_error("TutorialOverlay: node Cliente_manager nao encontrado")
	if script_menu == null:
		push_error("TutorialOverlay: node ScriptMenu nao encontrado")
	if shop_menu == null:
		push_error("TutorialOverlay: node ShopMenu nao encontrado")

	if script_menu != null:
		console_editor = script_menu.get_console_editor()
		if console_editor == null:
			push_error("TutorialOverlay: editor da IDE nao encontrado")
		script_menu_toggle_button = script_menu.get_node_or_null("ColorRect2/Button")
		if script_menu_toggle_button != null and not script_menu_toggle_button.toggled.is_connected(_on_script_menu_toggled):
			script_menu_toggle_button.toggled.connect(_on_script_menu_toggled)
		elif script_menu_toggle_button == null:
			push_error("TutorialOverlay: botao em ScriptMenu/ColorRect2/Button nao encontrado")

func _enter_step(step: int) -> void:
	if step > FINAL_STEP:
		_finish_tutorial()
		return

	current_step = clamp(step, 0, FINAL_STEP)
	Saves.set_tutorial_step(current_step)
	_set_shop_menu_highlight(current_step == SHOP_MENU_HIGHLIGHT_STEP)
	_set_script_menu_highlight(
		current_step >= SCRIPT_MENU_HIGHLIGHT_FIRST_STEP
		and current_step <= SCRIPT_MENU_HIGHLIGHT_LAST_STEP
	)

	match current_step:
		0:
			_call_if_exists(client_spawner, "bloquear_spawn")
			_set_text("Bem-vindo. Vou te mostrar o básico rapidinho, sem enrolar.")
		1:
			_set_text("A ideia é automatizar o mercado. Primeiro, abre a tela de script.")
			if script_menu != null and script_menu.has_method("is_aberto") and script_menu.call("is_aberto"):
				_advance_step()
		2:
			_call_if_exists(client_spawner, "bloquear_spawn")
			_call_if_exists(script_menu, "set_aberto", [true])
			_set_text("É aqui que você vai passar boa parte do jogo. Vamos começar com um código bem simples.")
		3:
			_call_if_exists(script_menu, "set_aberto", [true])
			_set_code_text("int main(){\n    print(\"Ola mundo\");\n}")
			_set_text("A linguagem parece C. Roda esse código para ver se está tudo respondendo.")
		4:
			_set_text("Erros e prints aparecem ali embaixo, no retorno do sistema.")
		5:
			_call_if_exists(client_spawner, "bloquear_spawn")
			if not _tutorial_client_spawned:
				_tutorial_client_spawned = true
				_call_if_exists(client_spawner, "spawnar_cliente_tutorial")
			_set_text("Para atender cliente, você vai usar bastante duas funções: input() e send().")
		6:
			_call_if_exists(script_menu, "set_aberto", [true])
			_set_code_text("int main(){\n    float a = input();\n	print(a);}")
			_set_text("input() pega um valor do cliente. Chamou uma vez, pegou um valor. Chamou de novo, pega o próximo.")
		7:
			_call_if_exists(script_menu, "set_aberto", [true])
			_set_code_text("int main(){\n    float a = 99.99;\n		print(a);\n		send(a);}")
			_set_text("send() manda a resposta. Se o número estiver certo, a venda fecha. Se não, o cliente vai embora.")
		8:
			_call_if_exists(shop_menu, "set_aberto", [true])
			_call_if_exists(script_menu, "set_aberto", [false])
			_set_text("No menu de melhorias você compra coisas novas: mais lucro, mais clientes e novas regras para o código.")
		9:
			_set_text("Pronto. Agora tenta deixar a loja rodando sozinha.")

func _advance_step() -> void:
	_enter_step(current_step + 1)

func _on_next_pressed() -> void:
	_advance_step()

func _on_script_menu_toggled(toggled_on: bool) -> void:
	if current_step == 1 and toggled_on:
		_advance_step()

func _on_execution_finished() -> void:
	if current_step in EXECUTION_AUTO_ADVANCE_STEPS:
		_advance_step()

func _on_end_client(result: bool) -> void:
	if current_step != 7:
		return

	if not result:
		_set_text("A resposta ainda não bateu. Ajusta o código e tenta de novo.")
		_tutorial_client_spawned = true
		_call_if_exists(client_spawner, "spawnar_cliente_tutorial")

func _finish_tutorial() -> void:
	_set_shop_menu_highlight(false)
	_set_script_menu_highlight(false)
	Saves.complete_tutorial()
	_call_if_exists(client_spawner, "liberar_spawn")
	queue_free()

func _set_text(text: String) -> void:
	text_label.text = text

func _set_script_menu_highlight(enabled: bool) -> void:
	if enabled:
		if script_menu == null:
			push_error("TutorialOverlay: nao foi possivel destacar ScriptMenu porque ele nao foi encontrado")
			return

		if not _script_menu_original_z_index_saved:
			_script_menu_original_z_index = script_menu.z_index
			_script_menu_original_z_index_saved = true

		if _script_menu_highlight_layer == null:
			_script_menu_highlight_layer = CanvasLayer.new()
			_script_menu_highlight_layer.name = "ScriptMenuHighlightLayer"
			_script_menu_highlight_layer.layer = _overlay_original_layer + SCRIPT_MENU_HIGHLIGHT_LAYER_OFFSET
			game_ref.add_child(_script_menu_highlight_layer)

		if script_menu.get_parent() != _script_menu_highlight_layer:
			_script_menu_original_parent = script_menu.get_parent()
			_script_menu_original_index = script_menu.get_index()
			script_menu.reparent(_script_menu_highlight_layer, true)

		if _panel_highlight_layer == null:
			_panel_highlight_layer = CanvasLayer.new()
			_panel_highlight_layer.name = "TutorialPanelHighlightLayer"
			_panel_highlight_layer.layer = _overlay_original_layer + TUTORIAL_PANEL_LAYER_OFFSET
			game_ref.add_child(_panel_highlight_layer)

		if panel.get_parent() != _panel_highlight_layer:
			_panel_original_parent = panel.get_parent()
			_panel_original_index = panel.get_index()
			panel.reparent(_panel_highlight_layer, true)

		script_menu.z_index = max(SCRIPT_MENU_HIGHLIGHT_Z_INDEX, _script_menu_original_z_index)
		return

	if _panel_original_parent != null and panel.get_parent() == _panel_highlight_layer:
		panel.reparent(_panel_original_parent, true)
		if _panel_original_index >= 0:
			_panel_original_parent.move_child(panel, _panel_original_index)

	if _panel_highlight_layer != null:
		_panel_highlight_layer.queue_free()
		_panel_highlight_layer = null

	if script_menu != null and _script_menu_original_z_index_saved:
		script_menu.z_index = _script_menu_original_z_index
		if _script_menu_original_parent != null and script_menu.get_parent() == _script_menu_highlight_layer:
			script_menu.reparent(_script_menu_original_parent, true)
			if _script_menu_original_index >= 0:
				_script_menu_original_parent.move_child(script_menu, _script_menu_original_index)

	if _script_menu_highlight_layer != null:
		_script_menu_highlight_layer.queue_free()
		_script_menu_highlight_layer = null

func _set_shop_menu_highlight(enabled: bool) -> void:
	if enabled:
		if shop_menu == null:
			push_error("TutorialOverlay: nao foi possivel destacar ShopMenu porque ele nao foi encontrado")
			return

		if not _shop_menu_original_z_index_saved:
			_shop_menu_original_z_index = shop_menu.z_index
			_shop_menu_original_z_index_saved = true

		if _script_menu_highlight_layer == null:
			_script_menu_highlight_layer = CanvasLayer.new()
			_script_menu_highlight_layer.name = "MenuHighlightLayer"
			_script_menu_highlight_layer.layer = _overlay_original_layer + SCRIPT_MENU_HIGHLIGHT_LAYER_OFFSET
			game_ref.add_child(_script_menu_highlight_layer)

		if shop_menu.get_parent() != _script_menu_highlight_layer:
			_shop_menu_original_parent = shop_menu.get_parent()
			_shop_menu_original_index = shop_menu.get_index()
			shop_menu.reparent(_script_menu_highlight_layer, true)

		if _panel_highlight_layer == null:
			_panel_highlight_layer = CanvasLayer.new()
			_panel_highlight_layer.name = "TutorialPanelHighlightLayer"
			_panel_highlight_layer.layer = _overlay_original_layer + TUTORIAL_PANEL_LAYER_OFFSET
			game_ref.add_child(_panel_highlight_layer)

		if panel.get_parent() != _panel_highlight_layer:
			_panel_original_parent = panel.get_parent()
			_panel_original_index = panel.get_index()
			panel.reparent(_panel_highlight_layer, true)

		shop_menu.z_index = max(SHOP_MENU_HIGHLIGHT_Z_INDEX, _shop_menu_original_z_index)
		return

	if shop_menu != null and _shop_menu_original_z_index_saved:
		shop_menu.z_index = _shop_menu_original_z_index
		if _shop_menu_original_parent != null and shop_menu.get_parent() == _script_menu_highlight_layer:
			shop_menu.reparent(_shop_menu_original_parent, true)
			if _shop_menu_original_index >= 0:
				_shop_menu_original_parent.move_child(shop_menu, _shop_menu_original_index)

func _set_code_text(text: String) -> void:
	if console_editor == null:
		push_error("TutorialOverlay: nao foi possivel inserir codigo porque o editor nao foi encontrado")
		return
	if not console_editor.has_method("set_code_text"):
		push_error("TutorialOverlay: editor nao possui set_code_text")
		return
	console_editor.set_code_text(text)

func _call_if_exists(target: Object, method: String, args: Array = []) -> void:
	if target == null:
		push_error("TutorialOverlay: alvo nulo ao chamar %s" % method)
		return
	if not target.has_method(method):
		push_error("TutorialOverlay: metodo %s nao encontrado em %s" % [method, target])
		return
	target.callv(method, args)
