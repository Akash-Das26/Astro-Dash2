class_name Starfield
extends Node2D
## Three parallax star layers drawn with primitives (no textures, no shaders)
## over the purple backdrop. Scrolls downward at different speeds and pauses
## with the tree like every other world object.

const VIEW_SIZE: Vector2 = Vector2(400.0, 600.0)
const LAYER_SPEEDS: Array[float] = [18.0, 42.0, 78.0]
const LAYER_COUNTS: Array[int] = [28, 18, 12]
const LAYER_SIZES: Array[float] = [1.0, 2.0, 3.0]
const LAYER_COLORS: Array[Color] = [
	Color(0.55, 0.6, 0.9, 0.55),
	Color(0.75, 0.8, 1.0, 0.75),
	Color(1.0, 1.0, 1.0, 0.95),
]

var _star_positions: Array[PackedVector2Array] = []
var _layer_offsets: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	for layer: int in LAYER_SPEEDS.size():
		_star_positions.append(_make_layer(LAYER_COUNTS[layer]))
		_layer_offsets.append(0.0)


func _process(delta: float) -> void:
	for layer: int in _layer_offsets.size():
		var wrapped: float = _layer_offsets[layer] + LAYER_SPEEDS[layer] * delta
		_layer_offsets[layer] = fmod(wrapped, VIEW_SIZE.y)
	queue_redraw()


func _draw() -> void:
	for layer: int in _star_positions.size():
		var star_size: float = LAYER_SIZES[layer]
		var color: Color = LAYER_COLORS[layer]
		var offset: float = _layer_offsets[layer]
		for star: Vector2 in _star_positions[layer]:
			var y: float = fmod(star.y + offset, VIEW_SIZE.y)
			draw_rect(Rect2(Vector2(star.x, y), Vector2(star_size, star_size)), color)


func _make_layer(count: int) -> PackedVector2Array:
	var stars := PackedVector2Array()
	for _i: int in count:
		stars.append(Vector2(randf() * VIEW_SIZE.x, randf() * VIEW_SIZE.y))
	return stars
