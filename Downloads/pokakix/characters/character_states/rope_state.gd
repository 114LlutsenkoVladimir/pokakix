extends PlayerState
class_name RopeState

@onready var rope_physics: RopePhysics = $RopePhysicModel
@onready var rope_line: Line2D = $RopeLine

func enter(p: WormsPlayer, data: Dictionary = {}) -> void:
	p.velocity = Vector2.ZERO
	rope_line.visible = true
	rope_line.width = 2.0
	rope_line.default_color = Color.WHITE
	
	p._disable_follow_ground_frames = 999999
	p._on_floor_stable = false

	p.is_on_rope = true
	p._want_weapon_visible = true
	if is_instance_valid(p.pritsel):
		p.pritsel.visible = false
	p.weapon_pivot.rotation = 0.0

	var hook_pos: Vector2 = data.get("hook_pos")
	var player_center: Vector2 = p._pos_center()

	var min_len := p._px_to_world(10)
	var max_len := p._px_to_world(380)

	rope_physics.reset(hook_pos, player_center, min_len, max_len)

	# чтобы normal-state не вмешивался
	p._disable_follow_ground_frames = 999999
	p._grace_left = 0.0
	p._on_floor = false
	p._on_floor_stable = false


func physics_update(p: WormsPlayer, delta: float) -> void:
	p._want_weapon_visible = true
	p._on_floor = false
	p._on_floor_stable = false

	if is_instance_valid(p.pritsel):
		p.pritsel.visible = false
	p.weapon_pivot.rotation = 0.0

	# detach
	if Input.is_action_just_pressed("fire"):
		detach_rope(p)
		return

	# --- Wormix ACC: 0.5 px / tick ---
	var acc_tick := p._px_to_world(0.5)
	rope_physics.acc_x = 0.0

	if Input.is_action_pressed("right"):
		rope_physics.acc_x += acc_tick
	if Input.is_action_pressed("left"):
		rope_physics.acc_x -= acc_tick

	# length control
	var dlen_tick := p._px_to_world(10)
	p._disable_follow_ground_frames = 10
	rope_physics.d_length = 0.0
	if Input.is_action_pressed("aim_up"):
		rope_physics.d_length -= dlen_tick
	if Input.is_action_pressed("aim_down"):
		rope_physics.d_length += dlen_tick

	rope_physics.update(p, delta)

	# защита от залипаний
	rope_physics.acc_x = 0.0
	rope_physics.d_length = 0.0

	_update_rope_line(p)


func detach_rope(p: WormsPlayer) -> void:
	rope_physics.clear()
	p.is_on_rope = false

	p._grace_left = 0.0
	p._on_floor = false
	p._on_floor_stable = false

	p._player_state = p.get_node("States/NormalState")
	p._disable_follow_ground_frames = 0

func _update_rope_line(p: WormsPlayer) -> void:
	rope_line.clear_points()

	var pts := rope_physics.get_joint_points(p)
	for pt in pts:
		rope_line.add_point(pt)
