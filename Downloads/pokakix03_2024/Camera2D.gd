extends Camera2D

var zoom_min = Vector2(1.000001, 1.000001)
var zoom_max = Vector2(2.000001, 2.000001)
var zoom_speed = Vector2(0.2000001, 0.2000001)
var des_zoom = zoom
var drag_sens = 1.0

func _process(_delta):
	zoom = lerp(zoom, des_zoom, 0.2)

func _input(event):
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		position -= event.relative * drag_sens / zoom
		if position.x > 1870:
			position.x = 1870
		if position.x < 50:
			position.x = 50
		if position.y > 1030:
			position.y = 1030
		if position.y < 50:
			position.y = 50
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if des_zoom > zoom_min:
					des_zoom -= zoom_speed
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if des_zoom < zoom_max:
					des_zoom += zoom_speed
