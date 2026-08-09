extends Node2D

@export var max_jumps: int = 2
@export var movement_node: Node

var cur_jumps: int = 1
@onready var player: CharacterBody2D = get_parent() as CharacterBody2D

signal bwd_jump
signal fwd_jump


func _ready() -> void:
	player.landed.connect(_on_player_landed)
	_on_player_landed()

func _on_player_landed() -> void:
	$jump_delay_timer.stop()
	cur_jumps = max_jumps
	if Input.get_axis("left", "right") == 0:
		player.velocity.x = 0.0

func _physics_process(delta: float) -> void:
	if cur_jumps > 0 and $jump_delay_timer.is_stopped():
		var fwd_pressed: bool = Input.is_action_pressed("jump_fwd")
		var bwd_pressed: bool = Input.is_action_pressed("jump_bwd")
		
		if fwd_pressed or bwd_pressed:
			var shift_boost: float = 1.5 if Input.is_action_pressed("shift") else 1.0
			
			if fwd_pressed:
				_jump_fwd_impl(shift_boost)
			elif bwd_pressed:
				_jump_bwd_impl(shift_boost)

func _jump_fwd_impl(shift_boost) -> void:
	bwd_jump.emit()
	movement_node.set_process_unhandled_input(false)
	$jump_delay_timer.start()
	cur_jumps -= 1
	player.velocity.y = -200.0 * shift_boost
	player.velocity.x = -125.0 * shift_boost * -player.facing_direction
	

func _jump_bwd_impl(shift_boost: float) -> void:
	fwd_jump.emit()
	movement_node.set_process_unhandled_input(false)
	$jump_delay_timer.start()
	cur_jumps -= 1
	player.velocity.x /= 2
	player.velocity.y = -300.0 * shift_boost
	
	$bwd_jump_fix_timer.start()
	
	await $bwd_jump_fix_timer.timeout
	
	if player.velocity.y < 0:
		player.velocity.x = 85.0 * shift_boost * -player.facing_direction
