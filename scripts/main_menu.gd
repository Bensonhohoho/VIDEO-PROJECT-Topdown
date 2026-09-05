extends Control

@export_file("*.tscn") var game_scene_path := "res://scenes/game.tscn"
@export_file("*.tscn") var clear_scene_path := "res://scenes/win_scene.tscn"
@export var level_target_score := 30
@export var score_label_path: NodePath = ^"MenuPanel/MenuContent/ScoreLabel"
@export var progress_label_path: NodePath = ^"MenuPanel/MenuContent/ProgressLabel"
@export var continue_button_path: NodePath = ^"MenuPanel/MenuContent/ContinueButton"
@export var new_game_button_path: NodePath = ^"MenuPanel/MenuContent/NewGameButton"
@export var exit_button_path: NodePath = ^"MenuPanel/MenuContent/ExitButton"

var score_label: Label
var progress_label: Label
var continue_button: Button
var new_game_button: Button
var exit_button: Button


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false

	score_label = get_node_or_null(score_label_path) as Label
	progress_label = get_node_or_null(progress_label_path) as Label
	continue_button = get_node_or_null(continue_button_path) as Button
	new_game_button = get_node_or_null(new_game_button_path) as Button
	exit_button = get_node_or_null(exit_button_path) as Button

	SaveManager.ensure_round_started(level_target_score)
	if not SaveManager.score_changed.is_connected(_on_score_changed):
		SaveManager.score_changed.connect(_on_score_changed)
	if not SaveManager.round_score_changed.is_connected(_on_round_score_changed):
		SaveManager.round_score_changed.connect(_on_round_score_changed)
	if not SaveManager.progression_changed.is_connected(_on_progression_changed):
		SaveManager.progression_changed.connect(_on_progression_changed)

	if continue_button != null:
		continue_button.pressed.connect(_on_continue_pressed)
	if new_game_button != null:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if exit_button != null:
		exit_button.pressed.connect(_on_exit_pressed)

	_update_menu_state()
	if continue_button != null and not continue_button.disabled:
		continue_button.grab_focus()
	elif new_game_button != null:
		new_game_button.grab_focus()


func _exit_tree() -> void:
	if SaveManager.score_changed.is_connected(_on_score_changed):
		SaveManager.score_changed.disconnect(_on_score_changed)
	if SaveManager.round_score_changed.is_connected(_on_round_score_changed):
		SaveManager.round_score_changed.disconnect(_on_round_score_changed)
	if SaveManager.progression_changed.is_connected(_on_progression_changed):
		SaveManager.progression_changed.disconnect(_on_progression_changed)


func _on_continue_pressed() -> void:
	if SaveManager.is_game_cleared():
		_change_scene(clear_scene_path, "clear")
		return
	_change_scene(game_scene_path, "game")


func _on_new_game_pressed() -> void:
	SaveManager.reset_save()
	_change_scene(game_scene_path, "game")


func _change_scene(scene_path: String, scene_description: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Main menu could not open %s scene: %s" % [scene_description, scene_path])


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_score_changed(_new_score: int) -> void:
	_update_menu_state()


func _on_round_score_changed(_current_score: int, _target_score: int) -> void:
	_update_menu_state()


func _on_progression_changed(_completed: int, _required: int, _cleared: bool) -> void:
	_update_menu_state()


func _update_menu_state() -> void:
	var completed := SaveManager.get_rounds_completed()
	var required := SaveManager.get_required_rounds()
	var cleared := SaveManager.is_game_cleared()

	if progress_label != null:
		if cleared:
			progress_label.text = "EVENT COMPLETE  •  %d / %d ROUNDS" % [completed, required]
		else:
			progress_label.text = "ROUND %d OF %d  •  %d COMPLETE" % [
				SaveManager.get_current_playthrough_number(),
				required,
				completed
			]

	if score_label != null:
		score_label.text = "Fan Score  %d     Submitted  %d / %d" % [
			SaveManager.get_score(),
			SaveManager.get_round_score(),
			SaveManager.get_target_score()
		]

	if continue_button != null:
		continue_button.disabled = not SaveManager.has_continue_data()
		continue_button.text = "View Ending" if cleared else "Continue"
