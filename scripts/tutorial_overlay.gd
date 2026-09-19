extends Control

signal dismissed(tutorial_id: String)

@export var title_label_path: NodePath = ^"Center/Panel/Margin/Content/TitleLabel"
@export var body_label_path: NodePath = ^"Center/Panel/Margin/Content/BodyLabel"
@export var continue_button_path: NodePath = ^"Center/Panel/Margin/Content/ContinueButton"

var title_label: Label
var body_label: Label
var continue_button: Button
var current_tutorial_id := ""


func _ready() -> void:
	title_label = get_node_or_null(title_label_path) as Label
	body_label = get_node_or_null(body_label_path) as Label
	continue_button = get_node_or_null(continue_button_path) as Button
	if continue_button != null:
		continue_button.pressed.connect(dismiss)
	visible = false


func present(tutorial_id: String, title: String, body: String, button_text := "Continue") -> void:
	current_tutorial_id = tutorial_id
	if title_label != null:
		title_label.text = title
	if body_label != null:
		body_label.text = body
	if continue_button != null:
		continue_button.text = button_text
		continue_button.disabled = false
	visible = true
	if continue_button != null:
		continue_button.grab_focus()


func dismiss() -> void:
	if not visible or current_tutorial_id.is_empty():
		return
	var dismissed_id := current_tutorial_id
	current_tutorial_id = ""
	visible = false
	dismissed.emit(dismissed_id)
