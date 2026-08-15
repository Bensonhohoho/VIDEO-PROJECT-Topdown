extends Node2D

# Lightweight reusable dust puff. It draws a few fading circles, then frees itself.
@export var lifetime: float = 0.28
@export var particle_count: int = 6
@export var dust_color: Color = Color(0.72, 0.64, 0.52, 0.45)
@export var base_radius: float = 1.6
@export var horizontal_spread: float = 22.0
@export var upward_spread: float = 12.0

var _age := 0.0
var _particles: Array[Dictionary] = []


func _ready() -> void:
	for index in range(particle_count):
		_particles.append({
			"velocity": Vector2(randf_range(-horizontal_spread, horizontal_spread), randf_range(-upward_spread, -2.0)),
			"radius": randf_range(base_radius * 0.65, base_radius * 1.25),
		})


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	queue_redraw()


func _draw() -> void:
	var progress := _age / lifetime
	for particle in _particles:
		var position: Vector2 = particle["velocity"]
		position *= progress
		position.y += 18.0 * progress * progress

		var color := dust_color
		color.a *= 1.0 - progress
		var radius: float = particle["radius"]
		draw_circle(position, radius * (1.0 + progress), color)
