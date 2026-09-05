extends CanvasLayer

const TOGGLE_KEY_UNICODE := [96, 126]
const SCORE_CHEAT_AMOUNT := 10

var commands: Dictionary = {}
var panel: PanelContainer
var commands_label: Label
var input: LineEdit
var status_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not DebugFlags.is_debug_build():
		set_process_input(false)
		return

	_build_ui()
	register_command("godmode", _cmd_godmode)
	register_command("scoretozero", _cmd_score_to_zero)
	register_command("addscore", _cmd_add_score)
	register_command("resetprogress", _cmd_reset_progress)
	register_command("help", _cmd_help)
	_set_open(false)


func _input(event: InputEvent) -> void:
	if _is_score_cheat_event(event):
		_grant_hidden_score()
		get_viewport().set_input_as_handled()
		return

	if _is_console_toggle_event(event):
		_set_open(not visible)
		get_viewport().set_input_as_handled()
		return

	if visible and _is_escape_key(event):
		_set_open(false)
		get_viewport().set_input_as_handled()


func register_command(command_name: String, callback: Callable) -> void:
	commands[command_name.to_lower()] = callback


func run_command(text: String) -> void:
	var parts := text.strip_edges().split(" ", false)
	if parts.size() == 0:
		return

	var command_name := parts[0].to_lower()
	var args := parts.slice(1)

	if not commands.has(command_name):
		_set_status("Unknown command: %s" % command_name)
		return

	var callback := commands[command_name] as Callable
	callback.call(args)


func _build_ui() -> void:
	layer = 100

	panel = PanelContainer.new()
	panel.name = "DebugConsolePanel"
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 24.0
	panel.offset_top = 24.0
	panel.offset_right = -24.0
	panel.offset_bottom = 110.0
	add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.03, 0.88)
	style.border_color = Color(0.36, 0.8, 0.95, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	panel.add_child(layout)

	commands_label = Label.new()
	commands_label.text = _get_command_list_text()
	layout.add_child(commands_label)

	status_label = Label.new()
	status_label.text = "Debug console ready"
	layout.add_child(status_label)

	input = LineEdit.new()
	input.placeholder_text = "Command"
	input.caret_blink = true
	input.text_submitted.connect(_on_input_text_submitted)
	layout.add_child(input)


func _on_input_text_submitted(text: String) -> void:
	input.clear()
	run_command(text)


func _set_open(open: bool) -> void:
	visible = open
	DebugFlags.set_console_input_active(open)

	if input == null:
		return

	if open:
		input.grab_focus()
	else:
		input.release_focus()


func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
	print(message)


func _cmd_godmode(args: PackedStringArray) -> void:
	if args.size() > 0:
		match args[0].to_lower():
			"on", "1", "true":
				DebugFlags.set_godmode_enabled(true)
			"off", "0", "false":
				DebugFlags.set_godmode_enabled(false)
			_:
				_set_status("Usage: godmode, godmode on, or godmode off")
				return
	else:
		DebugFlags.toggle_godmode()

	_set_status("godmode: %s" % ("on" if DebugFlags.is_godmode_enabled() else "off"))


func _cmd_score_to_zero(_args: PackedStringArray) -> void:
	SaveManager.set_score(0)
	_set_status("score: 0")


func _cmd_add_score(args: PackedStringArray) -> void:
	if args.size() != 1 or not args[0].is_valid_int():
		_set_status("Usage: addScore <amount>")
		return

	var amount := int(args[0])
	if amount <= 0:
		_set_status("addScore amount must be greater than 0")
		return

	SaveManager.add_score(amount)
	_set_status("score: %d (+%d)" % [SaveManager.get_score(), amount])


func _cmd_reset_progress(_args: PackedStringArray) -> void:
	SaveManager.reset_progress_for_testing(false)
	_set_status("progress reset: round 0 / %d, score 0" % SaveManager.get_required_rounds())


func _grant_hidden_score() -> void:
	# Editor/debug convenience only. This does not register a queue attempt,
	# queue success, submission, or completed round.
	SaveManager.add_score(SCORE_CHEAT_AMOUNT)
	print("Debug score shortcut: +%d (total %d)" % [SCORE_CHEAT_AMOUNT, SaveManager.get_score()])


func _cmd_help(_args: PackedStringArray) -> void:
	_set_status(_get_command_list_text())


func _get_command_list_text() -> String:
	return "Commands: godmode | scoreToZero | addScore <amount> | resetProgress | help"


func _is_console_toggle_event(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false

	return key_event.keycode == KEY_QUOTELEFT \
		or key_event.physical_keycode == KEY_QUOTELEFT \
		or key_event.keycode == KEY_F10 \
		or key_event.physical_keycode == KEY_F10 \
		or TOGGLE_KEY_UNICODE.has(key_event.unicode)


func _is_score_cheat_event(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false

	return key_event.ctrl_pressed \
		and key_event.shift_pressed \
		and (key_event.keycode == KEY_F8 or key_event.physical_keycode == KEY_F8)


func _is_escape_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
