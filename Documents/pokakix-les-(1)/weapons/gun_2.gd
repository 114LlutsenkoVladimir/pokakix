extends Node2D
class_name Gun2Weapon

@export var BULLET_SCENE: PackedScene = preload("res://shell/bullet/bullet.tscn")

@export var BURST_COUNT: int = 5          # сколько пуль в очереди
@export var BURST_INTERVAL: float = 0.07  # пауза между пулями (сек)

var _burst_active: bool = false

func can_fire(p: CharacterBody2D) -> bool:
	# нельзя начинать новую очередь, пока старая не закончилась
	if _burst_active:
		return false
	return p._on_floor_stable

func fire(p: CharacterBody2D) -> void:
	if _burst_active:
		return
	if not can_fire(p):
		return

	var mz := get_node_or_null("muzzle") as Marker2D
	if mz == null:
		return

	_burst_active = true

	for i in range(BURST_COUNT):
		# если оружие/игрок удалены — тихо выходим
		if not is_instance_valid(self) or not is_instance_valid(p):
			_burst_active = false
			return

		# каждый выстрел берём актуальные позиции (на случай, если игрок целится/двигается)
		var b := BULLET_SCENE.instantiate()
		p.get_tree().current_scene.add_child(b)
		b.global_position = mz.global_position

		var dir: Vector2 = (mz.global_position - p.weapon_pivot.global_position).normalized()
		if b.has_method("setup"):
			b.call("setup", dir, p, p.terrain)

		# пауза между пулями, кроме последней
		if i < BURST_COUNT - 1:
			await get_tree().create_timer(BURST_INTERVAL).timeout

	_burst_active = false
