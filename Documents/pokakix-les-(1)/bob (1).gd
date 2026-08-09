extends CharacterBody2D

@export var SPEED : int = 70
@export var GRAVITY : int = 900
@export var HEALTH : int = 500
@export var TEAM = "green"

@export var WALK_FACTOR: float = 0.2              # замедление при Shift
@export var SHIFT_START_DELAY: float = 0.12       # задержка старта движения при зажатом Shift
@export var DEBUG: bool = true

# Прицел/оружие
@export var AIM_SPEED_DEG: float = 180.0          # скорость наведения (град/с)
@export var AIM_MIN_DEG:   float = -90.0          # нижняя граница
@export var AIM_MAX_DEG:   float =  90.0          # верхняя граница
@onready var weapon_pivot: Node2D = $bob/weapon_pivot
@onready var muzzle: Marker2D = $bob/weapon_pivot/muzzle
var _aim_deg_local: float = 0.0
var shown_deg: float = 0.0

var BulletScene := preload("res://shell/bullet/bullet.tscn")

# Блок движения до указанного физического кадра (включительно)
var _no_move_until_frame: int = -1

# Учёт удержания направления (для задержки старта при Shift)
var _dir_hold_time: float = 0.0
var _last_dir_for_hold: int = 0

# Флаг обхода задержки в текущем кадре (тап в свою сторону при зажатом Shift)
var _bypass_shift_delay_this_frame: bool = false

# Прочее
var jump_delay_time: float = 0.5
var rotate: bool = true
var rotate_timer: int = 0

# Прыжки
@export var possible_jumps: int = 1        # СКОЛЬКО ДОП. ПРЫЖКОВ В ВОЗДУХЕ (0 = только с земли)
var possible_jumps_now: int = 0            # текущий остаток (только для воздуха)
var _jumped_this_frame: bool = false
var _was_on_floor: bool = false
var jump_delay: int = 20	# Тут ставить задержку между прыжками 
var jump_counter: int = 0
@export var JUMP_STRENGHT: int = 0 # Параметр сила прыжка для сильных лёнчиков

func _ready() -> void:
	await get_tree().create_timer(0.4).timeout
	$character_trail.visible = true
	possible_jumps_now = possible_jumps
	_was_on_floor = is_on_floor()

func _physics_process(delta: float) -> void:
	var frame: int = Engine.get_physics_frames()
	_bypass_shift_delay_this_frame = false
	_jumped_this_frame = false

	# --- Прыжки: ловим нажатие ОДИН раз ---
	# Первый прыжок с земли НЕ тратит запас. В воздухе прыжок тратит one charge.
	if Input.is_action_pressed("jump_fwd") or Input.is_action_pressed("jump_bwd"):
		if is_on_floor():
			if Input.is_action_pressed("jump_fwd"):
				_jump_fwd_impl()
			else:
				_jump_bwd_impl()
			_jumped_this_frame = true
		else:
			if possible_jumps_now > 0:
				if Input.is_action_pressed("jump_fwd"):
					_jump_fwd_impl()
				else:
					_jump_bwd_impl()
				_jumped_this_frame = true

	# --- Переход состояния пола для сброса попыток ---
	var now_on_floor: bool = is_on_floor()
	if now_on_floor and not _was_on_floor:
		# Приземлились: восстановить запас воздушных прыжков
		possible_jumps_now = possible_jumps

	# --- Земля/Воздух ---
	if now_on_floor:
		show_weapon()

		rotate = false
		rotate_timer = 0
		$bob.rotation_degrees = 0

		if frame <= _no_move_until_frame:
			if DEBUG:
				print("[DBG]", frame, " PHYS: MOVE blocked (until=", _no_move_until_frame, ")")
			velocity.x = 0
		else:
			if not _jumped_this_frame:
				_handle_on_ground()
	else:
		hide_weapon()
		velocity.y += GRAVITY * delta
		if rotate == true:
			$bob.rotate(0.001 * abs(velocity.y) * $bob.scale.x)
		rotate_timer += 1
		if rotate_timer >= 30:
			rotate = true
	
	if jump_counter <= jump_delay:
		jump_counter = jump_counter + 1

	# Телепорт по клику (как было)
	if Input.is_action_just_pressed("action"):
		position = get_global_mouse_position()

	# Падение за карту
	if position.y > 2000.0:
		$character_trail.visible = false
		position = Vector2(900.0, -1000.0)
		velocity = Vector2.ZERO
		await get_tree().create_timer(0.5).timeout
		$character_trail.visible = true

	# Страховка на блок-кадр
	if frame <= _no_move_until_frame:
		velocity.x = 0

	move_and_slide()

	# Обновление прицела
	_update_weapon_aim(delta)

	# Учёт удержания направления для задержки при Shift
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

	_was_on_floor = now_on_floor

