extends Control

@export_file("*.tscn") var game_scene_path := "res://scenes/game.tscn"
@export var level_target_score := 30
@export var score_label_path: NodePath = ^"MenuPanel/MenuContent/ScoreLabel"
@export var continue_button_path: NodePath = ^"MenuPanel/MenuContent/ContinueButton"
@export var new_game_button_path: NodePath = ^"MenuPanel/MenuContent/NewGameButton"
@export var exit_button_path: NodePath = ^"MenuPanel/MenuContent/ExitButton"

var score_label: Label
var continue_button: Button
var new_game_button: Button
var exit_button: Button


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false

	score_label = get_node_or_null(score_label_path) as Label
	continue_button = get_node_or_null(continue_button_path) as Button
	new_game_button = get_node_or_null(new_game_button_path) as Button
	exit_button = get_node_or_null(exit_button_path) as Button

	SaveManager.ensure_round_started(level_target_score)
	if not SaveManager.score_changed.is_connected(_on_score_changed):
		SaveManager.score_changed.connect(_on_score_changed)
	if not SaveManager.round_score_changed.is_connected(_on_round_score_changed):
		SaveManager.round_score_changed.connect(_on_round_score_changed)

	if continue_button != null:
		continue_button.pressed.connect(_on_continue_pressed)
		continue_button.grab_focus()
	if new_game_button != null:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if exit_button != null:
		exit_button.pressed.connect(_on_exit_pressed)

	_update_score_label()


func _exit_tree() -> void:
	if SaveManager.score_changed.is_connected(_on_score_changed):
		SaveManager.score_changed.disconnect(_on_score_changed)
	if SaveManager.round_score_changed.is_connected(_on_round_score_changed):
		SaveManager.round_score_changed.disconnect(_on_round_score_changed)


func _on_continue_pressed() -> void:
	if SaveManager.is_round_completed():
		SaveManager.start_new_round(level_target_score)

	_change_to_game_scene()


func _on_new_game_pressed() -> void:
	SaveManager.reset_save()
	_change_to_game_scene()


func _change_to_game_scene() -> void:
	var error := get_tree().change_scene_to_file(game_scene_path)
	if error != OK:
		push_error("Main menu could not start game scene: " + game_scene_path)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_score_changed(_new_score: int) -> void:
	_update_score_label()


func _on_round_score_changed(_current_score: int, _target_score: int) -> void:
	_update_score_label()


func _update_score_label() -> void:
	if score_label == null:
		return

	score_label.text = "Score: %d\nTarget: %d / %d" % [
		SaveManager.get_score(),
		SaveManager.get_round_score(),
		SaveManager.get_target_score()
	]
