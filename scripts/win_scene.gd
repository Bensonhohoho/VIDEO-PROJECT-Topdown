extends Control

@export_file("*.tscn") var game_scene_path := "res://scenes/game.tscn"
@export_file("*.tscn") var main_menu_scene_path := "res://scenes/main_menu.tscn"
@export var completion_label_path: NodePath = ^"ClearPanel/ClearContent/CompletionLabel"
@export var stats_label_path: NodePath = ^"ClearPanel/ClearContent/ReportPanel/StatsLabel"
@export var restart_button_path: NodePath = ^"ClearPanel/ClearContent/ButtonRow/RestartButton"
@export var main_menu_button_path: NodePath = ^"ClearPanel/ClearContent/ButtonRow/MainMenuButton"
@export var quit_button_path: NodePath = ^"ClearPanel/ClearContent/QuitButton"

var completion_label: Label
var stats_label: Label
var restart_button: Button
var main_menu_button: Button
var quit_button: Button


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false

	completion_label = get_node_or_null(completion_label_path) as Label
	stats_label = get_node_or_null(stats_label_path) as Label
	restart_button = get_node_or_null(restart_button_path) as Button
	main_menu_button = get_node_or_null(main_menu_button_path) as Button
	quit_button = get_node_or_null(quit_button_path) as Button

	if restart_button != null:
		restart_button.pressed.connect(_on_restart_pressed)
	if main_menu_button != null:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
		main_menu_button.grab_focus()
	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)

	_update_result_text()


func _on_restart_pressed() -> void:
	SaveManager.reset_progress_for_testing(false)
	_change_scene(game_scene_path, "restart")


func _on_main_menu_pressed() -> void:
	_change_scene(main_menu_scene_path, "title")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _change_scene(scene_path: String, scene_description: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Clear screen could not open %s scene: %s" % [scene_description, scene_path])


func _update_result_text() -> void:
	if completion_label != null:
		completion_label.text = "%d / %d ROUNDS COMPLETE" % [
			SaveManager.get_rounds_completed(),
			SaveManager.get_required_rounds()
		]

	if stats_label != null:
		stats_label.text = "Submitted score   %d / %d\nQueue attempts    %d\nFan score left    %d" % [
			SaveManager.get_round_score(),
			SaveManager.get_target_score(),
			SaveManager.get_queue_attempt_count(),
			SaveManager.get_score()
		]
