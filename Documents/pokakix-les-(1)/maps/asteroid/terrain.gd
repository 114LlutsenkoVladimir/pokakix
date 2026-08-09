extends Node2D

@export var BODY_PATH: NodePath
@export var DEFAULT_RADIUS: float = 32.0
@export_range(8, 64, 1) var CIRCLE_SEGMENTS: int = 28
@export var AABB_PAD: float = 2.0
@export var DEBUG_LOG: bool = true

var body: StaticBody2D

func _ready() -> void:
	if BODY_PATH == NodePath(""):
		push_error("BODY_PATH не задан.")
		return
	body = get_node(BODY_PATH) as StaticBody2D
	if body == null:
		push_error("BODY_PATH указывает не на StaticBody2D.")
		return

	# Нормализуем все уже существующие CollisionPolygon2D.
	for c in body.get_children():
		if c is CollisionPolygon2D:
			var cp := c as CollisionPolygon2D
			cp.build_mode = CollisionPolygon2D.BUILD_SOLIDS
			if cp.position != Vector2.ZERO or cp.rotation != 0.0 or cp.scale != Vector2.ONE:
				var xf: Transform2D = cp.transform
				var pts := PackedVector2Array()
				for v in cp.polygon:
					# Godot 4: вместо xf.xform(v) используем оператор умножения
					pts.append(xf * v)
				cp.polygon = pts
				cp.position = Vector2.ZERO
				cp.rotation = 0.0
				cp.scale = Vector2.ONE

	if DEBUG_LOG:
		var total := 0
		for c in body.get_children():
			if c is CollisionPolygon2D:
				total += 1
		print("[POLY] стартовых collision-полигонов: ", total)

func _unhandled_input(e: InputEvent) -> void:
	if body == null:
		return
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			carve_hole(get_global_mouse_position(), DEFAULT_RADIUS)
		elif e.button_index == MOUSE_BUTTON_RIGHT and DEBUG_LOG:
			_debug_probe(get_global_mouse_position())

func carve_hole(world_pos: Vector2, radius: float) -> void:
	var center_local: Vector2 = body.to_local(world_pos)
	var circle: PackedVector2Array = _make_circle(center_local, radius, CIRCLE_SEGMENTS)
	var circle_aabb: Rect2 = _aabb(circle).grow(AABB_PAD)

	var to_add: Array = []
	var to_del: Array = []

	for child in body.get_children():
		if not (child is CollisionPolygon2D):
			continue
		var cp := child as CollisionPolygon2D
		var poly: PackedVector2Array = cp.polygon

		# Быстрая проверка по AABB
		if not _aabb(poly).intersects(circle_aabb):
			continue

		# Разность: poly \ circle
		var result: Array = Geometry2D.clip_polygons(poly, circle)

		if result.is_empty():
			to_del.append(cp)
			if DEBUG_LOG:
				print("[CARVE] poly полностью удалён")
			continue

		# Первый результат остаётся в текущем узле
		cp.polygon = result[0]
		cp.build_mode = CollisionPolygon2D.BUILD_SOLIDS

		# Остальные добавляем как новые CollisionPolygon2D
		for i in range(1, result.size()):
			var new_poly: PackedVector2Array = result[i]
			var ncp := CollisionPolygon2D.new()
			ncp.build_mode = CollisionPolygon2D.BUILD_SOLIDS
			ncp.polygon = new_poly
			body.add_child(ncp)

	for n in to_del:
		n.queue_free()

	if DEBUG_LOG:
		print("[CARVE] применено: удалено=", to_del.size(), " добавлено=", max(0, body.get_child_count()))

func _debug_probe(world_pos: Vector2) -> void:
	var p := body.to_local(world_pos)
	var found := 0
	for child in body.get_children():
		if child is CollisionPolygon2D and Geometry2D.is_point_in_polygon(p, child.polygon):
			found += 1
	print("[PROBE] точка ", p, " попадает в ", found, " полигон(а)")

func _make_circle(center: Vector2, r: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segs):
		var t := float(i) / float(segs)
		var ang := TAU * t
		pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	return pts

func _aabb(pts: PackedVector2Array) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var r := Rect2(pts[0], Vector2.ZERO)
	for v in pts:
		r = r.expand(v)
	return r
