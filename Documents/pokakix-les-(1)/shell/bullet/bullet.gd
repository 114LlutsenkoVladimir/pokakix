extends Node2D

@export var SPEED: float = 900.0
@export var LIFETIME: float = 3.0
@export var EXPLOSION_SCENE: PackedScene

# Макс. дистанция полёта (в МИРОВЫХ единицах!)
@export var MAX_DISTANCE_WORLD: float = 1000.0

# Радиус дырки (в МИРОВЫХ единицах)
@export var HOLE_RADIUS_WORLD: float = 20.0

# Если не хочешь задавать из setup — можно указать путь до Terrain в инспекторе
@export var TERRAIN_PATH: NodePath

@export var VISUAL_SCALE: float = 0.03
@export var HITBOX_SIZE: Vector2 = Vector2(12, 6) # чисто визуально/для будущего

@onready var hitbox: Area2D = $Area2D
@onready var sprite: Sprite2D = $bullet

var velocity: Vector2 = Vector2.ZERO
var shooter: Node = null
var terrain: Node = null
var _traveled: float = 0.0
var _alive: bool = true

func setup(dir: Vector2, shooter_ref: Node, terrain_ref: Node = null) -> void:
	shooter = shooter_ref
	terrain = terrain_ref
	velocity = dir.normalized() * SPEED
	rotation = dir.angle()
	_traveled = 0.0

func _ready() -> void:
	# Визуал/хитбокс (не обязателен для битмапа, но оставим)
	sprite.scale = Vector2(VISUAL_SCALE, VISUAL_SCALE)
	

	var cs: CollisionShape2D = hitbox.get_node("CollisionShape2D")
	cs.shape = cs.shape.duplicate(true)
	var rect_shape: RectangleShape2D = cs.shape as RectangleShape2D
	if rect_shape:
		rect_shape.size = HITBOX_SIZE

	# Подхват Terrain из инспектора, если не передали в setup
	if terrain == null and TERRAIN_PATH != NodePath(""):
		terrain = get_node_or_null(TERRAIN_PATH)

	# Таймер жизни (без await, чтобы не было сюрпризов если очередь на удаление раньше)
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = LIFETIME
	add_child(t)
	t.timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)
	t.start()




func _physics_process(delta: float) -> void:
	if not _alive:
		return

	var from: Vector2 = global_position
	var to: Vector2 = from + velocity * delta

	# Страховка по дистанции
	var step_len: float = (to - from).length()
	_traveled += step_len
	if _traveled >= MAX_DISTANCE_WORLD:
		queue_free()
		return

	# Если нет terrain — просто летим
	if terrain == null:
		global_position = to
		return

	# --- Шаг для “рейкаста” по битмапу ---
	var px_step: float = 1.0
	if "world_scale" in terrain:
		px_step = max(0.001, float(terrain.world_scale))
	else:
		px_step = 1.0

	# --- Проверяем столкновение с битмапом вдоль траектории ---
	var dir_vec: Vector2 = to - from
	var dist: float = dir_vec.length()

	if dist <= 0.000001:
		return

	var dir_n: Vector2 = dir_vec / dist
	var steps: int = int(ceil(dist / px_step))

	var hit_pos: Vector2 = Vector2.ZERO
	var hit_found := false

	# Можно начинать с 1, чтобы не “самопопадать” если старт внутри земли.
	for i in range(1, steps + 1):
		var p: Vector2 = from + dir_n * min(float(i) * px_step, dist)

		# Проверка по террейну
		if terrain.has_method("is_solid") and terrain.call("is_solid", p):
			hit_pos = p
			hit_found = true
			break

	if hit_found:
		if EXPLOSION_SCENE:
			var e := EXPLOSION_SCENE.instantiate()
			get_tree().current_scene.add_child(e)
			e.global_position = hit_pos

			var ws := 1.0
			if "world_scale" in terrain:
				ws = float(terrain.world_scale)

			# ВАЖНО: вызвать play у сцены взрыва
			e.call("play", HOLE_RADIUS_WORLD, ws)
		# Делаем дырку
		if terrain.has_method("carve_hole"):
			terrain.call("carve_hole", hit_pos, HOLE_RADIUS_WORLD)

		global_position = hit_pos
		queue_free()
		return

	# Нет попадания — летим дальше
	global_position = to
