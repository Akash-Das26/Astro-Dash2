class_name MapBadge
extends Node2D
## The conquered check badge, on its own node so it stays above the hull art.
##
## It draws itself: the marker used to connect this node's `draw` signal to a
## method on the marker, and the engine rejected every draw_* call made outside
## the drawing item's own `_draw()`, so the badge rendered nothing and logged an
## error per frame.

## Badge radius in map units. The marker keeps it in step with the map zoom.
var radius: float = 10.0


func _draw() -> void:
	if radius <= 0.0:
		return
	draw_circle(Vector2.ZERO, radius, Color(0.07, 0.28, 0.16, 0.95))
	draw_arc(
		Vector2.ZERO, radius, 0.0, TAU, 18, Color(0.45, 1.0, 0.65, 0.9), 1.5, true
	)
	var tick := PackedVector2Array([
		Vector2(-0.40, 0.02) * radius,
		Vector2(-0.10, 0.42) * radius,
		Vector2(0.48, -0.38) * radius,
	])
	draw_polyline(tick, Color(0.7, 1.0, 0.8), 2.0)
