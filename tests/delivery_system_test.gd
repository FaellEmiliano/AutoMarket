extends Node

const Config = preload("res://data/DeliveryConfig.gd")

var _failures: Array[String] = []
var _money_events := 0
var _delivery_script_id := ""
var _notifications: Array[String] = []


func _ready() -> void:
	if not EventBus.update_money.is_connected(_on_update_money):
		EventBus.update_money.connect(_on_update_money)
	if not EventBus.player_notification.is_connected(_on_notification):
		EventBus.player_notification.connect(_on_notification)

	_reset_all()
	_test_calculation_table()
	_test_delivery_upgrade_unlock()
	_reset_all()
	await _test_report_is_stable_and_copied()
	await _test_delivery_builtins_are_contextual()
	await _test_argument_errors()
	await _test_wrong_answer_has_no_reward()
	await _test_structural_validation()
	await _test_runtime_recursion_required()
	await _test_valid_recursive_solution()
	await _test_python_valid_recursive_solution()
	await _test_python_non_recursive_solution()
	await _test_python_declared_recursion_must_execute()
	await _test_python_facts_are_runtime_local()
	await _test_valid_while_solution()
	await _test_duplicate_and_cooldown_authority()
	await _test_diamond_cap()
	await _test_recursion_depth_limit()
	await _test_parallel_runtime_isolation()
	_test_save_roundtrip_and_old_defaults()
	_test_final_upgrade()

	InterpreterSystem.runtime_manager.stop_all()
	if _failures.is_empty():
		print("DELIVERY_SYSTEM_TEST_OK")
	else:
		push_error("\n".join(_failures))

	await get_tree().process_frame
	get_tree().quit()


func _reset_all() -> void:
	InterpreterSystem.runtime_manager.reset()
	FeatureManager.reset_progression()
	FeatureManager.unlock_feature(FeatureManager.FEATURE_IF)
	FeatureManager.unlock_feature(FeatureManager.FEATURE_STOCK)
	GameManager.money = 0
	GameManager.diamonds = 0
	GameManager.game_completed = false
	GameManager.upgrades.clear()
	UpgradeManager.upgrades_comprados.clear()
	UpgradeManager.upgrades_liberados.clear()
	DeliverySystem.load_save_data({})
	DeliverySystem.unlock(false)
	_delivery_script_id = InterpreterSystem.ensure_delivery_script()
	_money_events = 0
	_notifications.clear()


func _reset_report(deliveries: Array) -> void:
	InterpreterSystem.runtime_manager.stop_script(_delivery_script_id)
	DeliverySystem.load_save_data({})
	DeliverySystem.unlock(false)
	_check(DeliverySystem.debug_set_report(deliveries), "O relatório de teste deve ser aceito: %s" % str(deliveries))
	GameManager.money = 0
	GameManager.diamonds = 0
	_money_events = 0


func _test_calculation_table() -> void:
	var expected := {
		2: [0, 2, 6, 14, 30, 62],
		4: [0, 4, 12, 28, 60, 124],
		7: [0, 7, 21, 49, 105, 217]
	}
	for base_value in Config.BASE_VALUES:
		for quantity in range(Config.MIN_DELIVERIES, Config.MAX_DELIVERIES + 1):
			_check(
				DeliverySystem.calculate_profit(quantity, base_value) == expected[base_value][quantity],
				"Lucro incorreto para base %d e quantidade %d." % [base_value, quantity]
			)


func _test_delivery_upgrade_unlock() -> void:
	FeatureManager.reset_progression()
	DeliverySystem.load_save_data({})
	GameManager.money = Config.DELIVERY_UNLOCK_COST
	GameManager.upgrades = ["premium_3", "marketing_3"]
	UpgradeManager.upgrades_comprados = {"premium_3": true, "marketing_3": true}
	UpgradeManager.upgrades_liberados.clear()
	_notifications.clear()
	UpgradeManager.verificar_desbloqueios()
	_check(UpgradeManager.upgrades_liberados.has("delivery_online"), "Delivery Online deve aparecer apenas no fim da árvore de upgrades.")
	_check(UpgradeManager.can_buy("delivery_online"), "Delivery Online deve poder ser comprado com o custo configurado.")
	UpgradeManager.comprar_upgrade("delivery_online")
	_check(GameManager.money == 0, "Upgrade Delivery Online deve descontar o custo configurado do dinheiro existente.")
	_check(FeatureManager.has_feature(FeatureManager.FEATURE_DELIVERY), "Compra do upgrade deve desbloquear a feature Delivery.")
	_check(DeliverySystem.state == DeliverySystem.State.WAITING_DECLARATION, "Compra deve gerar o primeiro relatório.")
	_check(not InterpreterSystem.get_delivery_script_id().is_empty(), "Compra deve criar a aba reservada Delivery.")
	_check(_notifications.any(func(message): return message.contains("Delivery Online desbloqueado")), "Compra deve notificar o desbloqueio.")
	var money_after_purchase := GameManager.money
	UpgradeManager.comprar_upgrade("delivery_online")
	_check(GameManager.money == money_after_purchase, "Upgrade Delivery Online não pode ser comprado duas vezes.")


