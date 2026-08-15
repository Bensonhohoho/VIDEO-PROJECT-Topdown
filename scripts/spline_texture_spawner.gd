@tool
extends Node2D

@export var path_node: NodePath = ^"..":
	set(value):
		path_node = value
		_queue_regeneration()

@export var line_node: NodePath = ^"../Line2D":
	set(value):
		line_node = value
		_queue_regeneration()

@export var prefer_line_points: bool = true:
	set(value):
		prefer_line_points = value
		_queue_regeneration()

@export var atlas_texture: Texture2D = preload("res://assets/sprites/world_tileset.png"):
	set(value):
		atlas_texture = value
		_queue_regeneration()

@export var atlas_regions: Array[Rect2] = [
	Rect2(0.0, 0.0, 16.0, 16.0),
	Rect2(16.0, 0.0, 16.0, 16.0),
	Rect2(32.0, 0.0, 16.0, 16.0)
]:
	set(value):
		atlas_regions = value
		_queue_regeneration()

@export_range(4.0, 256.0, 1.0) var spacing: float = 32.0:
	set(value):
		spacing = value
		_queue_regeneration()

@export var sprite_scale: Vector2 = Vector2(1.5, 1.5):
	set(value):
		sprite_scale = value
		_queue_regeneration()

@export var rotate_along_path: bool = true:
	set(value):
		rotate_along_path = value
		_queue_regeneration()

@export var path_offset: float = 0.0:
	set(value):
		path_offset = value
		_queue_regeneration()

@export_tool_button("Regenerate Path Sprites") var regenerate_button: Callable = _queue_regeneration

var _connected_curve: Curve2D
var _regeneration_queued: bool = false
var _last_source_signature := ""


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	_connect_to_path_curve()
	_spawn_sprites_along_path()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return

	var source_signature := _get_source_signature()
	if source_signature != _last_source_signature:
		_last_source_signature = source_signature
		_queue_regeneration()


func _exit_tree() -> void:
	_disconnect_from_path_curve()


func _queue_regeneration() -> void:
	if not is_inside_tree() or _regeneration_queued:
		return

	_regeneration_queued = true
	_regenerate_deferred.call_deferred()


func _regenerate_deferred() -> void:
	_regeneration_queued = false
	_connect_to_path_curve()
	_spawn_sprites_along_path()


func _connect_to_path_curve() -> void:
	_disconnect_from_path_curve()

	var queue_path: Path2D = get_node_or_null(path_node) as Path2D
	if queue_path == null or queue_path.curve == null:
		return

	_connected_curve = queue_path.curve
	if not _connected_curve.changed.is_connected(_on_path_curve_changed):
		_connected_curve.changed.connect(_on_path_curve_changed)


func _disconnect_from_path_curve() -> void:
	if _connected_curve != null and _connected_curve.changed.is_connected(_on_path_curve_changed):
		_connected_curve.changed.disconnect(_on_path_curve_changed)

	_connected_curve = null


func _on_path_curve_changed() -> void:
	_queue_regeneration()


func _spawn_sprites_along_path() -> void:
	_clear_spawned_sprites()

	var line_points := _get_line_source_points()
	if prefer_line_points and line_points.size() >= 2:
		_spawn_sprites_along_points(line_points)
		_last_source_signature = _get_source_signature()
		return

	var queue_path: Path2D = get_node_or_null(path_node) as Path2D
	if queue_path == null or queue_path.curve == null:
		push_warning("SplineTextureSpawner needs a valid Path2D.")
		return

	if atlas_texture == null or atlas_regions.is_empty():
		push_warning("SplineTextureSpawner needs a texture and at least one atlas region.")
		return

	var path_length: float = queue_path.curve.get_baked_length()
	var safe_spacing: float = maxf(4.0, spacing)
	var sample_distance: float = maxf(0.0, path_offset)
	var sprite_index: int = 0

	while sample_distance <= path_length:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "PathTexture%d" % (sprite_index + 1)
		sprite.texture = atlas_texture
		sprite.region_enabled = true
		sprite.region_rect = atlas_regions[sprite_index % atlas_regions.size()]
		sprite.position = queue_path.curve.sample_baked(sample_distance)
		sprite.scale = sprite_scale

		if rotate_along_path:
			sprite.rotation = _sample_path_rotation(queue_path.curve, sample_distance, path_length)

		add_child(sprite)
		sprite_index += 1
		sample_distance += safe_spacing

	_last_source_signature = _get_source_signature()


