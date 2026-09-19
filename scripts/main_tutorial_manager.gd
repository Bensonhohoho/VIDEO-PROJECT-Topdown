extends Node

@export var overlay_path: NodePath = ^"../UI/TutorialOverlay"
@export var objective_hud_path: NodePath = ^"../UI/ObjectiveHUD"
@export var objective_text_path: NodePath = ^"../UI/ObjectiveHUD/Margin/Rows/ObjectiveText"
@export var post_round_choice_path: NodePath = ^"../UI/PostRoundChoice"
@export var submit_score_button_path: NodePath = ^"../UI/SubmitScoreButton"
@export var queue_guide_path: NodePath = ^"../TutorialGuides/QueueEntranceGuide"
@export var trash_bin_guide_path: NodePath = ^"../TutorialGuides/TrashBinGuide"
@export var movement_completion_distance := 48.0

var overlay: Control
var objective_hud: Control
var objective_text: Label
var post_round_choice: Control
var submit_score_button: Button
var queue_guide: Node2D
var trash_bin_guide: Node2D
var player: Node2D

var pending_tutorials: Array[Dictionary] = []
var current_tutorial: Dictionary = {}
var movement_start_position := Vector2.ZERO
var player_was_frozen := false
var score_tutorial_presented_this_session := false


func _ready() -> void:
	add_to_group("main_tutorial_manager")
	overlay = get_node_or_null(overlay_path) as Control
	objective_hud = get_node_or_null(objective_hud_path) as Control
	objective_text = get_node_or_null(objective_text_path) as Label
	post_round_choice = get_node_or_null(post_round_choice_path) as Control
	submit_score_button = get_node_or_null(submit_score_button_path) as Button
	queue_guide = get_node_or_null(queue_guide_path) as Node2D
	trash_bin_guide = get_node_or_null(trash_bin_guide_path) as Node2D
	player = get_tree().get_first_node_in_group("player") as Node2D

	if overlay != null and overlay.has_signal("dismissed"):
		overlay.connect("dismissed", _on_overlay_dismissed)
	_connect_save_signals()
	_queue_initial_tutorials()
	_update_objective()
	_try_show_next.call_deferred()


func _exit_tree() -> void:
	if SaveManager.score_changed.is_connected(_on_score_changed):
		SaveManager.score_changed.disconnect(_on_score_changed)
	if SaveManager.score_submitted.is_connected(_on_score_submitted):
		SaveManager.score_submitted.disconnect(_on_score_submitted)
	if SaveManager.progression_changed.is_connected(_on_progression_changed):
		SaveManager.progression_changed.disconnect(_on_progression_changed)
	if SaveManager.trash_state_changed.is_connected(_on_trash_state_changed):
		SaveManager.trash_state_changed.disconnect(_on_trash_state_changed)
	if SaveManager.round_choice_recorded.is_connected(_on_round_choice_recorded):
		SaveManager.round_choice_recorded.disconnect(_on_round_choice_recorded)
	if SaveManager.tutorial_progress_changed.is_connected(_on_tutorial_progress_changed):
		SaveManager.tutorial_progress_changed.disconnect(_on_tutorial_progress_changed)


func _process(_delta: float) -> void:
	if not current_tutorial.is_empty() \
		and str(current_tutorial.get("id", "")) == "movement" \
		and player != null \
		and player.global_position.distance_to(movement_start_position) >= movement_completion_distance:
		overlay.call("dismiss")

	if current_tutorial.is_empty() and not pending_tutorials.is_empty():
		_try_show_next()


func request_score_submission_tutorial() -> void:
	if SaveManager.is_tutorial_seen("score_submission") or score_tutorial_presented_this_session:
		return
	score_tutorial_presented_this_session = true
	_request_tutorial(
		"score_submission_info",
		"SCORE SUBMISSION",
		"Submit your collected points here to progress through the event.",
		"Continue",
		true,
		false
	)


