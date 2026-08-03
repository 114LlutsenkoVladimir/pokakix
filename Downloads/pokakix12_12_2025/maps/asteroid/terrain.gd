extends Node2D

# --- пути к узлам ---
@export var SPRITE_PATH: NodePath
@export var BODY_PATH: NodePath

# --- источник картинки ---
@export_file("*.png") var SOURCE_IMAGE: String

# --- как строим маску ---
enum MaskMode { Alpha = 0, ColorKey = 1, Luminance = 2 }
@export var MASK_MODE: MaskMode = MaskMode.Alpha
@export var ALPHA_THRESHOLD: float = 0.1
@export var COLORKEY_TOLERANCE: float = 0.06
@export var LUMINANCE_THRESH: float = 0.7

# --- производительность/геометрия ---
@export var POLY_SMOOTHING: float = 1.0
@export var SIMPLIFY_TOLERANCE: float = 0.0
@export var CHUNK_SIZE: int = 256
@export var DEBUG: bool = true

var sprite: Sprite2D
var body: StaticBody2D

var _img: Image
var _mask: Image
var _tex: ImageTexture
var _tex_size: Vector2i

var _sprite_to_body: Transform2D
var _body_to_sprite: Transform2D

func _ready() -> void:
	# Узлы
	if SPRITE_PATH == NodePath("") or BODY_PATH == NodePath(""):
		push_error("Укажи SPRITE_PATH и BODY_PATH в инспекторе.")
		return
	sprite = get_node(SPRITE_PATH) as Sprite2D
	body   = get_node(BODY_PATH)   as StaticBody2D
	if sprite == null or body == null:
		push_error("Неверные пути SPRITE_PATH/BODY_PATH.")
		return

	_sprite_to_body = body.transform.affine_inverse() * sprite.transform
	_body_to_sprite = sprite.transform.affine_inverse() * body.transform

	# Картинка
	if SOURCE_IMAGE != "":
		_img = Image.new()
		var err: int = _img.load(SOURCE_IMAGE)
		if err != OK:
			push_error("Не удалось открыть: " + SOURCE_IMAGE)
			return
	else:
		if sprite.texture == null:
			push_error("Нет SOURCE_IMAGE и у спрайта пустая texture.")
			return
		var tex_img: Image = sprite.texture.get_image()
		if tex_img == null:
			push_error("sprite.texture.get_image() вернул null — укажи SOURCE_IMAGE.")
			return
		_img = tex_img

	_img.convert(Image.FORMAT_RGBA8)
	_tex_size = _img.get_size()

	_tex = ImageTexture.create_from_image(_img)
	sprite.texture = _tex
	# Рекомендуется: sprite.centered = true; sprite.position = Vector2.ZERO

	# Маска
	_mask = _build_mask(_img)

	if DEBUG:
		var cx: int = _tex_size.x / 2
		var cy: int = _tex_size.y / 2
		var mask_center_a: float = _mask.get_pixel(cx, cy).a
		var src_center_a: float  = _img.get_pixel(cx, cy).a
		print("[TERRAIN] size=", _tex_size,
			  " mask(center.a)=", mask_center_a,
			  " src(center.a)=",  src_center_a,
			  " mode=", MASK_MODE)

	_rebuild_all_chunks()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			carve_hole(get_global_mouse_position(), 24)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_debug_probe(get_global_mouse_position())

func _debug_probe(world_pos: Vector2) -> void:
	var uv: Vector2 = sprite.to_local(world_pos) + Vector2(_tex_size) * 0.5
	var xi: int = clampi(int(floor(uv.x)), 0, _tex_size.x - 1)
	var yi: int = clampi(int(floor(uv.y)), 0, _tex_size.y - 1)
	var a: float = _mask.get_pixel(xi, yi).a
	var cix: int = xi / CHUNK_SIZE
	var ciy: int = yi / CHUNK_SIZE
	print("[PROBE] world=", world_pos, " uv=", Vector2i(xi, yi), " a=", a, " chunk=(", cix, ",", ciy, ")")

