extends Node

@export var restart_delay := 0.6
@export var death_time_scale := 0.5
@export var pickup_score_reward := 1
@export var level_target_score := 30
@export var submit_score_cost := 10
@export var purchase_score_cost := 5
@export var final_reveal_delay := 2.4
@export_file("*.tscn") var win_scene_path := "res://scenes/win_scene.tscn"
@export var victory_label_path: NodePath = ^"../UI/VictoryLabel"
@export var round_progress_label_path: NodePath = ^"../UI/RoundProgressPanel/Content/RoundProgressLabel"
@export var progress_toast_label_path: NodePath = ^"../UI/ProgressToast"
@export var submit_window_path: NodePath = ^"../UI/SubmitScoreWindow"
@export var submit_current_score_label_path: NodePath = ^"../UI/SubmitScoreWindow/Panel/CurrentScoreLabel"
@export var submit_cost_label_path: NodePath = ^"../UI/SubmitScoreWindow/Panel/SubmitCostLabel"
@export var submit_target_label_path: NodePath = ^"../UI/SubmitScoreWindow/Panel/TargetScoreLabel"
@export var submit_progress_label_path: NodePath = ^"../UI/SubmitScoreWindow/Panel/SubmittedScoreLabel"
@export var submit_warning_label_path: NodePath = ^"../UI/SubmitScoreWindow/Panel/WarningLabel"
@export var submit_confirm_button_path: NodePath = ^"../UI/SubmitScoreWindow/Panel/ButtonRow/ConfirmButton"
@export var submit_cancel_button_path: NodePath = ^"../UI/SubmitScoreWindow/Panel/ButtonRow/CancelButton"
@export var submit_score_button_path: NodePath = ^"../UI/SubmitScoreButton"
@export var post_round_choice_path: NodePath = ^"../UI/PostRoundChoice"
@export var final_cleanup_panel_path: NodePath = ^"../UI/FinalCleanupPanel"
@export var final_cleanup_status_path: NodePath = ^"../UI/FinalCleanupPanel/Panel/StatusLabel"
@export var finish_cleanup_button_path: NodePath = ^"../UI/FinalCleanupPanel/Panel/FinishButton"

var is_game_over := false
var victory_label: Label
var round_progress_label: Label
var progress_toast_label: Label
var submit_window: Control
var submit_current_score_label: Label
var submit_cost_label: Label
var submit_target_label: Label
var submit_progress_label: Label
var submit_warning_label: Label
var submit_confirm_button: Button
var submit_cancel_button: Button
var submit_score_button: Button
var post_round_choice: Control
var final_cleanup_panel: Control
var final_cleanup_status: Label
var finish_cleanup_button: Button
var is_changing_scene := false
var progress_toast_tween: Tween
var is_awaiting_round_choice := false
var pending_choice_round := 0
var is_final_result_sequence_playing := false


func _ready():
	Engine.time_scale = 1.0
	victory_label = get_node_or_null(victory_label_path) as Label
	round_progress_label = get_node_or_null(round_progress_label_path) as Label
	progress_toast_label = get_node_or_null(progress_toast_label_path) as Label
	submit_window = get_node_or_null(submit_window_path) as Control
	submit_current_score_label = get_node_or_null(submit_current_score_label_path) as Label
	submit_cost_label = get_node_or_null(submit_cost_label_path) as Label
	submit_target_label = get_node_or_null(submit_target_label_path) as Label
	submit_progress_label = get_node_or_null(submit_progress_label_path) as Label
	submit_warning_label = get_node_or_null(submit_warning_label_path) as Label
	submit_confirm_button = get_node_or_null(submit_confirm_button_path) as Button
	submit_cancel_button = get_node_or_null(submit_cancel_button_path) as Button
	submit_score_button = get_node_or_null(submit_score_button_path) as Button
	post_round_choice = get_node_or_null(post_round_choice_path) as Control
	final_cleanup_panel = get_node_or_null(final_cleanup_panel_path) as Control
	final_cleanup_status = get_node_or_null(final_cleanup_status_path) as Label
	finish_cleanup_button = get_node_or_null(finish_cleanup_button_path) as Button

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
	if not SaveManager.progression_changed.is_connected(_on_progression_changed):
		SaveManager.progression_changed.connect(_on_progression_changed)
	if not SaveManager.trash_state_changed.is_connected(_on_trash_state_changed):
		SaveManager.trash_state_changed.connect(_on_trash_state_changed)
	if post_round_choice != null and post_round_choice.has_signal("choice_selected"):
		post_round_choice.connect("choice_selected", _on_round_choice_selected)
	if finish_cleanup_button != null:
		finish_cleanup_button.pressed.connect(_on_finish_cleanup_pressed)
	_setup_submit_window()
	if final_cleanup_panel != null:
		final_cleanup_panel.visible = false
	_update_round_progress_label()
	_update_victory_state()
	if SaveManager.has_pending_round_choice():
		_show_pending_round_choice()

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
	if SaveManager.progression_changed.is_connected(_on_progression_changed):
		SaveManager.progression_changed.disconnect(_on_progression_changed)
	if SaveManager.trash_state_changed.is_connected(_on_trash_state_changed):
		SaveManager.trash_state_changed.disconnect(_on_trash_state_changed)


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
	if is_changing_scene:
		return
	if SaveManager.has_pending_round_choice():
		_show_pending_round_choice()
		return

	_handle_final_round_ready(current_score, current_target_score)


