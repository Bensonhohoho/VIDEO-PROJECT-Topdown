extends CharacterBody2D

signal died(source)

# Main-map movement is top-down: no gravity, no jump, just flat 4-direction walking.
@export var move_speed: float = 150.0
@export var acceleration: float = 900.0
@export var deceleration: float = 1200.0

@export_group("Player Art")
@export var player_sprite_scale := Vector2(0.38, 0.38)

@export_group("Ground Materials")
@export var normal_acceleration_multiplier: float = 1.0
@export var normal_deceleration_multiplier: float = 1.0
@export var stone_acceleration_multiplier: float = 1.2
@export var stone_deceleration_multiplier: float = 1.1
@export var ice_acceleration_multiplier: float = 0.55
@export var ice_deceleration_multiplier: float = 0.18

@export_group("Pushable Litter")
@export var litter_push_impulse: float = 10.0

@export_group("Footsteps")
# Drop sound files into these slots in the inspector. Empty streams are skipped.
@export var normal_footstep_stream: AudioStream
@export var stone_footstep_stream: AudioStream
@export var ice_footstep_stream: AudioStream
@export var footstep_interval: float = 0.18
@export var footstep_min_speed: float = 35.0

var is_dead := false
var _ground_material: StringName = &"normal"
var _ground_material_stack: Array = []
var _footstep_time_left := 0.0
var _last_direction := Vector2.DOWN

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var footstep_audio: AudioStreamPlayer2D = $FootstepAudio


func _ready() -> void:
	_update_animation(Vector2.ZERO)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	var input_direction := _get_movement_input()
	if input_direction != Vector2.ZERO:
		_last_direction = _get_cardinal_direction(input_direction)
		velocity = velocity.move_toward(input_direction * move_speed, _get_current_acceleration() * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, _get_current_deceleration() * delta)

	move_and_slide()
	_push_litter_from_slide_collisions()
	_update_animation(input_direction)
	_update_footsteps(delta, input_direction)


func _get_movement_input() -> Vector2:
	if DebugFlags.is_console_input_active():
		return Vector2.ZERO

	var direction := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	# Normalizing keeps diagonal movement from being faster than cardinal movement.
	return direction.normalized() if direction.length_squared() > 1.0 else direction


func _push_litter_from_slide_collisions() -> void:
	var pushed_body_ids: Dictionary = {}
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		var rigid_body := collision.get_collider() as RigidBody2D
		if rigid_body == null or not rigid_body.is_in_group("pushable_litter"):
			continue

		var body_id := rigid_body.get_instance_id()
		if pushed_body_ids.has(body_id):
			continue
		pushed_body_ids[body_id] = true

		var push_direction := -collision.get_normal()
		var contact_offset := collision.get_position() - rigid_body.global_position
		rigid_body.apply_impulse(push_direction * litter_push_impulse, contact_offset)


func _get_cardinal_direction(input_direction: Vector2) -> Vector2:
	if absf(input_direction.x) > absf(input_direction.y):
		return Vector2.RIGHT if input_direction.x > 0.0 else Vector2.LEFT

	return Vector2.DOWN if input_direction.y > 0.0 else Vector2.UP


func _update_animation(input_direction: Vector2) -> void:
	if animated_sprite == null:
		return

	var direction_name := _direction_to_animation_name(_last_direction)
	var animation_name := "walk_%s" % direction_name if input_direction != Vector2.ZERO else "idle_%s" % direction_name

	# The supplied side sheet faces left. Right-facing animations reuse it flipped.
	animated_sprite.flip_h = _last_direction == Vector2.RIGHT
	# All directions share one normalized atlas, so the visible size stays constant.
	animated_sprite.scale = player_sprite_scale
	_play_animation_with_fallback(StringName(animation_name))


func _direction_to_animation_name(direction: Vector2) -> String:
	if direction == Vector2.UP:
		return "up"
	if direction == Vector2.LEFT:
		return "left"
	if direction == Vector2.RIGHT:
		return "right"

	return "down"


func _play_animation_with_fallback(animation_name: StringName) -> void:
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
		return

	# Older prototype frames used platformer names; keep them as a graceful fallback.
	match String(animation_name):
		"walk_down":
			animated_sprite.play(&"move_down")
		"walk_up":
			animated_sprite.play(&"move_up")
		"walk_left", "walk_right":
			animated_sprite.play(&"run")
		_:
			animated_sprite.play(&"idle")


func take_damage(_amount: int = 1, source: Node = null) -> void:
	if DebugFlags.is_godmode_enabled():
		return

	if is_dead:
		return

	die(source)


func die(source: Node = null) -> void:
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	_disable_collision()
	died.emit(source)


func _disable_collision() -> void:
	for child in find_children("*", "CollisionShape2D"):
		child.set_deferred("disabled", true)


func set_ground_material(material_name: StringName) -> void:
	# GroundMaterialArea can still tune top-down movement on special floor zones.
	if not _ground_material_stack.has(material_name):
		_ground_material_stack.append(material_name)
	_ground_material = material_name


func clear_ground_material(material_name: StringName) -> void:
	_ground_material_stack.erase(material_name)
	_ground_material = &"normal" if _ground_material_stack.is_empty() else _ground_material_stack.back()


func _get_current_acceleration() -> float:
	return acceleration * _get_acceleration_multiplier(_ground_material)


func _get_current_deceleration() -> float:
	return deceleration * _get_deceleration_multiplier(_ground_material)


func _get_acceleration_multiplier(material_name: StringName) -> float:
	match String(material_name):
		"stone":
			return stone_acceleration_multiplier
		"ice":
			return ice_acceleration_multiplier
		_:
			return normal_acceleration_multiplier


func _get_deceleration_multiplier(material_name: StringName) -> float:
	match String(material_name):
		"stone":
			return stone_deceleration_multiplier
		"ice":
			return ice_deceleration_multiplier
		_:
			return normal_deceleration_multiplier


func _update_footsteps(delta: float, input_direction: Vector2) -> void:
	if input_direction == Vector2.ZERO or velocity.length() < footstep_min_speed:
		_footstep_time_left = 0.0
		return

	_footstep_time_left -= delta
	if _footstep_time_left > 0.0:
		return

	_play_footstep()
	_footstep_time_left = maxf(0.05, footstep_interval)


func _play_footstep() -> void:
	var stream := _get_footstep_stream(_ground_material)
	if stream == null or footstep_audio == null:
		return

	footstep_audio.stream = stream
	footstep_audio.pitch_scale = randf_range(0.94, 1.06)
	footstep_audio.play()


func _get_footstep_stream(material_name: StringName) -> AudioStream:
	match String(material_name):
		"stone":
			return stone_footstep_stream
		"ice":
			return ice_footstep_stream
		_:
			return normal_footstep_stream
