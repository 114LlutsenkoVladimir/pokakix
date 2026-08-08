extends Node2D

@export var map_sprite: Sprite2D 
@export var static_body: StaticBody2D
@export var CIRCLE_TEX: Texture2D 

var collision_polygons: Array[CollisionPolygon2D] = []
var _mask_dirty: bool = false

func _ready() -> void:
	# 1. Сбор и настройка коллизий
	for child in static_body.get_children():
		if child is CollisionPolygon2D:
			child.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
			collision_polygons.append(child)
	
	# 2. ПОИСК ВЬЮПОРТА (проверяем, видим ли мы его)
	var vp = get_node_or_null("asteroid/MaskVP")
	if vp:
		# Устанавливаем размер вьюпорта в точности как у спрайта с учетом масштаба
		var sprite_size = map_sprite.get_rect().size * map_sprite.scale
		vp.size = Vector2i(sprite_size) 
	  
		# ВАЖНО: Установите фильтр текстуры, чтобы убрать ступенчатость
		vp.canvas_item_default_texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		print("Вьюпорт найден успешно.")
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.transparent_bg = true
		
		# Настройка шейдера
		if map_sprite and map_sprite.material is ShaderMaterial:
			map_sprite.material.set_shader_parameter("mask_tex", vp.get_texture())
			print("Текстура вьюпорта передана в шейдер.")

		

	# 3. ОТЛАДОЧНЫЙ СПРАЙТ
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	var debug_sprite = Sprite2D.new()
	canvas.add_child(debug_sprite)
	
	if vp:
		debug_sprite.texture = vp.get_texture()
		debug_sprite.position = Vector2(100, 100)
		debug_sprite.scale = Vector2(0.5, 0.5)
		print("Отладочный спрайт создан.")

#func _input(event: InputEvent) -> void:
	#if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		#carve_hole(get_global_mouse_position(), 250.0)

func carve_hole(world_pos: Vector2, radius: float) -> void:
	var local_pos = static_body.to_local(world_pos)
	var explosion_poly = _create_circle_polygon(local_pos, radius, 16)
	
	# Режем каждый кусок острова отдельно (это быстро в режиме SEGMENTS)
	for i in range(collision_polygons.size() - 1, -1, -1):
		var col = collision_polygons[i]
		var results = Geometry2D.clip_polygons(col.polygon, explosion_poly)
		
		if results.is_empty():
			# Полигон полностью уничтожен
			col.queue_free()
			collision_polygons.remove_at(i)
		else:
			# Обновляем первый кусок
			col.polygon = results[0]
			# Если полигон развалился на части, создаем новые коллизии для них
			for j in range(1, results.size()):
				var new_col = CollisionPolygon2D.new()
				new_col.polygon = results[j]
				new_col.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
				static_body.add_child(new_col)
				collision_polygons.append(new_col)
				
	_stamp_hole_to_mask(local_pos, radius)

# Этот код будет внутри скрипта вашего астероида (где висит Area2D)
func _stamp_hole_to_mask(local_pos: Vector2, radius: float) -> void:
	var vp = get_node_or_null("MaskVP")
	var stamps = get_node_or_null("MaskVP/Stamps")
	if not vp or not stamps or not map_sprite or not map_sprite.texture: return

	# 1. Сдвигаем из центра спрайта (0,0) в левый верхний угол для вьюпорта.
	# Так как мы используем to_local(global_click), local_pos - это координаты
	# внутри спрайта, где (0,0) - его центр.
	var tex_size = map_sprite.texture.get_size()
	
	# Делим на scale спрайта, чтобы превратить игровые единицы в пиксели текстуры
	var final_pos = (local_pos / map_sprite.scale) + (tex_size / 2.0)
	
	# 2. Создаем штамп
	var s = Sprite2D.new()
	s.texture = CIRCLE_TEX
	s.centered = true
	s.position = final_pos
	
	# 3. Масштаб (радиус в пикселях текстуры)
	var radius_px = radius / map_sprite.scale.x
	s.scale = Vector2(radius_px * 2.0, radius_px * 2.0) / CIRCLE_TEX.get_size()
	
	# 4. Проверка и добавление
	var rect_vp = Rect2(Vector2.ZERO, Vector2(vp.size))
	if rect_vp.has_point(final_pos):
		stamps.add_child(s)
		_mask_dirty = true
		print("УСПЕХ! Штамп на: ", final_pos)
	else:
		print("ПРОМАХ! Позиция вне вьюпорта: ", final_pos)

func _process(_delta: float) -> void:
	var vp = get_node_or_null("MaskVP")
	if _mask_dirty and vp:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		_mask_dirty = false
	# После добавления штампа
	
func _create_circle_polygon(center: Vector2, radius: float, sides: int) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(sides):
		var angle = i * PI * 2 / sides
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
