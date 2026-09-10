extends "res://interpreter/python_like/runtime/python_like_automarket_bridge.gd"
class_name GodotAutoMarketPythonBridge


const BridgeContract = preload("res://interpreter/python_like/runtime/python_like_automarket_bridge.gd")

var _delivery_report_id: int = 0
var _program_facts = null
var _runtime_recursion_provider := Callable()


func configure_program_facts(program_facts, recursion_provider: Callable) -> void:
	_program_facts = program_facts
	_runtime_recursion_provider = recursion_provider
	_delivery_report_id = 0


func read_input(_context: Dictionary) -> Response:
	return BridgeContract.Response.succeeded(TransactionManager.next_input())


func send(values: Array, _context: Dictionary) -> Response:
	var detached_values := values.duplicate(true)
	EventBus.emit_signal("send_output", detached_values.duplicate(true))
	return BridgeContract.Response.succeeded(TransactionManager.submit(detached_values))


func read_sensor(name: String, _context: Dictionary) -> Response:
	if not FeatureManager.has_feature(FeatureManager.FEATURE_SENSOR):
		return BridgeContract.Response.failed(
			"AUTOMARKET_FEATURE_LOCKED",
			FeatureManager.locked_message(FeatureManager.FEATURE_SENSOR),
			"gameplay", {"feature": FeatureManager.FEATURE_SENSOR, "operation": "sensor"}
		)
	return BridgeContract.Response.succeeded(SensorSystem.get_sensor(name))


func get_stock(_context: Dictionary) -> Response:
	return BridgeContract.Response.succeeded(StockSystem.get_stock_snapshot().duplicate())


func buy_stock(purchase: Array, _context: Dictionary) -> Response:
	var result := StockSystem.try_buy_stock_from_script(purchase.duplicate(true))
	if not bool(result.get("success", false)):
		return BridgeContract.Response.failed(
			"AUTOMARKET_STOCK_PURCHASE_REJECTED",
			str(result.get("error", "Compra cancelada.")),
			"gameplay", {"operation": "buy_stock"}
		)
	var output: Array[String] = []
	var warning := str(result.get("warning", ""))
	if not warning.is_empty():
		output.append(warning)
	return BridgeContract.Response.succeeded(null, output)


func get_deliveries(context: Dictionary) -> Response:
	var response := DeliverySystem.request_deliveries(
		str(context.get("runtime_id", "")),
		str(context.get("script_id", ""))
	)
	if not bool(response.get("success", false)):
		return BridgeContract.Response.failed(
			"AUTOMARKET_DELIVERY_REQUEST_REJECTED",
			str(response.get("message", "Não foi possível ler o relatório do Delivery.")),
			"gameplay", {"operation": "get_deliveries"}
		)
	_delivery_report_id = int(response.get("report_id", 0))
	var deliveries: Array = response.get("deliveries", [])
	return BridgeContract.Response.succeeded(deliveries.duplicate(true))


func declare_profit(profits: Array, _context: Dictionary) -> Response:
	if profits.size() != 3:
		return BridgeContract.Response.failed(
			"AUTOMARKET_DELIVERY_INVALID_PROFITS",
			"declare_profit() espera uma lista com 3 posições.",
			"gameplay", {"operation": "declare_profit", "expected_size": 3}
		)
	for index in range(profits.size()):
		var value = profits[index]
		if not (value is int or value is float) or float(value) != float(int(value)):
			return BridgeContract.Response.failed(
				"AUTOMARKET_DELIVERY_INVALID_PROFITS",
				"O lucro na posição %d precisa ser inteiro." % index,
				"gameplay", {"operation": "declare_profit", "index": index}
			)
	if _delivery_report_id <= 0:
		return BridgeContract.Response.failed(
			"AUTOMARKET_DELIVERY_REPORT_REQUIRED",
			"Leia o relatório com get_deliveries() antes de declarar os lucros.",
			"gameplay", {"operation": "declare_profit"}
		)
	if _program_facts == null or not _runtime_recursion_provider.is_valid():
		return BridgeContract.Response.failed(
			"AUTOMARKET_PROGRAM_FACTS_UNAVAILABLE",
			"Não consegui acessar os fatos do programa desta execução.",
			"bridge", {"operation": "declare_profit"}
		)
	var recursive_functions: Array = _program_facts.valid_recursive_functions
	var runtime_recursion_ok := bool(_runtime_recursion_provider.call(
		recursive_functions
	))
	var response := DeliverySystem.submit_declaration(
		profits.duplicate(true),
		str(_context.get("runtime_id", "")),
		str(_context.get("script_id", "")),
		_delivery_report_id,
		_program_facts,
		runtime_recursion_ok
	)
	var message := str(response.get("message", "Declaração rejeitada."))
	if bool(response.get("success", false)):
		return BridgeContract.Response.succeeded(null, [message])
	if bool(response.get("fatal", false)):
		return BridgeContract.Response.failed(
			str(response.get("code", "AUTOMARKET_DELIVERY_DECLARATION_REJECTED")),
			message, "gameplay", {"operation": "declare_profit"}
		)
	var output: Array[String] = []
	if bool(response.get("emit_feedback", true)):
		output.append(message)
	return BridgeContract.Response.succeeded(null, output)


func wait(seconds: float, _context: Dictionary) -> Response:
	if not FeatureManager.has_feature(FeatureManager.FEATURE_STOCK):
		return BridgeContract.Response.failed(
			"AUTOMARKET_FEATURE_LOCKED",
			"Você ainda não liberou wait(). Compre o upgrade Abrir estoque.",
			"gameplay", {"feature": FeatureManager.FEATURE_STOCK, "operation": "wait"}
		)
	return BridgeContract.Response.suspended(seconds)
