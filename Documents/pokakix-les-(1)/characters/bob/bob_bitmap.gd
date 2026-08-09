extends CharacterBody2D

@export var TERRAIN_PATH: NodePath

# Геометрия персонажа (круг)
@export var RADIUS: float = 8.0
@export var CENTER_OFFSET: Vector2 = Vector2.ZERO

# Движение по битмапу
@export var MAX_STEP_HEIGHT_PX: int = 10
@export var SKIN_PX: int = 1
@export var PREJUMP_LIFT_PX: int = 1
@export var GROUND_GRACE_TIME: float = 0.10

# Семплы
@export var FOOT_SAMPLES: int = 11
@export var WALL_SAMPLES: int = 9
@export var CEIL_SAMPLES: int = 9

# Дуга опоры
@export var SUPPORT_MIN_DEG: float = 20.0
@export var SUPPORT_MAX_DEG: float = 160.0

# Макс. наклон (пока просто оставляем параметр, если захочешь — добавим реальный расчёт нормали)
@export var MAX_SLOPE_DEG: float = 60.0

# Скорости
@export var SPEED: int = 70
@export var GRAVITY: int = 900
@export var WALK_FACTOR: float = 0.2
@export var SHIFT_START_DELAY: float = 0.12
@export var DEBUG: bool = false

# Прилипание к земле на спуске
@export var FOLLOW_GROUND_EXTRA_PX: int = 12

# ✅ Саб-степ по X в пикселях террейна.
# при world_scale=2: 0.25px = 0.5 world units
@export var MOVE_SUBSTEP_PX: float = 0.25

# Прыжки
@export var possible_jumps: int = 2
var possible_jumps_now: int = 0

# Прицел
@export var AIM_SPEED_DEG: float = 180.0
@export var AIM_MIN_DEG: float = -90.0
@export var AIM_MAX_DEG: float = 90.0

@onready var weapon_pivot: Node2D = $bob/weapon_pivot
@onready var pritsel: CanvasItem = $bob/weapon_pivot/pritsel

# States
@onready var _player_state: Node = $States/NormalState

# Оружие
var current_weapon: Node2D = null
var weapon_socket: Node2D = null

@export var GUN_SCENE: PackedScene = preload("res://weapons/gun.tscn")
@export var GUN2_SCENE: PackedScene = preload("res://weapons/gun2.tscn")
@export var ROPE_SCENE: PackedScene = preload("res://weapons/rope/rope.tscn")
var _weapon_slot: int = 1

@onready var hand: Node2D = $bob/weapon_pivot/hand
@onready var hand_bwd: Node2D = $bob/weapon_pivot/hand_bwd

var _aim_deg_local: float = 0.0
var shown_deg: float = 0.0

var terrain: Node = null

# Shift-логика
var _no_move_until_frame: int = -1
var _dir_hold_time: float = 0.0
var _last_dir_for_hold: int = 0
var _bypass_shift_delay_this_frame: bool = false

# Состояния движения
var _jumped_this_frame: bool = false
var _jump_pressed_this_frame: bool = false
var _on_floor: bool = false
var _on_floor_stable: bool = false
var _grace_left: float = 0.0
var _disable_follow_ground_frames: int = 0
var base_bob_scale: Vector2 = Vector2.ONE

# ввод по X (-1/0/+1)
var _move_input_dir: int = 0

# state ставит “хочу оружие”, player применяет в конце кадра
var _want_weapon_visible: bool = false


# -------------------- READY --------------------

func _ready() -> void:
	base_bob_scale = $bob.scale

	terrain = get_node_or_null(TERRAIN_PATH) if TERRAIN_PATH != NodePath("") else null
	if terrain == null:
		push_error("TERRAIN_PATH не найден / Terrain отсутствует")
		return

	_ensure_weapon_socket()

	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout

	if has_node("character_trail"):
		$character_trail.visible = true

	possible_jumps_now = possible_jumps

	_resolve_penetration()
	_snap_to_ground(MAX_STEP_HEIGHT_PX)

	_on_floor = _ground_check(_pos_center())
	_on_floor_stable = _on_floor
	_grace_left = 0.0

	_weapon_slot = 1
	_set_weapon(GUN2_SCENE)


