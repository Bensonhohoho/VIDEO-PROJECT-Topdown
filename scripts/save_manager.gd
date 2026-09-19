extends Node

signal score_changed(new_score: int)
signal score_added(amount: int, new_score: int)
signal score_spent(amount: int, new_score: int)
signal round_score_changed(current_score: int, target_score: int)
signal round_completed(current_score: int, target_score: int)
signal progression_changed(rounds_completed: int, required_rounds: int, game_cleared: bool)
signal submit_failed(message: String)
signal score_submitted(amount: int, current_score: int, submitted_score: int, target_score: int)
signal queue_difficulty_changed(current_queue_level: int)
signal round_choice_recorded(round_number: int, choice: String)
signal trash_state_changed(
	total_generated: int,
	total_cleaned: int,
	carried: int,
	cleanup_enabled: bool
)
signal final_environment_result_changed(result: String)
signal tutorial_progress_changed(tutorial_id: String, seen: bool)

const SAVE_PATH := "user://save_data.json"
const REQUIRED_ROUNDS := 3
const CHOICE_KEEP_GOING := "keep_going"
const CHOICE_CLEANUP := "cleanup"
const FINAL_RESULT_NONE := "none"
const FINAL_RESULT_CLEAN := "clean"
const FINAL_RESULT_WASTE := "waste"
const TUTORIAL_IDS: Array[String] = [
	"intro",
	"movement",
	"queue_entrance",
	"queue_minigame",
	"points_earned",
	"score_submission",
	"round_progress",
	"trash",
	"cleanup",
	"first_deposit"
]
const ROUND_1_TRASH_IDS: Array[String] = [
	"round1_spawn01",
	"round1_spawn02",
	"round1_spawn03",
	"round1_spawn04",
	"round1_spawn05"
]
const ROUND_2_TRASH_IDS: Array[String] = [
	"round2_spawn01",
	"round2_spawn02",
	"round2_spawn03",
	"round2_spawn04",
	"round2_spawn05",
	"round2_spawn06",
	"round2_spawn07"
]

var total_score := 0
var current_round_score := 0
var target_score := 30
var rounds_completed := 0
var game_cleared := false
var minigames_completed_this_round := 0
var queue_attempt_count := 0
var current_queue_level := 0
var queue_fail_count := 0
var round_started := false
var round_is_completed := false
var keep_going_count := 0
var cleanup_count := 0
var round_choices: Array[String] = []
var total_trash_generated := 0
var total_trash_cleaned := 0
var carried_trash := 0
var cleanup_mode := false
var collected_trash_ids: Array[String] = []
var final_environment_result := FINAL_RESULT_NONE
var tutorial_flags: Dictionary = {}


func _ready() -> void:
	load_game()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_reset_runtime_state(false)
		_emit_current_state()
		return

	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		push_error("SaveManager could not open save file for reading.")
		_reset_runtime_state(false)
		_emit_current_state()
		return

	var parsed_data = JSON.parse_string(save_file.get_as_text())
	if not (parsed_data is Dictionary):
		push_error("SaveManager found invalid save data.")
		_reset_runtime_state(false)
		_emit_current_state()
		return

	var save_data := parsed_data as Dictionary
	total_score = maxi(0, int(save_data.get("total_score", 0)))
	target_score = maxi(1, int(save_data.get("target_score", 30)))
	current_round_score = clampi(int(save_data.get("current_round_score", 0)), 0, target_score)
	rounds_completed = clampi(int(save_data.get("rounds_completed", 0)), 0, REQUIRED_ROUNDS)
	game_cleared = bool(save_data.get("game_cleared", false)) or rounds_completed >= REQUIRED_ROUNDS
	minigames_completed_this_round = maxi(0, int(save_data.get("minigames_completed_this_round", 0)))
	queue_attempt_count = maxi(0, int(save_data.get("queue_attempt_count", 0)))
	current_queue_level = maxi(0, int(save_data.get("current_queue_level", 0)))
	queue_fail_count = maxi(0, int(save_data.get("queue_fail_count", 0)))
	round_started = bool(save_data.get("round_started", false)) \
		or total_score > 0 \
		or current_round_score > 0 \
		or rounds_completed > 0 \
		or queue_attempt_count > 0
	round_is_completed = bool(save_data.get("round_is_completed", false)) \
		or current_round_score >= target_score \
		or game_cleared
	_load_round_choices(save_data.get("round_choices", []))
	_load_trash_state(save_data)
	var saved_final_result := str(save_data.get("final_environment_result", FINAL_RESULT_NONE))
	if saved_final_result in [FINAL_RESULT_CLEAN, FINAL_RESULT_WASTE]:
		final_environment_result = saved_final_result
	else:
		final_environment_result = FINAL_RESULT_NONE
	_load_tutorial_flags(save_data.get("tutorial_flags", {}))
	_emit_current_state()


