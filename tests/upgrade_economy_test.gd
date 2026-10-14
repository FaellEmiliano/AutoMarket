extends Node

const UpgradeData = preload("res://data/UpgradeData.gd")

const PRIMARY_MIN_RUNS := 9.0
const PRIMARY_MAX_RUNS := 11.0
const SECONDARY_MIN_RUNS := 5.0
const SECONDARY_MAX_RUNS := 6.0

# Ganho medio do estagio imediatamente anterior a cada compra na ordem
# pedagogica. Depois de abrir o estoque, o valor ja desconta a reposicao
# media de um estoque diversificado, sem o bonus de estoque cheio.
const STAGES := [
	{"id": "premium_1", "average_income": 8.0, "primary": false},
	{"id": "marketing_1", "average_income": 10.0, "primary": false},
	{"id": "lang_if", "average_income": 10.0, "primary": true},
	{"id": "lang_while", "average_income": 11.08, "primary": true},
	{"id": "premium_2", "average_income": 15.20, "primary": false},
	{"id": "lang_sensor", "average_income": 18.44, "primary": true},
	{"id": "marketing_2", "average_income": 18.44, "primary": false},
	{"id": "gameplay_stock", "average_income": 24.44, "primary": true},
	{"id": "premium_3", "average_income": 28.82, "primary": false},
	{"id": "marketing_3", "average_income": 37.18, "primary": false},
	{"id": "delivery_online", "average_income": 37.18, "primary": true},
]


func _ready() -> void:
	var change: Dictionary = UpgradeData.UPGRADES["gameplay_change"]
	assert(int(change["preco"]) == 120 and int(change["saldo_minimo_compra"]) == 250,
		"Troco deve exigir cerca de tres vendas de R$24 e preservar R$130 para o estoque.")
	var promotions: Dictionary = UpgradeData.UPGRADES["gameplay_promotions"]
	assert(int(promotions["preco"]) == 160 and int(promotions["saldo_minimo_compra"]) == 300
		and promotions["requer"] == ["gameplay_change"],
		"Promocoes devem exigir troco, cerca de seis vendas adicionais e preservar R$140.")
	for stage in STAGES:
		var id := str(stage["id"])
		var average_income := float(stage["average_income"])
		var price := float(UpgradeData.UPGRADES[id]["preco"])
		var average_runs := price / average_income
		var minimum := PRIMARY_MIN_RUNS if bool(stage["primary"]) else SECONDARY_MIN_RUNS
		var maximum := PRIMARY_MAX_RUNS if bool(stage["primary"]) else SECONDARY_MAX_RUNS
		assert(
			average_runs >= minimum and average_runs <= maximum,
			"%s exige em media %.2f execucoes; esperado entre %.0f e %.0f." % [
				id,
				average_runs,
				minimum,
				maximum,
			]
		)

	print("UPGRADE_ECONOMY_TEST_OK")
	get_tree().quit()
