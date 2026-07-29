extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

var img: Image
var img_tex: ImageTexture
var img_size: Vector2i
var bm: BitMap

func _ready() -> void:
	
	if sprite == null or sprite.texture == null:
		push_error("Sprite2D/texture не найдены")
		return

	img = sprite.texture.get_image()
	img_size = img.get_size()
	img_tex = ImageTexture.create_from_image(img)
	sprite.texture = img_tex

	bm = BitMap.new()
	bm.create_from_image_alpha(img)

	print("[TERRAIN] size=", img_size)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		carve_hole(get_global_mouse_position(), 32.0)

func carve_hole(world_pos: Vector2, radius: float) -> void:
	if sprite == null:
		return

	var center_local: Vector2 = sprite.to_local(world_pos)
	var center_px := center_local + Vector2(img_size) / 2.0

	var min_x := int(floor(center_px.x - radius))
	var max_x := int(ceil(center_px.x + radius))
	var min_y := int(floor(center_px.y - radius))
	var max_y := int(ceil(center_px.y + radius))

	min_x = clamp(min_x, 0, img_size.x - 1)
	max_x = clamp(max_x, 0, img_size.x - 1)
	min_y = clamp(min_y, 0, img_size.y - 1)
	max_y = clamp(max_y, 0, img_size.y - 1)

	var r2 := radius * radius

	# режем картинку
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(x, y)
			if p.distance_squared_to(center_px) <= r2:
				var c := img.get_pixel(x, y)
				c.a = 0.0
				img.set_pixel(x, y, c)
	img_tex.update(img)

	# обновляем битмаску
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(x, y)
			if p.distance_squared_to(center_px) <= r2:
				bm.set_bitv(Vector2i(x, y), false)

func is_solid(world_pos: Vector2) -> bool:
	var local := sprite.to_local(world_pos)
	var px := local + Vector2(img_size) / 2.0
	var xi := int(round(px.x))
	var yi := int(round(px.y))

	if xi < 0 or xi >= img_size.x or yi < 0 or yi >= img_size.y:
		return false

	return bm.get_bitv(Vector2i(xi, yi))
