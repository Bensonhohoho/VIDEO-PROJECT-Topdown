extends Control

@export var show_bottom_bunting := true

const PINK := Color("#ef9eb8")
const CREAM := Color("#fff4dc")
const LAVENDER := Color("#b9a7df")
const SOFT_GREEN := Color("#a8c98f")
const GOLD := Color("#efc76b")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	draw_circle(Vector2(size.x * 0.08, size.y * 0.18), size.y * 0.18, Color(PINK, 0.14))
	draw_circle(Vector2(size.x * 0.93, size.y * 0.78), size.y * 0.24, Color(LAVENDER, 0.13))
	draw_circle(Vector2(size.x * 0.88, size.y * 0.12), size.y * 0.11, Color(SOFT_GREEN, 0.13))

	_draw_bunting(48.0, size.x - 48.0, 70.0)
	if show_bottom_bunting:
		_draw_bunting(130.0, size.x - 130.0, size.y - 78.0, true)

	_draw_bow(Vector2(size.x * 0.12, size.y * 0.25), 1.15)
	_draw_bow(Vector2(size.x * 0.88, size.y * 0.25), 1.15)

	var star_positions := [
		Vector2(size.x * 0.18, size.y * 0.42),
		Vector2(size.x * 0.81, size.y * 0.40),
		Vector2(size.x * 0.10, size.y * 0.68),
		Vector2(size.x * 0.90, size.y * 0.65),
		Vector2(size.x * 0.24, size.y * 0.82),
		Vector2(size.x * 0.76, size.y * 0.84)
	]
	for index in star_positions.size():
		var color := GOLD if index % 2 == 0 else LAVENDER
		_draw_star(star_positions[index], 11.0 + float(index % 3) * 2.0, Color(color, 0.82))


func _draw_bunting(from_x: float, to_x: float, y: float, flip_vertical: bool = false) -> void:
	draw_line(Vector2(from_x, y), Vector2(to_x, y + 12.0), Color("#8d746f"), 3.0, true)
	var colors := [PINK, GOLD, LAVENDER, SOFT_GREEN, CREAM]
	var flag_count := 15
	var direction := -1.0 if flip_vertical else 1.0
	for index in flag_count:
		var ratio := float(index) / float(flag_count - 1)
		var x := lerpf(from_x + 18.0, to_x - 18.0, ratio)
		var flag_y := y + ratio * 12.0
		var points := PackedVector2Array([
			Vector2(x - 13.0, flag_y),
			Vector2(x + 13.0, flag_y),
			Vector2(x, flag_y + 28.0 * direction)
		])
		draw_colored_polygon(points, Color(colors[index % colors.size()], 0.82))


func _draw_bow(center: Vector2, bow_scale: float) -> void:
	var left := PackedVector2Array([
		center,
		center + Vector2(-30.0, -17.0) * bow_scale,
		center + Vector2(-42.0, 2.0) * bow_scale,
		center + Vector2(-29.0, 21.0) * bow_scale
	])
	var right := PackedVector2Array([
		center,
		center + Vector2(30.0, -17.0) * bow_scale,
		center + Vector2(42.0, 2.0) * bow_scale,
		center + Vector2(29.0, 21.0) * bow_scale
	])
	draw_colored_polygon(left, Color(PINK, 0.74))
	draw_colored_polygon(right, Color(PINK, 0.74))
	draw_circle(center, 11.0 * bow_scale, Color(CREAM, 0.94))


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.28, -radius * 0.28),
		center + Vector2(radius, 0.0),
		center + Vector2(radius * 0.28, radius * 0.28),
		center + Vector2(0.0, radius),
		center + Vector2(-radius * 0.28, radius * 0.28),
		center + Vector2(-radius, 0.0),
		center + Vector2(-radius * 0.28, -radius * 0.28)
	])
	draw_colored_polygon(points, color)
