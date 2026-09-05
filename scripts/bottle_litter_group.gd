extends Node2D

const BOTTLE_PROP_SCRIPT := preload("res://scripts/bottle_litter_prop.gd")
const BOTTLE_COLORS := [
	Color("#8fc9c3"),
	Color("#e8a4bb"),
	Color("#b5a5da"),
	Color("#e4c16f"),
	Color("#9dbc83")
]

@export_range(1, 3, 1) var reveal_round := 1
@export var bottle_positions := PackedVector2Array()
@export var bottle_scale := 1.0
@export_group("Safe Spawn")
@export var avoid_spawn_collisions := true
@export var spawn_clearance_radius := 13.0
@export var spawn_search_step := 18.0
@export_range(1, 10, 1) var spawn_search_rings := 6

var spawned_bottles: Array[RigidBody2D] = []
var spawn_is_pending := false


func _ready() -> void:
	add_to_group("round_bottle_litter")
	if not SaveManager.progression_changed.is_connected(_on_progression_changed):
		SaveManager.progression_changed.connect(_on_progression_changed)
	_on_progression_changed(
		SaveManager.get_rounds_completed(),
		SaveManager.get_required_rounds(),
		SaveManager.is_game_cleared()
	)


func _exit_tree() -> void:
	if SaveManager.progression_changed.is_connected(_on_progression_changed):
		SaveManager.progression_changed.disconnect(_on_progression_changed)


func _on_progression_changed(completed: int, _required: int, _cleared: bool) -> void:
	var should_be_revealed := completed >= reveal_round
	visible = should_be_revealed
	if should_be_revealed and spawned_bottles.is_empty() and not spawn_is_pending:
		_spawn_bottles_after_physics_ready()
	elif not should_be_revealed and not spawned_bottles.is_empty():
		_despawn_bottles()


func _spawn_bottles_after_physics_ready() -> void:
	spawn_is_pending = true
	await get_tree().physics_frame
	spawn_is_pending = false
	if not is_inside_tree() or SaveManager.get_rounds_completed() < reveal_round:
		return
	if spawned_bottles.is_empty():
		_spawn_bottles()


func _spawn_bottles() -> void:
	for index in bottle_positions.size():
		var desired_position := bottle_positions[index]
		var placement := _find_safe_spawn_position(desired_position, index)
		if not bool(placement.get("found", false)):
			push_warning(
				"%s skipped bottle %d because no collision-free spawn was found near %s."
				% [name, index + 1, desired_position]
			)
			continue

		var bottle := BOTTLE_PROP_SCRIPT.new() as RigidBody2D
		bottle.name = "Bottle%02d" % (index + 1)
		bottle.position = placement.get("position", desired_position) as Vector2
		bottle.rotation = deg_to_rad(float((index * 47 + reveal_round * 19) % 130) - 65.0)
		bottle.set("bottle_scale", bottle_scale)
		bottle.set("body_color", BOTTLE_COLORS[(index + reveal_round) % BOTTLE_COLORS.size()])
		add_child(bottle)
		spawned_bottles.append(bottle)


func _find_safe_spawn_position(desired_position: Vector2, bottle_index: int) -> Dictionary:
	if not avoid_spawn_collisions:
		return {"found": true, "position": desired_position}

	if _is_spawn_position_clear(desired_position):
		return {"found": true, "position": desired_position}

	# Search deterministic rings around the authored point. This keeps bottles
	# close to their intended area while avoiding buildings, gardens, the player,
	# map boundaries, and bottles that have already spawned.
	for ring in range(1, spawn_search_rings + 1):
		var radius := spawn_search_step * float(ring)
		var sample_count := 8 + ring * 2
		var angle_offset := float(bottle_index) * 0.41
		for sample in sample_count:
			var angle := TAU * float(sample) / float(sample_count) + angle_offset
			var candidate := desired_position + Vector2.from_angle(angle) * radius
			if _is_spawn_position_clear(candidate):
				return {"found": true, "position": candidate}

	return {"found": false, "position": desired_position}


func _is_spawn_position_clear(local_position: Vector2) -> bool:
	var clearance_shape := CircleShape2D.new()
	clearance_shape.radius = spawn_clearance_radius * bottle_scale
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = clearance_shape
	query.transform = Transform2D(0.0, to_global(local_position))
	query.collision_mask = 3
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _despawn_bottles() -> void:
	for bottle in spawned_bottles:
		if is_instance_valid(bottle):
			bottle.queue_free()
	spawned_bottles.clear()
