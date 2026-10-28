class_name Player
extends Node2D
## The player ship. It owns its movement and fire rate, but never creates
## bullets itself: it broadcasts `shot_fired` and a manager spawns the bullet.

signal shot_fired(spawn_position: Vector2)

@export var move_speed: float = 300.0
@export var fire_interval: float = 0.5
@export var muzzle_offset: Vector2 = Vector2(0.0, -20.0)
@export var play_area_width: float = 400.0
@export var half_width: float = 16.0

var _shoot_cooldown: float = 0.0


func _process(delta: float) -> void:
	_move(delta)
	_update_shooting(delta)


func _move(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	var target_x: float = position.x + direction * move_speed * delta
	position.x = clampf(target_x, half_width, play_area_width - half_width)


func _update_shooting(delta: float) -> void:
	_shoot_cooldown += delta
	if not Input.is_action_pressed("shoot") or _shoot_cooldown < fire_interval:
		return
	_shoot_cooldown = 0.0
	shot_fired.emit(position + muzzle_offset)
