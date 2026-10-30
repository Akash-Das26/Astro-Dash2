class_name Shockwave
extends Node2D
## Expanding ring drawn with primitives, spawned next to a kill or a big hit.
## It frees itself when the ring has faded.

var tint: Color = Color(1.0, 0.85, 1.0)
var radius: float = Tuning.SHOCKWAVE_RADIUS
var life_time: float = Tuning.SHOCKWAVE_LIFE

var _age: float = 0.0


func _process(delta: float) -> void:
	_age += delta
	if _age >= life_time:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(_age / maxf(life_time, 0.01), 0.0, 1.0)
	var current: float = radius * (0.25 + 0.75 * progress)
	draw_arc(
		Vector2.ZERO,
		current,
		0.0,
		TAU,
		32,
		Color(tint.r, tint.g, tint.b, (1.0 - progress) * 0.9),
		2.0,
		true
	)