func _connect_save_signals() -> void:
	if not SaveManager.score_changed.is_connected(_on_score_changed):
		SaveManager.score_changed.connect(_on_score_changed)
	if not SaveManager.score_submitted.is_connected(_on_score_submitted):
		SaveManager.score_submitted.connect(_on_score_submitted)
	if not SaveManager.progression_changed.is_connected(_on_progression_changed):
		SaveManager.progression_changed.connect(_on_progression_changed)
	if not SaveManager.trash_state_changed.is_connected(_on_trash_state_changed):
		SaveManager.trash_state_changed.connect(_on_trash_state_changed)
	if not SaveManager.round_choice_recorded.is_connected(_on_round_choice_recorded):
		SaveManager.round_choice_recorded.connect(_on_round_choice_recorded)
	if not SaveManager.tutorial_progress_changed.is_connected(_on_tutorial_progress_changed):
		SaveManager.tutorial_progress_changed.connect(_on_tutorial_progress_changed)


func _queue_initial_tutorials() -> void:
	if not SaveManager.is_tutorial_seen("movement"):
		movement_start_position = player.global_position if player != null else Vector2.ZERO
		_request_tutorial(
			"movement",
			"WELCOME TO THE IDOL EVENT",
			"Explore the venue, complete activities, and earn points to progress through the event.\n\nMOVE\nUse WASD or Arrow Keys to move.",
			"Continue",
			false,
			true
		)
	if SaveManager.get_minigames_completed() > 0 and not SaveManager.is_tutorial_seen("points_earned"):
		_request_points_earned_tutorial()
	if SaveManager.get_rounds_completed() >= 1:
		_request_first_round_tutorials()
	if SaveManager.get_round_choices().has(SaveManager.CHOICE_CLEANUP) \
		and not SaveManager.is_tutorial_seen("cleanup"):
		_request_cleanup_tutorial()


func _request_points_earned_tutorial() -> void:
	_request_tutorial(
		"points_earned",
		"POINTS EARNED",
		"You earned points by completing the activity.",
		"Continue",
		true,
		true
	)


func _request_first_round_tutorials() -> void:
	if not SaveManager.is_tutorial_seen("round_progress"):
		_request_tutorial(
			"round_progress",
			"ROUND 1 COMPLETE",
			"1 / 3\n\nComplete three rounds to finish the event.",
			"Continue",
			true,
			true
		)
	if SaveManager.get_total_trash_generated() > 0 and not SaveManager.is_tutorial_seen("trash"):
		_request_tutorial(
			"trash",
			"WASTE LEFT BEHIND",
			"Activities at the event have left litter around the plaza.",
			"Continue",
			true,
			true
		)


func _request_cleanup_tutorial() -> void:
	_request_tutorial(
		"cleanup",
		"CLEANUP MODE",
		"Walk into litter to pick it up.\n\nYour carried trash will appear on the HUD.\n\nBring collected trash to the trash bin at the edge of the plaza.",
		"Start Cleaning",
		true,
		true
	)


func _request_tutorial(
	tutorial_id: String,
	title: String,
	body: String,
	button_text: String,
	freeze_player: bool,
	mark_on_dismiss: bool
) -> void:
	if mark_on_dismiss and SaveManager.is_tutorial_seen(tutorial_id):
		return
	if not current_tutorial.is_empty() and str(current_tutorial.get("id", "")) == tutorial_id:
		return
	for queued_tutorial in pending_tutorials:
		if str(queued_tutorial.get("id", "")) == tutorial_id:
			return
	pending_tutorials.append({
		"id": tutorial_id,
		"title": title,
		"body": body,
		"button_text": button_text,
		"freeze_player": freeze_player,
		"mark_on_dismiss": mark_on_dismiss
	})
	_try_show_next.call_deferred()


func _try_show_next() -> void:
	if overlay == null or not current_tutorial.is_empty() or pending_tutorials.is_empty():
		return
	if post_round_choice != null and post_round_choice.visible:
		return

	current_tutorial = pending_tutorials.pop_front()
	var should_freeze := bool(current_tutorial.get("freeze_player", true))
	player_was_frozen = false
	if should_freeze and player != null and player.is_physics_processing():
		player_was_frozen = true
		player.set_physics_process(false)
	overlay.call(
		"present",
		str(current_tutorial.get("id", "")),
		str(current_tutorial.get("title", "")),
		str(current_tutorial.get("body", "")),
		str(current_tutorial.get("button_text", "Continue"))
	)


