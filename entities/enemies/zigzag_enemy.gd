class_name ZigzagEnemy
extends EnemyBase
## Drops at a constant rate while sweeping left and right around the column
## it spawned in. Fragile (1 hp) but worth 20 points.

@export var sway_amplitude: float = 70.0
@export var sway_frequency: float = 2.5

var _elapsed: float = 0.0


func _move(delta: float) -> void:
	_elapsed += delta
	position.y += speed * delta
	var sway: float = sin(_elapsed * sway_frequency) * sway_amplitude
	position.x = clampf(spawn_center_x + sway, 16.0, PLAY_AREA_WIDTH - 16.0)
