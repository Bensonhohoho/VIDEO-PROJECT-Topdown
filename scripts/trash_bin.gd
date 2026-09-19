extends Area2D

var deposit_locked := false


func _ready() -> void:
	add_to_group("trash_bin")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if deposit_locked or not body.is_in_group("player"):
		return

	deposit_locked = true
	SaveManager.deposit_carried_trash()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		deposit_locked = false


func _draw() -> void:
	# A readable pastel placeholder that can be replaced by final bin art later.
	draw_ellipse_shadow()
	draw_rect(Rect2(-31, -42, 62, 76), Color("#8fc9a5"), true)
	draw_rect(Rect2(-31, -42, 62, 76), Color("#527967"), false, 3.0)
	draw_rect(Rect2(-36, -48, 72, 10), Color("#b8dfc8"), true)
	draw_rect(Rect2(-36, -48, 72, 10), Color("#527967"), false, 3.0)
	draw_rect(Rect2(-18, -27, 36, 22), Color("#fff3d8"), true)
	draw_rect(Rect2(-18, -27, 36, 22), Color("#d38eaa"), false, 2.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-15, -11),
		"BIN",
		HORIZONTAL_ALIGNMENT_CENTER,
		30,
		11,
		Color("#694d60")
	)


func draw_ellipse_shadow() -> void:
	var shadow := PackedVector2Array([
		Vector2(-39, 31), Vector2(-25, 42), Vector2(26, 42),
		Vector2(40, 31), Vector2(25, 24), Vector2(-25, 24)
	])
	draw_colored_polygon(shadow, Color(0.2, 0.18, 0.23, 0.2))
