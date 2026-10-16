extends Node

const Generator = preload("res://systems/DeliveryMapGenerator.gd")
const Validator = preload("res://systems/DeliveryRouteValidator.gd")
const Bridge = preload("res://interpreter/runtime/godot_automarket_python_bridge.gd")
const PanelScene = preload("res://scenes/delivery/delivery_panel.tscn")
var failures: Array[String] = []
var paid := 0
var max_operations := 0

func _ready() -> void:
	DeliverySystem.set_process(false)
	EventBus.update_money.connect(func(amount): paid += amount)
	_test_generator()
	_test_validator()
	_test_unlock_and_snapshots()
	_test_arrival_and_save()
	await _test_malformed_runtime_routes()
	await _test_interpreter()
	await _test_ui()
	InterpreterSystem.runtime_manager.stop_all()
	await get_tree().process_frame
	if failures.is_empty():
		print("DELIVERY_SYSTEM_TEST_OK: 500 seeds + sizes 2/3/7, routes, persistence, 8 real Python BFS jobs, budget <= %d" % max_operations)
	else:
		for message in failures:
			push_error(message)
	get_tree().quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

# Independent flood/edge accounting on the matrix, not DFS generator metadata.
func explore(matrix: Array, origin: Array, forbidden: Array = []) -> Dictionary:
	var parents := {Vector2i(origin[0], origin[1]): Vector2i(-1, -1)}
	var queue := [Vector2i(origin[0], origin[1])]
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		for delta in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + delta
			if forbidden == [cell, next] or forbidden == [next, cell]:
				continue
			if next.x >= 0 and next.y >= 0 and next.x < matrix.size() and next.y < matrix.size() and matrix[next.x][next.y] == 1 and not parents.has(next):
				parents[next] = cell
				queue.append(next)
	return parents

func solve(map: Dictionary) -> Array:
	var parents := explore(map.matrix, map.origin)
	var cell := Vector2i(map.destination[0], map.destination[1])
	var route := []
	while cell != Vector2i(-1, -1):
		route.push_front([cell.x, cell.y])
		cell = parents[cell]
	return route

func _test_generator() -> void:
	var history := []
	var previous := []
	for seed_value in range(500):
		var map := Generator.generate(seed_value, 5, 4, 6, 0, 32, history, previous)
		verify_map(map, 5)
		check(bool(map.constraints_met), "Default constraints seed %d" % seed_value)
		check(not history.has(map.fingerprint), "Repeated configuration seed %d" % seed_value)
		check(map.destination != previous, "Repeated destination seed %d" % seed_value)
		var route := solve(map)
		check(route.size() >= 7, "Minimum route seed %d" % seed_value)
		check(Validator.validate(route, map.matrix, map.origin, map.destination).is_empty(), "Valid generated route")
		# Removing any edge of the route must disconnect the target: independent uniqueness check.
		for index in range(route.size() - 1):
			var a := Vector2i(route[index][0], route[index][1])
			var b := Vector2i(route[index + 1][0], route[index + 1][1])
			check(not explore(map.matrix, map.origin, [a, b]).has(Vector2i(map.destination[0], map.destination[1])), "Alternative route exists")
		history.append(map.fingerprint)
		previous = map.destination
	for size_value in [2, 3, 7]:
		for seed_value in range(10):
			verify_map(Generator.generate(seed_value, size_value), size_value)
	var constrained := Generator.generate(12, 5, 0, 0, 999, 1)
	check(not constrained.constraints_met, "Impossible constraints reported")
	verify_map(constrained, 5)

func verify_map(map: Dictionary, intersections: int) -> void:
	var matrix: Array = map.matrix
	check(matrix.size() == intersections * 2 - 1, "Configurable dimensions")
	var edges := 0
	var walkable := 0
	for row in range(matrix.size()):
		check(matrix[row].size() == matrix.size(), "Square matrix")
		for col in range(matrix.size()):
			if matrix[row][col] == 1:
				walkable += 1
			if row % 2 == 0 and col % 2 == 0:
				check(matrix[row][col] == 1, "Intersection removed")
			elif row % 2 == 1 and col % 2 == 1:
				check(matrix[row][col] == 0, "Block must stay terrain")
			else:
				check(matrix[row][col] in [1, 2], "Street segment encoding")
				if matrix[row][col] == 1:
					edges += 1
	check(edges == intersections * intersections - 1, "Tree edge count")
	check(explore(matrix, [0, 0]).size() == walkable, "Disconnected streets")

