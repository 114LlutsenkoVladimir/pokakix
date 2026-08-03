extends CharacterBody2D


const SPEED = 100.0
const JUMP_VELOCITY = -400.0
@onready var sprite_2d = $Sprite2D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")


func _physics_process(delta):
	# Add the gravity.
	var free_movement = true
	if not is_on_floor():
		velocity.y += gravity * delta
		sprite_2d.rotate(0.1)
		free_movement = false
		
	if is_on_floor():
		sprite_2d.rotation_degrees = 0
		free_movement = true
		

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	if Input.is_action_just_pressed("left") and is_on_floor():
		sprite_2d.flip_h = false
	if Input.is_action_just_pressed("right") and is_on_floor():
		sprite_2d.flip_h = true
	var direction = Input.get_axis("left", "right")
	if direction and free_movement == true:
		velocity.x = direction * SPEED
	elif free_movement == false:
		velocity.x = move_toward(velocity.x, 0, 4)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
	# Прыжок вперед влево
	if Input.is_action_just_pressed("jump_fwd") and free_movement == true and sprite_2d.flip_h == false:
		velocity.y = -250.0
		velocity.x = move_toward(-320, 10, 4)
	# Прыжок вперед вправо
	if Input.is_action_just_pressed("jump_fwd") and free_movement == true and sprite_2d.flip_h == true:
		velocity.y = -250.0
		velocity.x = move_toward(320, 10, 4)
	# Прыжок назад вправо
	if Input.is_action_just_pressed("jump_bwd") and free_movement == true and sprite_2d.flip_h == false:
		velocity.y = -380.0
		velocity.x = move_toward(220, 10, 4)
	# Прыжок назад влево
	if Input.is_action_just_pressed("jump_bwd") and free_movement == true and sprite_2d.flip_h == true:
		velocity.y = -380.0
		velocity.x = move_toward(-220, 10, 4)

	move_and_slide()
