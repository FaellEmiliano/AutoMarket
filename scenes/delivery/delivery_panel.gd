extends Control

@onready var status_label: Label = %StatusLabel
@onready var progress_label: Label = %ProgressLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var map_renderer: Control = %Map
@onready var frame: PanelContainer = $WindowFrame

func _ready() -> void:
	%CloseButton.pressed.connect(close_panel)
	DeliverySystem.state_changed.connect(refresh)
	get_viewport().size_changed.connect(_fit_panel)
	_fit_panel()
	refresh()
	hide()

func open_panel() -> void:
	_fit_panel()
	refresh()
	show()

func close_panel() -> void:
	hide()

func _process(_delta: float) -> void:
	if visible:
		refresh()

func refresh() -> void:
	var view := DeliverySystem.get_view_data()
	match int(view.state):
		DeliverySystem.State.LOCKED:
			status_label.text = "Compre Delivery Online após Promoções."
		DeliverySystem.State.WAITING_DECLARATION:
			status_label.text = "ENTREGA PENDENTE • destino %s" % str(view.map.destination)
		DeliverySystem.State.MOVING:
			status_label.text = "MOTOQUEIRO EM ANDAMENTO"
		DeliverySystem.State.COOLDOWN:
			status_label.text = "ENTREGA CONCLUÍDA • próxima em %ds" % int(view.cooldown_remaining)
	progress_label.text = "Entregas: %d / 3 • Recompensa: R$ %d" % [int(view.completed), int(view.reward)]
	if bool(view.challenge_completed):
		progress_label.text = "Desafio concluído • %d entregas • R$ %d por chegada" % [int(view.completed), int(view.reward)]
	feedback_label.text = str(view.last_feedback)
	feedback_label.theme_type_variation = &"ErrorLabel" if view.last_feedback_kind == "rejected" else &"SubtitleLabel"
	map_renderer.set_view(view)

func _fit_panel() -> void:
	var viewport_size := get_viewport_rect().size
	# The docked IDE lives at bottom-right. Keep this window in the left half.
	var width := minf(420.0, viewport_size.x * 0.44)
	frame.position = Vector2(minf(170.0, viewport_size.x * 0.02), 18.0)
	frame.size = Vector2(maxf(200.0, width), maxf(180.0, viewport_size.y - 36.0))
	map_renderer.custom_minimum_size.y = minf(340.0, maxf(180.0, width - 40.0))