func _test_report_is_stable_and_copied() -> void:
	_reset_report([3, 0, 2])
	var runtime_id := InterpreterSystem.runtime_manager.start_script(_delivery_script_id, """
int main() {
	int primeiro[3];
	int segundo[3];
	primeiro = get_deliveries();
	primeiro[0] = 99;
	segundo = get_deliveries();
	print(segundo);
	await(1);
}
""", "Delivery")
	await _wait_frames(3)
	var runtime := InterpreterSystem.runtime_manager.get_runtime(runtime_id)
	_check(str(runtime.get("status", "")) == ScriptRuntimeManager.STATUS_SLEEPING, "await() deve suspender apenas o script do Delivery.")
	_check(str(runtime.get("output", "")).contains("[3, 0, 2]"), "get_deliveries() deve retornar o mesmo relatório e uma cópia segura.")
	_check(DeliverySystem.active_deliveries == [3, 0, 2], "Alterar o array retornado não pode alterar o relatório real.")
	InterpreterSystem.runtime_manager.stop_runtime(runtime_id)
	await get_tree().process_frame


func _test_delivery_builtins_are_contextual() -> void:
	_reset_report([1, 2, 3])
	var other_id := "not_delivery"
	var runtime_id := InterpreterSystem.runtime_manager.start_script(other_id, "int main(){ int e[3]; e = get_deliveries(); }", "Outro")
	var guard := 0
	while InterpreterSystem.runtime_manager.is_script_running(other_id) and guard < 60:
		guard += 1
		await get_tree().process_frame
	var runtime := InterpreterSystem.runtime_manager.get_runtime(runtime_id)
	_check(str(runtime.get("status", "")) == ScriptRuntimeManager.STATUS_ERROR, "Built-ins do Delivery devem rejeitar outra aba.")
	_check(_runtime_text(runtime).contains("aba Delivery"), "Uso fora da aba Delivery deve orientar o jogador.")
	_check(GameManager.money == 0 and GameManager.diamonds == 0, "Outra aba não pode receber recompensas do Delivery.")


func _test_argument_errors() -> void:
	var cases := [
		["int main(){ get_deliveries(1); }", "sem nada dentro dos parênteses"],
		["int main(){ declare_profit(); }", "precisa receber o array"],
		["int main(){ declare_profit(1); }", "espera um array"],
		["int main(){ declare_profit([1, 2, 3], [1, 2, 3]); }", "somente um argumento"],
		["int main(){ int e[3]; int p[2]; e = get_deliveries(); declare_profit(p); }", "3 posições"],
		["int main(){ int e[3]; e = get_deliveries(); declare_profit([1, 2.5, 3]); }", "precisa ser inteiro"]
	]
	for entry in cases:
		_reset_report([1, 2, 3])
		var runtime := await _run_delivery(str(entry[0]))
		_check(str(runtime.get("status", "")) == ScriptRuntimeManager.STATUS_ERROR, "Uso inválido deve encerrar somente a execução atual.")
		_check(_runtime_text(runtime).contains(str(entry[1])), "Erro de argumento não explicou o problema: %s" % str(entry[1]))
		_check(GameManager.money == 0 and GameManager.diamonds == 0, "Argumento inválido não pode conceder recompensa.")


func _test_wrong_answer_has_no_reward() -> void:
	_reset_report([2, 1, 0])
	var runtime := await _run_delivery(_valid_solution("lucros[1] = lucros[1] + 1;"))
	_check(_runtime_text(runtime).contains("expressas"), "Resposta parcial errada deve indicar a categoria sem revelar a solução.")
	_check(DeliverySystem.state == DeliverySystem.State.WAITING_DECLARATION, "Resposta errada deve manter o relatório aberto.")
	_check(GameManager.money == 0 and GameManager.diamonds == 0 and _money_events == 0, "Resposta errada não pode conceder dinheiro ou diamante.")


