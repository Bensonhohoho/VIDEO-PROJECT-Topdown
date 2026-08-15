extends Node2D

@export var lifetime: float = 0.35
@export var particle_count: int = 10
@export var burst_radius: float = 34.0
@export var particle_radius: float = 1.5
@export var burst_color: Color = Color(1.0, 0.86, 0.22, 0.9)

var _age := 0.0
var _particles: Array = []

@onready var collect_audio: AudioStreamPlayer2D = $CollectAudio


func _ready() -> void:
	for index in range(particle_count):
		var angle := TAU * float(index) / maxf(1.0, float(particle_count)) + randf_range(-0.18, 0.18)
		_particles.append({
			"direction": Vector2.RIGHT.rotated(angle),
			"speed": randf_range(0.65, 1.0),
			"radius": randf_range(particle_radius * 0.75, particle_radius * 1.35),
		})

	if collect_audio != null and collect_audio.stream != null:
		collect_audio.pitch_scale = randf_range(0.96, 1.06)
		collect_audio.play()


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		if collect_audio == null or not collect_audio.playing:
			queue_free()
		return

	queue_redraw()


func _draw() -> void:
	var progress := clampf(_age / lifetime, 0.0, 1.0)
	for particle in _particles:
		var direction: Vector2 = particle["direction"]
		var speed: float = particle["speed"]
		var radius: float = particle["radius"]
		var position := direction * burst_radius * speed * progress

		var color := burst_color
		color.a *= 1.0 - progress
		draw_circle(position, radius * (1.0 + progress), color)
