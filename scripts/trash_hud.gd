extends PanelContainer

@export var cleaned_label_path: NodePath = ^"Margin/Rows/CleanedLabel"
@export var carrying_label_path: NodePath = ^"Margin/Rows/CarryingLabel"

var cleaned_label: Label
var carrying_label: Label


func _ready() -> void:
	cleaned_label = get_node_or_null(cleaned_label_path) as Label
	carrying_label = get_node_or_null(carrying_label_path) as Label
	if not SaveManager.trash_state_changed.is_connected(_on_trash_state_changed):
		SaveManager.trash_state_changed.connect(_on_trash_state_changed)
	_refresh()


func _exit_tree() -> void:
	if SaveManager.trash_state_changed.is_connected(_on_trash_state_changed):
		SaveManager.trash_state_changed.disconnect(_on_trash_state_changed)


func _on_trash_state_changed(
	_total_generated: int,
	_total_cleaned: int,
	_carried: int,
	_cleanup_enabled: bool
) -> void:
	_refresh()


func _refresh() -> void:
	var generated := SaveManager.get_total_trash_generated()
	visible = generated > 0
	if cleaned_label != null:
		cleaned_label.text = "Trash Cleaned: %d / %d" % [
			SaveManager.get_total_trash_cleaned(),
			generated
		]
	if carrying_label != null:
		carrying_label.text = "Carrying: %d" % SaveManager.get_carried_trash()
