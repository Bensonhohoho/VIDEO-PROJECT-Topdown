extends Area2D

@export_enum("normal", "stone", "ice") var material_name: String = "normal"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_ground_material"):
		body.call("set_ground_material", StringName(material_name))


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("clear_ground_material"):
		body.call("clear_ground_material", StringName(material_name))