func _on_overlay_dismissed(tutorial_id: String) -> void:
	if current_tutorial.is_empty() or tutorial_id != str(current_tutorial.get("id", "")):
		return

	if tutorial_id == "movement":
		SaveManager.mark_tutorial_seen("intro")
		SaveManager.mark_tutorial_seen("movement")
	elif bool(current_tutorial.get("mark_on_dismiss", true)):
		SaveManager.mark_tutorial_seen(tutorial_id)

	if player_was_frozen and player != null:
		player.set_physics_process(true)
	player_was_frozen = false
	current_tutorial.clear()
	_update_objective()
	_try_show_next.call_deferred()


func _on_score_changed(_new_score: int) -> void:
	_update_objective()


func _on_score_submitted(
	_amount: int,
	_current_score: int,
	_submitted_score: int,
	_target_score: int
) -> void:
	SaveManager.mark_tutorial_seen("score_submission")
	_update_objective()


func _on_progression_changed(completed: int, _required: int, _cleared: bool) -> void:
	if completed >= 1:
		_request_first_round_tutorials()
	_update_objective()


func _on_trash_state_changed(
	generated: int,
	cleaned: int,
	_carried: int,
	_cleanup_enabled: bool
) -> void:
	if generated > 0 and not SaveManager.is_tutorial_seen("trash"):
		_request_first_round_tutorials()
	if cleaned > 0:
		SaveManager.mark_tutorial_seen("first_deposit")
	_update_objective()


func _on_round_choice_recorded(_round_number: int, choice: String) -> void:
	if choice == SaveManager.CHOICE_CLEANUP and not SaveManager.is_tutorial_seen("cleanup"):
		_request_cleanup_tutorial()
	_update_objective()


func _on_tutorial_progress_changed(_tutorial_id: String, _seen: bool) -> void:
	_update_objective()


func _update_objective() -> void:
	if objective_hud == null or objective_text == null:
		return

	var movement_complete := SaveManager.is_tutorial_seen("movement")
	objective_hud.visible = movement_complete
	if not movement_complete:
		_update_guides()
		return

	var generated := SaveManager.get_total_trash_generated()
	var cleaned := SaveManager.get_total_trash_cleaned()
	var carried := SaveManager.get_carried_trash()
	var remaining := SaveManager.get_remaining_trash_count()

	if SaveManager.is_game_cleared() \
		and SaveManager.get_final_environment_result() == SaveManager.FINAL_RESULT_NONE:
		objective_text.text = "Finish cleanup and review the result."
	elif carried > 0:
		objective_text.text = "Bring trash to the bin.\nCarrying: %d" % carried
	elif SaveManager.is_cleanup_mode_enabled() and remaining > 0:
		objective_text.text = "Clean the remaining trash.\n%d / %d cleaned" % [cleaned, generated]
	elif SaveManager.is_cleanup_mode_enabled() and generated > 0 and cleaned == generated:
		objective_text.text = "Continue the event."
	elif SaveManager.get_score() >= _get_submit_cost():
		objective_text.text = "Submit your score."
	elif SaveManager.get_minigames_completed() == 0:
		if SaveManager.is_tutorial_seen("queue_entrance"):
			objective_text.text = "Enter the queue.\nPress W / ↑"
		else:
			objective_text.text = "Find the queue entrance."
	else:
		objective_text.text = "Complete Round %d.\nRound %d / %d" % [
			SaveManager.get_current_playthrough_number(),
			SaveManager.get_rounds_completed(),
			SaveManager.get_required_rounds()
		]
	_update_guides()


func _update_guides() -> void:
	if queue_guide != null:
		queue_guide.visible = SaveManager.is_tutorial_seen("movement") \
			and not SaveManager.is_tutorial_seen("queue_entrance") \
			and SaveManager.get_minigames_completed() == 0
	if trash_bin_guide != null:
		trash_bin_guide.visible = SaveManager.is_tutorial_seen("cleanup") \
			and not SaveManager.is_tutorial_seen("first_deposit") \
			and SaveManager.is_cleanup_mode_enabled() \
			and SaveManager.get_total_trash_generated() > 0
	if submit_score_button != null:
		var should_highlight := SaveManager.get_score() >= _get_submit_cost() \
			and not SaveManager.is_tutorial_seen("score_submission")
		submit_score_button.modulate = Color("#fff0aa") if should_highlight else Color.WHITE


func _get_submit_cost() -> int:
	var game_manager := get_node_or_null("../GameManager")
	if game_manager != null:
		return int(game_manager.get("submit_score_cost"))
	return 10
