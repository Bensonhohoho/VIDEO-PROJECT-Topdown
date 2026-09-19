extends Control

signal choice_selected(choice: String)

const CHOICE_KEEP_GOING := "keep_going"
const CHOICE_CLEANUP := "cleanup"

@export var round_label_path: NodePath = ^"Center/Panel/Margin/Content/RoundLabel"
@export var keep_going_button_path: NodePath = ^"Center/Panel/Margin/Content/Choices/KeepGoingCard/CardMargin/CardContent/KeepGoingButton"
@export var cleanup_button_path: NodePath = ^"Center/Panel/Margin/Content/Choices/CleanupCard/CardMargin/CardContent/CleanupButton"

var round_label: Label
var keep_going_button: Button
var cleanup_button: Button
var accepting_choice := false


func _ready() -> void:
	round_label = get_node_or_null(round_label_path) as Label
	keep_going_button = get_node_or_null(keep_going_button_path) as Button
	cleanup_button = get_node_or_null(cleanup_button_path) as Button

	if keep_going_button != null:
		keep_going_button.pressed.connect(_on_keep_going_pressed)
	if cleanup_button != null:
		cleanup_button.pressed.connect(_on_cleanup_pressed)
	hide_choice()


func present(round_number: int, required_rounds: int) -> void:
	accepting_choice = true
	visible = true
	if round_label != null:
		round_label.text = "ROUND %d OF %d COMPLETE" % [round_number, required_rounds]
	_set_buttons_disabled(false)
	if keep_going_button != null:
		keep_going_button.grab_focus()


func hide_choice() -> void:
	accepting_choice = false
	visible = false
	_set_buttons_disabled(true)


func _on_keep_going_pressed() -> void:
	_submit_choice(CHOICE_KEEP_GOING)


func _on_cleanup_pressed() -> void:
	_submit_choice(CHOICE_CLEANUP)


func _submit_choice(choice: String) -> void:
	if not accepting_choice:
		return

	# Lock both buttons before emitting. Even if two input events arrive during
	# the same frame, only the first decision can be submitted.
	accepting_choice = false
	_set_buttons_disabled(true)
	choice_selected.emit(choice)


func _set_buttons_disabled(disabled: bool) -> void:
	if keep_going_button != null:
		keep_going_button.disabled = disabled
	if cleanup_button != null:
		cleanup_button.disabled = disabled
