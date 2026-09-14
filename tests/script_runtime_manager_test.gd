extends Node

const ScriptRuntimeManagerScript = preload("res://systems/ScriptRuntimeManager.gd")
const LanguageBackendFactoryScript = preload("res://interpreter/runtime/language_backend_factory.gd")
const CLikeRuntimeBackendScript = preload("res://interpreter/runtime/c_like_runtime_backend.gd")
const PythonLikeRuntimeBackendScript = preload("res://interpreter/runtime/python_like_runtime_backend.gd")

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
	await _test_structured_diagnostics(manager)
	_test_python_like_per_script_budget(manager)
	_test_python_like_global_budget(manager)
	await _test_python_like_lifecycle_and_isolation(manager)
	await _test_await_requires_stock(manager)
	FeatureManager.unlock_feature(FeatureManager.FEATURE_STOCK)
	await _test_python_like_real_builtins(manager)
	await _test_python_like_wait_lifecycle(manager)
	await _test_python_like_wait_functions_and_loops(manager)
	await _test_python_like_wait_stop_and_isolation(manager)
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
	await _test_python_like_delivery_boundary()

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
	backend = LanguageBackendFactoryScript.create("python_like")
	_check(backend != null and backend.get_script() == PythonLikeRuntimeBackendScript, "Factory deve criar o backend Python-like.")
	if backend != null:
		backend.free()
	_check(LanguageBackendFactoryScript.create("unknown_like") == null, "Factory não deve criar backend para linguagem desconhecida.")


