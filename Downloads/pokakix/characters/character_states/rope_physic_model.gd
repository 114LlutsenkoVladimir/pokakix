extends Node
class_name RopePhysics

# -------------------- НАСТРОЙКИ --------------------

@export var rope_gravity_scale: float = 1.0   # 1.0 = как у игрока
@export var idle_damping: float = 0.985       # демпфер без ввода (0.90–0.95)
@export var max_omega: float = 6.0             # ограничение раскрутки
@export var max_correction_world: float = 10.0

# Ввод КАК В WORMIX (ЗА ТИК)
var acc_x: float = 0.0        # world / tick
var d_length: float = 0.0     # world / tick
var _dir: Vector2 = Vector2.RIGHT

# -------------------- СОСТОЯНИЕ --------------------


var joints: Array[Vector2] = []
var last_joint: int = 0

var min_len: float = 0.0
var max_len: float = 0.0

var cur_len: float = 0.0
var target_len: float = 0.0

# канонические переменные Wormix
var angle: float = 0.0        # текущий угол
var omega: float = 0.0        # угловая скорость (рад / тик)




# --------------------------------------------------
# API
# --------------------------------------------------

func reset(anchor: Vector2, player_center: Vector2, min_len_world: float, max_len_world: float) -> void:
	joints = [anchor]
	last_joint = 0

	min_len = min_len_world
	max_len = max_len_world

	cur_len = clamp(player_center.distance_to(anchor), min_len, max_len)
	target_len = cur_len

	# --- ВАЖНО: вычисляем угол ТОЛЬКО ЗДЕСЬ ---
	var r := player_center - anchor
	angle = atan2(r.x, r.y)
	omega = 0.0

	acc_x = 0.0
	d_length = 0.0

func update(p: WormsPlayer, delta: float) -> void:
	if joints.is_empty():
		return

	var anchor := joints[last_joint]
	var center := p._pos_center()
	var grounded := p._ground_check(center)

	# -------------------------------
	# Геометрия
	# -------------------------------
	var r := center - anchor
	if r.length() < 0.001:
		return

	# -------------------------------
	# ⛔ НА ЗЕМЛЕ — ВЕРЁВКА НЕ ДВИГАЕТ
	# -------------------------------
	if grounded:
		omega = 0.0
		acc_x = 0.0
		d_length = 0.0
		return

	# -------------------------------
	# Управление длиной (энергосохранение)
	# -------------------------------
	if abs(d_length) > 0.00001:
		var old_len := cur_len
		var new_len : float = clamp(cur_len + d_length, min_len, max_len)
		if abs(new_len - old_len) > 0.00001:
			var vt := omega * old_len
			cur_len = new_len
			omega = vt / cur_len

	# -------------------------------
	# Гравитация маятника
	# -------------------------------
	var g := float(p.GRAVITY) * rope_gravity_scale
	omega += -(g / cur_len) * sin(angle) * delta

	# -------------------------------
	# Управление раскачкой
	# -------------------------------
	if abs(acc_x) > 0.00001 and abs(angle) < 0.4:
		omega += acc_x * 2.0 * delta

	# -------------------------------
	# Демпфер
	# -------------------------------
	if abs(acc_x) < 0.00001:
		omega *= idle_damping

	omega = clamp(omega, -max_omega, max_omega)

	# -------------------------------
	# Интеграция
	# -------------------------------
	angle += omega * delta

	# -------------------------------
	# КАСАТЕЛЬНОЕ движение
	# -------------------------------
	var tangent := Vector2(cos(angle), -sin(angle))
	var vt2 := omega * cur_len
	var move := tangent * vt2 * delta

	p._move_with_bitmap_motion(move)

	# -------------------------------
	# Constraint ТОЛЬКО В ВОЗДУХЕ
	# -------------------------------
	_apply_constraint_to_length_collision_safe(p, anchor, cur_len)

	# -------------------------------
	# Мягкая синхронизация угла
	# -------------------------------
	var new_r := p._pos_center() - anchor
	if new_r.length() > 0.001:
		angle = lerp_angle(angle, atan2(new_r.x, new_r.y), 0.08)

	acc_x = 0.0
	d_length = 0.0

func clear() -> void:
	joints.clear()
	last_joint = 0
	cur_len = 0.0
	target_len = 0.0
	omega = 0.0
	acc_x = 0.0
	d_length = 0.0




func _apply_constraint_to_length_collision_safe(
	p: WormsPlayer,
	anchor: Vector2,
	want_len: float
) -> void:
	var step : float = max(0.25, _piece_world(p))
	var guard := 0

	while guard < 64:
		guard += 1

		var center := p._pos_center()
		var r := center - anchor
		var dist := r.length()
		if dist < 0.0001:
			return

		var diff := dist - want_len
		if abs(diff) < 0.01:
			return

		# направление коррекции
		var n := r / dist

		# корректируем ТОЛЬКО по радиусу
		var corr := -n * diff
		corr = corr.limit_length(max_correction_world)
		corr = corr.limit_length(step)

		var before := p.global_position
		p._move_with_bitmap_motion(corr)

		# если упёрлись — дальше не тянем
		if p.global_position.distance_to(before) < 0.00001:
			return

# --------------------------------------------------
# ВИЗУАЛ / LINE2D
# --------------------------------------------------

func get_joint_points(player: WormsPlayer) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for j in joints:
		pts.append(j)
	pts.append(player._pos_center())
	return pts
	
const PIECE_PX: float = 5.0

func _piece_world(p: WormsPlayer) -> float:
	# минимальный шаг коррекции в world-координатах
	return PIECE_PX * float(p._px_step())
