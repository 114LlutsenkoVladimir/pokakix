extends Node2D

@export var max_jumps: int = 2

var cur_jumps: int = 1
@onready var player: CharacterBody2D = get_parent() as CharacterBody2D

func _ready() -> void:
	player.landed.connect(_on_player_landed)
	_on_player_landed()

func _on_player_landed() -> void:
	cur_jumps = max_jumps
	set_process_unhandled_input(true)
	
func _unhandled_input(event: InputEvent) -> void:
	var shift_held: bool = Input.is_action_pressed("shift")
	if Input.is_action_pressed("jump_fwd") and cur_jumps > 0 and $jump_delay_timer.is_stopped():
		if shift_held:
			_jump_fwd_impl(1.5)
		else:
			_jump_fwd_impl(1)
	elif Input.is_action_pressed("jump_bwd") and cur_jumps > 0 and $jump_delay_timer.is_stopped():
		if shift_held:
			_jump_bwd_impl(1.5)
		else:
			_jump_bwd_impl(1)

func _jump_fwd_impl(shift_boost) -> void:
	$jump_delay_timer.start()
	cur_jumps -= 1
	player.velocity.y = -200.0 * shift_boost
	player.velocity.x = -125.0 * shift_boost * -player.facing_direction

func _jump_bwd_impl(shift_boost) -> void:
	$jump_delay_timer.start()
	cur_jumps -= 1
	player.velocity.x /= 2
	player.velocity.y = -300.0 * shift_boost
	$bwd_jump_fix_timer.start()
	await $bwd_jump_fix_timer.timeout
	player.velocity.x = 85.0 * shift_boost * -player.facing_direction
