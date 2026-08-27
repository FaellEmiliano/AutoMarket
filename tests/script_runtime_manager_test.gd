extends Node

const ScriptRuntimeManagerScript = preload("res://systems/ScriptRuntimeManager.gd")
const LanguageBackendFactoryScript = preload("res://interpreter/runtime/language_backend_factory.gd")
const CLikeRuntimeBackendScript = preload("res://interpreter/runtime/c_like_runtime_backend.gd")

signal result_closed

var _failures: Array[String] = []
var _debug_text := ""
var _last_client_result := false


func _ready() -> void:
	EventBus.send_debug.connect(_on_send_debug)
	if not EventBus.update_money.is_connected(_on_update_money):
		EventBus.update_money.connect(_on_update_money)
	if not EventBus.end_client.is_connected(_on_end_client):
		EventBus.end_client.connect(_on_end_client)
	FeatureManager.unlock_feature(FeatureManager.FEATURE_IF)
	FeatureManager.unlock_feature(FeatureManager.FEATURE_SENSOR)

	var manager := ScriptRuntimeManagerScript.new()
	add_child(manager)

	_test_language_backend_factory()
	await _test_language_routing(manager)
	await _test_await_requires_stock(manager)
	FeatureManager.unlock_feature(FeatureManager.FEATURE_STOCK)
	await _test_infinite_print_does_not_freeze(manager)
	await _test_two_infinite_scripts_share_frames(manager)
	await _test_stop_one_runtime(manager)
	await _test_error_stops_only_one_runtime(manager)
	await _test_get_stock_loop(manager)
	await _test_buy_stock(manager)
	await _test_script_can_use_input_and_send(manager)
	await _test_await_sleeps_runtime(manager)
	await _test_stop_all(manager)
	await _test_finished_runtime(manager)
	await _test_restarting_script_replaces_previous_output(manager)

	if _failures.is_empty():
		print("SCRIPT_RUNTIME_MANAGER_TEST_OK")
	else:
		push_error("\n".join(_failures))

	await get_tree().create_timer(0.75).timeout
	manager.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _test_language_backend_factory() -> void:
	var backend: Node = LanguageBackendFactoryScript.create("c_like")
	_check(backend != null and backend.get_script() == CLikeRuntimeBackendScript, "Factory deve criar o backend C-like.")
	if backend != null:
		backend.free()
	_check(LanguageBackendFactoryScript.create("python_like") == null, "Factory não deve criar backend para linguagem desconhecida.")


