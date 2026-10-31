class_name EnergyMote
extends Node2D
## One bit of energy: a cyan laser shard with a soft glow that drifts, then
## homes on the ship once it is inside the magnet radius. No Area2D and no
## collision layer, it only measures the distance.

signal collected(value: int)

const TEXTURE: Texture2D = preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_laser_small_blue.png")

var value: int = 1

var _target: Node2D
var _homing: bool = false
var _age: float = 0.0
var _drift: Vector2 = Vector2(0.0, Tuning.ORB_DRIFT_SPEED)

@onready var _sprite: Sprite2D = $Sprite


## The ship it homes on and how much energy it is worth.
func setup(target: Node2D, amount: int) -> void:
	_target = target
	value = maxi(amount, 1)
	_drift = Vector2(randf_range(-28.0, 28.0), Tuning.ORB_DRIFT_SPEED * randf_range(0.6, 1.2))


func _process(delta: float) -> void:
	_age += delta
	if _age >= Tuning.ORB_LIFE_SECONDS:
		queue_free()
		return
	# Soft glow pulse: the sprite breathe and the halo behind it brightens.
	var pulse: float = 0.5 + 0.5 * sin(_age * Tuning.ORB_PULSE_SPEED)
	_sprite.modulate = Color(1.0, 1.0, 1.0, 0.7 + 0.3 * pulse)
	modulate.a = clampf((Tuning.ORB_LIFE_SECONDS - _age) / 1.4, 0.0, 1.0)
	_home_or_drift(delta)
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_age * Tuning.ORB_PULSE_SPEED)
	draw_circle(Vector2.ZERO, 9.0 + 2.0 * pulse, Color(0.35, 0.9, 1.0, 0.10 + 0.10 * pulse))


func _home_or_drift(delta: float) -> void:
	if _target != null and is_instance_valid(_target):
		var offset: Vector2 = _target.global_position - global_position
		if not _homing and offset.length() <= Tuning.ORB_MAGNET_RADIUS:
			_homing = true
		if _homing:
			var step: float = Tuning.ORB_HOME_SPEED * delta
			if offset.length() <= maxf(step, Tuning.ORB_PICKUP_RADIUS):
				collected.emit(value)
				queue_free()
				return
			global_position += offset.normalized() * step
			return
	global_position += _drift * delta
	if position.x < -60.0 or position.x > Tuning.VIEW_SIZE.x + 60.0 \
		or position.y > Tuning.ARENA_BOTTOM + 60.0 or position.y < Tuning.ARENA_TOP - 60.0:
		queue_free()