func _ensure_weapon_socket() -> void:
	if weapon_socket != null and is_instance_valid(weapon_socket):
		return
	weapon_socket = weapon_pivot.get_node_or_null("weapon_socket") as Node2D
	if weapon_socket == null:
		weapon_socket = Node2D.new()
		weapon_socket.name = "weapon_socket"
		weapon_pivot.add_child(weapon_socket)


# -------------------- INPUT --------------------

func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
		_teleport_to_mouse()

	if e.is_action_pressed("weapon_1") and e.is_pressed():
		_set_weapon(GUN_SCENE)
	elif e.is_action_pressed("weapon_2") and e.is_pressed():
		_set_weapon(GUN2_SCENE)
	elif e.is_action_pressed("weapon_3") and e.is_pressed():
		_set_weapon(ROPE_SCENE)


func _teleport_to_mouse() -> void:
	global_position = get_global_mouse_position()
	velocity = Vector2.ZERO
	_grace_left = 0.0
	_on_floor = false
	_on_floor_stable = false
	_resolve_penetration()
	_snap_to_ground(MAX_STEP_HEIGHT_PX)


# -------------------- WEAPON --------------------

func _set_weapon(weapon_scene: PackedScene) -> void:
	if weapon_scene == null:
		return

	_ensure_weapon_socket()

	if hand == null or hand_bwd == null:
		push_error("hand/hand_bwd == null. Проверь пути и существование нод.")
		return

	hand.reparent(weapon_pivot)
	hand_bwd.reparent(weapon_pivot)

	for c in weapon_socket.get_children():
		c.queue_free()
	current_weapon = null

	var w: Node2D = weapon_scene.instantiate() as Node2D
	weapon_socket.add_child(w)
	current_weapon = w
	w.position = Vector2.ZERO
	w.z_as_relative = false
	w.z_index = 4

	if not w.has_node("grip_front") or not w.has_node("grip_back"):
		push_warning("Weapon has no grip_front / grip_back")
		return

	var gf: Node2D = w.get_node("grip_front") as Node2D
	var gb: Node2D = w.get_node("grip_back") as Node2D

	hand.reparent(gf)
	hand.position = Vector2.ZERO
	hand_bwd.reparent(gb)
	hand_bwd.position = Vector2.ZERO

	hand.z_as_relative = false
	hand.z_index = 8
	hand_bwd.z_as_relative = false
	hand_bwd.z_index = 0


func _get_weapon() -> Node2D:
	return current_weapon


func hide_weapon() -> void:
	if current_weapon and current_weapon.has_node("weapon"):
		(current_weapon.get_node("weapon") as CanvasItem).visible = false
	pritsel.visible = false


func show_weapon() -> void:
	if current_weapon and current_weapon.has_node("weapon"):
		(current_weapon.get_node("weapon") as CanvasItem).visible = true
	pritsel.visible = true


# -------------------- PHYSICS --------------------

func _physics_process(delta: float) -> void:
	if terrain == null:
		return

	_want_weapon_visible = false
	if _player_state and _player_state.has_method("physics_update"):
		_player_state.call("physics_update", self, delta)

	velocity.y += GRAVITY * delta

	_on_floor = _move_with_bitmap(delta)

	_resolve_penetration()

	var was_stable: bool = _on_floor_stable
	_update_floor_stable(delta)

	if _on_floor_stable and not was_stable:
		possible_jumps_now = possible_jumps

	if _want_weapon_visible:
		show_weapon()
	else:
		hide_weapon()


# -------------------- AIM / FACING --------------------

func _get_facing_dir() -> int:
	var sx: float = float($bob.scale.x)
	if sx > 0.0:
		return -1
	if sx < 0.0:
		return 1
	return 0


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