func save_game() -> void:
	var save_data := {
		"total_score": total_score,
		"current_round_score": current_round_score,
		"target_score": target_score,
		"rounds_completed": rounds_completed,
		"game_cleared": game_cleared,
		"minigames_completed_this_round": minigames_completed_this_round,
		"queue_attempt_count": queue_attempt_count,
		"current_queue_level": current_queue_level,
		"queue_fail_count": queue_fail_count,
		"round_started": round_started,
		"round_is_completed": round_is_completed,
		"keep_going_count": keep_going_count,
		"cleanup_count": cleanup_count,
		"round_choices": round_choices,
		"total_trash_generated": total_trash_generated,
		"total_trash_cleaned": total_trash_cleaned,
		"carried_trash": carried_trash,
		"cleanup_mode": cleanup_mode,
		"collected_trash_ids": collected_trash_ids,
		"final_environment_result": final_environment_result,
		"tutorial_flags": tutorial_flags
	}

	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_error("SaveManager could not open save file for writing.")
		return

	save_file.store_string(JSON.stringify(save_data))


func add_score(amount: int) -> void:
	if amount <= 0:
		return

	total_score += amount
	save_game()
	score_changed.emit(total_score)
	score_added.emit(amount, total_score)


func set_score(new_score: int) -> void:
	total_score = maxi(0, new_score)
	save_game()
	score_changed.emit(total_score)


func spend_score(amount: int) -> bool:
	if amount <= 0 or total_score < amount:
		return false

	total_score -= amount
	save_game()
	score_changed.emit(total_score)
	score_spent.emit(amount, total_score)
	return true


func add_queue_reward(score_amount: int) -> void:
	# Queue rewards are awarded only by QueueGameManager.win_minigame().
	add_score(score_amount)


func start_new_round(new_target_score: int = 30) -> void:
	# A "round" save now represents the full three-playthrough event arc.
	_reset_runtime_state(true, new_target_score)
	save_game()
	_emit_current_state()


func ensure_round_started(new_target_score: int = 30) -> void:
	if game_cleared:
		_emit_current_state()
		return

	if round_started:
		target_score = maxi(1, new_target_score)
		current_round_score = mini(current_round_score, target_score)
		save_game()
		_emit_current_state()
		return

	start_new_round(new_target_score)


func add_round_score(amount: int) -> void:
	if amount <= 0 or round_is_completed:
		return

	if not round_started:
		start_new_round(target_score)

	# Legacy helper: keep old callers working by adding score and submitting it.
	add_score(amount)
	submit_score(amount)


func submit_score(amount: int) -> bool:
	if amount <= 0 or round_is_completed or game_cleared:
		return false

	if not round_started:
		start_new_round(target_score)

	if not spend_score(amount):
		submit_failed.emit("Not enough score to submit.")
		return false

	var previous_rounds_completed := rounds_completed
	current_round_score = mini(target_score, current_round_score + amount)
	rounds_completed = maxi(rounds_completed, _get_rounds_earned_from_score())
	game_cleared = rounds_completed >= REQUIRED_ROUNDS
	round_is_completed = game_cleared or current_round_score >= target_score
	var trash_generation_changed := _sync_trash_generation_to_rounds()
	save_game()

	round_score_changed.emit(current_round_score, target_score)
	score_submitted.emit(amount, total_score, current_round_score, target_score)
	if rounds_completed != previous_rounds_completed or game_cleared:
		progression_changed.emit(rounds_completed, REQUIRED_ROUNDS, game_cleared)
	if trash_generation_changed:
		_emit_trash_state()

	if round_is_completed:
		round_completed.emit(current_round_score, target_score)

	return true