func _on_score_changed(_new_score: int) -> void:
	_update_submit_window_text()


func _on_round_score_changed(_current_score: int, _current_target_score: int) -> void:
	_update_submit_window_text()
	_update_round_progress_label()


func _on_progression_changed(completed: int, required: int, cleared: bool) -> void:
	_update_round_progress_label()
	if SaveManager.has_pending_round_choice():
		_show_pending_round_choice()
		return
	if not cleared and completed > 0:
		_show_progress_toast(
			"ROUND %d / %d COMPLETE\nMore empty bottles have appeared in the plaza." % [completed, required]
		)


func _on_trash_state_changed(
	_total_generated: int,
	_total_cleaned: int,
	_carried: int,
	_cleanup_enabled: bool
) -> void:
	_update_final_cleanup_status()


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
	if submit_window == null or SaveManager.is_game_cleared() or is_awaiting_round_choice:
		return

	_update_submit_window_text()
	if submit_warning_label != null:
		submit_warning_label.visible = false
	submit_window.visible = true
	var tutorial_manager := get_tree().get_first_node_in_group("main_tutorial_manager")
	if tutorial_manager != null and tutorial_manager.has_method("request_score_submission_tutorial"):
		tutorial_manager.call("request_score_submission_tutorial")


func _hide_submit_window() -> void:
	if submit_window != null:
		submit_window.visible = false


func _update_submit_window_text() -> void:
	if submit_current_score_label != null:
		submit_current_score_label.text = "Current Fan Score: %d" % SaveManager.get_score()
	if submit_cost_label != null:
		submit_cost_label.text = "Round Stamp Cost: %d" % submit_score_cost
	if submit_target_label != null:
		submit_target_label.text = "Event Goal: %d rounds" % SaveManager.get_required_rounds()
	if submit_progress_label != null:
		submit_progress_label.text = "Progress: %d / %d rounds  •  %d / %d score" % [
			SaveManager.get_rounds_completed(),
			SaveManager.get_required_rounds(),
			SaveManager.get_round_score(),
			SaveManager.get_target_score()
		]


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
	if SaveManager.is_game_cleared() and not SaveManager.has_pending_round_choice():
		var saved_result := SaveManager.get_final_environment_result()
		if saved_result != SaveManager.FINAL_RESULT_NONE:
			_go_to_win_scene(SaveManager.get_round_score(), SaveManager.get_target_score())
		elif SaveManager.is_cleanup_mode_enabled() and _is_final_cleanup_incomplete():
			_enter_final_cleanup()
		else:
			_evaluate_and_show_final_result()
	elif victory_label != null:
		victory_label.visible = false
	if progress_toast_label != null:
		progress_toast_label.visible = false


func _update_round_progress_label() -> void:
	if round_progress_label == null:
		return

	var completed := SaveManager.get_rounds_completed()
	var required := SaveManager.get_required_rounds()
	var waste_text := "Garden is tidy"
	match completed:
		1:
			waste_text = "A little litter has appeared"
		2:
			waste_text = "Bottle waste is building up"
		3:
			waste_text = "Final result pending"
	round_progress_label.text = "EVENT ROUNDS  %d / %d\n%s" % [completed, required, waste_text]


func _show_progress_toast(message: String) -> void:
	if progress_toast_label == null:
		return

	if progress_toast_tween != null and progress_toast_tween.is_valid():
		progress_toast_tween.kill()
	progress_toast_label.text = message
	progress_toast_label.modulate = Color.WHITE
	progress_toast_label.visible = true
	progress_toast_tween = create_tween()
	progress_toast_tween.tween_interval(2.0)
	progress_toast_tween.tween_property(progress_toast_label, "modulate:a", 0.0, 0.45)
	progress_toast_tween.tween_callback(progress_toast_label.hide)


func _show_pending_round_choice() -> void:
	if post_round_choice == null:
		push_error("GameManager cannot show the required post-round choice overlay.")
		return

	var choice_round := SaveManager.get_pending_choice_round()
	if choice_round <= 0:
		return

	is_awaiting_round_choice = true
	pending_choice_round = choice_round
	_hide_submit_window()
	if submit_score_button != null:
		submit_score_button.disabled = true
	_stop_player_for_victory()
	post_round_choice.call("present", choice_round, SaveManager.get_required_rounds())


