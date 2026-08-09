extends CharacterBody2D
class_name WormsPlayer

@export var TERRAIN_PATH: NodePath

# --- ГЕОМЕТРИЯ ПЕРСОНАЖА (ПРЯМОУГОЛЬНИК) ---
@export var WIDTH: float = 4.0
@export var HEIGHT: float = 16.0
@export var CENTER_OFFSET: Vector2 = Vector2(0, 0)

# --- НАСТРОЙКИ ПРОВЕРОК ---
@export var SAMPLES_PER_SIDE: int = 5
@export var SKIN_PX: int = 1

# Движение
@export var MAX_STEP_HEIGHT_PX: int = 10
@export var PREJUMP_LIFT_PX: int = 2
@export var GROUND_GRACE_TIME: float = 0.10
@export var SPEED: int = 50
@export var GRAVITY: int = 900
@export var WALK_FACTOR: float = 0.2
@export var SHIFT_START_DELAY: float = 0.12
@export var MOVE_SUBSTEP_PX: float = 0.25
@export var FOLLOW_GROUND_EXTRA_PX: int = 12

# Состояние
@export var possible_jumps: int = 1
var possible_jumps_now: int = 0
var _move_input_dir: int = 0
var _jumped_this_frame: bool = false
var _jump_pressed_this_frame: bool = false
var _on_floor: bool = false
var _on_floor_stable: bool = false
var _grace_left: float = 0.0
var _disable_follow_ground_frames: int = 0
var _no_move_until_frame: int = -1
var _dir_hold_time: float = 0.0
var _last_dir_for_hold: int = 0
var _bypass_shift_delay_this_frame: bool = false
var _want_weapon_visible: bool = false

# Оружие и визуал
@export var GUN_SCENE: PackedScene = preload("res://weapons/gun.tscn")
@export var GUN2_SCENE: PackedScene = preload("res://weapons/gun2.tscn")
@export var ROPE_SCENE: PackedScene = preload("res://weapons/rope/rope.tscn")

var current_weapon: Node2D = null
var weapon_socket: Node2D = null
var _aim_deg_local: float = 0.0
var shown_deg: float = 0.0
var base_bob_scale: Vector2 = Vector2.ONE
var terrain: Node = null

@onready var weapon_pivot: Node2D = $bob/weapon_pivot
@onready var pritsel: CanvasItem = $bob/weapon_pivot/pritsel
@onready var hand: Node2D = $bob/weapon_pivot/hand
@onready var hand_bwd: Node2D = $bob/weapon_pivot/hand_bwd
@onready var _player_state: Node = $States/NormalState
@onready var rope_physics: RopePhysics = $States/RopeState/RopePhysicModel

@onready var trail: Line2D = get_node_or_null("character_trail")

@export var AIM_SPEED_DEG: float = 180.0
@export var AIM_MIN_DEG: float = -90.0
@export var AIM_MAX_DEG: float = 90.0

# --- ledge carry (чтобы не падал "топором") ---

@export var LEDGE_CARRY_MIN_SPEED: float = 22.7 # то, что ты хотел
@export var LEDGE_CARRY_MAX_SPEED: float = 120.0
@export var LEDGE_CARRY_DECAY: float = 0.0 # если захочешь лёгкое затухание в воздухе, поставь например 2.0

var _grounded_x_memory: float = 0.0
var _just_left_ground: bool = false

var is_on_rope: bool = false

# -------------------- INITIALIZATION --------------------

func _ready() -> void:
	base_bob_scale = $bob.scale
	terrain = get_node_or_null(TERRAIN_PATH)
	_ensure_weapon_socket()

	if trail:
		trail.visible = true

	await get_tree().create_timer(0.4).timeout
	possible_jumps_now = possible_jumps
	_resolve_penetration()
	_snap_to_ground(MAX_STEP_HEIGHT_PX)
	_set_weapon(GUN2_SCENE)


func _ensure_weapon_socket() -> void:
	if weapon_socket and is_instance_valid(weapon_socket):
		return
	weapon_socket = weapon_pivot.get_node_or_null("weapon_socket")
	if not weapon_socket:
		weapon_socket = Node2D.new()
		weapon_socket.name = "weapon_socket"
		weapon_pivot.add_child(weapon_socket)


