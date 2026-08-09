extends Node2D

# Ссылка на Sprite, который отображает карту
@onready var map_sprite: Sprite2D = $mapsprite

# Данные изображения, с которыми мы будем работать на CPU
var image_data: Image
# Текстура, которая связывает Image (CPU) и Sprite (GPU)
var image_texture: ImageTexture

func _ready():
	# 1. ПОДГОТОВКА ДАННЫХ
	
	# Получаем исходное изображение из текстуры спрайта
	# .get_image() создает копию данных в оперативной памяти
	var original_image = map_sprite.texture.get_image()
	
	# Создаем копию, чтобы не испортить исходный файл, 
	# и конвертируем в формат с альфа-каналом (чтобы можно было делать прозрачность)
	image_data = Image.create_empty(original_image.get_width(), original_image.get_height(), false, Image.FORMAT_RGBA8)
	image_data.blit_rect(original_image, Rect2i(0, 0, original_image.get_width(), original_image.get_height()), Vector2i(0,0))
	
	# Создаем новую пустую текстуру на основе этих данных
	image_texture = ImageTexture.create_from_image(image_data)
	
	# Назначаем Спрайту нашу новую, динамическую текстуру
	# Теперь Sprite показывает то, что лежит в переменной image_data
	map_sprite.texture = image_texture


func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 1. Переводим координаты из Мира в Локальные координаты Спрайта
		var local_mouse = map_sprite.to_local(get_global_mouse_position())
		
		# 2. Учитываем, что у Спрайта в Godot точка привязки (Origin) по умолчанию в центре.
		# Нам нужно прибавить половину размера текстуры, чтобы "ноль" оказался в левом верхнем углу.
		var offset = map_sprite.texture.get_size() / 2
		var image_pos = local_mouse + offset
		
		# Теперь отправляем правильные координаты (где (0,0) - это левый верхний угол картинки)
		cut_circle(image_pos, 570)


# --- ТА САМАЯ ФУНКЦИЯ (ЭТАЛОН) ---
# center: Vector2 - координаты центра взрыва в пикселях текстуры
# radius: float - радиус взрыва
func cut_circle(center: Vector2, radius: float):
	print("Взрыв в: ", center, " радиус: ", radius)
	
	# Определяем прямоугольную область (Bounding Box) вокруг взрыва,
	# чтобы не перебирать все пиксели огромной карты.
	var start_x = max(0, int(center.x - radius))
	var end_x = min(image_data.get_width(), int(center.x + radius))
	var start_y = max(0, int(center.y - radius))
	var end_y = min(image_data.get_height(), int(center.y + radius))
	
	# Квадрат радиуса (для оптимизации сравнения в цикле)
	var radius_sq = radius * radius
	
	# Двойной цикл по пикселям в области взрыва
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var current_pos = Vector2(x, y)
			
			# Математика: проверяем, лежит ли текущий пиксель внутри круга
			# (расстояние до центра меньше радиуса)
			if current_pos.distance_squared_to(center) < radius_sq:
				# Делаем пиксель абсолютно прозрачным
				image_data.set_pixel(x, y, Color(0, 0, 0, 0))
	
	# ВАЖНО: Мы изменили данные в RAM (image_data), 
	# теперь нужно насильно обновить текстуру в видеопамяти (GPU)
	map_sprite.texture = ImageTexture.create_from_image(image_data)
	print("Текстура обновлена")
