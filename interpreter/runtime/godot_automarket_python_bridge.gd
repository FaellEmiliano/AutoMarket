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
	return BridgeContract.Response.succeeded(StockSystem.get_stock_snapshot().duplicate(true))

func product_table(_context: Dictionary) -> Response:
	return BridgeContract.Response.succeeded(StockSystem.get_product_table().duplicate(true))

func promotions(_context: Dictionary) -> Response:
	var challenge = TransactionManager.active_challenge
	if challenge == null or not FeatureManager.has_feature(FeatureManager.FEATURE_DISCOUNT):
		return BridgeContract.Response.succeeded([])
	return BridgeContract.Response.succeeded(challenge.promotions.duplicate(true))

func get_budget(_context: Dictionary) -> Response:
	return BridgeContract.Response.succeeded(StockSystem.get_budget())

func buy_stock(purchase: Dictionary, _context: Dictionary) -> Response:
	var result := StockSystem.try_buy_stock_from_script(purchase.duplicate(true))
	var output: Array[String] = []
	if not bool(result.get("ok", false)):
		output.append(str(result.get("mensagem", "Compra cancelada.")))
	return BridgeContract.Response.succeeded(result.duplicate(true), output)


func get_deliveries(_context: Dictionary) -> Response:
	return BridgeContract.Response.failed("AUTOMARKET_DELIVERY_RETIRED", "Use entrega_atual(), mapa_entrega() e enviar_rota(rota).")

func declare_profit(_profits: Array, _context: Dictionary) -> Response:
	return BridgeContract.Response.failed("AUTOMARKET_DELIVERY_RETIRED", "declare_profit() foi aposentada. Use enviar_rota(rota).")

# Each runtime holds the id of the snapshot it actually read. Reading a matrix
# cannot silently rebind an old destination to a newly generated job.
var _navigation_id := 0
var _map_id := 0

func delivery_current(_context: Dictionary) -> Response:
	var delivery: Variant = DeliverySystem.current_delivery()
	_navigation_id = int(delivery.id) if delivery is Dictionary else 0
	return BridgeContract.Response.succeeded(delivery)

func delivery_map(_context: Dictionary) -> Response:
	var delivery: Variant = DeliverySystem.current_delivery()
	_map_id = int(delivery.id) if delivery is Dictionary else 0
	return BridgeContract.Response.succeeded(DeliverySystem.current_matrix())

func delivery_route(route: Variant, _context: Dictionary) -> Response:
	var snapshot_id := _navigation_id if _navigation_id == _map_id else 0
	var result := DeliverySystem.submit_route(route, snapshot_id)
	return BridgeContract.Response.succeeded(bool(result.success), [str(result.message)])


func wait(seconds: float, _context: Dictionary) -> Response:
	if not FeatureManager.has_feature(FeatureManager.FEATURE_STOCK):
		return BridgeContract.Response.failed(
			"AUTOMARKET_FEATURE_LOCKED",
			"Você ainda não liberou wait(). Compre o upgrade Abrir estoque.",
			"gameplay", {"feature": FeatureManager.FEATURE_STOCK, "operation": "wait"}
		)
	return BridgeContract.Response.suspended(seconds)