# -------------------- GROUND MOVE --------------------

func _handle_on_ground() -> void:
	var frame: int = Engine.get_physics_frames()
	var left_j: bool = Input.is_action_just_pressed("left")
	var right_j: bool = Input.is_action_just_pressed("right")
	var shift_held: bool = Input.is_action_pressed("shift")

	if shift_held and (left_j or right_j):
		var tap_dir: int = 0
		tap_dir = 1 if right_j else tap_dir
		tap_dir = -1 if left_j else tap_dir

		var facing: int = _get_facing_dir()
		if facing != 0 and tap_dir != 0:
			if tap_dir == facing:
				_bypass_shift_delay_this_frame = true
			else:
				_set_facing(tap_dir, "shift_turn_only")
				_no_move_until_frame = frame
				velocity.x = 0.0
				return

	var left_p: bool = Input.is_action_pressed("left")
	var right_p: bool = Input.is_action_pressed("right")

	var dir: int = 0
	dir += 1 if right_p else 0
	dir -= 1 if left_p else 0

	if frame <= _no_move_until_frame:
		velocity.x = 0.0
		return

	if dir == 0:
		velocity.x = 0.0
		return

	if dir != _get_facing_dir():
		_set_facing(dir, "ground_move")

	var speed: float = float(SPEED)
	if shift_held:
		if (not _bypass_shift_delay_this_frame) and (_dir_hold_time < SHIFT_START_DELAY):
			velocity.x = 0.0
			return
		speed = float(SPEED) * WALK_FACTOR

	velocity.x = float(dir) * speed


func _update_hold_timer(delta: float) -> void:
	var left_p: bool = Input.is_action_pressed("left")
	var right_p: bool = Input.is_action_pressed("right")

	var dir_now: int = 0
	dir_now += 1 if right_p else 0
	dir_now -= 1 if left_p else 0

	if dir_now != _last_dir_for_hold:
		_dir_hold_time = 0.0
		_last_dir_for_hold = dir_now
	else:
		_dir_hold_time = (_dir_hold_time + delta) if dir_now != 0 else 0.0


# -------------------- JUMPS --------------------

func _jump_fwd_impl() -> void:
	velocity.y = -200.0
	var sx: float = 1.0 if ($bob.scale.x >= 0.0) else -1.0
	velocity.x = -125.0 * sx


func _jump_bwd_impl() -> void:
	velocity.y = -300.0
	await get_tree().create_timer(0.1).timeout
	var sx: float = 1.0 if ($bob.scale.x >= 0.0) else -1.0
	velocity.x = 85.0 * sx


# -------------------- SCALE HELPERS --------------------

func _px_step() -> float:
	if terrain != null and ("world_scale" in terrain):
		var s: float = float(terrain.world_scale)
		return s if s > 0.0 else 1.0
	return 1.0


func _px_to_world(px: int) -> float:
	return float(px) * _px_step()


func _skin_world() -> float:
	return _px_to_world(max(0, SKIN_PX))


func _pos_center() -> Vector2:
	return global_position + CENTER_OFFSET


# -------------------- TERRAIN CHECKS --------------------

func _is_solid_point(world_pos: Vector2) -> bool:
	return terrain != null and terrain.is_solid(world_pos)


func _solid_on_arc(center: Vector2, radius: float, from_ang: float, to_ang: float, samples: int) -> bool:
	var n: int = max(2, samples)
	var a0: float = from_ang
	var a1: float = to_ang
	a0 = fposmod(a0, TAU)
	a1 = fposmod(a1, TAU)
	a1 = (a1 + TAU) if a1 < a0 else a1

	for i in range(n):
		var t: float = float(i) / float(n - 1)
		var a: float = a0 + (a1 - a0) * t
		var aa: float = fposmod(a, TAU)
		var p: Vector2 = center + Vector2(cos(aa), sin(aa)) * radius
		if _is_solid_point(p):
			return true
	return false


