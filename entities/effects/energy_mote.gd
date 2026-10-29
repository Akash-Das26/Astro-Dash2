class_name EnergyMote
extends Node2D
## One bit of energy. No Area2D and no collision layer: it measures the
## distance to the ship, drifts until the ship is inside the magnet radius and
## then homes in. Drawn with primitives, so it needs no texture.

signal collected(value: int)

var value: int = 1

var _target: Node2D
var _homing: bool = false
var _age: float = 0.0
var _drift: Vector2 = Vector2(0.0, Tuning.MOTE_DRIFT_SPEED)


## The ship it homes on and how much it is worth.
func setup(target: Node2D, amount: int) -> void:
	_target = target
	value = maxi(amount, 1)
	_drift = Vector2(randf_range(-16.0, 16.0), Tuning.MOTE_DRIFT_SPEED)


func _process(delta: float) -> void:
	_age += delta
	if _age >= Tuning.MOTE_LIFE_SECONDS:
		queue_free()
		return
	# Spin and pulse without redrawing: the shape itself never changes.
	rotation += delta * 2.6
	scale = Vector2.ONE * (1.0 + 0.1 * sin(_age * 11.0))
	modulate.a = clampf((Tuning.MOTE_LIFE_SECONDS - _age) / 1.2, 0.0, 1.0)
	_home_or_drift(delta)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.5, Color(0.35, 0.95, 0.75, 0.16))
	var diamond := PackedVector2Array([
		Vector2(0.0, -6.0),
		Vector2(5.0, 0.0),
		Vector2(0.0, 6.0),
		Vector2(-5.0, 0.0),
	])
	draw_colored_polygon(diamond, Color(0.45, 1.0, 0.75))


func _home_or_drift(delta: float) -> void:
	if _target != null and is_instance_valid(_target):
		var offset: Vector2 = _target.global_position - global_position
		if not _homing and offset.length() <= Tuning.MOTE_MAGNET_RADIUS:
			_homing = true
		if _homing:
			var step: float = Tuning.MOTE_HOME_SPEED * delta
			if offset.length() <= maxf(step, Tuning.MOTE_PICKUP_DISTANCE):
				collected.emit(value)
				queue_free()
				return
			global_position += offset.normalized() * step
			return
	global_position += _drift * delta
	if position.y > 640.0:
		queue_free()
