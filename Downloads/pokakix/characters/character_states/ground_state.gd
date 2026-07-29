extends PlayerState
class_name GroundState

func enter(p) -> void:
	p.show_weapon()

func physics_update(p, delta: float) -> void:
	# движение по земле
	if not p._jumped_this_frame:
		p._handle_on_ground()

	# прицел
	p._update_weapon_aim(delta)

	# выстрел (оружие само решит можно/нельзя)
	if Input.is_action_just_pressed("fire"):
		p._try_shoot()

	# если улетели с пола — переключим на AirState
	if not p.is_on_floor():
		p.set_state(AirState.new())