func _test_validator() -> void:
	var matrix := [[1, 1, 1], [2, 0, 1], [1, 1, 1]]
	var origin := [0, 0]
	var destination := [2, 2]
	var valid := [[0, 0], [0, 1], [0, 2], [1, 2], [2, 2]]
	check(Validator.validate(valid, matrix, origin, destination) == "", "Correct route")
	for route in [null, 1, {}, [], [[0, 0]], [[0, 1], [0, 2], [1, 2], [2, 2]],
		[[0, 0], [0, 1], [1, 2], [2, 2]], [[0, 0], [1, 0], [2, 0], [2, 1], [2, 2]],
		[[0, 0], [0, 1], [1, 1], [1, 2], [2, 2]], [[0, 0], [0, 2], [1, 2], [2, 2]],
		[[0, 0], [0, 1], [0, 0], [0, 1], [0, 2], [1, 2], [2, 2]],
		[[0, 0], [9, 0]], [[0, 0], [-1, 0]], [[0, 0], [0.0, 1]], [[0, 0], [true, 1]],
		[[0, 0], [0]], [[0, 0], "x"], [[0, 0], ["0", 1]]]:
		check(not Validator.validate(route, matrix, origin, destination).is_empty(), "Malformed route accepted: %s" % str(route))

func _test_unlock_and_snapshots() -> void:
	FeatureManager.reset_progression()
	DeliverySystem.load_save_data({})
	check(DeliverySystem.current_delivery() == null, "Locked delivery")
	check(not DeliverySystem.submit_route([], 1).success, "Locked submission")
	UpgradeManager.load_save_data({"comprados": {}})
	GameManager.money = 2000
	check(not UpgradeManager.can_buy("delivery_online"), "Delivery must follow promotions")
	UpgradeManager.comprar_upgrade("gameplay_change")
	UpgradeManager.comprar_upgrade("gameplay_promotions")
	check(UpgradeManager.can_buy("delivery_online"), "Delivery unlocked after promotions")
	UpgradeManager.comprar_upgrade("delivery_online")
	check(DeliverySystem.is_unlocked(), "Purchase enables delivery")
	var id := DeliverySystem.active_report_id
	var bridge := Bridge.new()
	bridge.delivery_current({})
	bridge.delivery_map({})
	var copy := DeliverySystem.current_matrix()
	copy[0][0] = 0
	check(DeliverySystem.current_matrix()[0][0] == 1, "Matrix copy isolation")
	var info: Dictionary = DeliverySystem.current_delivery()
	info.origem[0] = 8
	check(DeliverySystem.current_delivery().origem == [0, 0], "Delivery copy isolation")
	var before := DeliverySystem.get_view_data()
	DeliverySystem._generate_report(false, false)
	check(DeliverySystem.active_report_id == id, "Pending map cannot regenerate")
	check(not DeliverySystem.submit_route([], id).success, "Invalid route rejected")
	check(DeliverySystem.get_view_data().driver == before.driver, "Invalid route cannot move")
	var route := solve(before.map)
	check(not DeliverySystem.submit_route(route, id - 1).success, "Stale id rejected")
	check(DeliverySystem.submit_route(route, id).success, "Correct route accepted")
	route[0][0] = 100
	check(DeliverySystem.get_view_data().route[0] == [0, 0], "Route copy isolation")
	check(not DeliverySystem.submit_route([], id).success, "In-flight route rejected")
	DeliverySystem.advance_driver(100.0)
	DeliverySystem._process(16.0)
	check(bridge.delivery_route(solve(DeliverySystem.get_view_data().map), {}).value == false, "Bridge rejects stale snapshot")
	bridge.delivery_current({})
	check(bridge.delivery_route(solve(DeliverySystem.get_view_data().map), {}).value == false, "Both snapshots required for same id")

func _test_arrival_and_save() -> void:
	var data := DeliverySystem.get_save_data()
	var normalized := Saves._validar_delivery(data)
	DeliverySystem.load_save_data(JSON.parse_string(JSON.stringify(normalized)))
	check(DeliverySystem.current_delivery() != null, "Pending map survives JSON save")
	var route := solve(DeliverySystem.get_view_data().map)
	var id := DeliverySystem.active_report_id
	var before := paid
	check(DeliverySystem.submit_route(route, id).success, "Saved route accepted")
	check(paid == before, "No payment on submission")
	DeliverySystem.advance_driver(0.1)
	check(paid == before, "No payment during animation")
	var moving := DeliverySystem.get_save_data()
	DeliverySystem.load_save_data(JSON.parse_string(JSON.stringify(moving)))
	check(DeliverySystem.state == DeliverySystem.State.WAITING_DECLARATION, "Interrupted trip retries same map")
	check(DeliverySystem.submit_route(route, id).success, "Interrupted route accepted")
	DeliverySystem.advance_driver(100.0)
	check(paid == before + DeliveryConfig.REWARD, "Reward exactly on arrival")
	DeliverySystem.advance_driver(100.0)
	check(paid == before + DeliveryConfig.REWARD, "No duplicate arrival reward")
	check(not DeliverySystem.submit_route(route, id).success, "No route without pending job")
	var cooled := DeliverySystem.get_save_data()
	DeliverySystem.load_save_data(JSON.parse_string(JSON.stringify(cooled)))
	check(DeliverySystem.state == DeliverySystem.State.COOLDOWN, "Cooldown persisted")
	DeliverySystem._process(14.0)
	check(DeliverySystem.current_delivery() == null, "15-second cooldown respected")
	DeliverySystem._process(1.1)
	check(DeliverySystem.current_delivery() != null, "Next job after cooldown")
	var corrupted := DeliverySystem.get_save_data()
	corrupted.map.matrix[1][1] = 1
	DeliverySystem.load_save_data(corrupted)
	check(DeliverySystem.state == DeliverySystem.State.LOCKED, "Malformed saved topology rejected safely")
	DeliverySystem._process(0)

