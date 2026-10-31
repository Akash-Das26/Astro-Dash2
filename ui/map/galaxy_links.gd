class_name GalaxyLinks
extends Node2D
## Draws the sector graph: a line per link, dim for unexplored space, green when
## both ends are conquered, brighter when the link leads into an attackable
## body.

var _galaxy: Galaxy
var _conquered: Array[StringName] = []
var _attackable: Array[StringName] = []


func setup(galaxy: Galaxy) -> void:
	_galaxy = galaxy
	queue_redraw()


func set_state(conquered: Array[StringName], attackable: Array[StringName]) -> void:
	_conquered = conquered.duplicate()
	_attackable = attackable.duplicate()
	queue_redraw()


func _draw() -> void:
	if _galaxy == null:
		return
	var drawn: Dictionary = {}
	for body_id: StringName in _galaxy.order:
		for other: StringName in _galaxy.links_of(body_id):
			var key: String = _key(body_id, other)
			if drawn.has(key):
				continue
			drawn[key] = true
			var start: Vector2 = _galaxy.position_of(body_id)
			var end: Vector2 = _galaxy.position_of(other)
			var color: Color = Tuning.MAP_LINK_COLOR
			var width: float = 1.5
			if _conquered.has(body_id) and _conquered.has(other):
				color = Tuning.MAP_LINK_CONQUERED_COLOR
				width = 2.0
			elif (_conquered.has(body_id) and _attackable.has(other)) \
				or (_conquered.has(other) and _attackable.has(body_id)):
				color = Tuning.MAP_LINK_OPEN_COLOR
				width = 2.0
			draw_line(start, end, color, width)


## Order-independent key so an A-B link and a B-A link draw once.
func _key(a: StringName, b: StringName) -> String:
	var first: String = String(a)
	var second: String = String(b)
	if first < second:
		return first + "|" + second
	return second + "|" + first
