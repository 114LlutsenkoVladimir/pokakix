extends Node2D
class_name GunWeapon

@export var BULLET_SCENE : PackedScene = preload("res://shell/bullet/bullet.tscn")

func can_fire(p: CharacterBody2D) -> bool:
	return p._on_floor_stable  # или p.is_on_floor()

func fire(p: CharacterBody2D) -> void:
	var mz := get_node("muzzle") as Marker2D
	if mz == null:
		return

	var b := BULLET_SCENE.instantiate()
	p.get_tree().current_scene.add_child(b)
	b.global_position = mz.global_position

	var dir : Vector2  = (mz.global_position - p.weapon_pivot.global_position).normalized()
	if b.has_method("setup"):
		b.call("setup", dir, p, p.terrain)