func register_queue_success(max_level_count: int) -> void:
	queue_attempt_count += 1
	minigames_completed_this_round += 1
	queue_fail_count = 0
	if max_level_count > 0:
		current_queue_level = clampi(current_queue_level + 1, 0, max_level_count - 1)
	save_game()
	queue_difficulty_changed.emit(current_queue_level)


func register_queue_failure(max_level_count: int, played_level_index: int = -1) -> void:
	queue_attempt_count += 1
	queue_fail_count += 1
	var level_to_fall_back_from := current_queue_level if played_level_index < 0 else played_level_index
	if max_level_count > 0:
		current_queue_level = clampi(level_to_fall_back_from - 1, 0, max_level_count - 1)
	else:
		current_queue_level = maxi(0, level_to_fall_back_from - 1)
	save_game()
	queue_difficulty_changed.emit(current_queue_level)


func get_score() -> int:
	return total_score


func get_round_score() -> int:
	return current_round_score


func get_target_score() -> int:
	return target_score


func get_rounds_completed() -> int:
	return rounds_completed


func get_required_rounds() -> int:
	return REQUIRED_ROUNDS


func get_current_playthrough_number() -> int:
	return mini(REQUIRED_ROUNDS, rounds_completed + 1)


func get_current_round_number() -> int:
	var pending_round := get_pending_choice_round()
	if pending_round > 0:
		return pending_round
	return get_current_playthrough_number()


func get_keep_going_count() -> int:
	return keep_going_count


func get_cleanup_count() -> int:
	return cleanup_count


func get_round_choices() -> Array[String]:
	return round_choices.duplicate()


func get_pending_choice_round() -> int:
	if round_choices.size() >= rounds_completed:
		return 0
	return round_choices.size() + 1


func has_pending_round_choice() -> bool:
	return get_pending_choice_round() > 0


func record_round_choice(choice: String, round_number: int = -1) -> bool:
	if choice != CHOICE_KEEP_GOING and choice != CHOICE_CLEANUP:
		return false

	var pending_round := get_pending_choice_round()
	var requested_round := pending_round if round_number < 0 else round_number
	if pending_round <= 0 or requested_round != pending_round:
		return false

	round_choices.append(choice)
	if choice == CHOICE_KEEP_GOING:
		keep_going_count += 1
	else:
		cleanup_count += 1
	cleanup_mode = choice == CHOICE_CLEANUP
	save_game()
	round_choice_recorded.emit(requested_round, choice)
	_emit_trash_state()
	return true


func get_total_trash_generated() -> int:
	return total_trash_generated


func get_total_trash_cleaned() -> int:
	return total_trash_cleaned


func get_carried_trash() -> int:
	return carried_trash


func is_cleanup_mode_enabled() -> bool:
	return cleanup_mode


func get_remaining_trash_count() -> int:
	return maxi(0, total_trash_generated - total_trash_cleaned - carried_trash)


func is_trash_generated(trash_id: String) -> bool:
	return trash_id in _get_generated_trash_ids()


func is_trash_collected(trash_id: String) -> bool:
	return trash_id in collected_trash_ids


func collect_trash(trash_id: String) -> bool:
	if not cleanup_mode or not is_trash_generated(trash_id) or is_trash_collected(trash_id):
		return false

	collected_trash_ids.append(trash_id)
	carried_trash += 1
	_reconcile_trash_accounting()
	save_game()
	_emit_trash_state()
	return true


func deposit_carried_trash() -> int:
	if carried_trash <= 0:
		return 0

	var deposited := carried_trash
	total_trash_cleaned += deposited
	carried_trash = 0
	_reconcile_trash_accounting()
	save_game()
	_emit_trash_state()
	return deposited


