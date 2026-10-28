class_name ShakeCamera
extends Camera2D
## Trauma-based screen shake. Trauma stacks up to a hard cap of 1.0 and
## decays, and the actual shake scales with trauma squared so small hits stay
## subtle and big ones are punchy. Honours the "reduce motion" setting.

@export var decay_per_second: float = 1.6
@export var max_offset: Vector2 = Vector2(8.0, 8.0)
@export var max_rotation: float = 0.025
@export var noise_frequency: float = 22.0

var _trauma: float = 0.0
var _noise_time: float = 0.0


func _ready() -> void:
	_noise_time = randf() * 100.0


## 0.0 to 1.0. Stacks, but the total never exceeds 1.0 (the cap).
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		if offset != Vector2.ZERO or rotation != 0.0:
			offset = Vector2.ZERO
			rotation = 0.0
		return

	if SaveData.reduce_motion:
		_trauma = 0.0
		offset = Vector2.ZERO
		rotation = 0.0
		return

	_noise_time += delta * noise_frequency
	_trauma = maxf(_trauma - decay_per_second * delta, 0.0)
	var strength: float = _trauma * _trauma
	offset = Vector2(
		max_offset.x * strength * _noise(_noise_time),
		max_offset.y * strength * _noise(_noise_time + 13.0)
	)
	rotation = max_rotation * strength * _noise(_noise_time + 37.0)


## Cheap pseudo-noise in [-1, 1]; no textures, no shaders.
func _noise(time: float) -> float:
	return sin(time) * cos(time * 0.7 + 1.1)
