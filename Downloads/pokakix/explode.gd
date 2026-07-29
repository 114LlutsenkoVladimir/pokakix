extends Node2D

@export var anim: AnimatedSprite2D
const ANIM := "explode"
const BASE_RADIUS_PX := 820.0 * 1.4

func _ready() -> void:
	if anim == null:
		push_error("Explode: anim не назначен в инспекторе!")
		return

	anim.animation_finished.connect(queue_free)

func play(world_radius: float, world_scale: float) -> void:
	if anim == null:
		return

	if anim.sprite_frames:
		anim.sprite_frames.set_animation_loop(ANIM, false)

	var base_radius_world := BASE_RADIUS_PX * world_scale
	var k : float = world_radius / max(0.001, base_radius_world)
	scale = Vector2.ONE * k

	anim.play(ANIM)