func get_final_environment_result() -> String:
	return final_environment_result


func evaluate_final_environment_result() -> String:
	if not game_cleared:
		return FINAL_RESULT_NONE
	if final_environment_result != FINAL_RESULT_NONE:
		return final_environment_result

	if total_trash_cleaned == total_trash_generated:
		final_environment_result = FINAL_RESULT_CLEAN
	else:
		final_environment_result = FINAL_RESULT_WASTE

	save_game()
	final_environment_result_changed.emit(final_environment_result)
	return final_environment_result


func get_round_level_index() -> int:
	return current_queue_level


func get_queue_attempt_count() -> int:
	return queue_attempt_count


func get_minigames_completed() -> int:
	return minigames_completed_this_round


func is_tutorial_seen(tutorial_id: String) -> bool:
	return bool(tutorial_flags.get(tutorial_id, false))


func mark_tutorial_seen(tutorial_id: String) -> void:
	if tutorial_id not in TUTORIAL_IDS or is_tutorial_seen(tutorial_id):
		return
	tutorial_flags[tutorial_id] = true
	save_game()
	tutorial_progress_changed.emit(tutorial_id, true)


func reset_tutorial_progress() -> void:
	_initialize_tutorial_flags()
	save_game()
	for tutorial_id in TUTORIAL_IDS:
		tutorial_progress_changed.emit(tutorial_id, false)


func get_queue_fail_count() -> int:
	return queue_fail_count


func reset_queue_fail_count() -> void:
	queue_fail_count = 0
	save_game()


func is_round_completed() -> bool:
	return round_is_completed


func is_game_cleared() -> bool:
	return game_cleared


func has_continue_data() -> bool:
	return total_score > 0 \
		or current_round_score > 0 \
		or rounds_completed > 0 \
		or queue_attempt_count > 0 \
		or total_trash_generated > 0 \
		or carried_trash > 0 \
		or game_cleared


func reset_save() -> void:
	reset_progress_for_testing(false)


func reset_progress_for_testing(keep_total_score: bool = false) -> void:
	_reset_runtime_state(not keep_total_score, target_score)
	save_game()
	_emit_current_state()


func _get_rounds_earned_from_score() -> int:
	var score_per_round := maxi(1, ceili(float(target_score) / float(REQUIRED_ROUNDS)))
	if current_round_score >= target_score:
		return REQUIRED_ROUNDS
	return clampi(floori(float(current_round_score) / float(score_per_round)), 0, REQUIRED_ROUNDS)


func _reset_runtime_state(reset_total_score: bool, new_target_score: int = 30) -> void:
	if reset_total_score:
		total_score = 0
	target_score = maxi(1, new_target_score)
	current_round_score = 0
	rounds_completed = 0
	game_cleared = false
	minigames_completed_this_round = 0
	queue_attempt_count = 0
	current_queue_level = 0
	queue_fail_count = 0
	round_started = true
	round_is_completed = false
	keep_going_count = 0
	cleanup_count = 0
	round_choices.clear()
	total_trash_generated = 0
	total_trash_cleaned = 0
	carried_trash = 0
	cleanup_mode = false
	collected_trash_ids.clear()
	final_environment_result = FINAL_RESULT_NONE
	_initialize_tutorial_flags()


func _load_round_choices(saved_choices: Variant) -> void:
	round_choices.clear()
	if saved_choices is Array:
		for saved_choice in saved_choices:
			var choice := str(saved_choice)
			if choice != CHOICE_KEEP_GOING and choice != CHOICE_CLEANUP:
				continue
			if round_choices.size() >= mini(rounds_completed, REQUIRED_ROUNDS):
				break
			round_choices.append(choice)

	# Counts are derived from the per-round history so old or edited save files
	# cannot make the summary disagree with the actual decisions.
	keep_going_count = round_choices.count(CHOICE_KEEP_GOING)
	cleanup_count = round_choices.count(CHOICE_CLEANUP)


