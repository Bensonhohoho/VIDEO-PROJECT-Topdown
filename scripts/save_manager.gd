extends Node

signal score_changed(new_score: int)
signal score_added(amount: int, new_score: int)
signal score_spent(amount: int, new_score: int)
signal round_score_changed(current_score: int, target_score: int)
signal round_completed(current_score: int, target_score: int)
signal submit_failed(message: String)
signal score_submitted(amount: int, current_score: int, submitted_score: int, target_score: int)
signal queue_difficulty_changed(current_queue_level: int)

const SAVE_PATH := "user://save_data.json"

var total_score := 0
var current_round_score := 0
var target_score := 30
var minigames_completed_this_round := 0
var queue_attempt_count := 0
var current_queue_level := 0
var queue_fail_count := 0
var round_started := false
var round_is_completed := false


func _ready() -> void:
	# Load once when the autoload is created so every scene can ask for the
	# current saved score immediately.
	load_game()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		total_score = 0
		score_changed.emit(total_score)
		return

	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		push_error("SaveManager could not open save file for reading.")
		total_score = 0
		score_changed.emit(total_score)
		return

	var save_text := save_file.get_as_text()
	var parsed_data = JSON.parse_string(save_text)
	if not (parsed_data is Dictionary):
		push_error("SaveManager found invalid save data.")
		total_score = 0
		score_changed.emit(total_score)
		return

	total_score = int(parsed_data.get("total_score", 0))
	score_changed.emit(total_score)


func save_game() -> void:
	var save_data := {
		"total_score": total_score
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
	total_score = max(0, new_score)
	save_game()
	score_changed.emit(total_score)


func spend_score(amount: int) -> bool:
	if amount <= 0:
		return false

	if total_score < amount:
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
	# Round score is the submitted progress for the current level target.
	target_score = max(1, new_target_score)
	current_round_score = 0
	minigames_completed_this_round = 0
	queue_attempt_count = 0
	current_queue_level = 0
	queue_fail_count = 0
	round_started = true
	round_is_completed = false
	round_score_changed.emit(current_round_score, target_score)
	queue_difficulty_changed.emit(current_queue_level)


func ensure_round_started(new_target_score: int = 30) -> void:
	if round_started:
		target_score = max(1, new_target_score)
		round_score_changed.emit(current_round_score, target_score)
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
	if amount <= 0 or round_is_completed:
		return false

	if not round_started:
		start_new_round(target_score)

	if not spend_score(amount):
		submit_failed.emit("Not enough score to submit.")
		return false

	current_round_score += amount
	round_score_changed.emit(current_round_score, target_score)
	score_submitted.emit(amount, total_score, current_round_score, target_score)

	if current_round_score >= target_score:
		round_is_completed = true
		round_completed.emit(current_round_score, target_score)

	return true


func register_queue_success(max_level_count: int) -> void:
	queue_attempt_count += 1
	minigames_completed_this_round += 1
	queue_fail_count = 0
	if max_level_count > 0:
		current_queue_level = clampi(current_queue_level + 1, 0, max_level_count - 1)
	queue_difficulty_changed.emit(current_queue_level)


func register_queue_failure(max_level_count: int, played_level_index: int = -1) -> void:
	queue_attempt_count += 1
	queue_fail_count += 1
	var level_to_fall_back_from := current_queue_level if played_level_index < 0 else played_level_index
	if max_level_count > 0:
		current_queue_level = clampi(level_to_fall_back_from - 1, 0, max_level_count - 1)
	else:
		current_queue_level = max(0, level_to_fall_back_from - 1)
	queue_difficulty_changed.emit(current_queue_level)


func get_score() -> int:
	return total_score


func get_round_score() -> int:
	return current_round_score


func get_target_score() -> int:
	return target_score


func get_round_level_index() -> int:
	return current_queue_level


func get_queue_attempt_count() -> int:
	return queue_attempt_count


func get_queue_fail_count() -> int:
	return queue_fail_count


func reset_queue_fail_count() -> void:
	queue_fail_count = 0


func is_round_completed() -> bool:
	return round_is_completed


func reset_save() -> void:
	total_score = 0
	save_game()
	score_changed.emit(total_score)
	start_new_round(target_score)
