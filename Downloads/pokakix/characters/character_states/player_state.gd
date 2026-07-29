# res://states/player_state.gd
extends Node
class_name PlayerState

var p: CharacterBody2D

func enter(player: WormsPlayer) -> void:
	p = player
	set_active(true)

func exit(p: WormsPlayer) -> void:
	set_active(false)

func set_active(v: bool) -> void:
	# чтобы state сам не тикал (мы будем вызывать вручную) — тут можно оставить всё false
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)

func handle_input(_event: InputEvent) -> void:
	pass

func physics_update(player: WormsPlayer, _delta: float) -> void:
	pass