func _load_trash_state(save_data: Dictionary) -> void:
	total_trash_generated = clampi(int(save_data.get("total_trash_generated", 0)), 0, 12)
	total_trash_cleaned = maxi(0, int(save_data.get("total_trash_cleaned", 0)))
	carried_trash = maxi(0, int(save_data.get("carried_trash", 0)))
	if save_data.has("cleanup_mode"):
		cleanup_mode = bool(save_data.get("cleanup_mode", false))
	elif not round_choices.is_empty():
		# Saves from the first choice-system increment did not yet store the mode.
		cleanup_mode = round_choices[round_choices.size() - 1] == CHOICE_CLEANUP
	else:
		cleanup_mode = false
	collected_trash_ids.clear()

	var saved_ids = save_data.get("collected_trash_ids", [])
	if saved_ids is Array:
		for saved_id in saved_ids:
			var trash_id := str(saved_id)
			if trash_id not in collected_trash_ids:
				collected_trash_ids.append(trash_id)

	# Round progress is authoritative for generation. This also migrates saves
	# created before the cleanup system existed.
	_sync_trash_generation_to_rounds()
	_reconcile_trash_accounting()


func _load_tutorial_flags(saved_flags: Variant) -> void:
	_initialize_tutorial_flags()
	if not (saved_flags is Dictionary):
		return
	for tutorial_id in TUTORIAL_IDS:
		tutorial_flags[tutorial_id] = bool((saved_flags as Dictionary).get(tutorial_id, false))


func _initialize_tutorial_flags() -> void:
	tutorial_flags.clear()
	for tutorial_id in TUTORIAL_IDS:
		tutorial_flags[tutorial_id] = false


func _sync_trash_generation_to_rounds() -> bool:
	var expected_total := 0
	if rounds_completed >= 2:
		expected_total = ROUND_1_TRASH_IDS.size() + ROUND_2_TRASH_IDS.size()
	elif rounds_completed >= 1:
		expected_total = ROUND_1_TRASH_IDS.size()

	var changed := total_trash_generated != expected_total
	total_trash_generated = expected_total
	_reconcile_trash_accounting()
	return changed


func _get_generated_trash_ids() -> Array[String]:
	var generated_ids: Array[String] = []
	if rounds_completed >= 1:
		generated_ids.append_array(ROUND_1_TRASH_IDS)
	if rounds_completed >= 2:
		generated_ids.append_array(ROUND_2_TRASH_IDS)
	return generated_ids


func _reconcile_trash_accounting() -> void:
	var generated_ids := _get_generated_trash_ids()
	var valid_collected_ids: Array[String] = []
	for trash_id in collected_trash_ids:
		if trash_id in generated_ids and trash_id not in valid_collected_ids:
			valid_collected_ids.append(trash_id)
	collected_trash_ids = valid_collected_ids

	var requested_collected := mini(
		total_trash_generated,
		maxi(0, total_trash_cleaned) + maxi(0, carried_trash)
	)
	for trash_id in generated_ids:
		if collected_trash_ids.size() >= requested_collected:
			break
		if trash_id not in collected_trash_ids:
			collected_trash_ids.append(trash_id)

	if collected_trash_ids.size() > requested_collected:
		carried_trash += collected_trash_ids.size() - requested_collected

	total_trash_cleaned = clampi(total_trash_cleaned, 0, collected_trash_ids.size())
	carried_trash = collected_trash_ids.size() - total_trash_cleaned


func _emit_trash_state() -> void:
	trash_state_changed.emit(
		total_trash_generated,
		total_trash_cleaned,
		carried_trash,
		cleanup_mode
	)


func _emit_current_state() -> void:
	score_changed.emit(total_score)
	round_score_changed.emit(current_round_score, target_score)
	progression_changed.emit(rounds_completed, REQUIRED_ROUNDS, game_cleared)
	queue_difficulty_changed.emit(current_queue_level)
	_emit_trash_state()
	final_environment_result_changed.emit(final_environment_result)
	for tutorial_id in TUTORIAL_IDS:
		tutorial_progress_changed.emit(tutorial_id, is_tutorial_seen(tutorial_id))