func _test_language_routing(manager) -> void:
	var runtime_id: String = manager.start_script("default_language", "int main(){ print(\"ok\"); }", "DefaultLanguage")
	await _wait_until_not_running(manager, "default_language")
	var runtime: Dictionary = manager.get_runtime(runtime_id)
	_check(str(runtime.get("language", "")) == "c_like", "Ausência de linguagem deve usar C-like.")
	_check(str(runtime.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED, "Script C-like simples deve continuar executando.")

	_debug_text = ""
	runtime_id = manager.start_script(
		"python_language",
		"print(\"inicio\")\nx = 0\nfor i in range(5):\n    x = x + i\nprint(x)\n",
		"PythonLanguage", null, "python_like"
	)
	await _wait_until_not_running(manager, "python_language")
	runtime = manager.get_runtime(runtime_id)
	_check(str(runtime.get("language", "")) == "python_like", "Runtime deve preservar a linguagem Python-like selecionada.")
	_check(str(runtime.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED, "Script Python-like simples deve concluir pelo manager.")
	_check(str(runtime.get("output", "")).contains("[PythonLanguage] inicio") and str(runtime.get("output", "")).contains("[PythonLanguage] 10"), "Programa Python-like mínimo deve produzir inicio e 10 no terminal.")

	_debug_text = ""
	var runtime_count: int = manager.get_all_runtimes().size()
	var unknown_id: String = manager.start_script("unknown_language", "", "UnknownLanguage", null, "unknown_like")
	_check(unknown_id.is_empty(), "Linguagem sem backend deve falhar sem iniciar runtime.")
	_check(manager.get_all_runtimes().size() == runtime_count, "Falha de backend não deve criar runtime parcial.")
	_check(_debug_text.contains("unknown_like"), "Falha de backend deve identificar a linguagem desconhecida.")

	var active_script := InterpreterSystem.get_active_script()
	var original_language := str(active_script.get("language", "c_like"))
	var original_source := str(active_script.get("source", ""))
	active_script["language"] = "python_like"
	active_script["source"] = "print(\"ativo\")\n"
	_debug_text = ""
	var active_runtime_id := InterpreterSystem.start_active_script(EnvContext.new([], 0, []))
	active_script["language"] = original_language
	active_script["source"] = original_source
	_check(not active_runtime_id.is_empty(), "InterpreterSystem deve propagar a linguagem Python-like do documento ativo.")
	await _wait_until_not_running(InterpreterSystem.runtime_manager, str(active_script.get("id", "")))
	var active_runtime: Dictionary = InterpreterSystem.runtime_manager.get_runtime(active_runtime_id)
	_check(str(active_runtime.get("language", "")) == "python_like", "Runtime iniciado pelo documento deve manter a linguagem explícita.")
	_check(str(active_runtime.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED, "Documento Python-like ativo deve concluir normalmente.")


func _test_structured_diagnostics(manager) -> void:
	var runtime_id: String = manager.start_script(
		"python_diagnostic", "print(nome_inexistente)\n", "PythonDiagnostic", null, "python_like"
	)
	await _wait_until_not_running(manager, "python_diagnostic")
	var runtime: Dictionary = manager.get_runtime(runtime_id)
	var diagnostics: Array = runtime.get("diagnostics", [])
	_check(not diagnostics.is_empty(), "Erro Python-like deve chegar como diagnóstico estruturado.")
	if not diagnostics.is_empty():
		var diagnostic: Dictionary = diagnostics[0]
		_check(int(diagnostic.get("line", 0)) == 1, "Diagnóstico Python-like deve preservar a linha.")
		_check(str(diagnostic.get("script_id", "")) == "python_diagnostic", "Manager deve associar diagnóstico ao script.")

	runtime_id = manager.start_script(
		"c_diagnostic", "int main(){ @ }", "CDiagnostic", null, "c_like"
	)
	await _wait_until_not_running(manager, "c_diagnostic")
	runtime = manager.get_runtime(runtime_id)
	diagnostics = runtime.get("diagnostics", [])
	_check(not diagnostics.is_empty(), "Erro C-like deve chegar como diagnóstico estruturado.")
	if not diagnostics.is_empty():
		var diagnostic: Dictionary = diagnostics[0]
		_check(str(diagnostic.get("category", "")) == "lexical", "Erro léxico C-like deve manter categoria.")
		_check(str(diagnostic.get("code", "")) == "C_LEX_INVALID_CHARACTER", "Erro léxico C-like deve manter código estável.")
		_check(int(diagnostic.get("line", 0)) > 0, "Erro léxico C-like deve preservar linha válida.")


func _test_python_like_per_script_budget(manager) -> void:
	var previous_per_script: int = manager.operations_per_frame_per_script
	var previous_global: int = manager.global_operations_per_frame
	manager.operations_per_frame_per_script = 7
	manager.global_operations_per_frame = 100
	manager.start_script(
		"python_budget", "x = 0\nfor i in range(10000):\n    x = x + 1\n",
		"PythonBudget", null, "python_like"
	)
	manager._process(0.0)
	var runtime: Dictionary = manager.get_runtime_by_script_id("python_budget")
	_check(str(runtime.get("status", "")) == ScriptRuntimeManager.STATUS_RUNNING, "Loop Python-like grande não deve terminar em uma chamada do manager.")
	_check(int(runtime.get("operations_last_frame", 0)) == 7, "Python-like deve respeitar o budget por script configurado.")
	manager.stop_script("python_budget")
	manager.operations_per_frame_per_script = previous_per_script
	manager.global_operations_per_frame = previous_global


func _test_python_like_global_budget(manager) -> void:
	var previous_per_script: int = manager.operations_per_frame_per_script
	var previous_global: int = manager.global_operations_per_frame
	manager.operations_per_frame_per_script = 20
	manager.global_operations_per_frame = 25
	var source := "x = 0\nfor i in range(10000):\n    x = x + 1\n"
	manager.start_script("python_global_a", source, "PythonGlobalA", null, "python_like")
	manager.start_script("python_global_b", source, "PythonGlobalB", null, "python_like")
	manager._process(0.0)
	var first: Dictionary = manager.get_runtime_by_script_id("python_global_a")
	var second: Dictionary = manager.get_runtime_by_script_id("python_global_b")
	var consumed := int(first.get("operations_last_frame", 0)) + int(second.get("operations_last_frame", 0))
	_check(consumed == 25, "Dois runtimes Python-like devem compartilhar o budget global do manager.")
	_check(str(first.get("status", "")) == ScriptRuntimeManager.STATUS_RUNNING and str(second.get("status", "")) == ScriptRuntimeManager.STATUS_RUNNING, "Runtimes Python-like devem permanecer independentes ao esgotar o budget global.")
	manager.stop_script("python_global_a")
	manager.stop_script("python_global_b")
	manager.operations_per_frame_per_script = previous_per_script
	manager.global_operations_per_frame = previous_global


func _test_python_like_lifecycle_and_isolation(manager) -> void:
	manager.start_script("python_a", "x = 1\nprint(x)\n", "PythonA", null, "python_like")
	manager.start_script("python_b", "x = 2\nprint(x)\n", "PythonB", null, "python_like")
	await _wait_until_not_running(manager, "python_a")
	await _wait_until_not_running(manager, "python_b")
	var first: Dictionary = manager.get_runtime_by_script_id("python_a")
	var second: Dictionary = manager.get_runtime_by_script_id("python_b")
	_check(str(first.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED and str(second.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED, "Dois scripts Python-like devem concluir separadamente.")
	_check(str(first.get("output", "")).contains("[PythonA] 1") and not str(first.get("output", "")).contains("PythonB"), "Output do primeiro Python-like não deve misturar a outra aba.")
	_check(str(second.get("output", "")).contains("[PythonB] 2") and not str(second.get("output", "")).contains("PythonA"), "Output do segundo Python-like não deve misturar a outra aba.")

	manager.start_script("python_error", "print(nome_inexistente)\n", "PythonError", null, "python_like")
	await _wait_until_not_running(manager, "python_error")
	var failed: Dictionary = manager.get_runtime_by_script_id("python_error")
	_check(str(failed.get("status", "")) == ScriptRuntimeManager.STATUS_ERROR, "Erro Python-like deve transicionar RUNNING para ERROR.")
	_check(str(failed.get("error", "")).contains("NAME_") and str(failed.get("error", "")).contains("linha 1"), "Erro Python-like deve preservar código e posição no terminal.")
	var operations_after_error := int(failed.get("operations_total", 0))
	manager._process(0.0)
	_check(int(failed.get("operations_total", 0)) == operations_after_error, "Runtime Python-like com erro não deve continuar consumindo budget.")

	manager.start_script("python_stop", "while True:\n    x = 1\n", "PythonStop", null, "python_like")
	manager._process(0.0)
	manager.stop_script("python_stop")
	var stopped: Dictionary = manager.get_runtime_by_script_id("python_stop")
	_check(str(stopped.get("status", "")) == ScriptRuntimeManager.STATUS_STOPPED, "Stop externo deve encerrar apenas o Python-like selecionado.")
	var operations_after_stop := int(stopped.get("operations_total", 0))
	manager._process(0.0)
	_check(int(stopped.get("operations_total", 0)) == operations_after_stop, "Python-like parado não deve continuar executando frames.")


func _test_python_like_real_builtins(manager) -> void:
	_reset_stock()
	GameManager.money = 100
	SensorSystem.set_sensor("python_sensor", 42)
	manager.start_script("python_stock", """
print(sensor("python_sensor"))
print(get_stock()[0])
buy_stock([1, 0, 0, 0, 0, 0])
print(get_stock()[0])
""", "PythonStock", null, "python_like")
	await _wait_until_not_running(manager, "python_stock")
	var stock_runtime: Dictionary = manager.get_runtime_by_script_id("python_stock")
	_check(str(stock_runtime.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED, "Built-ins reais de sensor e estoque devem concluir no Python-like.")
	_check(str(stock_runtime.get("output", "")).contains("[PythonStock] 42") and str(stock_runtime.get("output", "")).contains("[PythonStock] 1"), "sensor/get_stock devem retornar valores reais ao Python-like.")
	_check(StockSystem.get_stock()[0].quantity == 1 and GameManager.money == 97, "buy_stock Python-like deve aplicar estoque e dinheiro pelas regras reais.")

	_last_client_result = false
	_start_fake_transaction([5], [5])
	manager.start_script("python_transaction", "valor = input()\nprint(valor)\nsend(valor)\n", "PythonTransaction", null, "python_like")
	await _wait_until_not_running(manager, "python_transaction")
	var transaction_runtime: Dictionary = manager.get_runtime_by_script_id("python_transaction")
	_check(str(transaction_runtime.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED, "input/send reais devem concluir no Python-like.")
	_check(_last_client_result, "send Python-like deve chegar ao TransactionManager com a resposta esperada.")
	_check(str(transaction_runtime.get("output", "")).contains("[PythonTransaction] 5"), "Valor de input convertido deve chegar ao print Python-like.")


func _test_python_like_wait_lifecycle(manager) -> void:
	manager.set_process(false)
	manager.start_script("python_wait", """
x = 1
print("antes")
wait(0.05)
x = 2
print("depois")
resultado = wait(0)
print(resultado)
""", "PythonWait", null, "python_like")
	manager._process(0.0)
	var sleeping: Dictionary = manager.get_runtime_by_script_id("python_wait")
	_check(str(sleeping.get("status", "")) == ScriptRuntimeManager.STATUS_SLEEPING,
		"wait deve mover o runtime Python-like para SLEEPING.")
	_check(str(sleeping.get("output", "")).contains("[PythonWait] antes")
		and not str(sleeping.get("output", "")).contains("depois"),
		"Output após wait não pode aparecer antes da retomada.")
	var operations_before := int(sleeping.get("operations_total", 0))
	manager._process(0.0)
	_check(int(sleeping.get("operations_total", 0)) == operations_before,
		"Runtime dormindo não deve consumir budget por script ou global.")
	await get_tree().create_timer(0.07).timeout
	manager._process(0.0)
	_check(str(sleeping.get("status", "")) == ScriptRuntimeManager.STATUS_SLEEPING
		and str(sleeping.get("output", "")).contains("[PythonWait] depois"),
		"Após o prazo, execução deve avançar até o wait(0), que cede um ciclo.")
	manager._process(0.0)
	_check(str(sleeping.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED
		and str(sleeping.get("output", "")).contains("[PythonWait] None"),
		"wait(0) deve retomar no ciclo seguinte e retornar None.")
	manager.set_process(true)


func _test_python_like_wait_functions_and_loops(manager) -> void:
	manager.set_process(false)
	manager.start_script("python_wait_frames", """
def f():
    local = 7
    wait(0)
    local = local + 3
    return local

resultado = f()
x = 0
for i in range(3):
    wait(0)
    x = x + 1
print(resultado)
print(x)
""", "PythonWaitFrames", null, "python_like")
	var sleeps := 0
	var guard := 0
	while manager.is_script_running("python_wait_frames") and guard < 12:
		manager._process(0.0)
		var runtime: Dictionary = manager.get_runtime_by_script_id("python_wait_frames")
		if str(runtime.get("status", "")) == ScriptRuntimeManager.STATUS_SLEEPING:
			sleeps += 1
		guard += 1
	var finished: Dictionary = manager.get_runtime_by_script_id("python_wait_frames")
	_check(str(finished.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED
		and sleeps == 4,
		"Função e loop devem preservar frames durante quatro suspensões independentes.")
	_check(str(finished.get("output", "")).contains("[PythonWaitFrames] 10")
		and str(finished.get("output", "")).contains("[PythonWaitFrames] 3"),
		"Ambiente local e ForFrame devem manter seus valores após wait.")
	manager.set_process(true)


func _test_python_like_wait_stop_and_isolation(manager) -> void:
	manager.set_process(false)
	manager.start_script(
		"python_wait_a", "print('A1')\nwait(0.02)\nprint('A2')\n",
		"PythonWaitA", null, "python_like"
	)
	manager.start_script(
		"python_wait_b", "print('B1')\nwait(0.08)\nprint('B2')\n",
		"PythonWaitB", null, "python_like"
	)
	manager._process(0.0)
	var first: Dictionary = manager.get_runtime_by_script_id("python_wait_a")
	var second: Dictionary = manager.get_runtime_by_script_id("python_wait_b")
	_check(str(first.get("status", "")) == ScriptRuntimeManager.STATUS_SLEEPING
		and str(second.get("status", "")) == ScriptRuntimeManager.STATUS_SLEEPING,
		"Dois scripts devem dormir com lifecycle independente.")

	var previous_per_script: int = manager.operations_per_frame_per_script
	var previous_global: int = manager.global_operations_per_frame
	manager.operations_per_frame_per_script = 9
	manager.global_operations_per_frame = 9
	manager.start_script(
		"python_wait_budget", "while True:\n    x = 1\n",
		"PythonWaitBudget", null, "python_like"
	)
	manager._process(0.0)
	var budget_runtime: Dictionary = manager.get_runtime_by_script_id("python_wait_budget")
	_check(int(budget_runtime.get("operations_last_frame", 0)) == 9,
		"Scripts dormindo não devem reduzir o budget global disponível a outro runtime.")
	manager.stop_script("python_wait_budget")
	manager.operations_per_frame_per_script = previous_per_script
	manager.global_operations_per_frame = previous_global

	await get_tree().create_timer(0.04).timeout
	manager._process(0.0)
	_check(str(first.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED
		and str(second.get("status", "")) == ScriptRuntimeManager.STATUS_SLEEPING,
		"Acordar o primeiro wait não pode acordar o segundo.")
	await get_tree().create_timer(0.06).timeout
	manager._process(0.0)
	_check(str(second.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED,
		"Segundo runtime deve retomar apenas após seu próprio prazo.")
	_check(str(first.get("output", "")).contains("A1")
		and str(first.get("output", "")).contains("A2")
		and not str(first.get("output", "")).contains("B2")
		and str(second.get("output", "")).contains("B1")
		and str(second.get("output", "")).contains("B2")
		and not str(second.get("output", "")).contains("A2"),
		"Outputs não devem se misturar entre waits concorrentes.")

	manager.start_script(
		"python_wait_stop", "print('antes')\nwait(0.03)\nprint('depois')\n",
		"PythonWaitStop", null, "python_like"
	)
	manager._process(0.0)
	var stopped: Dictionary = manager.get_runtime_by_script_id("python_wait_stop")
	var operations_before_stop := int(stopped.get("operations_total", 0))
	manager.stop_script("python_wait_stop")
	await get_tree().create_timer(0.05).timeout
	manager._process(0.0)
	_check(str(stopped.get("status", "")) == ScriptRuntimeManager.STATUS_STOPPED
		and int(stopped.get("operations_total", 0)) == operations_before_stop
		and not str(stopped.get("output", "")).contains("depois"),
		"Stop durante wait deve invalidar retomada e impedir chamadas posteriores.")
	manager.set_process(true)


func _test_python_like_delivery_boundary() -> void:
	DeliverySystem.unlock(false)
	var delivery_script_id := InterpreterSystem.ensure_delivery_script()
	_check(DeliverySystem.debug_set_report([1, 2, 3]), "Teste deve preparar relatório real para o Python-like.")
	var runtime_id: String = InterpreterSystem.runtime_manager.start_script(
		delivery_script_id,
		"relatorio = get_deliveries()\nprint(relatorio)\n",
		"DeliveryPython", null, "python_like"
	)
	await _wait_until_not_running(InterpreterSystem.runtime_manager, delivery_script_id)
	var runtime: Dictionary = InterpreterSystem.runtime_manager.get_runtime(runtime_id)
	_check(str(runtime.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED, "get_deliveries deve funcionar com contexto real do runtime Python-like.")
	_check(str(runtime.get("output", "")).contains("[1, 2, 3]"), "Relatório real deve atravessar a conversão para lista Python-like.")

	_check(DeliverySystem.debug_set_report([1, 2, 3]), "Teste deve preparar novo relatório para validar a fronteira pedagógica.")
	runtime_id = InterpreterSystem.runtime_manager.start_script(
		delivery_script_id,
		"get_deliveries()\ndeclare_profit([2, 12, 49])\n",
		"DeliveryPython", null, "python_like"
	)
	await _wait_until_not_running(InterpreterSystem.runtime_manager, delivery_script_id)
	runtime = InterpreterSystem.runtime_manager.get_runtime(runtime_id)
	_check(str(runtime.get("status", "")) == ScriptRuntimeManager.STATUS_FINISHED,
		"Rejeição pedagógica de declare_profit Python-like não deve virar erro do interpretador.")
	_check(str(runtime.get("output", "")).contains("função criada por você"),
		"declare_profit Python-like deve usar os fatos neutros e manter o feedback pedagógico.")


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
	manager.start_script(
		"locked_python_wait", "wait(0.1)\n", "WaitPythonBloqueado", null, "python_like"
	)
	await _wait_until_not_running(manager, "locked_python_wait")
	var runtime: Dictionary = manager.get_runtime_by_script_id("locked_python_wait")
	_check(str(runtime.get("status", "")) == ScriptRuntimeManager.STATUS_ERROR
		and str(runtime.get("error", "")).contains("AUTOMARKET_FEATURE_LOCKED"),
		"wait Python-like deve preservar o bloqueio de progressão do runtime atual.")


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
