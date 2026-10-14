extends Control

signal result_closed()

var challenge
var active_dialog = null

const _DIALOG_SCREEN :PackedScene = preload("res://scenes/Client/dialog_screen.tscn")
const PLAYER_HAPPY_FACESET := "res://assets/sprites/feliz.png"
const PLAYER_ANXIOUS_FACESET := "res://assets/sprites/ansioso.png"
const CUSTOMER_FACESET := "res://assets/sprites/faceset1.png"

@export_category("Objects")
@export var _hud :CanvasLayer = null

func _show_dialog(dialog) -> DialogScreen:
	if active_dialog and is_instance_valid(active_dialog):
		active_dialog.visible = false
		active_dialog.queue_free()
		active_dialog = null
	var _new_dialog : DialogScreen = _DIALOG_SCREEN.instantiate()
	_new_dialog.visible = false
	_new_dialog.data = dialog
	_new_dialog.auto_advance = true
	_hud.add_child(_new_dialog)
	active_dialog = _new_dialog
	return _new_dialog


func show_request_dialog(new_challenge) -> void:
	challenge = new_challenge
	if challenge == null or _hud == null:
		push_error("Context null no cliente!")
		return

	var dialog = {}
	var inputs = challenge.values

	dialog[0] = {
		"faceset": CUSTOMER_FACESET,
		"dialog": "Oi, queria comprar essas coisas:",
		"title": "Cliente"
	}

	dialog[1] = {
		"faceset": CUSTOMER_FACESET,
		"dialog": gerar_texto_pedido(inputs),
		"title": "Cliente"
	}

	if _tem_troco():
		dialog[dialog.size()] = {
		"faceset": CUSTOMER_FACESET,
			"dialog": "Vou pagar com R$ " + formatar(challenge.order.payment) + ". Informe o total da compra e quanto recebo de troco.",
			"title": "Cliente"
		}

	_show_dialog(dialog)


# =========================
# GERA TEXTO DO PEDIDO
# =========================
func gerar_texto_pedido(inputs):
	if challenge.requires_stock:
		var texto_estoque = gerar_texto_ingredientes(challenge.requested_items)
		if not challenge.promotions.is_empty():
			texto_estoque += "\nConsidere as ofertas ativas para os produtos em promoção."
		return texto_estoque

	if inputs.size() < 2:
		return "Tenho um pedido aqui."

	if challenge.type == "compra_variavel":
		var partes = []
		for value in inputs:
			partes.append("R$ " + formatar(value))
		var texto_carrinho = "Peguei estes itens: " + ", ".join(partes) + "."
		return texto_carrinho

	var texto = "Peguei dois itens: "

	for i in range(inputs.size()):
		texto += "R$ " + formatar(inputs[i])

		if i == inputs.size() - 2:
			texto += " e "
		elif i < inputs.size() - 2:
			texto += ", "

	texto += ". Quanto ficou?"

	return texto

func gerar_texto_ingredientes(items: Array) -> String:
	var linhas = ["Vou levar isso aqui:"]
	for item in items:
		linhas.append("[%d] %dx %s, R$ %s cada" % [
			int(item.get("code", 0)),
			int(item.get("quantity", 0)),
			str(item.get("name", "")),
			formatar(float(item.get("unit_price", 0.0)))
		])
	linhas.append("Qual é o total de todos os produtos?")
	return "\n".join(linhas)


func show_result_dialog(correto: bool, valores: Array) -> void:
	if correto:
		dialogo_acerto(valores)
	else:
		dialogo_erro(valores)


# =========================
# DIÁLOGO DE ACERTO
# =========================
func dialogo_acerto(valores):
	var dialog = {}

	if not _tem_troco():
		dialog = {
			0: {
				"faceset": PLAYER_HAPPY_FACESET,
				"dialog": "Ficou R$ " + formatar(valores[0]) + ".",
				"title": "Você"
			},
			1: {
				"faceset": CUSTOMER_FACESET,
				"dialog": "Fechou, valeu!",
				"title": "Cliente"
			}
		}

	else:
		dialog = {
			0: {
				"faceset": PLAYER_HAPPY_FACESET,
				"dialog": "Ficou R$ " + formatar(valores[0]) +
						  " e seu troco é R$ " + formatar(valores[1]) + ".",
				"title": "Você"
			},
			1: {
				"faceset": CUSTOMER_FACESET,
				"dialog": "Boa, era isso mesmo.",
				"title": "Cliente"
			}
		}

	var dialog_screen = _show_dialog(dialog)
	dialog_screen.end_dialog.connect(_on_result_dialog_closed)


# =========================
# DIÁLOGO DE ERRO
# =========================
func dialogo_erro(valores):
	var resposta = _formatar_resposta(valores)
	var dialog = {
		0: {
			"faceset": PLAYER_ANXIOUS_FACESET,
			"dialog": _gerar_texto_resposta_insegura(resposta),
			"title": "Você"
		},
		1: {
			"faceset": CUSTOMER_FACESET,
			"dialog": "Agora o caixa espera total e troco." if _tem_troco() and valores.size() != 2 else "Acho que essa conta não bateu.",
			"title": "Cliente"
		}
	}
	var dialog_screen = _show_dialog(dialog)
	dialog_screen.end_dialog.connect(_on_result_dialog_closed)


# =========================
# FORMATAR DINHEIRO
# =========================
func formatar(valor):
	return str("%.2f" % valor).replace(".", ",")

func _formatar_resposta(valores: Array) -> String:
	if valores.size() == 1:
		return "R$ " + formatar(valores[0])
	if valores.size() > 1:
		var partes = []
		for valor in valores:
			partes.append("R$ " + formatar(valor))
		return ", ".join(partes)
	return "nenhum valor"

func _gerar_texto_resposta_insegura(resposta: String) -> String:
	if challenge == null:
		return "Eh... Acho que é " + resposta + "."
	if _tem_troco():
		return "Eh... Acho que ficou " + resposta + "."
	if challenge.requires_stock:
		return "Eh... Somando esses produtos, acho que é " + resposta + "."
	if challenge.type == "compra_variavel":
		return "Eh... Pelo carrinho todo, acho que é " + resposta + "."
	return "Eh... Acho que é " + resposta + "."

func _tem_troco() -> bool:
	return challenge != null and challenge.expected_output.size() > 1


func _on_result_dialog_closed() -> void:
	active_dialog = null
	result_closed.emit()
	queue_free()
