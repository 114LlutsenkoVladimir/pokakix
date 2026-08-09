extends PlayerState
class_name NormalState

func physics_update(p: WormsPlayer, delta: float) -> void:
	# ввод по X
	var left_p: bool = Input.is_action_pressed("left")
	var right_p: bool = Input.is_action_pressed("right")
	p._move_input_dir = (1 if right_p else 0) - (1 if left_p else 0)

	var frame: int = Engine.get_physics_frames()
	p._bypass_shift_delay_this_frame = false
	p._jumped_this_frame = false
	p._jump_pressed_this_frame = false

	if p._disable_follow_ground_frames > 0:
		p._disable_follow_ground_frames -= 1

	# fire
	if Input.is_action_just_pressed("fire"):
		var w: Node = p._get_weapon()
		if w and w.has_method("can_fire") and w.call("can_fire", p):
			w.call("fire", p)

	# прыжок
	if Input.is_action_just_pressed("jump_fwd") or Input.is_action_just_pressed("jump_bwd"):
		p._jump_pressed_this_frame = true
		p.global_position.y -= p._px_to_world(p.PREJUMP_LIFT_PX)
		p._disable_follow_ground_frames = 1

		if p._on_floor_stable:
			if Input.is_action_just_pressed("jump_fwd"):
				p._jump_fwd_impl()
			else:
				p._jump_bwd_impl()
			p._jumped_this_frame = true
		else:
			if p.possible_jumps_now > 0:
				p.possible_jumps_now -= 1
				if Input.is_action_just_pressed("jump_fwd"):
					p._jump_fwd_impl()
				else:
					p._jump_bwd_impl()
				p._jumped_this_frame = true

		p._grace_left = 0.0
		p._on_floor_stable = false
		p._on_floor = false

	# наземное управление
	if p._on_floor_stable and not p._jumped_this_frame:
		p._want_weapon_visible = true  # ✅ ВОТ ЭТО НУЖНО
		if frame <= p._no_move_until_frame:
			p.velocity.x = 0.0
		else:
			p._handle_on_ground()
	else:
		p._want_weapon_visible = false

	if frame <= p._no_move_until_frame:
		p.velocity.x = 0.0

	p._update_weapon_aim(delta)
	p._update_hold_timer(delta)
