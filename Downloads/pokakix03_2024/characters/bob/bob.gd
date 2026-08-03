extends CharacterBody2D


@export var SPEED : int = 70
@export var GRAVITY : int = 900
@export var HEALTH : int = 500
@export var TEAM = "green"

var freeMovement = true
var jump_delay = 0
var jump_delay_time = 0.5
var rotate = true
var rotate_timer = 0
var did_jump = 0

# rip bob_flip 2024-2024

# Get the gravity from the project settings to be synced with RigidBody nodes.
# гульчичяп жужмальпупис
#чёт вентилятор сломался 卐卐卐卐, из-за грозы наверное ϟϟ, достаём инструменты☭☭☭☭, всё, починил, теперь можно и поспать ZzzZzzzZZ
# rip sex 2024-2024
func _ready():
	await get_tree().create_timer(0.4).timeout # СТАВИТ ЗАДЕРЖКУ НА ПОЯВЛЕНИЕ СЛЕДА ПРИ ЗАПУСКЕ ИГРЫ
	$character_trail.visible = true
	pass
	

func _physics_process(delta):
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
		$bob/weapon.visible = false
		velocity.y += GRAVITY * delta
		freeMovement = false
		if rotate == true:
			$bob.rotate(0.001 * abs(velocity.y) * $bob.scale.x)
		rotate_timer += 1
		if rotate_timer >= 30:
			rotate = true
			
	# Возвращает возможность движения и прыжков на земле
	if is_on_floor():
		$bob/weapon.visible = true
		rotate = false
		freeMovement = true
		rotate_timer = 0
		$bob.rotation_degrees = 0
		did_jump = 0
	
	if Input.is_action_just_pressed("action"):
		$".".position.x = get_global_mouse_position().x
		$".".position.y = get_global_mouse_position().y
	
	# Прыжок вперед
	if Input.is_action_just_pressed("jump_fwd") and freeMovement == true and jump_delay == 0:
		velocity.y = -200
		did_jump = 1
		velocity.x = -125 * $bob.scale.x
	# Прыжок назад
	if Input.is_action_just_pressed("jump_bwd") and freeMovement == true and jump_delay == 0:
		jump_delay = 1
		velocity.y = -300
		await get_tree().create_timer(0.1).timeout #ну просто бредятина нахуй (ЭТО ТАЙМЕР)
		velocity.x = 85 * $bob.scale.x
		rotate = true
		await is_on_floor()
		await get_tree().create_timer(jump_delay_time).timeout
		jump_delay = 0
		
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