# -------------------- CORE CHECKS --------------------

func _is_solid_point(pos: Vector2) -> bool:
	return terrain != null and terrain.is_solid(pos)


func _check_line(start: Vector2, end: Vector2, samples: int) -> bool:
	var n: int = max(2, samples)
	for i in range(n):
		var t: float = float(i) / float(n - 1)
		if _is_solid_point(start.lerp(end, t)):
			return true
	return false


func _ground_check(center: Vector2) -> bool:
	var hw: float = WIDTH / 2.0
	var hh: float = HEIGHT / 2.0
	return _check_line(center + Vector2(-hw, hh), center + Vector2(hw, hh), SAMPLES_PER_SIDE)


func _ceiling_check(center: Vector2) -> bool:
	var hw: float = WIDTH / 2.0
	var hh: float = HEIGHT / 2.0
	return _check_line(center + Vector2(-hw, -hh), center + Vector2(hw, -hh), SAMPLES_PER_SIDE)


func _wall_check(center: Vector2, dir: int) -> bool:
	var hw: float = WIDTH / 2.0
	var hh: float = HEIGHT / 2.0
	var side_x: float = center.x + (hw * float(dir))
	var s: float = _px_to_world(2) # отступ от пола/потолка
	return _check_line(Vector2(side_x, center.y - hh + s), Vector2(side_x, center.y + hh - s), SAMPLES_PER_SIDE)


func _any_overlap(c: Vector2) -> bool:
	return _ground_check(c) or _ceiling_check(c) or _wall_check(c, 1) or _wall_check(c, -1)


# -------------------- PHYSICS --------------------
func _physics_process(delta: float) -> void:
	if not terrain:
		return

	_want_weapon_visible = false
	if _player_state:
		_player_state.call("physics_update", self, delta)

	# ---------------- ROPE MODE ----------------
	if is_on_rope:
		rope_physics.acc_x = 0.0
		if Input.is_action_pressed("right"):
			rope_physics.acc_x += 1.0
		if Input.is_action_pressed("left"):
			rope_physics.acc_x -= 1.0

		rope_physics.update(self, delta)

		_resolve_penetration()
		_update_floor_stable(delta)
		return

	
	# ---------------- NORMAL MODE ----------------
	if _on_floor_stable and _move_input_dir == 0:
		velocity.x = 0

	velocity.y += GRAVITY * delta

	_on_floor = _move_with_bitmap(delta)
	_resolve_penetration()

	var was_stable: bool = _on_floor_stable
	_update_floor_stable(delta)

	if was_stable and not _on_floor_stable:
		_just_left_ground = true

	if not _on_floor_stable and LEDGE_CARRY_DECAY > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, LEDGE_CARRY_DECAY * delta * 60.0)

	if _on_floor_stable and not was_stable:
		_grounded_x_memory = velocity.x
		_just_left_ground = false
		possible_jumps_now = possible_jumps

	if _want_weapon_visible:
		show_weapon()
	else:
		hide_weapon()

	if trail and trail.visible:
		trail.add_point(global_position)
		if trail.points.size() > 20:
			trail.remove_point(0)