# ---------- ВСПОМОГАТЕЛЬНОЕ: поворот и направление ----------
func _set_facing(dir: int, src: String) -> void:
	if dir == 0:
		return
	var old: int = _get_facing_dir()
	if dir < 0:
		$bob.scale.x = 1.0
	else:
		$bob.scale.x = -1.0
	var now: int = _get_facing_dir()
	if now != old and old != 0:
		# инвертируем локальный угол прицела, чтобы мировой угол сохранился
		_aim_deg_local = -_aim_deg_local

# scale.x = 1.0 → смотрим влево (-1), scale.x = -1.0 → вправо (+1)
func _get_facing_dir() -> int:
	var sx: float = float($bob.scale.x)
	if sx > 0.0:
		return -1
	if sx < 0.0:
		return 1
	return 0

# ---------- ПРИЦЕЛ ----------
func _update_weapon_aim(delta: float) -> void:
	var up: bool  = Input.is_action_pressed("aim_up")
	var dn: bool  = Input.is_action_pressed("aim_down")

	var dir: int = _get_facing_dir()
	var delta_deg: float = 0.0
	if up:
		delta_deg += AIM_SPEED_DEG * delta
	if dn:
		delta_deg -= AIM_SPEED_DEG * delta

	# когда смотрим влево — инвертируем управление, чтобы "вверх" оставался вверх на экране
	if dir == -1:
		delta_deg = -delta_deg

	_aim_deg_local = clamp(_aim_deg_local + delta_deg, AIM_MIN_DEG, AIM_MAX_DEG)

	shown_deg = _aim_deg_local * float(dir)
	$bob/weapon_pivot.rotation = deg_to_rad(shown_deg)

# ---------- НАЗЕМНОЕ ДВИЖЕНИЕ + SHIFT-СТАН ----------
func _handle_on_ground() -> void:
	if Input.is_action_just_pressed("fire"):
		_shoot()

	var left_j: bool  = Input.is_action_just_pressed("left")
	var right_j: bool = Input.is_action_just_pressed("right")
	var shift_held: bool = Input.is_action_pressed("shift")

	var frame: int = Engine.get_physics_frames()

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
				return

	# удержания
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
		return

	if dir == 0:
		velocity.x = 0
		if DEBUG:
			print("[DBG]", frame, " IDLE: stop vx")
		return

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
				return
		speed = float(SPEED) * WALK_FACTOR

	velocity.x = dir * speed

	if DEBUG:
		print("[DBG]", frame, " MOVE: dir=", dir, " shift=", shift_held, " vx=", velocity.x)

# ---------- РЕАЛИЗАЦИЯ ПРЫЖКОВ (без списания попыток здесь) ----------
func _jump_fwd_impl() -> void:
	var shift_held: bool = Input.is_action_pressed("shift")
	if jump_counter > jump_delay:
		jump_counter = 0
		if !is_on_floor():
				possible_jumps_now -= 1
		if shift_held:
			velocity.y = -300.0
			velocity.x = -175.0 * $bob.scale.x
		if !shift_held:	
			velocity.y = -200.0
			velocity.x = -125.0 * $bob.scale.x
	else:
		pass

func _jump_bwd_impl() -> void:
	var shift_held: bool = Input.is_action_pressed("shift")
	if jump_counter > jump_delay:
		jump_counter = 0
		if !is_on_floor():
				possible_jumps_now -= 1
		if shift_held:
			velocity.y = -400.0
			if velocity.x > 100 or velocity.x < -100:
				velocity.x = 0
			await get_tree().create_timer(0.1).timeout
			velocity.x = 100.0 * $bob.scale.x
			rotate = true
		if !shift_held:	
			velocity.y = -300.0
			if velocity.x > 100 or velocity.x < -100:
				velocity.x = 0
			await get_tree().create_timer(0.1).timeout
			velocity.x = 85.0 * $bob.scale.x
			rotate = true
	else:
		pass

# ---------- ПОКАЗ/СКРЫТИЕ ОРУЖИЯ ----------
func hide_weapon() -> void:
	if has_node("bob/weapon_pivot/weapon"):
		$bob/weapon_pivot/weapon.visible = false
	if has_node("bob/weapon_pivot/pritsel"):
		$bob/weapon_pivot/pritsel.visible = false
	$bob/weapon_pivot.rotation = 0.0

func show_weapon() -> void:
	if has_node("bob/weapon_pivot/weapon"):
		$bob/weapon_pivot/weapon.visible = true
	if has_node("bob/weapon_pivot/pritsel"):
		$bob/weapon_pivot/pritsel.visible = true
	$bob/weapon_pivot.rotation = deg_to_rad(shown_deg)

# ---------- ВЫСТРЕЛ ----------
func _shoot() -> void:
	var b := BulletScene.instantiate()
	# позиция вылета
	b.global_position = $bob/weapon_pivot/muzzle.global_position
	# направление по стволу (устойчиво к флипу)
	var pivot := $bob/weapon_pivot
	var mz := $bob/weapon_pivot/muzzle
	var dir: Vector2 = (mz.global_position - pivot.global_position).normalized()
	b.setup(dir, self)
	get_tree().current_scene.add_child(b)

signal collide_with_map
