extends Node2D

@onready var player: CharacterBody2D = get_parent() as CharacterBody2D
@export var pritselix_node: Node

var jmp_dir: int = 1
func _ready() -> void:
	player.landed.connect(_on_player_landed)
	player.left_floor.connect(_on_player_left_floor)

	$"../jumper".bwd_jump.connect(func(): set_jmp_dir(-1))
	$"../jumper".fwd_jump.connect(func(): set_jmp_dir(1))

func _physics_process(delta: float) -> void:
	if not player.is_on_floor() and $rotation_timer.is_stopped():
		$"../bob".rotate(jmp_dir * 0.001 * abs(player.velocity.y) * $"../bob".scale.x)

func _on_player_landed() -> void:
	set_physics_process(false)
	$"../bob".rotation_degrees = 0
	$rotation_timer.stop()
	show_weapon()
	
func _on_player_left_floor() -> void:
	set_physics_process(true)
	$rotation_timer.start()
	hide_weapon()

func set_jmp_dir(dir: int) -> void:
	jmp_dir = dir

func hide_weapon() -> void:
	if has_node("../bob/weapon_pivot/weapon"):
		$"../bob/weapon_pivot/weapon".visible = false
	if has_node("../bob/weapon_pivot/pritsel"):
		$"../bob/weapon_pivot/pritsel".visible = false
	$"../bob/weapon_pivot".rotation = 0.0
	


func show_weapon() -> void:
	if has_node("../bob/weapon_pivot/weapon"):
		$"../bob/weapon_pivot/weapon".visible = true
	if has_node("../bob/weapon_pivot/pritsel"):
		$"../bob/weapon_pivot/pritsel".visible = true
	$"../bob/weapon_pivot".rotation = deg_to_rad(pritselix_node._aim_deg_local)