func _spawn_sprites_along_points(points: PackedVector2Array) -> void:
	if atlas_texture == null or atlas_regions.is_empty():
		push_warning("SplineTextureSpawner needs a texture and at least one atlas region.")
		return

	var path_length := _get_polyline_length(points)
	var safe_spacing: float = maxf(4.0, spacing)
	var sample_distance: float = maxf(0.0, path_offset)
	var sprite_index: int = 0

	while sample_distance <= path_length:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "PathTexture%d" % (sprite_index + 1)
		sprite.texture = atlas_texture
		sprite.region_enabled = true
		sprite.region_rect = atlas_regions[sprite_index % atlas_regions.size()]
		sprite.position = _sample_polyline(points, sample_distance)
		sprite.scale = sprite_scale

		if rotate_along_path:
			sprite.rotation = _sample_polyline_rotation(points, sample_distance, path_length)

		add_child(sprite)
		sprite_index += 1
		sample_distance += safe_spacing


func _get_line_source_points() -> PackedVector2Array:
	var line := get_node_or_null(line_node) as Line2D
	var source_points := PackedVector2Array()
	if line == null:
		return source_points

	for point in line.points:
		source_points.append(to_local(line.to_global(point)))

	return source_points


func _get_polyline_length(points: PackedVector2Array) -> float:
	var length := 0.0
	for index in range(points.size() - 1):
		length += points[index].distance_to(points[index + 1])

	return length


func _sample_polyline(points: PackedVector2Array, distance: float) -> Vector2:
	var remaining_distance := distance
	for index in range(points.size() - 1):
		var from_point := points[index]
		var to_point := points[index + 1]
		var segment_length := from_point.distance_to(to_point)
		if segment_length <= 0.0:
			continue

		if remaining_distance <= segment_length:
			return from_point.lerp(to_point, remaining_distance / segment_length)

		remaining_distance -= segment_length

	return points[points.size() - 1]


func _sample_polyline_rotation(points: PackedVector2Array, distance: float, path_length: float) -> float:
	var sample_radius := 2.0
	var before_point := _sample_polyline(points, maxf(0.0, distance - sample_radius))
	var after_point := _sample_polyline(points, minf(path_length, distance + sample_radius))

	return before_point.direction_to(after_point).angle()


func _sample_path_rotation(curve: Curve2D, distance: float, path_length: float) -> float:
	var sample_radius: float = 2.0
	var before_distance: float = maxf(0.0, distance - sample_radius)
	var after_distance: float = minf(path_length, distance + sample_radius)
	var before_point: Vector2 = curve.sample_baked(before_distance)
	var after_point: Vector2 = curve.sample_baked(after_distance)

	return before_point.direction_to(after_point).angle()


func _clear_spawned_sprites() -> void:
	for child: Node in get_children():
		child.free()


func _get_source_signature() -> String:
	var line_points := _get_line_source_points()
	if prefer_line_points and line_points.size() >= 2:
		return "line:%s" % _get_points_signature(line_points)

	var queue_path := get_node_or_null(path_node) as Path2D
	if queue_path == null or queue_path.curve == null:
		return "missing"

	var curve := queue_path.curve
	var parts := PackedStringArray(["curve", str(curve.point_count), str(curve.get_baked_length())])
	for index in range(curve.point_count):
		parts.append(str(curve.get_point_position(index)))
		parts.append(str(curve.get_point_in(index)))
		parts.append(str(curve.get_point_out(index)))

	return "|".join(parts)


func _get_points_signature(points: PackedVector2Array) -> String:
	var parts := PackedStringArray([str(points.size())])
	for point in points:
		parts.append(str(point))

	return "|".join(parts)
