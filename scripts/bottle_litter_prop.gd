extends RigidBody2D

@export var body_color := Color("#8fc9c3")
@export var bottle_scale := 1.0
@export var max_linear_speed := 105.0
@export var max_angular_speed := 7.0


func _ready() -> void:
	add_to_group("pushable_litter")
	gravity_scale = 0.0
	mass = 0.24
	linear_damp = 5.5
	angular_damp = 6.5
	collision_layer = 1
	collision_mask = 3
	can_sleep = true

	var material := PhysicsMaterial.new()
	material.friction = 0.72
	material.bounce = 0.08
	physics_material_override = material

	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "BottleCollision"
	var capsule := CapsuleShape2D.new()
	capsule.radius = 4.2 * bottle_scale
	capsule.height = 20.0 * bottle_scale
	collision_shape.shape = capsule
	add_child(collision_shape)
	queue_redraw()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.linear_velocity.length() > max_linear_speed:
		state.linear_velocity = state.linear_velocity.normalized() * max_linear_speed
	state.angular_velocity = clampf(state.angular_velocity, -max_angular_speed, max_angular_speed)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * bottle_scale)
	_draw_ellipse_shadow()
	var bottle_shape := PackedVector2Array([
		Vector2(-3.2, -10.0),
		Vector2(3.2, -10.0),
		Vector2(3.2, -7.2),
		Vector2(5.2, -4.8),
		Vector2(5.2, 8.5),
		Vector2(-5.2, 8.5),
		Vector2(-5.2, -4.8),
		Vector2(-3.2, -7.2)
	])
	draw_colored_polygon(bottle_shape, body_color)
	draw_polyline(bottle_shape + PackedVector2Array([bottle_shape[0]]), Color("#6f7678"), 1.15, true)
	draw_rect(Rect2(-3.4, -12.2, 6.8, 2.5), Color("#f4e5c6"), true)
	draw_rect(Rect2(-4.7, 0.2, 9.4, 3.4), Color("#fff5db"), true)
	draw_line(Vector2(-2.2, -5.0), Vector2(-2.2, -0.4), Color(1.0, 1.0, 1.0, 0.62), 1.1, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ellipse_shadow() -> void:
	var shadow := PackedVector2Array([
		Vector2(-6.8, 7.0),
		Vector2(-3.6, 9.8),
		Vector2(4.8, 9.8),
		Vector2(7.0, 7.0),
		Vector2(3.8, 5.7),
		Vector2(-4.5, 5.7)
	])
	draw_colored_polygon(shadow, Color(0.2, 0.18, 0.23, 0.18))