func _test_structural_validation() -> void:
	_reset_report([2, 1, 1])
	var no_recursion := await _run_delivery("""
int main() {
	int e[3]; int p[3]; int bases[3];
	bases[0] = 2; bases[1] = 4; bases[2] = 7;
	e = get_deliveries();
	for (int i = 0; i < 3; i++) { p[i] = 0; for (int j = 0; j < e[i]; j++) { p[i] = 2 * p[i] + bases[i]; } }
	declare_profit(p);
}
""")
	_check(_runtime_text(no_recursion).contains("função criada por você"), "Cálculo correto sem função criada pelo jogador deve ser rejeitado.")

	var non_recursive_function := await _run_delivery("""
int auxiliar(int valor) { return valor; }
int main() {
	int e[3]; int p[3]; int bases[3];
	bases[0] = 2; bases[1] = 4; bases[2] = 7; e = get_deliveries();
	for (int i = 0; i < 3; i++) { p[i] = 0; for (int j = 0; j < e[i]; j++) { p[i] = 2 * p[i] + auxiliar(bases[i]); } }
	declare_profit(p);
}
""")
	_check(_runtime_text(non_recursive_function).contains("chamar a si mesma"), "Função auxiliar não recursiva deve ser rejeitada.")

	_reset_report([2, 1, 1])
	var no_loop := await _run_delivery("""
int lucro(int n, int b) { if (n == 0) { return 0; } return 2 * lucro(n - 1, b) + b; }
int main() {
	int e[3]; int p[3]; e = get_deliveries();
	p[0] = lucro(e[0], 2); p[1] = lucro(e[1], 4); p[2] = lucro(e[2], 7);
	declare_profit(p);
}
""")
	_check(_runtime_text(no_loop).contains("Use for ou while"), "Solução sem loop deve ser rejeitada.")

	_reset_report([2, 1, 1])
	var no_base_case := await _run_delivery("""
int armadilha(int n) { if (n > 0) { return armadilha(n - 1); } return armadilha(n + 1); }
int main() {
	int e[3]; int p[3]; int bases[3]; bases[0] = 2; bases[1] = 4; bases[2] = 7; e = get_deliveries();
	for (int i = 0; i < 3; i++) { p[i] = 0; for (int j = 0; j < e[i]; j++) { p[i] = 2 * p[i] + bases[i]; } }
	declare_profit(p);
}
""")
	_check(_runtime_text(no_base_case).contains("caso-base"), "Função recursiva sem ramo de parada deve ser rejeitada pela AST.")


func _test_runtime_recursion_required() -> void:
	_reset_report([2, 1, 1])
	var runtime := await _run_delivery("""
int recursiva(int n) { if (n == 0) { return 0; } return recursiva(n - 1); }
int main() {
	int e[3]; int p[3]; int bases[3];
	bases[0] = 2; bases[1] = 4; bases[2] = 7; e = get_deliveries();
	for (int i = 0; i < 3; i++) { p[i] = 0; for (int j = 0; j < e[i]; j++) { p[i] = 2 * p[i] + bases[i]; } }
	declare_profit(p);
}
""")
	_check(_runtime_text(runtime).contains("não foi usada"), "Declarar recursão sem executá-la no relatório deve ser rejeitado.")
	_check(GameManager.money == 0 and GameManager.diamonds == 0, "Recursão não executada não pode render recompensa.")


func _test_valid_recursive_solution() -> void:
	_reset_report([3, 2, 1])
	var runtime := await _run_delivery(_valid_solution())
	_check(_runtime_text(runtime).contains("Declaração aprovada"), "Solução recursiva válida deve ser aprovada.")
	_check(GameManager.money == 33, "Relatório [3, 2, 1] deve creditar 33 moedas.")
	_check(GameManager.diamonds == 1, "Declaração correta deve conceder exatamente um diamante.")
	_check(_money_events == 1, "O lucro deve ser creditado por um único evento monetário.")
	_check(DeliverySystem.state == DeliverySystem.State.COOLDOWN, "A aprovação deve iniciar o cooldown do jogo.")
	_check(DeliverySystem.last_rewarded_report_id > 0, "A aprovação deve registrar o id anti-duplicação.")


