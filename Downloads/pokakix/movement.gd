extends Node2D

@onready var player: CharacterBody2D = get_parent() as CharacterBody2D

func _ready() -> void:
	player.landed.connect(_on_player_landed)
	player.left_floor.connect(_on_player_left_floor)
	_on_player_landed()
	player._flip(player.facing_direction)
	
func _update_input_movement() -> void:
	var direction = Input.get_axis("left", "right")
	if direction != 0 and direction != player.facing_direction:
		player._flip(direction)
	player.velocity.x = 70 * direction

func _unhandled_input(event: InputEvent) -> void:
	_update_input_movement()

func _on_player_landed() -> void:
	set_process_unhandled_input(true)
	_update_input_movement()
	
func _on_player_left_floor() -> void:
	set_process_unhandled_input(false)
