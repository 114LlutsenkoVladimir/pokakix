extends CharacterBody2D


@export var SPEED : int = 70
@export var GRAVITY : int = 900
@export var HEALTH : int = 500
@export var TEAM = "green"

var possible_jumps_now: int = 0   
var freeMovement = true
var jump_delay = 0
var jump_delay_time = 0.5
var rotate = true
var rotate_timer = 0
var did_jump = 0
var jump_counter: int = 0
var _jumped_this_frame: bool = false
# rip bob_flip 2024-2024

# Get the gravity from the project settings to be synced with RigidBody nodes. :eagle::eagle::eagle:
# гульчичяп жужмальпупис
#чёт вентилятор сломался 卐卐卐卐, из-за грозы наверное ϟϟ, достаём инструменты☭☭☭☭, всё, починил, теперь можно и поспать ZzzZzzzZZ
# rip sex 2024-2024
func _ready():
	await get_tree().create_timer(0.4).timeout # СТАВИТ ЗАДЕРЖКУ НА ПОЯВЛЕНИЕ СЛЕДА ПРИ ЗАПУСКЕ ИГРЫ
	$character_trail.visible = true
	pass
	

func _physics_process(delta):
	_jumped_this_frame = false
	# Боб разворачивается в нужную сторону
	# АААААА ПИСЯ asteroid spiral
	# оКСАНА УМОЛЯЮ ПРОДАЙ ЕЩЁ 2 КВАРТИРЫ У ТЕБЯ ТОЧНО ВСЁ ПОЛУЧИТСЯ
	if Input.is_action_pressed("left") and is_on_floor():
		$bob.scale.x = 1
	if Input.is_action_pressed("right") and is_on_floor(): # РАЗВОРАЧИВАЕТ БОБА
		$bob.scale.x = -1
		
	# Движение и остановка боба
	var direction = Input.get_axis("left", "right")
	if direction and freeMovement == true and did_jump == 0:
		velocity.x = direction * SPEED
	elif direction == 0 and is_on_floor():
		velocity.x = 0
		
	# Тянет боба вниз и не даёт ему двигаться, если он в воздухе
	if not is_on_floor():
		#$bob/weapon.visible = false
		velocity.y += GRAVITY * delta
		freeMovement = false
		if rotate == true:
			$bob.rotate(0.001 * abs(velocity.y) * $bob.scale.x)
		rotate_timer += 1
		if rotate_timer >= 30:
			rotate = true
			
	# Возвращает возможность движения и прыжков на земле
	if is_on_floor():
		#$bob/weapon.visible = true
		rotate = false
		freeMovement = true
		rotate_timer = 0
		$bob.rotation_degrees = 0
		did_jump = 0
	
	if Input.is_action_just_pressed("action"):
		$".".position.x = get_global_mouse_position().x
		$".".position.y = get_global_mouse_position().y
	
	# Прыжок вперед
	if Input.is_action_pressed("jump_fwd") or Input.is_action_pressed("jump_bwd"):
		if is_on_floor():
			if Input.is_action_pressed("jump_fwd"):
				_jump_fwd_impl()
			else:
				_jump_bwd_impl()
			_jumped_this_frame = true
		else:
			if possible_jumps_now > 0:
				if Input.is_action_pressed("jump_fwd"):
					_jump_fwd_impl()
				else:
					_jump_bwd_impl()
				_jumped_this_frame = true
	
	# --- Логика падения боба за карту ---
	if $".".position.y > 2000:
		# Скрывает след, чтобы он не отрисовывался через всю карту при тп
		$character_trail.visible = false
		# Телепортирует боба наверх (координата Х в дальнейшем должна вычисляться в зависимости от карты)
		$".".position.y = -1000
		$".".position.x = 900
		# Убирает ускорения и боб падает ровно вниз 
		velocity.y = 0
		velocity.x = 0
		# Возвращает видимость следу через пол секунды
		await get_tree().create_timer(0.5).timeout
		$character_trail.visible = true
		
	print($".".position)
	move_and_slide()
	# БАБКО БАБКО ШТУПЛЕН ЧЯЧЛЕН ПИСЮПА БАБКООООО
	# ЧЕЧЕНСКАЯ МАФИЯ 2

func _jump_fwd_impl() -> void:
	var shift_held: bool = Input.is_action_pressed("shift")
	if jump_counter >= jump_delay:
		jump_counter = 0
		if !is_on_floor():
				possible_jumps_now -= 1
		if shift_held:
			velocity.y = -300.0
			velocity.x = -175.0 * $bob.scale.x
		if !shift_held:	
			velocity.y = -200.0
			velocity.x = -125.0 * $bob.scale.x
	else:
		pass

func _jump_bwd_impl() -> void:
	var shift_held: bool = Input.is_action_pressed("shift")
	if jump_counter >= jump_delay:
		jump_counter = 0
		if !is_on_floor():
				possible_jumps_now -= 1
		if shift_held:
			velocity.y = -400.0
			if velocity.x > 100 or velocity.x < -100:
				velocity.x = 0
			await get_tree().create_timer(0.1).timeout
			velocity.x = 100.0 * $bob.scale.x
			rotate = true
		if !shift_held:	
			velocity.y = -300.0
			if velocity.x > 100 or velocity.x < -100:
				velocity.x = 0
			await get_tree().create_timer(0.1).timeout
			velocity.x = 85.0 * $bob.scale.x
			rotate = true
	else:
		pass
