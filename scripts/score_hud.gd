extends Label

enum DisplayMode {
	TOTAL_SCORE,
	ROUND_SCORE
}

@export var display_mode: DisplayMode = DisplayMode.TOTAL_SCORE
@export var pulse_scale: float = 1.18
@export var pulse_duration: float = 0.12
@export var floating_text_scene: PackedScene = preload("res://scenes/floating_score_text.tscn")

var _base_scale := Vector2.ONE
var _pulse_tween: Tween
var _last_round_score := 0


func _ready() -> void:
	# CanvasLayer keeps this label locked to the screen instead of the world.
	# The signal keeps the HUD updated when pickups or queue rewards change score.
	_base_scale = scale
	if display_mode == DisplayMode.ROUND_SCORE:
		_last_round_score = SaveManager.get_round_score()
		SaveManager.round_score_changed.connect(_on_round_score_changed)
		_update_round_score_text(SaveManager.get_round_score(), SaveManager.get_target_score())
	else:
		SaveManager.score_changed.connect(_on_score_changed)
		if not SaveManager.score_added.is_connected(_on_score_added):
			SaveManager.score_added.connect(_on_score_added)
		_update_score_text(SaveManager.get_score())


func _exit_tree() -> void:
	if SaveManager.score_changed.is_connected(_on_score_changed):
		SaveManager.score_changed.disconnect(_on_score_changed)
	if SaveManager.score_added.is_connected(_on_score_added):
		SaveManager.score_added.disconnect(_on_score_added)
	if SaveManager.round_score_changed.is_connected(_on_round_score_changed):
		SaveManager.round_score_changed.disconnect(_on_round_score_changed)


func _on_score_changed(new_score: int) -> void:
	_update_score_text(new_score)


func _on_score_added(amount: int, _new_score: int) -> void:
	if amount <= 0 or display_mode != DisplayMode.TOTAL_SCORE:
		return

	_pulse()
	_spawn_floating_text(amount)


func _on_round_score_changed(current_score: int, target_score: int) -> void:
	_update_round_score_text(current_score, target_score)
	if current_score > _last_round_score:
		_pulse()
	_last_round_score = current_score


func _update_score_text(new_score: int) -> void:
	text = "Score: " + str(new_score)


func _update_round_score_text(current_score: int, target_score: int) -> void:
	text = "Submitted: %d / %d" % [current_score, target_score]


func _pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()

	pivot_offset = size * 0.5
	scale = _base_scale * pulse_scale
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "scale", _base_scale, pulse_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _spawn_floating_text(amount: int) -> void:
	if floating_text_scene == null:
		return

	var floating_text := floating_text_scene.instantiate() as Label
	if floating_text == null:
		return

	var target_parent := get_parent()
	if target_parent == null:
		return

	target_parent.add_child(floating_text)
	floating_text.global_position = global_position + Vector2(-24.0, size.y + 4.0)
	if floating_text.has_method("setup"):
		floating_text.call("setup", amount)