func _ground_check(center: Vector2) -> bool:
	var skin: float = _skin_world()
	var r0: float = max(1.0, RADIUS - skin)
	var r1: float = r0 + _px_step() * 0.5
	var n: int = max(5, FOOT_SAMPLES)

	var a0: float = deg_to_rad(SUPPORT_MIN_DEG)
	var a1: float = deg_to_rad(SUPPORT_MAX_DEG)

	return (
		_solid_on_arc(center, r0, a0, a1, n)
		or _solid_on_arc(center, r1, a0, a1, n)
	)


func _ceiling_check(center: Vector2) -> bool:
	var r: float = max(1.0, RADIUS - _skin_world())
	return _solid_on_arc(center, r, deg_to_rad(225.0), deg_to_rad(315.0), max(3, CEIL_SAMPLES))


func _wall_check(center: Vector2, dir: int) -> bool:
	var r: float = max(1.0, RADIUS - _skin_world())
	return (
		_solid_on_arc(center, r, deg_to_rad(135.0), deg_to_rad(225.0), max(3, WALL_SAMPLES))
		if dir < 0
		else _solid_on_arc(center, r, deg_to_rad(315.0), deg_to_rad(45.0), max(3, WALL_SAMPLES))
	)


func _update_floor_stable(delta: float) -> void:
	var c: Vector2 = _pos_center()
	if _on_floor or _ground_check(c):
		_grace_left = GROUND_GRACE_TIME
	else:
		_grace_left = max(0.0, _grace_left - delta)
	_on_floor_stable = _grace_left > 0.0


# -------------------- SNAP / PENETRATION --------------------

func _snap_to_ground(max_px: int) -> void:
	if terrain == null:
		return
	var step: float = _px_step() * 0.5
	var max_drop: float = _px_to_world(max_px)
	var dropped: float = 0.0

	while dropped <= max_drop + 0.00001:
		if _ground_check(_pos_center()):
			velocity.y = 0.0
			_on_floor = true
			_on_floor_stable = true
			_grace_left = GROUND_GRACE_TIME
			return
		global_position.y += step
		dropped += step


func _any_overlap(center: Vector2) -> bool:
	return _ground_check(center) or _ceiling_check(center) or _wall_check(center, -1) or _wall_check(center, 1)


func _resolve_penetration() -> void:
	if terrain == null:
		return

	var step: float = _px_step() * 0.5
	var max_push: float = _px_to_world(MAX_STEP_HEIGHT_PX) + RADIUS + step

	var c0: Vector2 = _pos_center()
	if not _any_overlap(c0):
		return

	var v: Vector2 = velocity
	var prefer: Vector2 = (-v).normalized() if v.length() > 0.001 else Vector2.UP

	var dirs: Array[Vector2] = []
	dirs.append(prefer)
	dirs.append(Vector2.UP)
	dirs.append(Vector2.DOWN)
	dirs.append(Vector2.LEFT)
	dirs.append(Vector2.RIGHT)
	dirs.append(Vector2(-1, -1).normalized())
	dirs.append(Vector2(1, -1).normalized())
	dirs.append(Vector2(-1, 1).normalized())
	dirs.append(Vector2(1, 1).normalized())

	var best_pos: Vector2 = global_position
	var found: bool = false
	var pushed: float = 0.0

	while pushed <= max_push + 0.00001 and not found:
		pushed += step
		for d in dirs:
			var try_pos: Vector2 = global_position + d * pushed
			var try_center: Vector2 = try_pos + CENTER_OFFSET
			if not _any_overlap(try_center):
				best_pos = try_pos
				found = true
				break

	if found:
		global_position = best_pos
	else:
		velocity = Vector2.ZERO


# -------------------- MOVEMENT --------------------