func _move_with_bitmap(delta: float) -> bool:
	var step_world: float = max(0.25, _px_step() * MOVE_SUBSTEP_PX)
	var max_step: float = _px_to_world(MAX_STEP_HEIGHT_PX)
	var started_grounded: bool = _on_floor_stable or (_grace_left > 0.0)

	var pos: Vector2 = global_position
	var on_floor_now: bool = false
	var total_move: Vector2 = velocity * delta

	# --- X MOVEMENT ---
	var rem_x: float = total_move.x
	while abs(rem_x) > 0.0001:
		var sx: float = clamp(rem_x, -step_world, step_world)
		var dx: int = -1 if sx < 0.0 else 1

		# маленький margin чтобы не “влипать” в стенку по грани
		var margin: float = _px_to_world(1) * 0.1
		var test_x: float = pos.x + sx + (margin * float(dx))

		if _wall_check(Vector2(test_x, pos.y) + CENTER_OFFSET, dx):
			var climbed: bool = false
			for i in range(1, MAX_STEP_HEIGHT_PX + 1):
				var up: float = _px_to_world(i)
				if not _wall_check(Vector2(test_x, pos.y - up) + CENTER_OFFSET, dx):
					pos.x = test_x
					pos.y -= up
					climbed = true
					break

			if not climbed:
				velocity.x = 0.0
				rem_x = 0.0
				break
		else:
			pos.x = test_x

		# Stick to ground (только пока были “на земле”)
		if started_grounded and _disable_follow_ground_frames <= 0 and velocity.y >= 0.0:
			var found: bool = false
			var drop: float = 0.0
			while drop <= max_step:
				if _ground_check(pos + CENTER_OFFSET):
					found = true
					velocity.y = 0.0
					on_floor_now = true
					break
				pos.y += step_world
				drop += step_world

			if not found:
				pos.y -= drop

				# ✅ мягкий сход с края: даём горизонтальную скорость ОДИН РАЗ
				if _just_left_ground:
					var fall_dir: int = _move_input_dir if _move_input_dir != 0 else _get_facing_dir()

					# если на земле скорость была почти 0 — зададим минимум, иначе оставим ту, что была
					var carry: float = _grounded_x_memory
					if abs(carry) < LEDGE_CARRY_MIN_SPEED:
						carry = LEDGE_CARRY_MIN_SPEED * float(fall_dir)

					# ограничим, чтобы не разгоняло сверх меры
					carry = clamp(carry, -LEDGE_CARRY_MAX_SPEED, LEDGE_CARRY_MAX_SPEED)

					velocity.x = carry
					_just_left_ground = false

				started_grounded = false
				on_floor_now = false
		rem_x -= sx

	# --- Y MOVEMENT ---
	var rem_y: float = total_move.y
	while abs(rem_y) > 0.0001:
		var sy: float = clamp(rem_y, -step_world, step_world)
		pos.y += sy
		var c: Vector2 = pos + CENTER_OFFSET

		if sy > 0.0:
			if _ground_check(c):
				velocity.y = 0.0
				on_floor_now = true
				# “вытащим” наверх из пола мелким шагом
				while _ground_check(pos + CENTER_OFFSET):
					pos.y -= 0.1
				break
		elif sy < 0.0:
			if _ceiling_check(c):
				velocity.y = 0.0
				velocity.x *= 0.2
				while _ceiling_check(pos + CENTER_OFFSET):
					pos.y += 0.1
				break

		rem_y -= sy

	global_position = pos
	return on_floor_now or _ground_check(_pos_center())


# -------------------- HELPERS --------------------

func _px_step() -> float:
	return float(terrain.world_scale) if terrain else 1.0

func _px_to_world(px: int) -> float:
	return float(px) * _px_step()

func _pos_center() -> Vector2:
	return global_position + CENTER_OFFSET

func _update_floor_stable(delta: float) -> void:
	if _on_floor:
		_grace_left = GROUND_GRACE_TIME
	else:
		_grace_left = max(0.0, _grace_left - delta)
	_on_floor_stable = _grace_left > 0.0


