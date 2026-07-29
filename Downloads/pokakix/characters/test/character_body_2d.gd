extends CharacterBody2D

@export var TERRAIN_PATH: NodePath

@export var SPEED : int = 70
@export var GRAVITY : int = 900
@export var WALK_FACTOR: float = 0.2        # замедление при Shift
@export var SHIFT_START_DELAY: float = 0.12 # задержка старта движения при зажатом Shift
@export var DEBUG: bool = false

@export var FEET_OFFSET: Vector2 = Vector2(0, 8)  # нога относительно центра
@export var BODY_HEIGHT: float = 16.0             # примерная высота тела для коллизий

var MAX_STEP_HEIGHT = 4;
var terrain: Node

# --- ходьба/shift из твоего персонажа ---
var _no_move_until_frame: int = -1
var _dir_hold_time: float = 0.0
var _last_dir_for_hold: int = 0
var _bypass_shift_delay_this_frame: bool = false

func _ready() -> void:
	if TERRAIN_PATH != NodePath(""):
		terrain = get_node(TERRAIN_PATH)
	else:
		push_error("TERRAIN_PATH не задан")

# ======= ВСПОМОГАТЕЛЬНОЕ: ориентация спрайта =======

func _set_facing(dir: int, src: String) -> void:
	if dir == 0:
		return

	var old: int = _get_facing_dir()

	var s: Vector2 = $bob2.scale
	s.x = abs(s.x)        # возвращаем положительный модуль
	if dir > 0:           # смотрим вправо
		s.x = -s.x        # просто меняем знак
	# если dir < 0 → смотрим влево, оставляем x положительным

	$bob2.scale = s

	var now: int = _get_facing_dir()
	# остальное можешь не трогать

# scale.x = 1.0 → смотрим влево (-1), scale.x = -1.0 → вправо (+1)
func _get_facing_dir() -> int:
	var sx: float = float($bob2.scale.x)
	if sx > 0.0:
		return -1
	if sx < 0.0:
		return 1
	return 0

# ======= BitMap-земля =======

func _is_solid_point(world_pos: Vector2) -> bool:
	if terrain == null:
		return false
	return terrain.is_solid(world_pos)

func _is_on_ground(pos: Vector2) -> bool:
	# точка чуть ниже ног
	return _is_solid_point(pos + FEET_OFFSET + Vector2(0, 1))

# ======= Телепорт на ПКМ =======

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_RIGHT \
	and event.pressed:
		global_position = get_global_mouse_position()
		velocity = Vector2.ZERO

# ======= ОСНОВНОЙ ФИЗИЧЕСКИЙ ЦИКЛ =======

func _physics_process(delta: float) -> void:
	if terrain == null:
		return

	var frame: int = Engine.get_physics_frames()
	_bypass_shift_delay_this_frame = false

	# --- ГОРИЗОНТАЛЬНОЕ УПРАВЛЕНИЕ (твоя логика ходьбы) ---
	var left_j: bool  = Input.is_action_just_pressed("left")
	var right_j: bool = Input.is_action_just_pressed("right")
	var shift_held: bool = Input.is_action_pressed("shift")

	# tap при зажатом shift
	if shift_held and (left_j or right_j):
		var tap_dir: int = 0
		if right_j:
			tap_dir = 1
		elif left_j:
			tap_dir = -1

		var facing: int = _get_facing_dir()

		if facing != 0 and tap_dir != 0:
			if tap_dir == facing:
				_bypass_shift_delay_this_frame = true
				if DEBUG:
					print("[DBG]", frame, " SHIFT tap same-dir: allow move now (bypass delay)")
			else:
				_set_facing(tap_dir, "shift_turn_only")
				_no_move_until_frame = frame
				velocity.x = 0
				if DEBUG:
					print("[DBG]", frame, " SHIFT tap opposite-dir: turn-only, move blocked this frame")

	var left_p: bool  = Input.is_action_pressed("left")
	var right_p: bool = Input.is_action_pressed("right")

	var dir: int = 0
	if right_p:
		dir += 1
	if left_p:
		dir -= 1

	if frame <= _no_move_until_frame:
		if DEBUG:
			print("[DBG]", frame, " MOVE blocked inside handler (until=", _no_move_until_frame, ")")
		velocity.x = 0
	else:
		if dir == 0:
			velocity.x = 0
			if DEBUG:
				print("[DBG]", frame, " IDLE: stop vx")
		else:
			var current_facing: int = _get_facing_dir()
			if dir != current_facing:
				_set_facing(dir, "ground_move")

			var speed: float = float(SPEED)
			if shift_held:
				if not _bypass_shift_delay_this_frame:
					if _dir_hold_time < SHIFT_START_DELAY:
						if DEBUG:
							print("[DBG]", frame, " SHIFT delay: hold_time=", _dir_hold_time, " < ", SHIFT_START_DELAY, " → stop")
						velocity.x = 0
					else:
						speed = float(SPEED) * WALK_FACTOR
				else:
					speed = float(SPEED) * WALK_FACTOR

			if dir != 0:
				velocity.x = dir * speed

			if DEBUG:
				print("[DBG]", frame, " MOVE: dir=", dir, " shift=", shift_held, " vx=", velocity.x)

	# --- ГРАВИТАЦИЯ ---
	velocity.y += GRAVITY * delta

	# --- ДВИЖЕНИЕ С КОЛЛИЗИЯМИ ПО BITMAP (без climb по стенам) ---
	_move_with_bitmap(delta)

	# --- Учёт удержания направления для задержки при Shift ---
	_update_hold_timer(delta)

