extends Control

# game.gd — controlador de UI da tela principal
# Estado real (money, upgrades, unlocked_mechanics) vive em GameManager
const TutorialOverlayScene = preload("res://scenes/tutorial/tutorial_overlay.tscn")
const DebugMenuScene = preload("res://scenes/debug/debug_menu.tscn")
const DeliveryConfigData = preload("res://data/DeliveryConfig.gd")

@onready var dinheiro_label: Label = $VBoxContainer/ColorRect/VBoxContainer/Dinheiro
@onready var dinheiro_panel: NinePatchRect = $VBoxContainer/ColorRect
@onready var hud = $HUD
@onready var script_menu: Control = $ScriptMenu
@onready var shop_menu: HBoxContainer = $ShopMenu
@onready var estoque_panel: NinePatchRect = $VBoxContainer/Estoque
@onready var delivery_panel_button: NinePatchRect = $VBoxContainer/Delivery
@onready var delivery_button: Button = $VBoxContainer/Delivery/DeliveryButton
@onready var diamond_row: HBoxContainer = $VBoxContainer/ColorRect/VBoxContainer/DiamondRow
@onready var diamond_label: Label = $VBoxContainer/ColorRect/VBoxContainer/DiamondRow/DiamondLabel
@onready var client_spawner: Node = $Cliente_manager
@onready var help_menu: Control = $HUD/HelpMenu
@onready var pause_menu: Control = $HUD/PauseMenu
@onready var debug_hotspot: Button = $HUD/DebugHotspot
@onready var delivery_panel: Control = $HUD/DeliveryPanel
@onready var completion_overlay: Control = $HUD/CompletionOverlay
@onready var notification_panel: PanelContainer = $HUD/NotificationPanel
@onready var notification_label: Label = $HUD/NotificationPanel/Margin/NotificationLabel
@onready var notification_timer: Timer = $HUD/NotificationTimer

var debug_infinite_money := false
var _debug_click_count := 0
var _last_debug_click_ms := 0
var _debug_menu = null
var _notification_queue: Array[String] = []
var _current_notification := ""


func _ready() -> void:
	# Carrega save e popula GameManager
	var dados = Saves.carregar()
	if not Saves.has_valid_student_name():
		StudentIdentity.clear_student()
		push_warning("Save sem identificacao de aluno. Retornando ao menu de slots.")
		get_tree().change_scene_to_file("res://scenes/menus/main_screen.tscn")
		return
	StudentIdentity.show_student(Saves.get_student_name())
	GameManager.money = dados["dinheiro"]
	GameManager.upgrades = dados["upgrades"]
	for key in dados["unlocked_mechanics"]:
		GameManager.unlocked_mechanics[key] = dados["unlocked_mechanics"][key]

	dinheiro_label.text = _format_money(GameManager.money)
	_update_diamonds(GameManager.diamonds)
	EventBus.update_money.connect(update_money)
	EventBus.player_notification.connect(_queue_notification)
	EventBus.secret_menu_unlocked.connect(_on_secret_menu_unlocked)
	FeatureManager.feature_unlocked.connect(_on_feature_unlocked)
	GameManager.diamonds_changed.connect(_update_diamonds)
	GameManager.game_completed_changed.connect(_on_game_completed_changed)
	dinheiro_panel.gui_input.connect(_on_dinheiro_panel_gui_input)
	delivery_button.pressed.connect(_open_delivery_panel)
	notification_timer.timeout.connect(_show_next_notification)
	_update_debug_hotspot()
	UpgradeManager.verificar_desbloqueios()
	EventBus.emit_signal("update_money", 0)
	_atualizar_estado_mecanicas()
	_instanciar_tutorial_se_necessario()


func update_money(num: int) -> void:
	if debug_infinite_money and num < 0:
		dinheiro_label.text = _format_money(GameManager.money)
		Saves.salvar(GameManager.money, GameManager.unlocked_mechanics, GameManager.upgrades)
		return
	GameManager.money += num
	dinheiro_label.text = _format_money(GameManager.money)
	Saves.salvar(GameManager.money, GameManager.unlocked_mechanics, GameManager.upgrades)


