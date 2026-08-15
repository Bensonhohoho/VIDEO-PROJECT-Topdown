extends Node

@export var restart_delay := 0.6
@export var death_time_scale := 0.5
@export var pickup_score_reward := 1
@export var level_target_score := 30
@export var submit_score_cost := 10
@export var purchase_score_cost := 5
@export_file("*.tscn") var win_scene_path := "res://scenes/win_scene.tscn"
@export var victory_label_path: NodePath = ^"../UI/VictoryLabel"
@export var submit_window_path: NodePath = ^"../UI/SubmitScoreWindow"
@export var submit_current_score_label_path: NodePath = ^"../UI/SubmitScoreWindow/Panel/CurrentScoreLabel"
@export var submit_cost_label_path: NodePath = ^"../UI/SubmitScoreWindow/Panel/SubmitCostLabel"
@export var submit_target_label_path: NodePath = ^"../UI/SubmitScoreWindow/Panel/TargetScoreLabel"
@export var submit_progress_label_path: NodePath = ^"../UI/SubmitScoreWindow/Panel/SubmittedScoreLabel"
@export var submit_warning_label_path: NodePath = ^"../UI/SubmitScoreWindow/Panel/WarningLabel"
@export var submit_confirm_button_path: NodePath = ^"../UI/SubmitScoreWindow/Panel/ButtonRow/ConfirmButton"
@export var submit_cancel_button_path: NodePath = ^"../UI/SubmitScoreWindow/Panel/ButtonRow/CancelButton"

var is_game_over := false
var victory_label: Label
var submit_window: Control
var submit_current_score_label: Label
var submit_cost_label: Label
var submit_target_label: Label
var submit_progress_label: Label
var submit_warning_label: Label
var submit_confirm_button: Button
var submit_cancel_button: Button
var is_changing_scene := false


func _ready():
	Engine.time_scale = 1.0
	victory_label = get_node_or_null(victory_label_path) as Label
	submit_window = get_node_or_null(submit_window_path) as Control
	submit_current_score_label = get_node_or_null(submit_current_score_label_path) as Label
	submit_cost_label = get_node_or_null(submit_cost_label_path) as Label
	submit_target_label = get_node_or_null(submit_target_label_path) as Label
	submit_progress_label = get_node_or_null(submit_progress_label_path) as Label
	submit_warning_label = get_node_or_null(submit_warning_label_path) as Label
	submit_confirm_button = get_node_or_null(submit_confirm_button_path) as Button
	submit_cancel_button = get_node_or_null(submit_cancel_button_path) as Button

	# Start a fresh one-round goal only once. Returning from minigames keeps the
	# same autoload round state until the target has been reached.
	SaveManager.ensure_round_started(level_target_score)
	if not SaveManager.round_completed.is_connected(_on_round_completed):
		SaveManager.round_completed.connect(_on_round_completed)
	if not SaveManager.score_changed.is_connected(_on_score_changed):
		SaveManager.score_changed.connect(_on_score_changed)
	if not SaveManager.round_score_changed.is_connected(_on_round_score_changed):
		SaveManager.round_score_changed.connect(_on_round_score_changed)
	if not SaveManager.submit_failed.is_connected(_on_submit_failed):
		SaveManager.submit_failed.connect(_on_submit_failed)
	_setup_submit_window()
	_update_victory_state()

	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("died"):
		player.died.connect(_on_player_died)


func _exit_tree() -> void:
	if SaveManager.round_completed.is_connected(_on_round_completed):
		SaveManager.round_completed.disconnect(_on_round_completed)
	if SaveManager.score_changed.is_connected(_on_score_changed):
		SaveManager.score_changed.disconnect(_on_score_changed)
	if SaveManager.round_score_changed.is_connected(_on_round_score_changed):
		SaveManager.round_score_changed.disconnect(_on_round_score_changed)
	if SaveManager.submit_failed.is_connected(_on_submit_failed):
		SaveManager.submit_failed.disconnect(_on_submit_failed)


