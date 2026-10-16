extends RefCounted

# Rows/columns are matrix coordinates. Only street segments change between jobs.
const DIRECTIONS := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]

static func generate(seed_value: int, intersections := 5, min_distance := 4,
		min_moves := 6, min_dead_ends := 0, max_attempts := 32,
		excluded: Array = [], previous_destination: Array = []) -> Dictionary:
	var side := clampi(intersections, 2, 15)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var best := {}
	for _attempt in range(clampi(max_attempts, 1, 128)):
		var matrix: Array = []
		for row in range(side * 2 - 1):
			var cells: Array = []
			for col in range(side * 2 - 1):
				cells.append(0 if row % 2 == 1 and col % 2 == 1 else (1 if row % 2 == 0 and col % 2 == 0 else 2))
			matrix.append(cells)
		var stack := [Vector2i.ZERO]
		var visited := {Vector2i.ZERO: true}
		var distances := {Vector2i.ZERO: 0}
		var degrees := {}
		while not stack.is_empty():
			var current: Vector2i = stack.back()
			var choices := []
			for direction in DIRECTIONS:
				var neighbor: Vector2i = current + direction
				if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < side and neighbor.y < side and not visited.has(neighbor):
					choices.append(neighbor)
			if choices.is_empty():
				stack.pop_back()
				continue
			var next: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
			visited[next] = true
			distances[next] = int(distances[current]) + 2
			degrees[current] = int(degrees.get(current, 0)) + 1
			degrees[next] = int(degrees.get(next, 0)) + 1
			matrix[current.x + next.x][current.y + next.y] = 1
			stack.append(next)
		var candidates := []
		var farthest := Vector2i.ZERO
		var dead_ends := 0
		for vertex in visited:
			if int(degrees.get(vertex, 0)) == 1:
				dead_ends += 1
			if int(distances[vertex]) > int(distances[farthest]):
				farthest = vertex
			if vertex != Vector2i.ZERO and (vertex.x + vertex.y) * 2 >= min_distance and int(distances[vertex]) >= min_moves:
				if [vertex.x * 2, vertex.y * 2] != previous_destination:
					candidates.append(vertex)
		var destination: Vector2i = farthest if candidates.is_empty() else candidates[rng.randi_range(0, candidates.size() - 1)]
		var fingerprint := str(matrix)
		best = {"matrix": matrix, "origin": [0, 0], "destination": [destination.x * 2, destination.y * 2],
			"fingerprint": fingerprint, "dead_ends": dead_ends, "route_moves": int(distances[destination]), "intersections": side}
		if not candidates.is_empty() and dead_ends >= min_dead_ends and not excluded.has(fingerprint):
			best["constraints_met"] = true
			return best
	# Impossible tuning never returns a disconnected map. Surface relaxed constraints.
	best["constraints_met"] = false
	return best
