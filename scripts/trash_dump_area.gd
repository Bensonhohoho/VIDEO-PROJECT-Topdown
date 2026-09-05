extends Node2D

@export_range(1, 3, 1) var reveal_round := 3

const BOTTLE_COLORS := [
	Color("#79b7b1"),
	Color("#d98aa7"),
	Color("#a795cf"),
	Color("#d8b45e"),
	Color("#8cac73")
]

const BOTTLE_POINTS := [
	Vector2(-112, 39), Vector2(-91, 27), Vector2(-72, 47), Vector2(-54, 20),
	Vector2(-35, 43), Vector2(-16, 26), Vector2(4, 46), Vector2(24, 19),
	Vector2(45, 42), Vector2(66, 25), Vector2(86, 46), Vector2(108, 31),
	Vector2(-81, 4), Vector2(-59, -7), Vector2(-34, 6), Vector2(-8, -9),
	Vector2(17, 4), Vector2(42, -8), Vector2(68, 6), Vector2(91, -3),
	Vector2(-42, -29), Vector2(-15, -34), Vector2(14, -28), Vector2(43, -31)
]


func _ready() -> void:
	add_to_group("trash_dump_area")
	if not SaveManager.progression_changed.is_connected(_on_progression_changed):
		SaveManager.progression_changed.connect(_on_progression_changed)
	_on_progression_changed(
		SaveManager.get_rounds_completed(),
		SaveManager.get_required_rounds(),
		SaveManager.is_game_cleared()
	)
	queue_redraw()


func _exit_tree() -> void:
	if SaveManager.progression_changed.is_connected(_on_progression_changed):
		SaveManager.progression_changed.disconnect(_on_progression_changed)


func _draw() -> void:
	# This sits inside the previously closed backstage opening. It has no
	# collision, so it communicates the result without changing the map routes.
	draw_rect(Rect2(-154.0, -79.0, 308.0, 145.0), Color("#d8d1cd"), true)
	draw_rect(Rect2(-154.0, -79.0, 308.0, 145.0), Color("#8d7f88"), false, 3.0)
	draw_rect(Rect2(-144.0, -69.0, 288.0, 123.0), Color("#b9b0ad"), true)

	# Rear fence and a small cloth banner keep the reveal in the plaza's visual language.
	for x in range(-140, 141, 28):
		draw_line(Vector2(x, -67), Vector2(x, 48), Color("#7d6f73"), 3.0, true)
	draw_line(Vector2(-144, -57), Vector2(144, -57), Color("#7d6f73"), 4.0, true)
	draw_line(Vector2(-144, -23), Vector2(144, -23), Color("#7d6f73"), 4.0, true)
	draw_rect(Rect2(-82.0, -67.0, 164.0, 26.0), Color("#fff0d4"), true)
	draw_rect(Rect2(-82.0, -67.0, 164.0, 26.0), Color("#d58da9"), false, 2.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-76.0, -49.0),
		"BACKSTAGE WASTE",
		HORIZONTAL_ALIGNMENT_CENTER,
		152.0,
		11,
		Color("#6f5465")
	)

	# Soft rubbish bags create a base for the visibly excessive bottle heap.
	draw_circle(Vector2(-67, 33), 29.0, Color("#847c89"))
	draw_circle(Vector2(-20, 31), 35.0, Color("#766f7c"))
	draw_circle(Vector2(34, 34), 32.0, Color("#8c8490"))
	draw_circle(Vector2(77, 36), 27.0, Color("#746e79"))

	for index in BOTTLE_POINTS.size():
		var angle := deg_to_rad(float((index * 53) % 150) - 75.0)
		draw_set_transform(BOTTLE_POINTS[index], angle, Vector2.ONE * 0.9)
		_draw_bottle(BOTTLE_COLORS[index % BOTTLE_COLORS.size()])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_progression_changed(completed: int, _required: int, _cleared: bool) -> void:
	visible = completed >= reveal_round


func _draw_bottle(body_color: Color) -> void:
	var shape := PackedVector2Array([
		Vector2(-3, -9), Vector2(3, -9), Vector2(3, -6), Vector2(5, -4),
		Vector2(5, 8), Vector2(-5, 8), Vector2(-5, -4), Vector2(-3, -6)
	])
	draw_colored_polygon(shape, body_color)
	draw_polyline(shape + PackedVector2Array([shape[0]]), Color("#58565e"), 1.1, true)
	draw_rect(Rect2(-3, -11, 6, 2.3), Color("#f6e8c9"), true)
	draw_rect(Rect2(-4.5, 0, 9, 3), Color("#fff2d3"), true)