# ===================== ПУБЛИЧНО: вырезать дырку =====================
func carve_hole(world_pos: Vector2, radius_px: int) -> void:
	if _img == null or _mask == null:
		return

	var uv: Vector2 = sprite.to_local(world_pos) + Vector2(_tex_size) * 0.5

	# 1) визуал
	_punch_alpha_circle(_img, uv, radius_px)
	_tex.update(_img)

	# 2) физика (маска)
	_punch_alpha_circle(_mask, uv, radius_px, true)

	# 3) частичная пересборка чанков
	var rect: Rect2i = _circle_rect(uv, radius_px).grow(4)
	var full: Rect2i = Rect2i(Vector2i.ZERO, _tex_size)
	rect = rect.intersection(full)
	_rebuild_chunks_for_rect(rect)

# ===================== МАСКА =====================
func _build_mask(src: Image) -> Image:
	var mask: Image = Image.create(_tex_size.x, _tex_size.y, false, Image.FORMAT_RGBA8)
	var w: int = _tex_size.x
	var h: int = _tex_size.y

	if MASK_MODE == MaskMode.Alpha:
		for y in range(h):
			for x in range(w):
				var c: Color = src.get_pixel(x, y)
				var a: float
				if c.a > ALPHA_THRESHOLD:
					a = 1.0
				else:
					a = 0.0
				mask.set_pixel(x, y, Color(c.r, c.g, c.b, a))

	elif MASK_MODE == MaskMode.ColorKey:
		var bg: Color = src.get_pixel(0, 0)
		for y in range(h):
			for x in range(w):
				var c: Color = src.get_pixel(x, y)
				var dr: float = absf(c.r - bg.r)
				var dg: float = absf(c.g - bg.g)
				var db: float = absf(c.b - bg.b)
				var d: float = maxf(dr, maxf(dg, db))
				var a2: float
				if d <= COLORKEY_TOLERANCE:
					a2 = 0.0
				else:
					a2 = 1.0
				mask.set_pixel(x, y, Color(c.r, c.g, c.b, a2))

	else:
		for y in range(h):
			for x in range(w):
				var c: Color = src.get_pixel(x, y)
				var yv: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
				var a3: float
				if yv < LUMINANCE_THRESH:
					a3 = 1.0
				else:
					a3 = 0.0
				mask.set_pixel(x, y, Color(c.r, c.g, c.b, a3))

	return mask

# ===================== ЧАНКИ =====================
func _rebuild_all_chunks() -> void:
	_clear_all_chunks()
	var nx: int = int(ceil(float(_tex_size.x) / float(CHUNK_SIZE)))
	var ny: int = int(ceil(float(_tex_size.y) / float(CHUNK_SIZE)))
	for iy in range(ny):
		for ix in range(nx):
			_rebuild_chunk(ix, iy)

func _clear_all_chunks() -> void:
	for child in body.get_children():
		child.queue_free()

func _rebuild_chunks_for_rect(rect_img: Rect2i) -> void:
	var ix0: int = rect_img.position.x / CHUNK_SIZE
	var iy0: int = rect_img.position.y / CHUNK_SIZE
	var ix1: int = (rect_img.position.x + rect_img.size.x - 1) / CHUNK_SIZE
	var iy1: int = (rect_img.position.y + rect_img.size.y - 1) / CHUNK_SIZE

	# удалить только полигоны затронутых чанков
	for c in body.get_children():
		if c is CollisionPolygon2D:
			var nm: String = (c as Node).name
			if nm.begins_with("Chunk_"):
				var parts: Array = nm.split("_")
				if parts.size() >= 4:
					var cx: int = int(parts[1])
					var cy: int = int(parts[2])
					if cx >= ix0 and cx <= ix1 and cy >= iy0 and cy <= iy1:
						c.queue_free()

	for jy in range(iy0, iy1 + 1):
		for jx in range(ix0, ix1 + 1):
			_rebuild_chunk(jx, jy)

