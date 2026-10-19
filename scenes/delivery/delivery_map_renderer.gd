extends Control

# Only this rendering layer needs replacing when final sprites are ready.
const COLORS := {
	"grid": Color("252a30"),
	"road": Color("343942"), "centerline": Color.WHITE,
	"block": Color("527d49"), "barricade": Color("df7134"),
	"hole": Color("56392b"), "driver": Color("438aef"),
	"destination": Color("f6cf4b"), "route": Color("a2df79"),
	"home": Color("354f86")
}
@export_range(0.0, 4.0) var cell_gap := 1.0
@export_range(0.5, 4.0) var centerline_width := 1.5
@export_range(0.0, 12.0) var padding := 8.0
var _view: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_view(view: Dictionary) -> void:
	_view = view
	queue_redraw()

func _draw() -> void:
	var map: Dictionary = _view.get("map", {})
	var matrix: Array = map.get("matrix", [])
	if matrix.is_empty():
		return
	var side := matrix.size()
	var extent := minf(size.x, size.y) - padding * 2
	if extent <= 0:
		return
	var step := extent / float(side)
	var origin := (size - Vector2.ONE * extent) / 2.0
	# Every matrix position occupies an equally sized square, including streets.
	draw_rect(Rect2(origin, Vector2.ONE * extent), COLORS.grid)
	var gap := clampf(cell_gap, 0.0, step * 0.25)
	var dimensions := Vector2.ONE * (step - gap)
	for row in range(side):
		for col in range(side):
			var center := origin + Vector2(col + 0.5, row + 0.5) * step
			var color: Color = COLORS.road
			if row % 2 == 1 and col % 2 == 1:
				color = COLORS.block
			draw_rect(Rect2(center - dimensions / 2.0, dimensions), color)
			# One centered dash per street cell; both directions form a cross at intersections.
			var line_width := minf(centerline_width, step * 0.1)
			var half_dash := step * 0.32
			if row % 2 == 0:
				var half_horizontal := Vector2(half_dash, 0.0)
				draw_line(center - half_horizontal, center + half_horizontal, COLORS.centerline, line_width)
			if col % 2 == 0:
				var half_vertical := Vector2(0.0, half_dash)
				draw_line(center - half_vertical, center + half_vertical, COLORS.centerline, line_width)
			if matrix[row][col] == 2:
				var blockage_color: Color = COLORS.barricade if (row + col * 3) % 4 == 1 else COLORS.hole
				_draw_marker(origin, step, Vector2(row, col), blockage_color, 0.48)
	for cell in _view.get("route", []):
		var center := origin + Vector2(cell[1] + 0.5, cell[0] + 0.5) * step
		draw_rect(Rect2(center - Vector2.ONE * step * 0.09, Vector2.ONE * step * 0.18), COLORS.route)
	var destination: Array = map.get("destination", [0, 0])
	_draw_marker(origin, step, Vector2(destination[0], destination[1]), COLORS.destination, 0.62)
	_draw_marker(origin, step, Vector2.ZERO, COLORS.home, 0.62)
	_draw_marker(origin, step, _view.get("driver", Vector2.ZERO), COLORS.driver, 0.46)

func _draw_marker(origin: Vector2, step: float, coordinate: Vector2, color: Color, fraction: float) -> void:
	var center := origin + Vector2(coordinate.y + 0.5, coordinate.x + 0.5) * step
	draw_rect(Rect2(center - Vector2.ONE * step * fraction / 2.0, Vector2.ONE * step * fraction), color)
