class_name Starfield
extends Node2D
## Three parallax star layers drawn with primitives over the tiled background
## texture, drifting sideways at different speeds. No textures, no shaders, and
## it pauses with the tree like every other world object.

var _layer_positions: Array[PackedVector2Array] = []
var _layer_offsets: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	for layer: int in Tuning.STARFIELD_SPEEDS.size():
		_layer_positions.append(_make_layer(Tuning.STARFIELD_COUNTS[layer]))
		_layer_offsets.append(0.0)


func _process(delta: float) -> void:
	for layer: int in _layer_offsets.size():
		_layer_offsets[layer] = fmod(_layer_offsets[layer] + Tuning.STARFIELD_SPEEDS[layer] * delta, Tuning.VIEW_SIZE.x)
	queue_redraw()


func _draw() -> void:
	for layer: int in _layer_positions.size():
		var star_size: float = Tuning.STARFIELD_SIZES[layer]
		var color: Color = Tuning.STARFIELD_COLORS[layer]
		var offset: float = _layer_offsets[layer]
		for star: Vector2 in _layer_positions[layer]:
			var x: float = fmod(star.x + offset, Tuning.VIEW_SIZE.x)
			draw_rect(Rect2(Vector2(x, star.y), Vector2(star_size, star_size)), color)


func _make_layer(count: int) -> PackedVector2Array:
	var stars := PackedVector2Array()
	for _index: int in count:
		stars.append(Vector2(
			randf() * Tuning.VIEW_SIZE.x,
			randf_range(Tuning.ARENA_TOP, Tuning.ARENA_BOTTOM)
		))
	return stars