func _test_interpreter() -> void:
	var initial := DeliverySystem.completed_deliveries
	var script_id := InterpreterSystem.ensure_delivery_script()
	var source := FileAccess.get_file_as_string("res://docs/examples/delivery_bfs.py")
	var manager := InterpreterSystem.runtime_manager
	var runtime_id := manager.start_script(script_id, source, "Delivery BFS", null, "python_like")
	var runtime := manager.get_runtime(runtime_id)
	var guard := 0
	while DeliverySystem.completed_deliveries < initial + 8 and guard < 6000:
		guard += 1
		await get_tree().process_frame
		max_operations = maxi(max_operations, int(runtime.operations_last_frame))
		check(int(runtime.operations_last_frame) <= manager.operations_per_frame_per_script, "Incremental budget exceeded")
		if runtime.status == ScriptRuntimeManager.STATUS_ERROR:
			check(false, "Python BFS: " + str(runtime.output))
			break
		if DeliverySystem.state == DeliverySystem.State.MOVING:
			DeliverySystem.advance_driver(100.0)
		elif DeliverySystem.state == DeliverySystem.State.COOLDOWN:
			DeliverySystem._process(16.0)
		if runtime.status == ScriptRuntimeManager.STATUS_SLEEPING:
			# Advance the scheduler clock in the test instead of sleeping wall time.
			runtime.wake_time_msec = 0
	check(DeliverySystem.completed_deliveries == initial + 8, "Continuous BFS completes 8 distinct jobs")
	check(bool(ChallengeSystem.integrated_progress.delivery_completed), "Three jobs complete challenge")
	check(int(runtime.operations_total) > 200, "Search spans scheduler frames")
	print("DELIVERY_BFS_OPERATIONS ", runtime.operations_total, " frames ", guard)
	manager.stop_all()
	DeliverySystem._process(16.0)
	var dfs_source := FileAccess.get_file_as_string("res://docs/examples/delivery_dfs.py")
	var definition := dfs_source.substr(0, dfs_source.find("while True:"))
	var once := definition + "entrega = entrega_atual()\nif entrega:\n    enviar_rota(buscar(mapa_entrega(), entrega))\n"
	runtime_id = manager.start_script(script_id, once, "Delivery DFS", null, "python_like")
	runtime = manager.get_runtime(runtime_id)
	guard = 0
	while manager.is_script_running(script_id) and guard < 1000:
		guard += 1
		await get_tree().process_frame
	check(runtime.status == ScriptRuntimeManager.STATUS_FINISHED and DeliverySystem.state == DeliverySystem.State.MOVING, "Iterative DFS solves a real job")
	DeliverySystem.advance_driver(100.0)
	manager.stop_all()

func _test_ui() -> void:
	var panel := PanelScene.instantiate()
	add_child(panel)
	panel.open_panel()
	await get_tree().process_frame
	check(panel.visible and panel.map_renderer.size.y > 0, "Map visible")
	for viewport_size in [Vector2i(640, 480), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = viewport_size
		await get_tree().process_frame
		panel._fit_panel()
		check(panel.frame.size.x <= panel.get_viewport_rect().size.x and panel.frame.size.y <= panel.get_viewport_rect().size.y, "Responsive map window: %s viewport %s" % [panel.frame.size, panel.get_viewport_rect().size])
	panel.queue_free()


func _test_malformed_runtime_routes() -> void:
	var manager := InterpreterSystem.runtime_manager
	var script_id := InterpreterSystem.ensure_delivery_script()
	var id := DeliverySystem.active_report_id
	var runtime_id := manager.start_script(script_id, """entrega_atual()
mapa_entrega()
print(enviar_rota(1))
print(enviar_rota([[0.0, 0]]))
ciclo = [None, None]
ciclo[0] = ciclo
print(enviar_rota([ciclo]))
print("entradas verificadas")
""", "Entradas Delivery", null, "python_like")
	var guard := 0
	while manager.is_script_running(script_id) and guard < 100:
		guard += 1
		await get_tree().process_frame
	var runtime := manager.get_runtime(runtime_id)
	check(runtime.status == ScriptRuntimeManager.STATUS_FINISHED and str(runtime.output).contains("entradas verificadas"), "Malformed/cyclic routes do not crash runtime")
	check(DeliverySystem.active_report_id == id and DeliverySystem.state == DeliverySystem.State.WAITING_DECLARATION, "Malformed routes preserve pending map")
