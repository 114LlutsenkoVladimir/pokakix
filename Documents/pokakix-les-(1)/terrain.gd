extends Node2D

@export var CHUNK_SIZE: int = 256

# Маска/шейдер (визуал)
@export var CIRCLE_TEX: Texture2D
@export var MASK_ENABLED: bool = true
@export var MAX_STAMPS: int = 4000

# ВАЖНО: маску обновлять только при изменениях (лечит -FPS на старте)
@export var MASK_UPDATE_ON_DEMAND: bool = true

# Коллизия (оптимизация)
@export var COLLISION_SCALE: int =  2 # 1=точно, 2≈4x, 3≈9x, 4≈16x

# Визуальные чанки (обычно не нужны, если есть маска)
@export var UPDATE_CHUNKS_VISUAL: bool = false
@export var MAX_CHUNK_UPDATES_PER_FRAME: int = 6

@onready var anchor: Sprite2D = $Sprite2D
@onready var mask_vp: SubViewport = get_node_or_null("MaskVP")
@onready var stamps: Node2D = get_node_or_null("MaskVP/Stamps")

var img_size: Vector2i
var world_scale: float = 1.0

# Уменьшенная коллизия
var bm: BitMap
var col_size: Vector2i
var col_scale: float = 1.0  # = float(COLLISION_SCALE)

# Маска: грязный флаг
var _mask_dirty: bool = false

# чанки (опционально визуал)
var _chunks_x: int = 0
var _chunks_y: int = 0
var _chunk_imgs: Array[Image] = []
var _chunk_tex: Array[ImageTexture] = []
var _chunk_spr: Array[Sprite2D] = []
var _chunk_dirty: Array[bool] = []
var _circle_hard_tex: Texture2D


func _ready() -> void:
	
	if anchor == null or anchor.texture == null:
		push_error("Sprite2D/texture не найдены")
		return
		
	anchor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	anchor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if stamps != null:
		stamps.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var base_img: Image = anchor.texture.get_image()
	img_size = base_img.get_size()

	world_scale = anchor.global_scale.x
	if world_scale <= 0.0:
		world_scale = 1.0

	# ---- Коллизия: создаём уменьшенный BitMap ----
	col_scale = float(max(1, COLLISION_SCALE))
	col_size = Vector2i(
		max(1, int(ceil(float(img_size.x) / col_scale))),
		max(1, int(ceil(float(img_size.y) / col_scale)))
	)

	bm = BitMap.new()
	bm.create(col_size)

	_build_collision_bitmap_from_image(base_img)

	# ---- Визуал: маска + шейдер ----
	if MASK_ENABLED:
		_setup_mask_and_shader()

	# ---- Визуальные чанки (не рекомендую вместе с маской) ----
	if UPDATE_CHUNKS_VISUAL:
		_build_chunks_visual(base_img)
		anchor.texture = null  # базовую текстуру не рисуем
		
	if CIRCLE_TEX != null:
		_circle_hard_tex = _make_circle_hard(CIRCLE_TEX)

	print("[TERRAIN] img=", img_size,
		" world_scale=", world_scale,
		" col_size=", col_size,
		" col_scale=", COLLISION_SCALE,
		" mask=", MASK_ENABLED,
		" chunks_visual=", UPDATE_CHUNKS_VISUAL)