# ======= ДВИЖЕНИЕ ПО BITMAP (ось X и Y отдельно, без залезаний) =======

func _move_with_bitmap(delta: float) -> void:
	var new_pos: Vector2 = global_position
	var move: Vector2 = velocity * delta

	# --- X (стены + небольшой шаг вверх) ---
	var step_x: float = sign(move.x)
	var remaining_x: float = abs(move.x)

	while remaining_x > 0.0:
		var dx: float = min(1.0, remaining_x) * step_x
		var test_pos: Vector2 = new_pos + Vector2(dx, 0.0)

		if _collides_horiz(test_pos):
			# Пытаемся "шагнуть вверх" на пару пикселей, чтобы не застревать на краю ямы
			var stepped: bool = false
			for i in range(1, MAX_STEP_HEIGHT + 1):
				var step_pos: Vector2 = new_pos + Vector2(0.0, -float(i))
				var step_test: Vector2 = step_pos + Vector2(dx, 0.0)
				if not _collides_horiz(step_test):
					new_pos = step_test
					stepped = true
					break
			if stepped:
				remaining_x -= abs(dx)
				continue

			# Если даже шаг вверх не помог — это реальная стена, останавливаемся
			velocity.x = 0.0
			break

		new_pos.x += dx
		remaining_x -= abs(dx)

	# --- Y (земля и падение в дырки) ---
	var step_y: float = sign(move.y)
	var remaining_y: float = abs(move.y)

	while remaining_y > 0.0:
		var dy: float = min(1.0, remaining_y) * step_y
		var test_pos: Vector2 = new_pos + Vector2(0.0, dy)

		if _collides_vert(test_pos, dy):
			velocity.y = 0.0
			break

		new_pos.y += dy
		remaining_y -= abs(dy)

	global_position = new_pos


func _collides_horiz(pos: Vector2) -> bool:
	# Проверяем две точки по высоте: ноги и середину туловища
	var feet := pos + FEET_OFFSET
	var mid  := pos + Vector2(0, FEET_OFFSET.y - BODY_HEIGHT * 0.5)
	return _is_solid_point(feet) or _is_solid_point(mid)

func _collides_vert(pos: Vector2, dy: float) -> bool:
	if dy > 0.0:
		# вниз – проверяем ноги
		var feet := pos + FEET_OFFSET
		return _is_solid_point(feet)
	elif dy < 0.0:
		# вверх – проверяем голову
		var head := pos + Vector2(0, -BODY_HEIGHT * 0.5)
		return _is_solid_point(head)
	return false

# ======= ТАЙМЕР УДЕРЖАНИЯ НАПРАВЛЕНИЯ ДЛЯ SHIFT =======

func _update_hold_timer(delta: float) -> void:
	var left_p: bool  = Input.is_action_pressed("left")
	var right_p: bool = Input.is_action_pressed("right")
	var dir_now: int = 0
	if right_p:
		dir_now += 1
	if left_p:
		dir_now -= 1

	if dir_now != _last_dir_for_hold:
		_dir_hold_time = 0.0
		_last_dir_for_hold = dir_now
	else:
		if dir_now != 0:
			_dir_hold_time += delta
		else:
			_dir_hold_time = 0.0