func _format_money(value: int) -> String:
	return "R$ %d" % value

func set_debug_infinite_money(enabled: bool) -> void:
	debug_infinite_money = enabled
	if enabled and GameManager.money < 999999:
		EventBus.emit_signal("update_money", 999999 - GameManager.money)

func _on_dinheiro_panel_gui_input(event: InputEvent) -> void:
	if not GameManager.secret_menu_unlocked:
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	var now := Time.get_ticks_msec()
	if now - _last_debug_click_ms > 1200:
		_debug_click_count = 0
	_last_debug_click_ms = now
	_debug_click_count += 1
	if _debug_click_count < 3:
		return

	_debug_click_count = 0
	_open_debug_menu()

func _open_debug_menu() -> void:
	if not GameManager.secret_menu_unlocked:
		return
	if _debug_menu == null or not is_instance_valid(_debug_menu):
		_debug_menu = DebugMenuScene.instantiate()
		hud.add_child(_debug_menu)
		_debug_menu.setup(self, client_spawner)
	_debug_menu.open_menu()

func _on_secret_menu_unlocked() -> void:
	_update_debug_hotspot()

func _update_debug_hotspot() -> void:
	debug_hotspot.visible = GameManager.secret_menu_unlocked

func _unhandled_input(event: InputEvent) -> void:
	if script_menu.is_aberto():
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if help_menu.visible or (_debug_menu != null and is_instance_valid(_debug_menu) and _debug_menu.visible):
		return
	pause_menu.open_menu()
	get_viewport().set_input_as_handled()

func _on_feature_unlocked(_feature_id: String) -> void:
	_atualizar_estado_mecanicas()
	Saves.salvar(GameManager.money, GameManager.unlocked_mechanics, GameManager.upgrades)

func _atualizar_estado_mecanicas() -> void:
	estoque_panel.visible = FeatureManager.has_feature(FeatureManager.FEATURE_STOCK)
	delivery_panel_button.visible = FeatureManager.has_feature(FeatureManager.FEATURE_DELIVERY)
	diamond_row.visible = delivery_panel_button.visible or GameManager.diamonds > 0

func _open_delivery_panel() -> void:
	if not FeatureManager.has_feature(FeatureManager.FEATURE_DELIVERY):
		_queue_notification(FeatureManager.locked_message(FeatureManager.FEATURE_DELIVERY))
		return
	script_menu.set_aberto(false)
	shop_menu.set_aberto(false)
	delivery_panel.open_panel()

func _update_diamonds(value: int) -> void:
	diamond_label.text = "%d / %d" % [value, DeliveryConfigData.MAX_DIAMONDS]
	diamond_row.visible = FeatureManager.has_feature(FeatureManager.FEATURE_DELIVERY) or value > 0

func _on_game_completed_changed(completed: bool) -> void:
	if completed:
		completion_overlay.open_overlay()

func _queue_notification(message: String) -> void:
	var clean_message := message.strip_edges()
	if clean_message.is_empty() or clean_message == _current_notification:
		return
	if not _notification_queue.is_empty() and _notification_queue.back() == clean_message:
		return
	_notification_queue.append(clean_message)
	if not notification_panel.visible:
		_show_next_notification()

func _show_next_notification() -> void:
	if _notification_queue.is_empty():
		_current_notification = ""
		notification_panel.hide()
		return
	_current_notification = _notification_queue.pop_front()
	notification_label.text = _current_notification
	notification_panel.show()
	notification_timer.start()

func _instanciar_tutorial_se_necessario() -> void:
	var tutorial_data = Saves.get_tutorial_data()
	if tutorial_data.get("completed", false):
		return

	var tutorial_overlay = TutorialOverlayScene.instantiate()
	add_child(tutorial_overlay)
	tutorial_overlay.setup(self)
