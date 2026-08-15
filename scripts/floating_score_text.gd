extends Label

@export var float_distance: float = 42.0
@export var lifetime: float = 0.65
@export var start_scale: Vector2 = Vector2(1.25, 1.25)

var _age := 0.0
var _start_position := Vector2.ZERO


func setup(amount: int) -> void:
	text = "+%d" % amount


func _ready() -> void:
	_start_position = position
	scale = start_scale
	pivot_offset = size * 0.5


func _process(delta: float) -> void:
	_age += delta
	var progress := clampf(_age / maxf(0.01, lifetime), 0.0, 1.0)
	position = _start_position + Vector2(0.0, -float_distance * progress)
	modulate.a = 1.0 - progress
	scale = start_scale.lerp(Vector2.ONE, progress)

	if progress >= 1.0:
		queue_free()
