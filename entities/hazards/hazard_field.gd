class_name HazardField
extends Node
## Drifts rocks in from just outside the arena at the battle's density, and
## builds the debris when a large one is shot down. It never adds anything to
## the tree: every rock goes out through `asteroid_spawned`.

signal asteroid_spawned(rock: Asteroid)

const ASTEROID_SCENE: PackedScene = preload("res://entities/hazards/asteroid.tscn")

var _density: float = 0.0
var _running: bool = false
var _timer: float = 0.0
var _live: int = 0


func start(density: float) -> void:
	stop()
	_density = maxf(density, 0.0)
	_running = _density > 0.0
	_timer = _interval() * 0.5


func stop() -> void:
	_running = false
	_density = 0.0
	_timer = 0.0
	_live = 0


func _process(delta: float) -> void:
	if not _running:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = _interval()
	if _live >= Tuning.ASTEROID_MAX_LIVE:
		return
	_spawn(_edge_spawn())


## Debris after a split. Returns the rocks for the battle to add.
func make_debris(at: Vector2, count: int) -> Array[Asteroid]:
	var rocks: Array[Asteroid] = []
	for _index: int in maxi(count, 0):
		var rock := _build(false)
		rock.setup(
			false,
			Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
				* randf_range(Tuning.ASTEROID_SPEED_MIN, Tuning.ASTEROID_SPEED_MAX),
			at + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		)
		rocks.append(rock)
	return rocks


func _build(is_large: bool) -> Asteroid:
	var rock := ASTEROID_SCENE.instantiate() as Asteroid
	rock.large = is_large
	rock.tree_exited.connect(_on_rock_exited)
	_live += 1
	return rock


func _spawn(rock_data: Array) -> void:
	var rock := _build(true)
	rock.setup(true, rock_data[1], rock_data[0])
	asteroid_spawned.emit(rock)


func _on_rock_exited() -> void:
	_live = maxi(_live - 1, 0)


func _interval() -> float:
	return maxf(Tuning.ASTEROID_SPAWN_INTERVAL / maxf(_density, 0.01), 0.35)


## [position, velocity] just outside one of the four arena edges.
func _edge_spawn() -> Array:
	var margin: float = Tuning.ASTEROID_SPAWN_OFFSET
	var speed: float = randf_range(Tuning.ASTEROID_SPEED_MIN, Tuning.ASTEROID_SPEED_MAX)
	match randi() % 4:
		0:
			return [
				Vector2(-margin, randf_range(Tuning.ARENA_TOP, Tuning.ARENA_BOTTOM)),
				Vector2(speed, randf_range(-0.35, 0.35) * speed),
			]
		1:
			return [
				Vector2(Tuning.ARENA_RIGHT + margin, randf_range(Tuning.ARENA_TOP, Tuning.ARENA_BOTTOM)),
				Vector2(-speed, randf_range(-0.35, 0.35) * speed),
			]
		2:
			return [
				Vector2(randf_range(Tuning.ARENA_LEFT, Tuning.ARENA_RIGHT), Tuning.ARENA_TOP - margin),
				Vector2(randf_range(-0.35, 0.35) * speed, speed),
			]
		_:
			return [
				Vector2(randf_range(Tuning.ARENA_LEFT, Tuning.ARENA_RIGHT), Tuning.ARENA_BOTTOM + margin),
				Vector2(randf_range(-0.35, 0.35) * speed, -speed),
			]
