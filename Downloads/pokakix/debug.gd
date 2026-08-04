extends Node2D

@onready var player: CharacterBody2D = get_parent() as CharacterBody2D
@export var debug_menu_visible: bool = true
var debug_text_array: Array = []
	
func toggle_visibility() -> void:
	if debug_menu_visible:
		$debug_text.visible = true
	elif !debug_menu_visible:
		$debug_text.visible = false

func _ready() -> void:
	toggle_visibility()
	
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("debug_button"): 
		debug_menu_visible = !debug_menu_visible
		toggle_visibility()

func _process(delta: float) -> void:
	debug_text_array = [
		"нажми таб чтобы скрыть это меню или открыть его снова\n",
		"pos %10.2f"%player.position.x+" x, %10.2f"%player.position.y+" y\n", #Координаты игрока
		"motion %10.2f"%player.velocity.x+" x, %10.2f"%player.velocity.y+" y\n", #Ускорение игрока
		"jump delay timer %10.4f"%$"../jumper/jump_delay_timer".time_left+"\n" #Таймер задержки между прыжками
	]
	$debug_text.text = str(debug_text_array[0]+debug_text_array[1]+debug_text_array[2]+debug_text_array[3])
