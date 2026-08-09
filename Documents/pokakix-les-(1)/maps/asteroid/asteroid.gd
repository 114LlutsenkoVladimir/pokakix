extends Node2D

@export var map_sprite: Sprite2D 
@export var static_body: StaticBody2D
@export var CIRCLE_TEX: Texture2D 

var collision_polygons: Array[CollisionPolygon2D] = []
var _mask_dirty: bool = false



func _ready() -> void:
	var map_sprite = get_node_or_null("asteroid") as Sprite2D
	var vp = get_node_or_null("asteroid/MaskVP") as SubViewport
	var color_rect = get_node_or_null("asteroid/MaskVP/ColorRect") as ColorRect

	# 1. Сбор и настройка коллизий
	if static_body:
		for child in static_body.get_children():
			if child is CollisionPolygon2D:
				child.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
				collision_polygons.append(child)

	# 2. Настройка SubViewport и шейдера
	if map_sprite and map_sprite.texture and vp:
		var tex_size = Vector2i(map_sprite.texture.get_size())
		
		# Размер маски должен 1 в 1 совпадать с пикселями текстуры
		vp.size = tex_size
		if color_rect:
			color_rect.size = Vector2(tex_size)
			color_rect.color = Color.WHITE # Белая подложка (видимый холст)

		vp.transparent_bg = true
		vp.canvas_item_default_texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		print("Вьюпорт найден и настроен успешно.")

		# Передаем текстуру маски в шейдер спрайта
		if map_sprite.material is ShaderMaterial:
			map_sprite.material.set_shader_parameter("mask_texture", vp.get_texture())
			print("Текстура вьюпорта передана в шейдер.")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		carve_hole(get_global_mouse_position(), 250.0) # Вырежет и коллизию, и текстуру

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
				
	_stamp_hole_to_mask(world_pos, radius)

# Этот код будет внутри скрипта вашего астероида (где висит Area2D)
func _stamp_hole_to_mask(global_click_pos: Vector2, radius: float) -> void:
	var map_sprite = $asteroid as Sprite2D
	var vp = $asteroid/MaskVP as SubViewport
	var stamps = $asteroid/MaskVP/Stamps
	
	if not map_sprite or not map_sprite.texture: return
	
	var tex_size = map_sprite.texture.get_size()

	# 1. Локальные координаты клика
	var local_pos = map_sprite.to_local(global_click_pos)

	# 2. Смещение в координаты SubViewport (0,0 в левом верхнем углу)
	var final_pos = local_pos + (tex_size / 2.0) if map_sprite.centered else local_pos

	# 3. Создаем штамп-дырку
	var s = Sprite2D.new()
	s.texture = CIRCLE_TEX # Ваша текстура круга
	s.centered = true
	s.position = final_pos
	
	# Красим штамп в ЧЕРНЫЙ цвет (в маске это означает "вырезать/прозрачно")
	s.modulate = Color.BLACK 
	
	# 4. Масштаб штампа
	var circle_size = CIRCLE_TEX.get_size()
	var diameter = radius * 2.0
	s.scale = Vector2(diameter / circle_size.x, diameter / circle_size.y)
	
	# 5. Отрисовка
	if Rect2(Vector2.ZERO, Vector2(vp.size)).has_point(final_pos):
		stamps.add_child(s)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		print("УСПЕХ! Дырка вырезана в точке: ", final_pos)

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
