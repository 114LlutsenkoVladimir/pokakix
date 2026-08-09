@tool
extends Node

@export var map_sprite: Sprite2D
@export var static_body: StaticBody2D

@export_range(0.1, 20.0, 0.5) var smoothness_epsilon: float = 6.0

@export var run_generation: bool = false:
	set(val):
		run_generation = false
		generate_collisions()

func generate_collisions() -> void:
	if not map_sprite or not map_sprite.texture or not static_body: return

	var image = map_sprite.texture.get_image()
	var size = image.get_size()
	
	var bitmap_opaque = BitMap.new()
	bitmap_opaque.create_from_image_alpha(image, 0.5)
	
	var image_inv = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for x in range(size.x):
		for y in range(size.y):
			var a = image.get_pixel(x, y).a
			image_inv.set_pixel(x, y, Color(1, 1, 1, 1.0 - a))
			
	var bitmap_holes = BitMap.new()
	bitmap_holes.create_from_image_alpha(image_inv, 0.5)

	var outer_polys = bitmap_opaque.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), smoothness_epsilon)
	var hole_polys = bitmap_holes.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), smoothness_epsilon)

	var internal_holes: Array[PackedVector2Array] = []
	for hole in hole_polys:
		var is_touching_border = false
		for pt in hole:
			if pt.x <= 1 or pt.y <= 1 or pt.x >= size.x - 2 or pt.y >= size.y - 2:
				is_touching_border = true
				break
		if not is_touching_border:
			internal_holes.append(hole)

	# Вырезаем дыры
	var final_result_polygons: Array[PackedVector2Array] = outer_polys
	for hole in internal_holes:
		var next_step_polys: Array[PackedVector2Array] = []
		for base_poly in final_result_polygons:
			var clipped = Geometry2D.clip_polygons(base_poly, hole)
			for c_poly in clipped:
				next_step_polys.append(c_poly)
		final_result_polygons = next_step_polys

	# Очищаем старые узлы
	for child in static_body.get_children():
		if child is CollisionPolygon2D:
			child.free()

	# СОЗДАЕМ КОЛЛИЗИИ В РЕЖИМЕ SEGMENTS, НО РАЗБИТЫЕ НА ЧАСТИ
	var tex_size = map_sprite.texture.get_size()
	var created_count = 0
	
	for poly in final_result_polygons:
		if poly.size() < 3: continue
		
		# Декомпозируем сложные контуры на безопасные полигоны для физики
		var decomp = Geometry2D.decompose_polygon_in_convex(poly)
		if decomp.is_empty():
			decomp = [poly]
			
		for sub_poly in decomp:
			var col = CollisionPolygon2D.new()
			var offset_poly = PackedVector2Array()
			
			for pt in sub_poly:
				var point = Vector2(pt)
				if map_sprite.centered:
					point -= Vector2(tex_size) / 2.0
				offset_poly.append(point)

			col.polygon = offset_poly
			col.build_mode = CollisionPolygon2D.BUILD_SOLIDS
			static_body.add_child(col)
			
			if Engine.is_editor_hint():
				var root = get_tree().edited_scene_root
				col.owner = root if root else static_body
				
			created_count += 1

	print("ГОТОВО! Создано выпуклых полигонов без лагов: ", created_count)
