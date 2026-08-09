extends Node
@onready var player: Node2D = $bob    # путь к твоему Бобу
@onready var spawn: Marker2D = $SpawnPoint

func _ready() -> void:
	if player and spawn:
		player.global_position = spawn.global_position
