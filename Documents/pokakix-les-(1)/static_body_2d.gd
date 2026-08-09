extends StaticBody2D

func _ready() -> void:
	print("Сигнал подключен программно!")
	# Принудительно подключаем сигнал через код
	# Это работает даже если в редакторе что-то отвалилось
	input_event.connect(_on_input_event_custom)
	

func _on_input_event_custom(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# Этот принт будет работать всегда, если клик доходит до объекта
	print("Клик дошел до StaticBody2D!") 
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var global_pos = to_global(event.position)
		get_parent()._stamp_hole_to_mask(global_pos, 50.0)