func _move_with_bitmap(delta: float) -> bool:
	var px_step_world: float = _px_step()
	var step_world: float = max(0.25, px_step_world * MOVE_SUBSTEP_PX)
	var max_step: float = _px_to_world(MAX_STEP_HEIGHT_PX)
	var extra_down: float = _px_to_world(FOLLOW_GROUND_EXTRA_PX)
	var skin: float = _skin_world()

	# ✅ ВАЖНО: stick-to-ground “на большую глубину” только если мы реально были на земле
	# (или действует grace). Иначе он обрывает прыжок на падении.
	var started_grounded: bool = _on_floor_stable or (_grace_left > 0.0)

	var pos: Vector2 = global_position
	var on_floor_now: bool = false

	var total_move: Vector2 = velocity * delta
	var remaining_x: float = total_move.x

	while abs(remaining_x) > 0.00001:
		var step_x: float = clamp(remaining_x, -step_world, step_world)
		var dir_x: int = -1 if step_x < 0.0 else 1

		var target_x: float = pos.x + step_x
		var test_pos: Vector2 = pos
		test_pos.x = target_x

		if _collides_side(test_pos, dir_x, skin):
			var climbed: bool = false
			var up: float = step_world
			while up <= max_step + 0.00001:
				var t: Vector2 = pos + Vector2(0.0, -up)
				t.x = target_x
				if not _collides_side(t, dir_x, skin):
					pos = t
					pos.x = target_x
					climbed = true
					break
				up += step_world

			if not climbed:
				velocity.x = 0.0
				break
		else:
			pos.x = target_x

		# ✅ stick-to-ground после X-сабшага:
		# - только если started_grounded (иначе НЕ тянем вниз прыжок)
		# - и только если не заблокирован follow (после прыжка)
		# - и только если не идём вверх (velocity.y < 0)
		# ✅ stick-to-ground после X-сабшага:
		if started_grounded and _disable_follow_ground_frames == 0 and (not _jump_pressed_this_frame) and velocity.y >= 0.0:
			var center: Vector2 = pos + CENTER_OFFSET

			# ✅ КЛЮЧ: ищем землю ТОЛЬКО в пределах max_step.
			# Если не нашли — это обрыв, и мы НЕ "дотягиваем" вниз.
			var found_ground: bool = false
			var down: float = 0.0

			while down <= max_step + 0.00001:
				if _ground_check(center):
					found_ground = true
					break
				pos.y += step_world
				center.y += step_world
				down += step_world

			if found_ground:
				on_floor_now = true
				velocity.y = 0.0
			else:
				# откатим обратно, чтобы не сдвинуло Y ни на шаг
				pos.y -= down
		remaining_x -= step_x

	# Y движение саб-степами
	var remaining_y: float = total_move.y
	while abs(remaining_y) > 0.00001:
		var step_y: float = clamp(remaining_y, -step_world, step_world)
		pos.y += step_y

		var c: Vector2 = pos + CENTER_OFFSET
		if step_y > 0.0:
			if _collides_down(c, skin):
				var it: int = 0
				while it < 512 and _collides_down(c, skin):
					pos.y -= step_world
					c.y -= step_world
					it += 1
				velocity.y = 0.0
				on_floor_now = true
				break
		elif step_y < 0.0:
			if _collides_up(c, skin):
				var it2: int = 0
				while it2 < 512 and _collides_up(c, skin):
					pos.y += step_world
					c.y += step_world
					it2 += 1
				velocity.y = 0.0
				break

		remaining_y -= step_y

	global_position = pos
	on_floor_now = on_floor_now or _ground_check(_pos_center())
	return on_floor_now


# -------------------- COLLISIONS --------------------

func _collides_side(pos: Vector2, dir_x: int, _skin: float) -> bool:
	var c: Vector2 = pos + CENTER_OFFSET
	return _wall_check(c, dir_x)

func _collides_down(center: Vector2, _skin: float) -> bool:
	return _ground_check(center)

func _collides_up(center: Vector2, _skin: float) -> bool:
	return _ceiling_check(center)
