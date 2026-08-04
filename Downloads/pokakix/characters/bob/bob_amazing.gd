extends CharacterBody2D

signal landed
signal left_floor

var was_on_floor: bool = false
var facing_direction: float = 1.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980 * delta
		
	if $".".position.y > 1200:
		$".".position.y = $"../SpawnPoint".position.y
		$".".position.x = $"../SpawnPoint".position.x
		velocity.y = -300
		velocity.x = 0
		
	move_and_slide()
	
	if is_on_floor() and not was_on_floor:
		landed.emit()
	elif not is_on_floor() and was_on_floor:
		left_floor.emit()
		
	was_on_floor = is_on_floor()

func _flip(direction: float) -> void:
	if direction == 0:
		return
	facing_direction = sign(direction)
	$bob.scale.x = abs($bob.scale.x) * -facing_direction
