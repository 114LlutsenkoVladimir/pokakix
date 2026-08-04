extends Node2D

@onready var player: CharacterBody2D = get_parent() as CharacterBody2D

func _ready() -> void:
	pass
	
func _process(delta: float) -> void:
	if $ray_middle.is_colliding() or $ray_left.is_colliding() or $ray_right.is_colliding():
		if player.left_floor:
			player.velocity.x /= 2
