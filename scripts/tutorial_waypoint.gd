extends Node2D

@export var guide_color := Color("#f3a9c4")
@export var bob_height := 7.0
@export var bob_speed := 2.4

var base_position := Vector2.ZERO
var elapsed := 0.0


func _ready() -> void:
	base_position = position
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	position = base_position + Vector2(0.0, sin(elapsed * bob_speed) * bob_height)
	modulate.a = 0.78 + sin(elapsed * bob_speed) * 0.16


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(-18, -12), Vector2(18, -12), Vector2(18, 4),
		Vector2(30, 4), Vector2(0, 32), Vector2(-30, 4), Vector2(-18, 4)
	])
	draw_colored_polygon(points, guide_color)
	draw_polyline(points + PackedVector2Array([points[0]]), Color("#76566f"), 2.0, true)
