extends Node2D

@export var idle_animation: StringName = &"idle"

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _ready() -> void:
	if animated_sprite == null:
		return

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(idle_animation):
		animated_sprite.play(idle_animation)
