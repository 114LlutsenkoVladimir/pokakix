extends StaticBody2D

@export var DEFAULT_RADIUS: float = 32.0
@export_range(6, 32, 1) var CIRCLE_SEGMENTS: int = 14
@export var AABB_PAD: float = 2.0
@export var DEBUG_LOG: bool = true

@onready var sprite: Sprite2D = $Sprite2D

var img: Image
var img_tex: ImageTexture
var img_size: Vector2i

func _ready() -> void:
	# Подготовка текстуры к редактированию
	if sprite == null or sprite.texture == null:
		push_error("Sprite2D с текстурой не найден или не имеет texture.")
		return

	img = sprite.texture.get_image()
	img_size = img.get_size()
	img_tex = ImageTexture.create_from_image(img)
	sprite.texture = img_tex   # своя копия текстуры

	# Нормализуем все CollisionPolygon2D в координаты этого StaticBody2D
	for child in get_children():
		if child is CollisionPolygon2D:
			var cp := child as CollisionPolygon2D
			cp.build_mode = CollisionPolygon2D.BUILD_SOLIDS
			if cp.position != Vector2.ZERO or cp.rotation != 0.0 or cp.scale != Vector2.ONE:
				var xf: Transform2D = cp.transform
				var pts := PackedVector2Array()
				for v in cp.polygon:
					pts.append(xf * v)
				cp.polygon = pts
				cp.position = Vector2.ZERO
				cp.rotation = 0.0
				cp.scale = Vector2.ONE

	if DEBUG_LOG:
		var total := 0
		for c in get_children():
			if c is CollisionPolygon2D:
				total += 1
		print("[READY] collision polys =", total)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			carve_hole(get_global_mouse_position(), DEFAULT_RADIUS)
		elif e.button_index == MOUSE_BUTTON_RIGHT and DEBUG_LOG:
			_debug_probe(get_global_mouse_position())

func carve_hole(world_pos: Vector2, radius: float) -> void:
	var center_local: Vector2 = to_local(world_pos)
	var circle: PackedVector2Array = _make_circle(center_local, radius, CIRCLE_SEGMENTS)
	var circle_aabb: Rect2 = _aabb(circle).grow(AABB_PAD)

	var to_add: Array[PackedVector2Array] = []
	var to_del: Array[CollisionPolygon2D] = []
	var touched := 0

	# --- 1) Рвём коллизию ---
	for child in get_children():
		if not (child is CollisionPolygon2D):
			continue
		var cp := child as CollisionPolygon2D
		var poly: PackedVector2Array = cp.polygon

		if not _aabb(poly).intersects(circle_aabb):
			continue

		touched += 1
		var result: Array = Geometry2D.clip_polygons(poly, circle)

		if result.is_empty():
			to_del.append(cp)
			continue

		cp.polygon = result[0]
		cp.build_mode = CollisionPolygon2D.BUILD_SOLIDS

		for i in range(1, result.size()):
			to_add.append(result[i])

	for n in to_del:
		n.queue_free()

	for new_poly in to_add:
		var ncp := CollisionPolygon2D.new()
		ncp.build_mode = CollisionPolygon2D.BUILD_SOLIDS
		ncp.polygon = new_poly
		add_child(ncp)

	# --- 2) Выедаем дырку в картинке ---
	if sprite and img_tex:
		_carve_image_world(world_pos, radius)

	if DEBUG_LOG:
		print("[CARVE] touched=", touched, " removed=", to_del.size(), " islands=", to_add.size())

func _carve_image_world(world_pos: Vector2, radius: float) -> void:
	# Переводим мировую позицию взрыва в локальные координаты СПРАЙТА
	var center_sprite_local: Vector2 = sprite.to_local(world_pos)
	# Для Centered = true: центр текстуры в (0,0), левый верх = (-w/2, -h/2)
	var center_px := center_sprite_local + Vector2(img_size) / 2.0

	if DEBUG_LOG:
		print("[IMG] center_sprite_local=", center_sprite_local, " center_px=", center_px)

	var min_x := int(floor(center_px.x - radius))
	var max_x := int(ceil(center_px.x + radius))
	var min_y := int(floor(center_px.y - radius))
	var max_y := int(ceil(center_px.y + radius))

	min_x = clamp(min_x, 0, img_size.x - 1)
	max_x = clamp(max_x, 0, img_size.x - 1)
	min_y = clamp(min_y, 0, img_size.y - 1)
	max_y = clamp(max_y, 0, img_size.y - 1)

	var r2 := radius * radius

	img.lock()
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(x, y)
			if p.distance_squared_to(center_px) <= r2:
				var c := img.get_pixel(x, y)
				c.a = 0.0              # делаем прозрачным
				img.set_pixel(x, y, c)
	img.unlock()

	img_tex.update(img)

func _debug_probe(world_pos: Vector2) -> void:
	var p := to_local(world_pos)
	var found := 0
	for child in get_children():
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
