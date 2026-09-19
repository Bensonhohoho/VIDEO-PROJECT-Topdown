extends Area2D

@export var trash_id := ""
@export var body_color := Color("#8fc9c3")
@export var bottle_scale := 1.25

var pickup_locked := false


func _ready() -> void:
	add_to_group("collectible_trash")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	if not SaveManager.trash_state_changed.is_connected(_on_trash_state_changed):
		SaveManager.trash_state_changed.connect(_on_trash_state_changed)
	_refresh_state()
	queue_redraw()


func _exit_tree() -> void:
	if SaveManager.trash_state_changed.is_connected(_on_trash_state_changed):
		SaveManager.trash_state_changed.disconnect(_on_trash_state_changed)


func _on_body_entered(body: Node2D) -> void:
	if pickup_locked or not body.is_in_group("player"):
		return

	pickup_locked = true
	if SaveManager.collect_trash(trash_id):
		visible = false
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
	else:
		pickup_locked = false


func _on_trash_state_changed(
	_total_generated: int,
	_total_cleaned: int,
	_carried: int,
	_cleanup_enabled: bool
) -> void:
	_refresh_state()


func _refresh_state() -> void:
	var should_be_visible := SaveManager.is_trash_generated(trash_id) \
		and not SaveManager.is_trash_collected(trash_id)
	var should_monitor := should_be_visible and SaveManager.is_cleanup_mode_enabled()
	visible = should_be_visible
	set_deferred("monitoring", should_monitor)
	set_deferred("monitorable", should_monitor)
	if should_be_visible:
		pickup_locked = false


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * bottle_scale)
	var shadow := PackedVector2Array([
		Vector2(-6.8, 7.0), Vector2(-3.6, 9.8), Vector2(4.8, 9.8),
		Vector2(7.0, 7.0), Vector2(3.8, 5.7), Vector2(-4.5, 5.7)
	])
	draw_colored_polygon(shadow, Color(0.2, 0.18, 0.23, 0.18))

	var bottle_shape := PackedVector2Array([
		Vector2(-3.2, -10.0), Vector2(3.2, -10.0),
		Vector2(3.2, -7.2), Vector2(5.2, -4.8),
		Vector2(5.2, 8.5), Vector2(-5.2, 8.5),
		Vector2(-5.2, -4.8), Vector2(-3.2, -7.2)
	])
	draw_colored_polygon(bottle_shape, body_color)
	draw_polyline(
		bottle_shape + PackedVector2Array([bottle_shape[0]]),
		Color("#6f7678"),
		1.15,
		true
	)
	draw_rect(Rect2(-3.4, -12.2, 6.8, 2.5), Color("#f4e5c6"), true)
	draw_rect(Rect2(-4.7, 0.2, 9.4, 3.4), Color("#fff5db"), true)
	draw_line(Vector2(-2.2, -5.0), Vector2(-2.2, -0.4), Color(1, 1, 1, 0.62), 1.1, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
