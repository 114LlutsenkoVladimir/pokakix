extends Camera2D

@export var zoom_min := Vector2(0.5, 0.5)
@export var zoom_max := Vector2(2.0, 2.0)
@export var zoom_speed := Vector2(0.2, 0.2)
@export var drag_sens := 1.0


var des_zoom := Vector2.ONE
@export var terrain_sprite_path: NodePath
@onready var terrain_sprite: Sprite2D = null

func _ready() -> void:
	des_zoom = zoom
	make_current()

	if terrain_sprite_path != NodePath(""):
		var n := get_node_or_null(terrain_sprite_path)
		if n is Sprite2D:
			terrain_sprite = n

func _process(_delta: float) -> void:
	# сглаженный зум
	des_zoom.x = clamp(des_zoom.x, zoom_min.x, zoom_max.x)
	des_zoom.y = clamp(des_zoom.y, zoom_min.y, zoom_max.y)
	zoom = lerp(zoom, des_zoom, 0.2)

	# держим камеру в пределах карты
	_clamp_to_map()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# для изотропного зума берём zoom.x
		position -= event.relative * (drag_sens / zoom.x)
		_clamp_to_map()

	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			des_zoom -= zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			des_zoom += zoom_speed

func _clamp_to_map() -> void:
	if terrain_sprite == null or terrain_sprite.texture == null:
		return

	# мировые границы карты из текстуры, позиции и масштаба спрайта
	var tex_size: Vector2 = terrain_sprite.texture.get_size() * terrain_sprite.global_scale
	var center: Vector2 = terrain_sprite.global_position
	var left   := center.x - tex_size.x * 0.5
	var right  := center.x + tex_size.x * 0.5
	var top    := center.y - tex_size.y * 0.5
	var bottom := center.y + tex_size.y * 0.5

	# половина видимой области камеры в МИРОВЫХ координатах (учёт зума)
	var half_view: Vector2 = get_viewport().get_visible_rect().size * 0.5 / zoom

	# чтобы камера не выходила за края, учитываем половину окна
	var min_x := left   + half_view.x
	var max_x := right  - half_view.x
	var min_y := top    + half_view.y
	var max_y := bottom - half_view.y

	# если карта меньше окна — просто центрируем
	if min_x > max_x:
		position.x = center.x
	else:
		position.x = clamp(position.x, min_x, max_x)

	if min_y > max_y:
		position.y = center.y
	else:
		position.y = clamp(position.y, min_y, max_y)