func _test_language_routing(manager) -> void:
	var runtime_id: String = manager.start_script("default_language", "int main(){ print(\"ok\"); }", "DefaultLanguage")
	await _wait_until_not_running(manager, "default_language")
	var runtime: Dictionary = manager.get_runtime(runtime_id)
	_check(str(runtime.get("language", "")) == "c_like", "Ausência de linguagem deve usar C-like.")
	_check(str(runtime.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED, "Script C-like simples deve continuar executando.")

	_debug_text = ""
	var runtime_count: int = manager.get_all_runtimes().size()
	var unknown_id: String = manager.start_script("unknown_language", "int main(){}", "UnknownLanguage", null, "python_like")
	_check(unknown_id.is_empty(), "Linguagem sem backend deve falhar sem iniciar runtime.")
	_check(manager.get_all_runtimes().size() == runtime_count, "Falha de backend não deve criar runtime parcial.")
	_check(_debug_text.contains("python_like"), "Falha de backend deve identificar a linguagem desconhecida.")

	var active_script := InterpreterSystem.get_active_script()
	var original_language := str(active_script.get("language", "c_like"))
	active_script["language"] = "python_like"
	_debug_text = ""
	var active_runtime_id := InterpreterSystem.start_active_script(EnvContext.new([], 0, []))
	active_script["language"] = original_language
	_check(active_runtime_id.is_empty(), "InterpreterSystem deve propagar a linguagem explícita do documento ativo.")
	_check(_debug_text.contains("python_like"), "Erro de roteamento do documento ativo deve preservar a linguagem explícita.")


func _test_infinite_print_does_not_freeze(manager) -> void:
	_debug_text = ""
	manager.start_script("principal_a", "int main(){ while (1) { print(\"A\"); } }", "Principal")
	await _wait_frames(3)
	_check(manager.is_script_running("principal_a"), "Loop infinito com print deve continuar rodando sem travar.")
	_check(_debug_text.contains("[Principal] A"), "Output do loop infinito deve indicar origem Principal.")
	manager.stop_script("principal_a")
	await get_tree().process_frame
	_check(not manager.is_script_running("principal_a"), "Botao parar deve conseguir encerrar loop infinito.")


func _test_two_infinite_scripts_share_frames(manager) -> void:
	_debug_text = ""
	manager.start_script("principal", "int main(){ while (1) { print(\"A\"); } }", "Principal")
	manager.start_script("estoque", "int main(){ while (1) { print(\"B\"); } }", "Estoque")
	await _wait_frames(3)
	_check(manager.is_script_running("principal"), "Principal deve permanecer rodando.")
	_check(manager.is_script_running("estoque"), "Estoque deve rodar ao mesmo tempo que Principal.")
	_check(_debug_text.contains("[Principal] A"), "Output deve conter mensagens do Principal.")
	_check(_debug_text.contains("[Estoque] B"), "Output deve conter mensagens do Estoque.")


func _test_error_stops_only_one_runtime(manager) -> void:
	manager.start_script("erro_estoque", "int main(){ print(variavel_inexistente); }", "Estoque")
	await _wait_until_not_running(manager, "erro_estoque")

	var estoque_runtime: Dictionary = manager.get_runtime_by_script_id("erro_estoque")
	_check(str(estoque_runtime.get("status", "")) == "error", "Erro deve marcar apenas o runtime Estoque.")
	_check(manager.is_script_running("principal"), "Erro em Estoque nao pode parar Principal.")
	_check(_debug_text.contains("[Estoque]"), "Erro deve aparecer com o nome do script.")


func _test_stop_one_runtime(manager) -> void:
	manager.start_script("teste", _infinite_script(), "Teste")
	await get_tree().process_frame
	manager.stop_script("teste")
	await get_tree().process_frame
	_check(not manager.is_script_running("teste"), "Parar uma aba deve parar apenas ela.")
	_check(manager.is_script_running("principal"), "Parar Teste nao pode parar Principal.")


func _test_stop_all(manager) -> void:
	manager.stop_all()
	await get_tree().process_frame
	_check(manager.get_running_runtimes().is_empty(), "Parar todos deve encerrar todos os runtimes ativos.")


func _test_finished_runtime(manager) -> void:
	_debug_text = ""
	manager.start_script("finito", "int main(){ print(\"inicio\"); print(\"fim\"); }", "Finito")
	await _wait_until_not_running(manager, "finito")
	var runtime: Dictionary = manager.get_runtime_by_script_id("finito")
	_check(str(runtime.get("status", "")) == "finished", "Script finito deve ficar finished.")
	_check(_debug_text.contains("[Finito] inicio") and _debug_text.contains("[Finito] fim"), "Script finito deve imprimir inicio e fim.")


func _test_restarting_script_replaces_previous_output(manager) -> void:
	_debug_text = ""
	manager.start_script("reload", "int main(){ print(variavel_inexistente); }", "Reload")
	await _wait_until_not_running(manager, "reload")
	_check(_debug_text.contains("variavel_inexistente"), "Primeira execucao deve mostrar o erro.")

	manager.start_script("reload", "int main(){ print(\"ok\"); }", "Reload")
	await _wait_until_not_running(manager, "reload")
	_check(_debug_text.contains("[Reload] ok"), "Nova execucao deve mostrar a saida atual.")
	_check(not _debug_text.contains("variavel_inexistente"), "Nova execucao nao deve manter erro antigo da mesma aba.")


func _test_get_stock_loop(manager) -> void:
	_debug_text = ""
	_set_quantities([4, 0, 0, 0, 0, 0])
	manager.start_script("stock_loop", """
int main() {
	while (1) {
		int estoque[6];
		estoque = get_stock();
		print(estoque[0]);
	}
}
""", "EstoqueLoop")
	await _wait_frames(3)
	_check(manager.is_script_running("stock_loop"), "Loop com get_stock() deve continuar rodando.")
	_check(_debug_text.contains("[EstoqueLoop] 4"), "get_stock() deve funcionar repetidamente no loop.")
	manager.stop_script("stock_loop")
	await get_tree().process_frame


func _test_buy_stock(manager) -> void:
	_reset_stock()
	GameManager.money = 100
	manager.start_script("buy_stock", """
int main() {
	int compra[6];
	for (int i = 0; i < 6; i++) {
		compra[i] = 0;
	}
	compra[0] = 1;
	buy_stock(compra);
}
""", "Compra")
	await _wait_until_not_running(manager, "buy_stock")
	_check(StockSystem.get_stock()[0].quantity == 1, "buy_stock() deve aplicar a compra.")
	_check(GameManager.money == 97, "buy_stock() deve descontar dinheiro.")
	_check(manager.is_script_running("principal"), "buy_stock() nao pode parar outros scripts.")


func _test_script_can_use_input_and_send(manager) -> void:
	_last_client_result = false
	_start_fake_transaction([2, 3], [5])
	manager.start_script("input_send_runner", """
int main() {
	while (1) {
		if (sensor("cliente_na_tela") == true) {
			float x = input();
			float y = input();
			send(x + y);
		}
		await(0.1);
	}
}
""", "InputSend")
	await _wait_frames(6)
	_check(manager.is_script_running("input_send_runner"), "Script com input/send deve continuar rodando depois do atendimento.")
	_check(_last_client_result, "Script deve consumir input e enviar resposta correta.")
	manager.stop_script("input_send_runner")
	await get_tree().process_frame


func _test_await_sleeps_runtime(manager) -> void:
	_debug_text = ""
	manager.start_script("waiter", "int main(){ while (1) { print(\"tick\"); await(1); } }", "Waiter")
	await _wait_frames(3)
	var runtime: Dictionary = manager.get_runtime_by_script_id("waiter")
	_check(str(runtime.get("status", "")) == "sleeping", "await(1) deve colocar o runtime em sleeping.")
	_check(_debug_text.contains("[Waiter] tick"), "await() deve permitir imprimir antes de dormir.")
	manager.stop_script("waiter")
	await get_tree().process_frame


func _test_await_requires_stock(manager) -> void:
	_debug_text = ""
	manager.start_script("locked_await", "int main(){ await(0.1); }", "AwaitBloqueado")
	await _wait_until_not_running(manager, "locked_await")
	_check(_debug_text.contains("Compre o upgrade Abrir estoque"), "await() deve informar qual upgrade libera a função.")


func _infinite_script() -> String:
	return "int main(){ while (1) { } }"


func _wait_until_not_running(manager, script_id: String) -> void:
	var guard := 0
	while manager.is_script_running(script_id) and guard < 60:
		guard += 1
		await get_tree().process_frame
	if manager.is_script_running(script_id):
		_failures.append("Runtime %s excedeu o limite de frames." % script_id)
		manager.stop_script(script_id)


func _on_send_debug(text: String) -> void:
	_debug_text = text


func _on_update_money(amount: int) -> void:
	GameManager.money += amount


func _on_end_client(result: bool) -> void:
	_last_client_result = result


func show_request_dialog(_challenge) -> void:
	pass


func show_result_dialog(_correct: bool, _values: Array) -> void:
	emit_signal("result_closed")


func _start_fake_transaction(inputs: Array, expected: Array) -> void:
	TransactionManager._finish_transaction()
	var challenge := ChallengeData.new()
	challenge.env_context = EnvContext.new(inputs, 0, expected)
	challenge.expected_output = expected
	challenge.requires_stock = false
	challenge.requested_items = []
	var started := TransactionManager.start_transaction(self, challenge)
	_check(started, "Transacao fake deve iniciar para teste de client.")


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _reset_stock() -> void:
	for item in StockSystem.get_stock():
		item.quantity = 0
		item.max_quantity = 10
	GameManager.money = 0


func _set_quantities(values: Array) -> void:
	_reset_stock()
	for i in range(values.size()):
		StockSystem.get_stock()[i].quantity = int(values[i])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
