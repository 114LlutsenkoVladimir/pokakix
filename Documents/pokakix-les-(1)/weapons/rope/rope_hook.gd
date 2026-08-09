extends Node2D
class_name RopeHead

signal hooked(hook_pos: Vector2)
signal missed()

@export var SPEED: float = 320.0
@export var MAX_LIFE: float = 1.2
@export var HIT_STEP_PX: float = 0.25 # важно для world_scale=2 и COLLISION_SCALE=2

var _terrain: Node = null
var _vel: Vector2 = Vector2.ZERO
var _life: float = 0.0

func setup(dir: Vector2, terrain: Node) -> void:
	_terrain = terrain
	_vel = dir.normalized() * SPEED

func _physics_process(delta: float) -> void:
	if _terrain == null:
		emit_signal("missed")
		queue_free()
		return

	var prev: Vector2 = global_position
	var next: Vector2 = prev + _vel * delta

	# ✅ ray-march по битмапу (чтобы не "пролетать" тонкие места)
	var step_world: float = 1.0
	if "world_scale" in _terrain:
		# world_scale=2 + collision_scale=2 => надо шагать мелко
		step_world = float(_terrain.world_scale) * HIT_STEP_PX
	else:
		step_world = HIT_STEP_PX

	var d: Vector2 = next - prev
	var dist: float = d.length()
	var dir: Vector2 = d / max(0.00001, dist)

	var t: float = 0.0
	while t <= dist:
		var p: Vector2 = prev + dir * t
		if _terrain.is_solid(p):
			global_position = p
			emit_signal("hooked", p)
			set_physics_process(false)
			visible = false
			return
		t += step_world

	global_position = next

	_life += delta
	if _life >= MAX_LIFE:
		emit_signal("missed")
		queue_free()
