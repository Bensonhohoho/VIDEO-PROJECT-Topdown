extends Node2D

const TRASH_ITEM_SCENE := preload("res://scenes/trash_item.tscn")
const TRASH_COLORS := [
	Color("#8fc9c3"),
	Color("#e8a4bb"),
	Color("#b5a5da"),
	Color("#e4c16f"),
	Color("#9dbc83")
]

@export var trash_items_path: NodePath = ^"TrashItems"
@export var round_1_spawn_points_path: NodePath = ^"TrashSpawnPoints/Round1"
@export var round_2_spawn_points_path: NodePath = ^"TrashSpawnPoints/Round2"


func _ready() -> void:
	var trash_items := get_node_or_null(trash_items_path) as Node2D
	var round_1_points := get_node_or_null(round_1_spawn_points_path) as Node2D
	var round_2_points := get_node_or_null(round_2_spawn_points_path) as Node2D
	if trash_items == null or round_1_points == null or round_2_points == null:
		push_error("TrashSystem is missing its item container or authored spawn points.")
		return

	_spawn_round_items(trash_items, round_1_points, 1, 5, 0)
	_spawn_round_items(trash_items, round_2_points, 2, 7, 5)


func _spawn_round_items(
	trash_items: Node2D,
	spawn_points: Node2D,
	round_number: int,
	expected_count: int,
	color_offset: int
) -> void:
	var markers: Array[Marker2D] = []
	for child in spawn_points.get_children():
		if child is Marker2D:
			markers.append(child as Marker2D)

	if markers.size() != expected_count:
		push_error(
			"TrashSystem Round%d requires exactly %d Marker2D spawn points, but found %d."
			% [round_number, expected_count, markers.size()]
		)

	for index in markers.size():
		var marker := markers[index]
		var trash_item := TRASH_ITEM_SCENE.instantiate() as Area2D
		trash_item.name = "Trash_Round%d_%s" % [round_number, marker.name]
		trash_item.position = trash_items.to_local(marker.global_position)
		trash_item.rotation = deg_to_rad(float((index * 47 + round_number * 19) % 130) - 65.0)
		trash_item.set("trash_id", "round%d_%s" % [round_number, marker.name.to_lower()])
		trash_item.set("body_color", TRASH_COLORS[(index + color_offset) % TRASH_COLORS.size()])
		trash_items.add_child(trash_item)
