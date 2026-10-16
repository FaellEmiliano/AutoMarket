extends RefCounted

static func validate(route: Variant, matrix: Array, origin: Array, destination: Array) -> String:
	if not route is Array:
		return "A rota precisa ser uma lista de coordenadas [linha, coluna]."
	if route.is_empty():
		return "A rota está vazia. Inclua a origem e o destino."
	if matrix.is_empty() or route.size() > matrix.size() * matrix.size():
		return "A rota tem coordenadas demais para este bairro."
	var seen := {}
	var previous: Array = []
	for coordinate in route:
		if not coordinate is Array or coordinate.size() != 2:
			return "Coordenada inválida: use [linha, coluna]."
		if not coordinate[0] is int or not coordinate[1] is int:
			return "As coordenadas precisam conter dois inteiros."
		var row: int = coordinate[0]
		var col: int = coordinate[1]
		if row < 0 or row >= matrix.size() or col < 0 or col >= matrix[row].size():
			return "Coordenada fora da matriz."
		if matrix[row][col] == 2:
			return "A rota atravessa uma rua bloqueada."
		if matrix[row][col] != 1:
			return "A rota atravessa um quarteirão. Use somente ruas."
		var key := Vector2i(row, col)
		if seen.has(key):
			return "A rota repete uma posição. Envie um caminho simples."
		seen[key] = true
		if not previous.is_empty() and absi(row - int(previous[0])) + absi(col - int(previous[1])) != 1:
			return "Movimento inválido: avance uma célula na horizontal ou vertical, sem diagonais."
		previous = coordinate
	if route[0] != origin:
		return "A rota não começa na origem."
	if route.back() != destination:
		return "A rota não chega ao destino."
	return ""