func _rebuild_chunk(ix: int, iy: int) -> void:
	var pos_img: Vector2i = Vector2i(ix * CHUNK_SIZE, iy * CHUNK_SIZE)
	var size_img: Vector2i = Vector2i(
		min(CHUNK_SIZE, _tex_size.x - pos_img.x),
		min(CHUNK_SIZE, _tex_size.y - pos_img.y)
	)
	if size_img.x <= 0 or size_img.y <= 0:
		return

	var rect_img: Rect2i = Rect2i(pos_img, size_img)
	var bm: BitMap = _bm_from_image_region(_mask, rect_img)
	var polys: Array = bm.opaque_to_polygons(Rect2i(Vector2i.ZERO, rect_img.size), POLY_SMOOTHING)

	var half: Vector2 = Vector2(_tex_size) * 0.5
	var offset_sprite: Vector2 = Vector2(rect_img.position) - half

	var created: int = 0
	for poly in polys:
		var pts_body: PackedVector2Array = PackedVector2Array()
		for p in poly:
			var spt: Vector2 = Vector2(p) + offset_sprite   # локаль спрайта
			var bpt: Vector2 = _sprite_to_body * spt        # локаль тела
			pts_body.append(bpt)

		if SIMPLIFY_TOLERANCE > 0.0:
			pts_body = _simplify_polygon(pts_body, SIMPLIFY_TOLERANCE)

		if pts_body.size() >= 3:
			var cp: CollisionPolygon2D = CollisionPolygon2D.new()
			cp.name = "Chunk_%d_%d_%d" % [ix, iy, created]
			cp.polygon = pts_body
			cp.build_mode = CollisionPolygon2D.BUILD_SEGMENTS   # ключевое
			body.add_child(cp)
			created += 1

			if DEBUG and created == 1:
				var aabb: Rect2 = Rect2(pts_body[0], Vector2.ZERO)
				for v in pts_body:
					aabb = aabb.expand(v)
				print("[TERRAIN] chunk(", ix, ",", iy, ") first poly AABB=", aabb)

	if DEBUG:
		print("[TERRAIN] chunk(", ix, ",", iy, ") polys=", created)

# ===================== ПИКСЕЛИ =====================
func _punch_alpha_circle(img: Image, uv: Vector2, r: int, _mask_only: bool = false) -> void:
	var cx: int = int(uv.x)
	var cy: int = int(uv.y)
	var r2: int = r * r
	for y in range(-r, r + 1):
		var py: int = cy + y
		if py < 0 or py >= _tex_size.y:
			continue
		var yy: int = y * y
		var maxx: int = int(sqrt(float(r2 - yy)))
		var x0: int = cx - maxx
		if x0 < 0:
			x0 = 0
		var x1: int = cx + maxx
		var xmax_allowed: int = _tex_size.x - 1
		if x1 > xmax_allowed:
			x1 = xmax_allowed
		for px in range(x0, x1 + 1):
			var c: Color = img.get_pixel(px, py)
			c.a = 0.0
			img.set_pixel(px, py, c)

func _circle_rect(uv: Vector2, r: int) -> Rect2i:
	var tl: Vector2i = Vector2i(int(uv.x) - r, int(uv.y) - r)
	var sz: Vector2i = Vector2i(r * 2, r * 2)
	return Rect2i(tl, sz)

func _bm_from_image_region(img: Image, rect: Rect2i) -> BitMap:
	var sub: Image = Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	sub.blit_rect(img, Rect2i(rect.position, rect.size), Vector2i.ZERO)
	var bm: BitMap = BitMap.new()
	bm.create_from_image_alpha(sub, 0.5)  # читаем альфу маски
	return bm

# ===================== УПРОЩЕНИЕ (RDP) =====================
func _simplify_polygon(points: PackedVector2Array, tol: float) -> PackedVector2Array:
	if points.size() <= 3 or tol <= 0.0:
		return points.duplicate()
	return _rdp(points, 0, points.size() - 1, tol)

func _rdp(points: PackedVector2Array, i0: int, i1: int, eps: float) -> PackedVector2Array:
	var max_d: float = 0.0
	var idx: int = -1
	var p0: Vector2 = points[i0]
	var p1: Vector2 = points[i1]
	for i in range(i0 + 1, i1):
		var p: Vector2 = points[i]
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, p0, p1)
		var d: float = p.distance_to(q)
		if d > max_d:
			max_d = d
			idx = i
	if max_d > eps and idx != -1:
		var left: PackedVector2Array = _rdp(points, i0, idx, eps)
		var right: PackedVector2Array = _rdp(points, idx, i1, eps)
		left.resize(left.size() - 1)
		left.append_array(right)
		return left
	else:
		var res: PackedVector2Array = PackedVector2Array()
		res.append(p0)
		res.append(p1)
		return res
