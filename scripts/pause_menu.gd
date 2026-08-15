extends CanvasLayer

@export_file("*.tscn") var main_menu_scene_path := "res://scenes/main_menu.tscn"
@export var overlay_path: NodePath = ^"Overlay"
@export var resume_button_path: NodePath = ^"Overlay/MenuPanel/MenuContent/ResumeButton"
@export var main_menu_button_path: NodePath = ^"Overlay/MenuPanel/MenuContent/MainMenuButton"

var overlay: Control
var resume_button: Button
var main_menu_button: Button
var is_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = get_node_or_null(overlay_path) as Control
	resume_button = get_node_or_null(resume_button_path) as Button
	main_menu_button = get_node_or_null(main_menu_button_path) as Button

	if resume_button != null:
		resume_button.pressed.connect(_on_resume_pressed)
	if main_menu_button != null:
		main_menu_button.pressed.connect(_on_main_menu_pressed)

	_set_open(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or _is_escape_key(event):
		_set_open(not is_open)
		get_viewport().set_input_as_handled()


func _is_escape_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE


func _on_resume_pressed() -> void:
	_set_open(false)


func _on_main_menu_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(main_menu_scene_path)
	if error != OK:
		push_error("Pause menu could not return to main menu: " + main_menu_scene_path)


func _set_open(open: bool) -> void:
	is_open = open
	get_tree().paused = open
	if overlay != null:
		overlay.visible = open
	if open and resume_button != null:
		resume_button.grab_focus()