func _test_python_valid_recursive_solution() -> void:
	_reset_report([3, 2, 1])
	var runtime := await _run_python_delivery(_valid_python_solution())
	_check(str(runtime.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED,
		"Solução Python-like válida deve terminar normalmente.")
	_check(_runtime_text(runtime).contains("Declaração aprovada"),
		"Solução Python-like recursiva válida deve ser aprovada.")
	_check(GameManager.money == 33 and GameManager.diamonds == 1,
		"Solução Python-like deve receber as mesmas recompensas da C-like.")
	_check(_money_events == 1 and DeliverySystem.state == DeliverySystem.State.COOLDOWN,
		"Aprovação Python-like deve aplicar uma única recompensa e iniciar cooldown.")


func _test_python_non_recursive_solution() -> void:
	_reset_report([2, 1, 1])
	var runtime := await _run_python_delivery(_non_recursive_python_solution())
	_check(str(runtime.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED,
		"Rejeição pedagógica Python-like não deve ser erro do runtime.")
	_check(_runtime_text(runtime).contains("chamar a si mesma"),
		"Cálculo Python-like correto sem recursão deve ser rejeitado como no C-like.")
	_check(GameManager.money == 0 and GameManager.diamonds == 0,
		"Solução Python-like sem recursão não pode receber recompensa.")


func _test_python_declared_recursion_must_execute() -> void:
	_reset_report([2, 1, 1])
	var runtime := await _run_python_delivery("""
def recursiva(n):
    if n == 0:
        return 0
    return recursiva(n - 1)

def calcular(quantidade, valor_base):
    lucro = 0
    for passo in range(quantidade):
        lucro = 2 * lucro + valor_base
    return lucro

entregas = get_deliveries()
bases = [2, 4, 7]
lucros = [0, 0, 0]
for i in range(3):
    lucros[i] = calcular(entregas[i], bases[i])
declare_profit(lucros)
""")
	_check(_runtime_text(runtime).contains("não foi usada"),
		"Declarar recursão Python-like sem executá-la após o relatório deve ser rejeitado.")
	_check(GameManager.money == 0 and GameManager.diamonds == 0,
		"Recursão Python-like não executada não pode conceder recompensa.")


func _test_python_facts_are_runtime_local() -> void:
	_reset_report([2, 1, 1])
	var other_id := "python_delivery_facts_other"
	InterpreterSystem.runtime_manager.start_script(other_id, """
def recursiva(n):
    if n == 0:
        return 0
    return recursiva(n - 1)

while True:
    wait(1)
""", "OutroPython", null, "python_like")
	await _wait_frames(2)
	_check(InterpreterSystem.runtime_manager.is_script_running(other_id),
		"Runtime Python-like paralelo deve permanecer suspenso durante o teste.")
	var runtime := await _run_python_delivery(_non_recursive_python_solution())
	_check(_runtime_text(runtime).contains("chamar a si mesma"),
		"Delivery não pode herdar fatos recursivos de outro runtime Python-like.")
	_check(GameManager.money == 0 and GameManager.diamonds == 0,
		"Fatos de outro runtime não podem liberar recompensa.")
	InterpreterSystem.runtime_manager.stop_script(other_id)

	_reset_report([2, 1, 1])
	var invalid := await _run_python_delivery("def quebrada(:\n    return 1\n")
	_check(str(invalid.get("status", "")) == ScriptRuntimeManager.STATUS_ERROR,
		"Source Python-like inválido deve falhar sem produzir fatos válidos.")
	_check(GameManager.money == 0 and GameManager.diamonds == 0,
		"Falha de parse após restart não pode reutilizar fatos nem conceder recompensa.")


func _test_valid_while_solution() -> void:
	_reset_report([1, 0, 2])
	var runtime := await _run_delivery("""
int lucro(int n, int b) { if (n == 0) { return 0; } return 2 * lucro(n - 1, b) + b; }
int main() {
	int e[3]; int p[3]; int bases[3]; int i = 0;
	bases[0] = 2; bases[1] = 4; bases[2] = 7; e = get_deliveries();
	while (i < 3) { p[i] = lucro(e[i], bases[i]); i = i + 1; }
	declare_profit(p);
}
""")
	_check(_runtime_text(runtime).contains("Declaração aprovada"), "while também deve atender ao requisito de loop.")
	_check(GameManager.money == 23 and GameManager.diamonds == 1, "Solução válida com while deve receber as recompensas corretas.")


func _test_duplicate_and_cooldown_authority() -> void:
	var money_before := GameManager.money
	var diamonds_before := GameManager.diamonds
	var duplicate := await _run_delivery(_valid_solution())
	_check(_runtime_text(duplicate).contains("Aguarde"), "Nova leitura durante cooldown deve informar a espera do jogo.")
	_check(GameManager.money == money_before and GameManager.diamonds == diamonds_before, "Remover await() não pode duplicar recompensas.")
	_check(_money_events == 1, "Declaração repetida não pode emitir novo crédito.")

	DeliverySystem.next_report_unix = int(Time.get_unix_time_from_system()) - 1
	DeliverySystem.call("_process", 0.0)
	_check(DeliverySystem.state == DeliverySystem.State.WAITING_DECLARATION, "O jogo deve liberar novo relatório ao fim do cooldown.")
	_check(DeliverySystem.active_report_id > DeliverySystem.last_rewarded_report_id, "O novo relatório deve possuir id posterior ao já premiado.")


func _test_diamond_cap() -> void:
	_reset_report([1, 1, 1])
	GameManager.diamonds = Config.MAX_DIAMONDS
	var runtime := await _run_delivery(_valid_solution())
	_check(_runtime_text(runtime).contains("Declaração aprovada"), "Diamantes no máximo não devem bloquear o lucro.")
	_check(GameManager.diamonds == Config.MAX_DIAMONDS, "Diamantes não podem ultrapassar o máximo.")
	_check(GameManager.money == 13, "Lucro ainda deve ser creditado com diamantes no máximo.")
	_check(int(DeliverySystem.last_result.get("diamond_awarded", -1)) == 0, "Resultado deve informar que nenhum diamante extra foi concedido.")


func _test_recursion_depth_limit() -> void:
	var runtime := await _run_delivery("""
int sem_fim(int n) { return sem_fim(n + 1); }
int main() { print(sem_fim(0)); }
""")
	_check(str(runtime.get("status", "")) == ScriptRuntimeManager.STATUS_ERROR, "Recursão sem caso-base deve encerrar com erro seguro.")
	_check(_runtime_text(runtime).contains("limite de chamadas recursivas"), "Profundidade excessiva deve mostrar mensagem clara.")


func _test_parallel_runtime_isolation() -> void:
	_reset_report([1, 2, 1])
	var other_id := "parallel_other"
	InterpreterSystem.runtime_manager.start_script(other_id, "int main(){ while (1) { await(1); } }", "Outro")
	await _wait_frames(2)
	_check(InterpreterSystem.runtime_manager.is_script_running(other_id), "Outro script deve rodar em paralelo com o Delivery.")
	var invalid := await _run_delivery("int main(){ int e[3]; e = get_deliveries(); declare_profit(1); }")
	_check(str(invalid.get("status", "")) == ScriptRuntimeManager.STATUS_ERROR, "Erro no Delivery deve ficar restrito ao runtime do Delivery.")
	_check(InterpreterSystem.runtime_manager.is_script_running(other_id), "Erro no Delivery não pode parar outro script em await().")
	InterpreterSystem.runtime_manager.stop_script(other_id)


func _test_save_roundtrip_and_old_defaults() -> void:
	_reset_report([0, 3, 2])
	var snapshot := DeliverySystem.get_save_data()
	DeliverySystem.load_save_data(snapshot)
	_check(DeliverySystem.state == DeliverySystem.State.WAITING_DECLARATION, "Save deve restaurar relatório ativo.")
	_check(DeliverySystem.active_deliveries == [0, 3, 2], "Save deve preservar as quantidades do relatório.")
	var report_id := DeliverySystem.active_report_id
	DeliverySystem.load_save_data({
		"state": DeliverySystem.State.COOLDOWN,
		"last_rewarded_report_id": report_id,
		"next_report_id": report_id + 1,
		"next_report_unix": int(Time.get_unix_time_from_system()) + 30
	})
	_check(DeliverySystem.active_report_id == 0 and DeliverySystem.last_rewarded_report_id == report_id, "Save aprovado não pode reabrir o relatório premiado.")

	GameManager.load_save_data({"dinheiro": 17, "upgrades": [], "unlocked_mechanics": {}})
	_check(GameManager.diamonds == 0 and not GameManager.game_completed, "Save antigo deve assumir 0 diamantes e jogo não concluído.")
	DeliverySystem.load_save_data({})
	_check(DeliverySystem.state == DeliverySystem.State.LOCKED, "Save antigo deve assumir Delivery bloqueado.")


func _test_final_upgrade() -> void:
	FeatureManager.unlock_feature(FeatureManager.FEATURE_DELIVERY)
	GameManager.game_completed = false
	GameManager.diamonds = Config.FINAL_UPGRADE_COST - 1
	GameManager.upgrades = ["delivery_online"]
	UpgradeManager.upgrades_comprados = {"delivery_online": true}
	UpgradeManager.upgrades_liberados = ["zerar"]
	_check(not UpgradeManager.can_buy("zerar"), "Zerar deve ficar indisponível com menos de 5 diamantes.")
	GameManager.diamonds = Config.FINAL_UPGRADE_COST
	_check(UpgradeManager.can_buy("zerar"), "Zerar deve liberar com 5 diamantes.")
	UpgradeManager.comprar_upgrade("zerar")
	_check(GameManager.diamonds == 0, "Zerar deve gastar os cinco diamantes.")
	_check(GameManager.game_completed, "Zerar deve marcar o jogo como concluído.")
	_check(DeliverySystem.state == DeliverySystem.State.COMPLETED, "Zerar deve encerrar novos relatórios.")
	_check(UpgradeManager.has_upgrade("zerar") and not UpgradeManager.can_buy("zerar"), "Zerar não pode ser comprado novamente.")


func _valid_solution(extra_line := "") -> String:
	return """
int resolver(int quantidade, int valor_base) {
	if (quantidade == 0) { return 0; }
	return 2 * resolver(quantidade - 1, valor_base) + valor_base;
}
int main() {
	int entregas[3]; int bases[3]; int lucros[3];
	bases[0] = 2; bases[1] = 4; bases[2] = 7;
	entregas = get_deliveries();
	for (int i = 0; i < 3; i++) { lucros[i] = resolver(entregas[i], bases[i]); }
	%s
	declare_profit(lucros);
}
""" % extra_line


func _valid_python_solution() -> String:
	return """
def resolver(quantidade, valor_base):
    if quantidade == 0:
        return 0
    return 2 * resolver(quantidade - 1, valor_base) + valor_base

entregas = get_deliveries()
bases = [2, 4, 7]
lucros = [0, 0, 0]
for i in range(3):
    lucros[i] = resolver(entregas[i], bases[i])
declare_profit(lucros)
"""


func _non_recursive_python_solution() -> String:
	return """
def calcular(quantidade, valor_base):
    lucro = 0
    for passo in range(quantidade):
        lucro = 2 * lucro + valor_base
    return lucro

entregas = get_deliveries()
bases = [2, 4, 7]
lucros = [0, 0, 0]
for i in range(3):
    lucros[i] = calcular(entregas[i], bases[i])
declare_profit(lucros)
"""


func _run_delivery(code: String) -> Dictionary:
	var runtime_id := InterpreterSystem.runtime_manager.start_script(_delivery_script_id, code, "Delivery")
	var guard := 0
	while InterpreterSystem.runtime_manager.is_script_running(_delivery_script_id) and guard < 180:
		guard += 1
		await get_tree().process_frame
	if InterpreterSystem.runtime_manager.is_script_running(_delivery_script_id):
		_check(false, "Execução do Delivery excedeu o limite de frames.")
		InterpreterSystem.runtime_manager.stop_script(_delivery_script_id)
	return InterpreterSystem.runtime_manager.get_runtime(runtime_id)


func _run_python_delivery(code: String) -> Dictionary:
	var runtime_id := InterpreterSystem.runtime_manager.start_script(
		_delivery_script_id, code, "Delivery", null, "python_like"
	)
	var guard := 0
	while InterpreterSystem.runtime_manager.is_script_running(_delivery_script_id) and guard < 180:
		guard += 1
		await get_tree().process_frame
	if InterpreterSystem.runtime_manager.is_script_running(_delivery_script_id):
		_check(false, "Execução Python-like do Delivery excedeu o limite de frames.")
		InterpreterSystem.runtime_manager.stop_script(_delivery_script_id)
	return InterpreterSystem.runtime_manager.get_runtime(runtime_id)


func _runtime_text(runtime: Dictionary) -> String:
	return str(runtime.get("output", "")) + "\n" + str(runtime.get("error", ""))


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _on_update_money(amount: int) -> void:
	_money_events += 1
	GameManager.money += amount


func _on_notification(message: String) -> void:
	_notifications.append(message)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
