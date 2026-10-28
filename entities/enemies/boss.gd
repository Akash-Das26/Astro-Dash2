class_name Boss
extends EnemyBase
## Appears every fifth wave. It flies in, then strafes across the screen;
## after a few seconds it starts firing bullet fans while it keeps strafing.
## Leaving the screen does not cost a life, it just ends the wave.

signal spread_shot(origin: Vector2, directions: PackedVector2Array)

enum Phase { STRAFE, SPREAD }

@export var entry_y: float = 120.0
@export var strafe_speed: float = 80.0
@export var strafe_margin: float = 70.0
## Seconds of pure strafing before the spread phase starts.
@export var strafe_seconds: float = 4.0
## Slow descent once it starts firing, so an unfinished boss eventually
## crosses the Boundary and ends the wave by itself.
@export var descent_speed: float = 32.0
@export var spread_interval: float = 2.0
@export var spread_bullets: int = 5
## Total width of the fan, in degrees.
@export var spread_degrees: float = 60.0

var _phase: Phase = Phase.STRAFE
var _phase_time: float = 0.0
var _shot_timer: float = 0.0
var _strafe_direction: float = 1.0


func _move(delta: float) -> void:
	if position.y < entry_y:
		position.y = minf(position.y + speed * delta, entry_y)
		return

	_strafe(delta)
	_phase_time += delta

	if _phase == Phase.STRAFE and _phase_time >= strafe_seconds:
		_phase = Phase.SPREAD
		_shot_timer = 0.0

	if _phase == Phase.SPREAD:
		position.y += descent_speed * delta
		_shot_timer += delta
		if _shot_timer >= spread_interval:
			_shot_timer = 0.0
			_fire_spread()


## Ramming the boss hurts the player but does not destroy the boss.
func on_player_contact() -> void:
	pass


func _strafe(delta: float) -> void:
	position.x += strafe_speed * _strafe_direction * delta
	if position.x <= strafe_margin:
		position.x = strafe_margin
		_strafe_direction = 1.0
	elif position.x >= PLAY_AREA_WIDTH - strafe_margin:
		position.x = PLAY_AREA_WIDTH - strafe_margin
		_strafe_direction = -1.0


func _fire_spread() -> void:
	var directions := PackedVector2Array()
	for index: int in spread_bullets:
		var t: float = 0.5
		if spread_bullets > 1:
			t = float(index) / float(spread_bullets - 1)
		var angle: float = deg_to_rad(lerpf(-spread_degrees * 0.5, spread_degrees * 0.5, t))
		directions.append(Vector2.DOWN.rotated(angle))
	spread_shot.emit(global_position, directions)
