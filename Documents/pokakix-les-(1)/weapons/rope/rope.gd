extends Node2D
class_name RopeWeapon

@export var ROPE_HEAD_SCENE: PackedScene = preload("res://weapons/rope/rope_head.tscn")

# как в Wormix
@export var ROPE_SPEED_MAX: float = 50.0
@export var ROPE_SPEED_MIN: float = 25.0
@export var MAX_LENGTH_PX: int = 380
@export var MIN_LENGTH_PX: int = 10

@onready var rope_line: Line2D = $rope_line
var _head: Node2D = null
var _attached: bool = false

func _ready() -> void:
	if rope_line:
		rope_line.top_level = true
		rope_line.visible = false
		
var _active_head: RopeHead = null
@export var ROPE_HEAD_SCALE: float = 0.005

func can_fire(p: WormsPlayer) -> bool:
	return _active_head == null

func fire(p: WormsPlayer) -> void:
	if _active_head != null:
		return

	var muzzle: Node2D = $muzzle as Node2D
	var dir: Vector2 = -Vector2.RIGHT.rotated(muzzle.global_rotation).normalized()

	var head: RopeHead = ROPE_HEAD_SCENE.instantiate() as RopeHead
	p.get_tree().current_scene.add_child(head)

	head.global_position = muzzle.global_position
	head.global_rotation = muzzle.global_rotation
	head.scale = Vector2.ONE * ROPE_HEAD_SCALE
	head.setup(dir, p.terrain)

	_active_head = head
	head.hooked.connect(func(hook_pos: Vector2) -> void:
		_active_head = null
		p.change_state_to_rope(hook_pos)
	)
	head.missed.connect(func() -> void:
		_active_head = null
	)



func _on_head_attached(player: Node, attach_pos: Vector2) -> void:
	if rope_line:
		rope_line.visible = true
	_attached = true
	# говорим игроку: стартуем rope-режим
	if player and player.has_method("rope_attach"):
		player.call("rope_attach", attach_pos)

	# голова больше не нужна как снаряд
	if _head:
		_head.queue_free()
	_head = null

func _on_head_disposed() -> void:
	# промах / исчезла
	if _head:
		_head.queue_free()
	_head = null
	_attached = false
	rope_line.clear_points()

func update_rope_line(points: Array[Vector2], player_pos: Vector2) -> void:
	if rope_line == null:
		return
	rope_line.clear_points()
	for p in points:
		rope_line.add_point(p)
	rope_line.add_point(player_pos)
