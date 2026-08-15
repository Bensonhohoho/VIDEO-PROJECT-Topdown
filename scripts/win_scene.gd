extends Control

@export_file("*.tscn") var game_scene_path := "res://scenes/game.tscn"
@export_file("*.tscn") var main_menu_scene_path := "res://scenes/main_menu.tscn"
@export var level_target_score := 30
@export var attempts_label_path: NodePath = ^"WinPanel/WinContent/AttemptsLabel"
@export var score_label_path: NodePath = ^"WinPanel/WinContent/ScoreLabel"
@export var replay_button_path: NodePath = ^"WinPanel/WinContent/ButtonRow/ReplayButton"
@export var main_menu_button_path: NodePath = ^"WinPanel/WinContent/ButtonRow/MainMenuButton"

var attempts_label: Label
var score_label: Label
var replay_button: Button
var main_menu_button: Button


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false

	attempts_label = get_node_or_null(attempts_label_path) as Label
	score_label = get_node_or_null(score_label_path) as Label
	replay_button = get_node_or_null(replay_button_path) as Button
	main_menu_button = get_node_or_null(main_menu_button_path) as Button

	if replay_button != null:
		replay_button.pressed.connect(_on_replay_pressed)
		replay_button.grab_focus()
	if main_menu_button != null:
		main_menu_button.pressed.connect(_on_main_menu_pressed)

	_update_result_text()


func _on_replay_pressed() -> void:
	SaveManager.start_new_round(level_target_score)
	var error := get_tree().change_scene_to_file(game_scene_path)
	if error != OK:
		push_error("Win scene could not replay game scene: " + game_scene_path)


func _on_main_menu_pressed() -> void:
	var error := get_tree().change_scene_to_file(main_menu_scene_path)
	if error != OK:
		push_error("Win scene could not return to main menu: " + main_menu_scene_path)


func _update_result_text() -> void:
	if attempts_label != null:
		attempts_label.text = "Stay In Line attempts: %d" % SaveManager.get_queue_attempt_count()

	if score_label != null:
		score_label.text = "Score: %d / %d\nRemaining Score: %d" % [
			SaveManager.get_round_score(),
			SaveManager.get_target_score(),
			SaveManager.get_score()
		]
