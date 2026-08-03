extends Node2D

@export var SPEED: float = 900.0
@export var LIFETIME: float = 3.0                 # можно оставить как «страховку»
@export var MAX_DISTANCE: float = 1000.0          # макс. дистанция полёта (в пикселях)
@export var MAP_MASK: int = 1
@export var VISUAL_SCALE: float = 0.03
@export var HITBOX_SIZE: Vector2 = Vector2(12, 6)

@onready var hitbox: Area2D = $Area2D
@onready var sprite: Sprite2D = $bullet

var velocity: Vector2 = Vector2.ZERO
var shooter: Node = null
var _traveled: float = 0.0                        # накопленный путь

func setup(dir: Vector2, shooter_ref: Node) -> void:
	shooter = shooter_ref
	velocity = dir.normalized() * SPEED
	rotation = dir.angle()
	_traveled = 0.0

func _ready() -> void:
	# визуал/хитбокс
	sprite.scale = Vector2(VISUAL_SCALE, VISUAL_SCALE)
	var cs: CollisionShape2D = hitbox.get_node("CollisionShape2D")
	cs.shape = cs.shape.duplicate(true)
	var rect_shape: RectangleShape2D = cs.shape as RectangleShape2D
	if rect_shape:
		rect_shape.size = HITBOX_SIZE

	# «страховка» по времени (если не нужна — закомментируй 2 строки ниже)
	await get_tree().create_timer(LIFETIME).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	var from: Vector2 = global_position
	var to: Vector2 = from + velocity * delta

	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.collision_mask = MAP_MASK
	params.exclude = [self, hitbox, shooter]

	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(params)

	if not hit.is_empty():
		var hit_pos: Vector2 = hit.get("position")
		var col_obj: Object = hit.get("collider")

		if col_obj is Node:
			var cur: Node = col_obj
			var terrain: Node = null
			# поднимаемся по предкам, пока не найдём carve_hole
			while cur != null and terrain == null:
				if cur.has_method("carve_hole"):
					terrain = cur
					break
				cur = cur.get_parent()

			if terrain:
				terrain.call("carve_hole", hit_pos, 24)  # радиус подбери
			else:
				# отладка: покажем, куда попали
				print("Hit node=", (col_obj as Node).name, 
					  " groups=", (col_obj as Node).get_groups())

		global_position = hit_pos
		queue_free()
		return

	global_position = to