func add_point():
	# Coin pickups are score pickups. Tune this value per level in the inspector.
	SaveManager.add_score(pickup_score_reward)


func spend_score_for_purchase(cost: int = -1) -> bool:
	var final_cost := purchase_score_cost if cost < 0 else cost
	return SaveManager.spend_score(final_cost)


func _on_player_died(_source: Node = null) -> void:
	if is_game_over:
		return

	is_game_over = true
	print("You died!")
	Engine.time_scale = death_time_scale

	await get_tree().create_timer(restart_delay, true, false, true).timeout

	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _on_round_completed(current_score: int, current_target_score: int) -> void:
	_go_to_win_scene(current_score, current_target_score)
	_hide_submit_window()


func _on_score_changed(_new_score: int) -> void:
	_update_submit_window_text()


func _on_round_score_changed(_current_score: int, _current_target_score: int) -> void:
	_update_submit_window_text()


func _setup_submit_window() -> void:
	if submit_window != null:
		submit_window.visible = false

	if submit_warning_label != null:
		submit_warning_label.visible = false

	if submit_confirm_button != null and not submit_confirm_button.pressed.is_connected(_on_submit_confirm_pressed):
		submit_confirm_button.pressed.connect(_on_submit_confirm_pressed)

	if submit_cancel_button != null and not submit_cancel_button.pressed.is_connected(_on_submit_cancel_pressed):
		submit_cancel_button.pressed.connect(_on_submit_cancel_pressed)

	_update_submit_window_text()


func open_submit_window() -> void:
	if submit_window == null:
		return

	_update_submit_window_text()
	if submit_warning_label != null:
		submit_warning_label.visible = false
	submit_window.visible = true


func _hide_submit_window() -> void:
	if submit_window != null:
		submit_window.visible = false


func _update_submit_window_text() -> void:
	if submit_current_score_label != null:
		submit_current_score_label.text = "Current Score: %d" % SaveManager.get_score()
	if submit_cost_label != null:
		submit_cost_label.text = "Required Submit Score: %d" % submit_score_cost
	if submit_target_label != null:
		submit_target_label.text = "Level Target Score: %d" % SaveManager.get_target_score()
	if submit_progress_label != null:
		submit_progress_label.text = "Submitted Score: %d / %d" % [SaveManager.get_round_score(), SaveManager.get_target_score()]


func _on_submit_confirm_pressed() -> void:
	if SaveManager.submit_score(submit_score_cost):
		if submit_warning_label != null:
			submit_warning_label.visible = false
		if not SaveManager.is_round_completed():
			_hide_submit_window()


func _on_submit_cancel_pressed() -> void:
	_hide_submit_window()


func _on_submit_failed(message: String) -> void:
	if submit_warning_label == null:
		return

	submit_warning_label.text = message
	submit_warning_label.visible = true


func _update_victory_state() -> void:
	if SaveManager.is_round_completed():
		_go_to_win_scene(SaveManager.get_round_score(), SaveManager.get_target_score())
	elif victory_label != null:
		victory_label.visible = false


func _go_to_win_scene(current_score: int, current_target_score: int) -> void:
	if is_changing_scene:
		return

	is_game_over = true
	_stop_player_for_victory()
	_hide_submit_window()

	if win_scene_path.is_empty():
		_show_victory(current_score, current_target_score)
		return

	is_changing_scene = true
	Engine.time_scale = 1.0
	_change_to_win_scene.call_deferred()


func _change_to_win_scene() -> void:
	var error := get_tree().change_scene_to_file(win_scene_path)
	if error != OK:
		push_error("GameManager could not change to win scene: " + win_scene_path)
		is_changing_scene = false
		_show_victory(SaveManager.get_round_score(), SaveManager.get_target_score())


func _show_victory(current_score: int, current_target_score: int) -> void:
	if victory_label == null:
		return

	is_game_over = true
	_stop_player_for_victory()
	victory_label.text = "Victory! Goal Completed: %d / %d" % [current_score, current_target_score]
	victory_label.visible = true


func _stop_player_for_victory() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO
	player.set_physics_process(false)
