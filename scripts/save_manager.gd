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

const SAVE_PATH := "user://save_data.json"
const REQUIRED_ROUNDS := 3

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
		"round_is_completed": round_is_completed
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
	save_game()

	round_score_changed.emit(current_round_score, target_score)
	score_submitted.emit(amount, total_score, current_round_score, target_score)
	if rounds_completed != previous_rounds_completed or game_cleared:
		progression_changed.emit(rounds_completed, REQUIRED_ROUNDS, game_cleared)

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


func get_round_level_index() -> int:
	return current_queue_level


func get_queue_attempt_count() -> int:
	return queue_attempt_count


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


func _emit_current_state() -> void:
	score_changed.emit(total_score)
	round_score_changed.emit(current_round_score, target_score)
	progression_changed.emit(rounds_completed, REQUIRED_ROUNDS, game_cleared)
	queue_difficulty_changed.emit(current_queue_level)
