extends CharacterBody2D

signal death_animation_finished

@export var move_speed: float = 220.0
@export var death_bounce_velocity: float = -300.0
@export var death_fall_gravity: float = 900.0
@export var death_animation_duration: float = 1.0

var is_dead := false
var input_enabled := true
var _death_elapsed := 0.0
var _death_target_y := 0.0
var _death_max_duration := 0.0
var _death_finished := false

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.y += death_fall_gravity * delta
		move_and_slide()
		_update_death_animation(delta)
		return

	if not input_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		_play_animation(&"idle")
		return

	if DebugFlags.is_console_input_active():
		velocity = Vector2.ZERO
		move_and_slide()
		_play_animation(&"idle")
		return

	# This tiny fallback controller is only here because the queue mini-game does
	# not reuse the platformer Player movement script.
	var input_direction := _get_input_direction()
	velocity = input_direction * move_speed
	move_and_slide()
	_update_movement_animation(input_direction)


func reset_to_spawn(spawn_position: Vector2) -> void:
	# The mini-game manager uses this when preparing the scene.
	is_dead = false
	input_enabled = true
	_death_finished = false
	global_position = spawn_position
	velocity = Vector2.ZERO
	_set_collision_enabled(true)
	_play_animation(&"idle")


func start_death_animation() -> void:
	if is_dead:
		return

	# Disable input and collision so queue-exit/obstacle callbacks cannot keep
	# retriggering the fail animation while the player is falling away.
	is_dead = true
	input_enabled = false
	velocity = Vector2(0.0, death_bounce_velocity)
	_set_collision_enabled(false)
	_play_animation(&"jump")
	_death_elapsed = 0.0
	_death_target_y = _get_death_fall_target_y()
	_death_max_duration = death_animation_duration + 1.0
	_death_finished = false


func play_death_animation() -> void:
	start_death_animation()
	if _death_finished:
		return

	await death_animation_finished


func _get_input_direction() -> Vector2:
	# Godot's built-in ui_* actions cover arrow keys. The direct key checks make
	# WASD work without requiring project-wide input map changes.
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd_direction := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)

	if wasd_direction.length_squared() > 0.0:
		direction = wasd_direction.normalized()

	return direction


func _update_movement_animation(input_direction: Vector2) -> void:
	if animated_sprite == null:
		return

	if input_direction.x > 0.0:
		animated_sprite.flip_h = false
	elif input_direction.x < 0.0:
		animated_sprite.flip_h = true

	if input_direction.length_squared() == 0.0:
		_play_animation(&"idle")
	elif input_direction.y > absf(input_direction.x):
		_play_animation(&"move_down")
	elif -input_direction.y > absf(input_direction.x):
		_play_animation(&"move_up")
	else:
		_play_animation(&"run")


func _play_animation(animation_name: StringName) -> void:
	if animated_sprite == null:
		return

	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)


func _set_collision_enabled(is_enabled: bool) -> void:
	for child in find_children("*", "CollisionShape2D"):
		var collision_shape := child as CollisionShape2D
		collision_shape.set_deferred("disabled", not is_enabled)


func _update_death_animation(delta: float) -> void:
	if _death_finished:
		return

	# death_animation_duration is the minimum; if the bounce arc has not carried
	# the player below the visible screen yet, wait briefly until it does.
	_death_elapsed += delta
	var minimum_time_passed := _death_elapsed >= death_animation_duration
	var below_screen := global_position.y >= _death_target_y
	var timed_out := _death_elapsed >= _death_max_duration
	if minimum_time_passed and (below_screen or timed_out):
		_death_finished = true
		death_animation_finished.emit()


func _get_death_fall_target_y() -> float:
	return get_viewport_rect().size.y + 96.0
