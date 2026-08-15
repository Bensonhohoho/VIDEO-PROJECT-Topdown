extends Area2D

@export var collect_effect_scene: PackedScene = preload("res://scenes/score_collect_effect.tscn")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var game_manager: Node = %GameManager

var is_collected := false


func _ready() -> void:
	animated_sprite.play("default")


func _on_body_entered(_body: Node2D) -> void:
	if is_collected:
		return

	is_collected = true
	monitoring = false
	_spawn_collect_effect()
	game_manager.add_point()
	animated_sprite.play("default_2")
	await get_tree().create_timer(0.8).timeout
	queue_free()


func _spawn_collect_effect() -> void:
	if collect_effect_scene == null:
		return

	var effect := collect_effect_scene.instantiate() as Node2D
	if effect == null:
		return

	get_parent().add_child(effect)
	effect.global_position = global_position