func _make_circle_hard(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var a := img.get_pixel(x,y).a
			# всё что не 100% — делаем 0
			img.set_pixel(x,y, Color(1,1,1, 1.0 if a >= 0.99 else 0.0))
	return ImageTexture.create_from_image(img)

func _build_collision_bitmap_from_image(base_img: Image) -> void:
	for by in range(col_size.y):
		var y0 := int(floor(float(by) * col_scale))
		var y1: int = min(img_size.y - 1, int(floor(float(by + 1) * col_scale)) - 1)

		for bx in range(col_size.x):
			var x0 := int(floor(float(bx) * col_scale))
			var x1: int = min(img_size.x - 1, int(floor(float(bx + 1) * col_scale)) - 1)

			var solid := false
			for y in range(y0, y1 + 1):
				for x in range(x0, x1 + 1):
					if base_img.get_pixel(x, y).a > 0.001:
						solid = true
						break
				if solid:
					break

			bm.set_bitv(Vector2i(bx, by), solid)

func _setup_mask_and_shader() -> void:
	if mask_vp == null or stamps == null:
		push_error("MaskVP/Stamps не найдены в сцене Terrain")
		return

	mask_vp.size = img_size

	var mat := anchor.material as ShaderMaterial
	if mat == null:
		push_error("На Sprite2D нет ShaderMaterial (нужен uniform mask_tex)")
		return

	mat.set_shader_parameter("mask_tex", mask_vp.get_texture())

	# очистим штампы при старте
	for c in stamps.get_children():
		c.queue_free()

	# Ключевая оптимизация: не рендерить гигантский viewport каждый кадр
	if MASK_UPDATE_ON_DEMAND:
		mask_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_mask_dirty = true  # один раз обновим после старта

func _process(_delta: float) -> void:
	# ---- Маска: обновлять ТОЛЬКО при изменениях ----
	if MASK_ENABLED and MASK_UPDATE_ON_DEMAND and mask_vp != null:
		if _mask_dirty:
			mask_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			_mask_dirty = false
		else:
			if mask_vp.render_target_update_mode != SubViewport.UPDATE_DISABLED:
				mask_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED

	# ---- Чанки (опционально) ----
	if not UPDATE_CHUNKS_VISUAL:
		return

	var budget := MAX_CHUNK_UPDATES_PER_FRAME
	for i in range(_chunk_dirty.size()):
		if not _chunk_dirty[i]:
			continue
		_chunk_tex[i].update(_chunk_imgs[i])
		_chunk_dirty[i] = false
		budget -= 1
		if budget <= 0:
			break

# --- координаты ---

func _world_to_pixel(world_pos: Vector2) -> Vector2:
	var local: Vector2 = anchor.to_local(world_pos)
	return local + Vector2(img_size) * 0.5

func _pixel_to_bm(pix: Vector2) -> Vector2i:
	return Vector2i(
		clamp(int(floor(pix.x / col_scale)), 0, col_size.x - 1),
		clamp(int(floor(pix.y / col_scale)), 0, col_size.y - 1)
	)

func _chunk_id(cx: int, cy: int) -> int:
	return cy * _chunks_x + cx

# --- API ---

func carve_hole(world_pos: Vector2, radius_world: float) -> void:
	if bm == null:
		return

	var center_px: Vector2 = _world_to_pixel(world_pos)
	var radius_px: float = radius_world / world_scale

	_apply_hole_to_bitmap_scaled(center_px, radius_px)

	if MASK_ENABLED:
		_stamp_hole_to_mask(center_px, radius_px)

	if UPDATE_CHUNKS_VISUAL:
		_apply_hole_to_chunks_visual(center_px, radius_px)

func _apply_hole_to_bitmap_scaled(center_px: Vector2, radius_px: float) -> void:
	var c_bm: Vector2 = center_px / col_scale
	var r_bm: float = radius_px / col_scale

	var cx := int(round(c_bm.x))
	var cy := int(round(c_bm.y))
	var r := int(ceil(r_bm))
	var r2 := r_bm * r_bm

	var min_y: int = clamp(cy - r, 0, col_size.y - 1)
	var max_y: int = clamp(cy + r, 0, col_size.y - 1)

	for y in range(min_y, max_y + 1):
		var dy := float(y - cy)
		var inside := r2 - dy * dy
		if inside < 0.0:
			continue
		var dx_max := int(floor(sqrt(inside)))

		var x1: int = clamp(cx - dx_max, 0, col_size.x - 1)
		var x2: int = clamp(cx + dx_max, 0, col_size.x - 1)

		for x in range(x1, x2 + 1):
			bm.set_bitv(Vector2i(x, y), false)


func _stamp_hole_to_mask(center_px: Vector2, radius_px: float) -> void:
	if stamps == null or CIRCLE_TEX == null:
		return

	if MAX_STAMPS > 0 and stamps.get_child_count() >= MAX_STAMPS:
		stamps.get_child(0).queue_free()

	var s := Sprite2D.new()
	s.texture = _circle_hard_tex if _circle_hard_tex != null else CIRCLE_TEX
	s.centered = true
	s.position = center_px
	s.modulate = Color(0, 0, 0, 1)

	var ts := Vector2(CIRCLE_TEX.get_width(), CIRCLE_TEX.get_height())
	if ts.x <= 0.0 or ts.y <= 0.0:
		return

	var extra_px := col_scale * 2.0  # при COLLISION_SCALE=2 это +4px к диаметру
	var d := radius_px * 2.0 + extra_px
	s.scale = Vector2(d / ts.x, d / ts.y)

	stamps.add_child(s)

	# помечаем маску грязной — обновим viewport один раз
	if MASK_UPDATE_ON_DEMAND and mask_vp != null:
		_mask_dirty = true

# ---------- Визуальные чанки (опционально) ----------

func _build_chunks_visual(base_img: Image) -> void:
	_chunks_x = int(ceil(float(img_size.x) / float(CHUNK_SIZE)))
	_chunks_y = int(ceil(float(img_size.y) / float(CHUNK_SIZE)))

	_chunk_imgs.resize(_chunks_x * _chunks_y)
	_chunk_tex.resize(_chunks_x * _chunks_y)
	_chunk_spr.resize(_chunks_x * _chunks_y)
	_chunk_dirty.resize(_chunks_x * _chunks_y)
	for i in range(_chunk_dirty.size()):
		_chunk_dirty[i] = false

	for cy in range(_chunks_y):
		for cx in range(_chunks_x):
			var id := _chunk_id(cx, cy)

			var x0 := cx * CHUNK_SIZE
			var y0 := cy * CHUNK_SIZE
			var w: int = min(CHUNK_SIZE, img_size.x - x0)
			var h: int = min(CHUNK_SIZE, img_size.y - y0)

			var cimg := Image.create(w, h, false, base_img.get_format())
			cimg.blit_rect(base_img, Rect2i(x0, y0, w, h), Vector2i(0, 0))

			var ctex := ImageTexture.create_from_image(cimg)

			var spr := Sprite2D.new()
			spr.texture = ctex
			spr.centered = false
			spr.position = Vector2(x0, y0) - Vector2(img_size) * 0.5

			anchor.add_child(spr)

			_chunk_imgs[id] = cimg
			_chunk_tex[id] = ctex
			_chunk_spr[id] = spr

func _apply_hole_to_chunks_visual(center_px: Vector2, radius_px: float) -> void:
	if _chunk_imgs.is_empty():
		return

	var min_x: int = int(floor(center_px.x - radius_px))
	var max_x: int = int(ceil(center_px.x + radius_px))
	var min_y: int = int(floor(center_px.y - radius_px))
	var max_y: int = int(ceil(center_px.y + radius_px))

	min_x = clamp(min_x, 0, img_size.x - 1)
	max_x = clamp(max_x, 0, img_size.x - 1)
	min_y = clamp(min_y, 0, img_size.y - 1)
	max_y = clamp(max_y, 0, img_size.y - 1)

	var r2: float = radius_px * radius_px

	for y in range(min_y, max_y + 1):
		var dy := float(y) - center_px.y
		for x in range(min_x, max_x + 1):
			var dx := float(x) - center_px.x
			if dx * dx + dy * dy > r2:
				continue

			var cx := x / CHUNK_SIZE
			var cy := y / CHUNK_SIZE
			var id := _chunk_id(cx, cy)

			var lx := x - cx * CHUNK_SIZE
			var ly := y - cy * CHUNK_SIZE

			_chunk_imgs[id].set_pixel(lx, ly, Color(0, 0, 0, 0))
			_chunk_dirty[id] = true

func is_solid(world_pos: Vector2) -> bool:
	if bm == null:
		return false

	var px: Vector2 = _world_to_pixel(world_pos)

	# вне картинки — пустота
	if px.x < 0 or px.x >= img_size.x or px.y < 0 or px.y >= img_size.y:
		return false

	return bm.get_bitv(_pixel_to_bm(px))