func _resolve_penetration() -> void:
	var center: Vector2 = _pos_center()
	if not _any_overlap(center):
		return

	var step: float = 0.1
	for i in range(1, 10):
		var dist: float = float(i) * step
		for d in [Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
			if not _any_overlap(center + d * dist):
				global_position += d * dist
				return


func _snap_to_ground(max_px: int) -> void:
	for _i in range(max_px * 2):
		if _ground_check(_pos_center()):
			return
		global_position.y += 0.5


# -------------------- WEAPONS --------------------

func _set_weapon(scene: PackedScene) -> void:
	if not scene:
		return
	_ensure_weapon_socket()
	for c in weapon_socket.get_children():
		c.queue_free()

	var w: Node2D = scene.instantiate() as Node2D
	weapon_socket.add_child(w)
	current_weapon = w

	# руки
	if w.has_node("grip_front"):
		hand.reparent(w.get_node("grip_front"))
		hand.position = Vector2.ZERO
	if w.has_node("grip_back"):
		hand_bwd.reparent(w.get_node("grip_back"))
		hand_bwd.position = Vector2.ZERO


func hide_weapon() -> void:
	if current_weapon and current_weapon.has_node("weapon"):
		(current_weapon.get_node("weapon") as CanvasItem).visible = false
	pritsel.visible = false
	# rope_line НЕ трогаем — она живёт в rope.tscn и управляется RopeState/weapon


func show_weapon() -> void:
	if current_weapon and current_weapon.has_node("weapon"):
		(current_weapon.get_node("weapon") as CanvasItem).visible = true
	pritsel.visible = true


func _get_weapon() -> Node2D:
	return current_weapon


# -------------------- AIM / FACING --------------------

func _get_facing_dir() -> int:
	return 1 if $bob.scale.x < 0.0 else -1


func _set_facing(dir: int, _src: String) -> void:
	if dir == 0:
		return
	var old: int = _get_facing_dir()
	var s: Vector2 = base_bob_scale
	s.x = (-abs(base_bob_scale.x)) if dir > 0 else abs(base_bob_scale.x)
	$bob.scale = s
	var now: int = _get_facing_dir()
	if now != old and old != 0:
		_aim_deg_local = -_aim_deg_local


func _update_weapon_aim(delta: float) -> void:
	var up: bool = Input.is_action_pressed("aim_up")
	var dn: bool = Input.is_action_pressed("aim_down")

	var dir: int = _get_facing_dir()
	var d: float = 0.0
	d += AIM_SPEED_DEG * delta if up else 0.0
	d -= AIM_SPEED_DEG * delta if dn else 0.0
	d = (-d) if dir == -1 else d

	_aim_deg_local = clamp(_aim_deg_local + d, AIM_MIN_DEG, AIM_MAX_DEG)
	shown_deg = _aim_deg_local * float(dir)
	weapon_pivot.rotation = deg_to_rad(shown_deg)


# -------------------- MOVEMENT LOGIC --------------------

func _handle_on_ground() -> void:
	var dir: int = (1 if Input.is_action_pressed("right") else 0) - (1 if Input.is_action_pressed("left") else 0)
	var shift_held: bool = Input.is_action_pressed("shift")
	var frame: int = Engine.get_physics_frames()

	# поворот на шифте (без движения)
	if shift_held and dir != 0:
		var current_facing: int = _get_facing_dir()
		if dir != current_facing:
			_set_facing(dir, "shift_turn")
			_no_move_until_frame = frame + 5
			velocity.x = 0.0
			_move_input_dir = 0
			return

	if frame <= _no_move_until_frame:
		velocity.x = 0.0
		_move_input_dir = 0
		return

	_move_input_dir = dir
	if dir != 0:
		_set_facing(dir, "walk")

	var speed: float = float(SPEED)
	if shift_held:
		speed *= WALK_FACTOR

	velocity.x = float(dir) * speed


func _update_hold_timer(delta: float) -> void:
	var dir: int = (1 if Input.is_action_pressed("right") else 0) - (1 if Input.is_action_pressed("left") else 0)
	_dir_hold_time = (_dir_hold_time + delta) if dir != 0 else 0.0


# -------------------- JUMPS --------------------

func _jump_fwd_impl() -> void:
	velocity.y = -220.0
	velocity.x = 130.0 * float(_get_facing_dir())

func _jump_bwd_impl() -> void:
	velocity.y = -320.0
	velocity.x = -80.0 * float(_get_facing_dir())


# -------------------- INPUT --------------------

func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
		global_position = get_global_mouse_position()
		velocity = Vector2.ZERO

	# оружия
	if e.is_action_pressed("weapon_1"):
		_set_weapon(GUN_SCENE)
	if e.is_action_pressed("weapon_2"):
		_set_weapon(GUN2_SCENE)
	if e.is_action_pressed("weapon_3"):
		_set_weapon(ROPE_SCENE)


# -------------------- STATES --------------------

func change_state_to_rope(hook_pos: Vector2) -> void:
	var rope_state: Node = $States/RopeState
	_player_state = rope_state
	if _player_state and _player_state.has_method("enter"):
		_player_state.call("enter", self, {"hook_pos": hook_pos})


# Проверка коллизий, но для произвольной позиции (не текущей)
func _any_overlap_at_global_pos(test_global_pos: Vector2) -> bool:
	var old_pos := global_position
	global_position = test_global_pos
	var c := _pos_center()
	var bad := _any_overlap(c)
	global_position = old_pos
	return bad


# Движение "на смещение" (motion), а не velocity*delta.
# Используем тот же алгоритм, что и _move_with_bitmap, но total_move = motion.
func _set_center_position(center: Vector2) -> void:
	# смещение от global_position до центра
	var offset := _pos_center() - global_position
	global_position = center - offset


func _move_with_bitmap_motion(motion: Vector2) -> bool:
	var step_world: float = max(0.25, _px_step() * MOVE_SUBSTEP_PX)
	var max_step: float = _px_to_world(MAX_STEP_HEIGHT_PX)
	var started_grounded: bool = _on_floor_stable or (_grace_left > 0.0)

	var pos: Vector2 = global_position
	var on_floor_now: bool = false
	var total_move: Vector2 = motion

	# --- X MOVEMENT ---
	var rem_x: float = total_move.x
	var guard_x: int = 0
	while abs(rem_x) > 0.0001 and guard_x < 256:
		guard_x += 1

		var sx: float = clamp(rem_x, -step_world, step_world)
		var dx: int = int(sign(sx))
		var margin: float = _px_to_world(1) * 0.1
		var test_x: float = pos.x + sx + (margin * float(dx))

		if dx != 0 and _wall_check(Vector2(test_x, pos.y) + CENTER_OFFSET, dx):
			var climbed: bool = false
			for i in range(1, MAX_STEP_HEIGHT_PX + 1):
				var up: float = _px_to_world(i)
				if not _wall_check(Vector2(test_x, pos.y - up) + CENTER_OFFSET, dx):
					pos.x = test_x
					pos.y -= up
					climbed = true
					break
			if not climbed:
				rem_x = 0.0
				break
		else:
			pos.x = test_x

		# stick-to-ground только если реально были на земле
		if started_grounded and _disable_follow_ground_frames <= 0 and motion.y >= 0.0:
			var found: bool = false
			var drop: float = 0.0
			var guard_drop: int = 0
			while drop <= max_step and guard_drop < 256:
				guard_drop += 1
				if _ground_check(pos + CENTER_OFFSET):
					found = true
					break
				pos.y += step_world
				drop += step_world

			if not found:
				pos.y -= drop
				started_grounded = false
				on_floor_now = false
			else:
				on_floor_now = true

		rem_x -= sx

	# --- Y MOVEMENT ---
	var rem_y: float = total_move.y
	var guard_y: int = 0
	while abs(rem_y) > 0.0001 and guard_y < 256:
		guard_y += 1

		var sy: float = clamp(rem_y, -step_world, step_world)
		pos.y += sy
		var c: Vector2 = pos + CENTER_OFFSET

		if sy > 0.0:
			if _ground_check(c):
				on_floor_now = true
				# вместо 0.1 — step_world и лимит
				var it_fix: int = 0
				while it_fix < 64 and _ground_check(pos + CENTER_OFFSET):
					pos.y -= step_world
					it_fix += 1
				break
		elif sy < 0.0:
			if _ceiling_check(c):
				var it_fix2: int = 0
				while it_fix2 < 64 and _ceiling_check(pos + CENTER_OFFSET):
					pos.y += step_world
					it_fix2 += 1
				break

		rem_y -= sy

	global_position = pos
	return on_floor_now or _ground_check(_pos_center())


func _solid_check(pos: Vector2) -> bool:
	var hw := WIDTH * 0.5
	var h := HEIGHT

	# точки хитбокса
	var points := [
		pos + Vector2(-hw, 0),        # верх-лево
		pos + Vector2( hw, 0),        # верх-право
		pos + Vector2(-hw, h),        # низ-лево
		pos + Vector2( hw, h),        # низ-право

		pos + Vector2(0, 0),          # верх-центр
		pos + Vector2(0, h),          # низ-центр
		pos + Vector2(-hw, h * 0.5),  # центр-лево
		pos + Vector2( hw, h * 0.5),  # центр-право
		pos + Vector2(0, h * 0.5)     # центр
	]

	for p in points:
		if _is_solid_point(p):
			return true

	return false