func _on_round_choice_selected(choice: String) -> void:
	if not is_awaiting_round_choice:
		return

	if not SaveManager.record_round_choice(choice, pending_choice_round):
		post_round_choice.call("present", pending_choice_round, SaveManager.get_required_rounds())
		return

	is_awaiting_round_choice = false
	pending_choice_round = 0
	post_round_choice.call("hide_choice")

	# This normally advances one round at a time. The extra check also migrates
	# an older save cleanly if it already contains multiple completed rounds.
	if SaveManager.has_pending_round_choice():
		_show_pending_round_choice()
		return

	if SaveManager.is_game_cleared():
		if choice == SaveManager.CHOICE_CLEANUP and _is_final_cleanup_incomplete():
			_enter_final_cleanup()
		else:
			_evaluate_and_show_final_result()
		return

	_resume_player_after_choice()
	if submit_score_button != null:
		submit_score_button.disabled = false
	_show_progress_toast(
		"ROUND %d / %d COMPLETE" % [
			SaveManager.get_rounds_completed(),
			SaveManager.get_required_rounds()
		]
	)


func _resume_player_after_choice() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		player.set_physics_process(true)


func _handle_final_round_ready(current_score: int, current_target_score: int) -> void:
	if SaveManager.is_cleanup_mode_enabled() and _is_final_cleanup_incomplete():
		_enter_final_cleanup()
		return
	_evaluate_and_show_final_result(current_score, current_target_score)


func _is_final_cleanup_incomplete() -> bool:
	return SaveManager.get_total_trash_cleaned() < SaveManager.get_total_trash_generated()


func _enter_final_cleanup() -> void:
	is_game_over = false
	_hide_submit_window()
	if submit_score_button != null:
		submit_score_button.disabled = true
	if victory_label != null:
		victory_label.visible = false
	if final_cleanup_panel != null:
		final_cleanup_panel.visible = true
	_update_final_cleanup_status()
	_resume_player_after_choice()


func _update_final_cleanup_status() -> void:
	if final_cleanup_status == null:
		return
	final_cleanup_status.text = "Trash Cleaned: %d / %d    Carrying: %d" % [
		SaveManager.get_total_trash_cleaned(),
		SaveManager.get_total_trash_generated(),
		SaveManager.get_carried_trash()
	]


func _on_finish_cleanup_pressed() -> void:
	if not SaveManager.is_game_cleared() or is_final_result_sequence_playing:
		return
	_evaluate_and_show_final_result()


func _evaluate_and_show_final_result(
	current_score: int = -1,
	current_target_score: int = -1
) -> void:
	if is_final_result_sequence_playing or is_changing_scene:
		return

	var result := SaveManager.evaluate_final_environment_result()
	if result == SaveManager.FINAL_RESULT_NONE:
		return

	is_final_result_sequence_playing = true
	is_game_over = true
	_stop_player_for_victory()
	_hide_submit_window()
	if final_cleanup_panel != null:
		final_cleanup_panel.visible = false

	if result == SaveManager.FINAL_RESULT_WASTE:
		_focus_camera_on_final_waste()

	if victory_label != null:
		var result_heading := (
			"CLEAN RESULT"
			if result == SaveManager.FINAL_RESULT_CLEAN
			else "WASTE RESULT"
		)
		victory_label.text = "%s\nTrash Cleaned: %d / %d" % [
			result_heading,
			SaveManager.get_total_trash_cleaned(),
			SaveManager.get_total_trash_generated()
		]
		victory_label.visible = true

	await get_tree().create_timer(final_reveal_delay).timeout
	if not is_inside_tree():
		return
	var final_score := SaveManager.get_round_score() if current_score < 0 else current_score
	var final_target := SaveManager.get_target_score() if current_target_score < 0 else current_target_score
	_go_to_win_scene(final_score, final_target)


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


func _focus_camera_on_final_waste() -> void:
	var dump_area := get_tree().get_first_node_in_group("garbage_dump_area") as Node2D
	var camera := get_viewport().get_camera_2d()
	if dump_area == null or camera == null:
		return
	var camera_parent := camera.get_parent() as Node2D
	if camera_parent == null:
		return

	# Pan to the newly revealed backstage area without moving or replacing the
	# player. The camera returns to normal when the next scene loads.
	var target_global_position := dump_area.global_position + Vector2(0.0, 120.0)
	var target_local_position := camera_parent.to_local(target_global_position)
	var camera_tween := create_tween()
	camera_tween.set_trans(Tween.TRANS_QUAD)
	camera_tween.set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(camera, "position", target_local_position, 0.85)
