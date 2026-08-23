extends Node2D

@export var radius: float = 36.0
@export var activation_duration: float = 0.22
@export var deactivation_duration: float = 0.16
@export var pulse_speed: float = 4.5
@export var pulse_amount: float = 0.025

var _is_active := false
var _appearance := 0.0
var _visual_time := 0.0


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	set_process(false)


func set_active(is_active: bool, immediate: bool = false) -> void:
	_is_active = is_active

	if immediate:
		_appearance = 1.0 if is_active else 0.0
		visible = is_active
		modulate.a = _appearance
		scale = Vector2.ONE
		set_process(is_active)
		queue_redraw()
		return

	if is_active:
		visible = true

	set_process(true)


func _process(delta: float) -> void:
	_visual_time += delta

	if _is_active:
		_appearance = minf(1.0, _appearance + delta / maxf(activation_duration, 0.001))
	else:
		_appearance = maxf(0.0, _appearance - delta / maxf(deactivation_duration, 0.001))

	var pop_scale := lerpf(0.72, 1.0, _ease_out_back(_appearance))
	var pulse := 1.0 + sin(_visual_time * pulse_speed) * pulse_amount * _appearance
	scale = Vector2.ONE * pop_scale * pulse
	rotation = sin(_visual_time * 0.8) * 0.025
	modulate.a = _appearance
	queue_redraw()

	if not _is_active and is_zero_approx(_appearance):
		visible = false
		set_process(false)


func _draw() -> void:
	# Layered translucent circles and highlights keep the shield readable against
	# both the pale queue background and darker obstacles.
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.25, 0.67, 0.16))
	draw_circle(Vector2.ZERO, radius - 4.0, Color(1.0, 0.55, 0.82, 0.09))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.35, 0.73, 0.92), 3.0, true)
	draw_arc(Vector2.ZERO, radius - 5.0, -2.75, -1.25, 24, Color(1.0, 0.88, 0.96, 0.9), 3.5, true)
	draw_arc(Vector2.ZERO, radius - 7.0, 0.25, 1.05, 16, Color(1.0, 0.45, 0.78, 0.45), 2.0, true)

	for index in range(3):
		var angle := _visual_time * (0.85 + index * 0.12) + index * TAU / 3.0
		var sparkle_position := Vector2.from_angle(angle) * (radius + 3.0)
		var sparkle_radius := 1.8 + sin(_visual_time * 5.0 + index) * 0.45
		draw_circle(sparkle_position, sparkle_radius, Color(1.0, 0.82, 0.94, 0.9))


func _ease_out_back(value: float) -> float:
	var overshoot := 1.70158
	var shifted := value - 1.0
	return 1.0 + (overshoot + 1.0) * shifted * shifted * shifted + overshoot * shifted * shifted
