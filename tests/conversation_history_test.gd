extends Node

const ConversationHistoryModel = preload("res://systems/ConversationHistory.gd")
const GameScene = preload("res://scenes/game/game.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	var history = ConversationHistoryModel.new()
	history.add_message("Cliente", "Primeira")
	history.add_message("Você", "Segunda")
	_check(history.size() == 2, "O histórico deve registrar falas do cliente e do jogador.")

	for index in range(ConversationHistoryModel.MAX_MESSAGES):
		history.add_message("Cliente", "Mensagem %d" % index)

	var messages: Array[Dictionary] = history.get_messages()
	_check(messages.size() == 50, "O histórico deve manter no máximo 50 mensagens.")
	_check(messages.front()["text"] == "Mensagem 0", "As mensagens mais antigas devem ser removidas primeiro.")
	_check(messages.back()["text"] == "Mensagem 49", "A mensagem mais recente deve ser preservada.")

	history.add_message("Cliente", "   ")
	_check(history.size() == 50, "Mensagens vazias não devem entrar no histórico.")

	var game = GameScene.instantiate()
	var history_button := game.get_node_or_null("HUD/HistoryButton") as Button
	var history_panel := game.get_node_or_null("HUD/HistoryPanel") as PanelContainer
	var history_text := game.get_node_or_null("HUD/HistoryPanel/Margin/Layout/HistoryText") as RichTextLabel
	var close_button := game.get_node_or_null("HUD/HistoryPanel/Margin/Layout/Header/CloseButton") as Button
	_check(history_button != null, "A tela do jogo deve oferecer o botão de histórico.")
	_check(history_panel != null and not history_panel.visible, "O painel de histórico deve iniciar fechado.")
	_check(history_text != null, "O painel deve conter a lista de mensagens.")
	if history_button != null:
		_check(history_button.anchor_top == 1.0 and history_button.anchor_left == 0.0,
			"O botão de histórico deve permanecer no canto inferior esquerdo.")
		_check(history_button.focus_mode == Control.FOCUS_NONE,
			"O botão de histórico não deve competir com o diálogo pelo Enter.")
	_check(close_button != null and close_button.focus_mode == Control.FOCUS_NONE,
		"O botão de fechar histórico não deve capturar o Enter do diálogo.")
	game.free()

	if _failures.is_empty():
		print("CONVERSATION_HISTORY_TEST_OK")
	else:
		push_error("\n".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
