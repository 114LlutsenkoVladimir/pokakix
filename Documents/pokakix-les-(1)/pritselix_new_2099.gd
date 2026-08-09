extends Node2D

@onready var player: CharacterBody2D = get_parent() as CharacterBody2D
@export var AIM_STEP_DEG: float = 3.0 
@export var AIM_MIN_DEG: float = -90.0
@export var AIM_MAX_DEG: float =  90.0
@export var HOLD_STEP_DELAY: float = 0.15
@export var HOLD_STEP_SPEED: float = 0.075

var _aim_deg_local: float = 0.0
var shown_deg: float = 0.0
var _hold_timer: float = 0.0
var _cur_delay: float = 0.0

func _process(delta: float) -> void:
	var up_pressed: bool = Input.is_action_just_pressed("aim_up")
	var dn_pressed: bool = Input.is_action_just_pressed("aim_down")
	var up_hold: bool = Input.is_action_pressed("aim_up")
	var dn_hold: bool = Input.is_action_pressed("aim_down")

	# 1. Первичное нажатие: делаем 1 шаг и СРАЗУ ставим интервал холда (без HOLD_STEP_DELAY)
	if up_pressed or dn_pressed:
		_update_weapon_aim(up_pressed, dn_pressed)
		_hold_timer = 0.0
		_cur_delay = HOLD_STEP_SPEED 
		
	# 2. Удержание: продолжает шагать ровно каждые HOLD_STEP_SPEED секунд без паузы
	elif up_hold or dn_hold:
		_hold_timer += delta
		if _hold_timer >= _cur_delay:
			_update_weapon_aim(up_hold, dn_hold)
			_hold_timer = 0.0
			_cur_delay = 0.030
			
	# 3. Кнопки отпущены
	else:
		_hold_timer = 0.0
		_cur_delay = 0.0
		
func _ready() -> void:
	player.landed.connect(_on_player_landed)
	player.left_floor.connect(_on_player_left_floor)
	_on_player_landed()

func _on_player_landed() -> void:
	set_process(true)
	
func _on_player_left_floor() -> void:
	set_process(false)

# чёт вентилятор сломался 卐卐卐卐, из-за грозы наверное ϟϟ, достаём инструменты☭☭☭☭, 
# всё, починил, теперь можно и поспать ZzzZzzzZZ
# не хватает charge ϟϟ перед прыжком, по этому прицел ╬ дергается
func _update_weapon_aim(up: bool, dn: bool) -> void:
	var dir: float = player.facing_direction
	var delta_deg: float = 0.0
	if up:
		delta_deg += AIM_STEP_DEG * dir
	if dn:
		delta_deg -= AIM_STEP_DEG * dir
	if dir == -1:
		delta_deg = -delta_deg
	_aim_deg_local = clamp(_aim_deg_local + delta_deg, AIM_MIN_DEG, AIM_MAX_DEG)
	shown_deg = _aim_deg_local * dir
	$"../bob/weapon_pivot".rotation = deg_to_rad(shown_deg) * dir
