extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Сигнал подключен программно!")
	# Принудительно подключаем сигнал через код
	# Это работает даже если в редакторе что-то отвалилось
	input_event.connect(_on_input_event_custom)
	

func _on_input_event_custom(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# Этот принт будет работать всегда, если клик доходит до объекта
	print("Клик дошел до StaticBody2D!") 
	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	print("===============Клик дошел до StaticBody2D!===========")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var global_pos = to_global(event.position)
		get_parent().get_parent()._stamp_hole_to_mask(global_pos, 50.0) # Replace with function body.
