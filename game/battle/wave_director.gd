class_name WaveDirector
extends Node
## Turns a Battle resource into waves of fighters. It hands each fighter out
## through `enemy_spawned` (the battle adds it to the scene) and knows when a
## wave and the whole battle are done.

signal wave_started(index: int, total: int)
signal enemy_spawned(enemy: EnemyBase)
signal wave_cleared(index: int)
signal battle_won

const FIGHTER_SCENE: PackedScene = preload("res://entities/enemies/enemy_base.tscn")
## Spawn attempts that land closer than this to the ship are thrown away.
const MIN_SHIP_DISTANCE: float = 220.0
const MAX_SPAWN_TRIES: int = 12

var wave: int = 0

var _battle: Battle
var _ship: Ship
var _running: bool = false
var _queue: Array[StringName] = []
var _active: int = 0
var _spawn_timer: Timer
var _gap_timer: Timer


func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_on_spawn_timeout)
	add_child(_spawn_timer)

	_gap_timer = Timer.new()
	_gap_timer.name = "WaveGapTimer"
	_gap_timer.one_shot = true
	_gap_timer.wait_time = Tuning.WAVE_GAP
	_gap_timer.timeout.connect(_on_gap_timeout)
	add_child(_gap_timer)


func start(battle: Battle, ship: Ship) -> void:
	stop()
	_battle = battle
	_ship = ship
	_running = true
	_start_wave(1)


func stop() -> void:
	_running = false
	wave = 0
	_queue.clear()
	_active = 0
	_spawn_timer.stop()
	_gap_timer.stop()


func wave_total() -> int:
	return _battle.waves if _battle != null else 0


func is_running() -> bool:
	return _running


func _start_wave(index: int) -> void:
	if not _running or _battle == null:
		return
	wave = index
	_queue = _build_queue()
	wave_started.emit(wave, wave_total())
	_spawn_timer.wait_time = Tuning.SPAWN_STAGGER
	_spawn_timer.start()


func _on_gap_timeout() -> void:
	_start_wave(wave + 1)


func _on_spawn_timeout() -> void:
	if not _running:
		return
	if _queue.is_empty():
		_check_cleared()
		return
	var kind: StringName = _queue.pop_front()
	var at: Vector2 = _spawn_point()
	_spawn_at(kind, at)
	# A swarm unit arrives as a cluster: one queue slot, several fighters.
	if _is_swarm(kind):
		var extra: int = randi_range(Tuning.DRONE_CLUSTER_MIN, Tuning.DRONE_CLUSTER_MAX)
		for _index: int in extra:
			var offset := Vector2(
				randf_range(-Tuning.DRONE_CLUSTER_SPREAD, Tuning.DRONE_CLUSTER_SPREAD),
				randf_range(-Tuning.DRONE_CLUSTER_SPREAD, Tuning.DRONE_CLUSTER_SPREAD)
			)
			_spawn_at(kind, _clamp_spawn(at + offset))
	if not _queue.is_empty():
		_spawn_timer.start()


func _spawn_at(kind: StringName, at: Vector2) -> void:
	var enemy := FIGHTER_SCENE.instantiate() as EnemyBase
	if enemy == null:
		return
	enemy.configure(kind, at, _ship, _battle.hp_scale, _battle.fire_interval_scale)
	# Connect before the fighter reaches the tree, so every exit is counted.
	enemy.tree_exited.connect(_on_enemy_exited)
	_active += 1
	enemy_spawned.emit(enemy)


func _is_swarm(kind: StringName) -> bool:
	var row: Dictionary = Tuning.ENEMY_TYPES.get(kind, {})
	return bool(row.get("swarm", false))


## Keeps a cluster's extra bodies inside the arena and off the ship.
func _clamp_spawn(at: Vector2) -> Vector2:
	var clamped := Vector2(
		clampf(at.x, Tuning.ARENA_LEFT + Tuning.ARENA_MARGIN, Tuning.ARENA_RIGHT - Tuning.ARENA_MARGIN),
		clampf(at.y, Tuning.ARENA_TOP + Tuning.ARENA_MARGIN, Tuning.ARENA_BOTTOM - Tuning.ARENA_MARGIN)
	)
	if _ship != null and is_instance_valid(_ship):
		if clamped.distance_to(_ship.global_position) < MIN_SHIP_DISTANCE * 0.5:
			return _spawn_point()
	return clamped


func _on_enemy_exited() -> void:
	_active = maxi(_active - 1, 0)
	_check_cleared()


func _check_cleared() -> void:
	if not _running:
		return
	if not _queue.is_empty() or _active > 0:
		return
	if wave >= wave_total():
		_running = false
		battle_won.emit()
		return
	wave_cleared.emit(wave)
	if _gap_timer.time_left <= 0.0:
		_gap_timer.start()


## Weighted mix: the kinds are repeated by their weight, shuffled, then dealt
## round-robin until the wave is full.
func _build_queue() -> Array[StringName]:
	var palette: Array[StringName] = []
	for kind: StringName in _battle.enemy_mix:
		for _weight: int in maxi(int(_battle.enemy_mix[kind]), 0):
			palette.append(kind)
	if palette.is_empty():
		palette.append(&"scout")
	palette.shuffle()
	var queue: Array[StringName] = []
	for index: int in _battle.enemies_per_wave:
		queue.append(palette[index % palette.size()])
	queue.shuffle()
	return queue


## Random arena point that is not on top of the ship.
func _spawn_point() -> Vector2:
	var best := Vector2(
		randf_range(Tuning.ARENA_LEFT + Tuning.ARENA_MARGIN, Tuning.ARENA_RIGHT - Tuning.ARENA_MARGIN),
		randf_range(Tuning.ARENA_TOP + Tuning.ARENA_MARGIN, Tuning.ARENA_BOTTOM - Tuning.ARENA_MARGIN)
	)
	if _ship == null or not is_instance_valid(_ship):
		return best
	for _try: int in MAX_SPAWN_TRIES:
		if best.distance_to(_ship.global_position) >= MIN_SHIP_DISTANCE:
			return best
		best = Vector2(
			randf_range(Tuning.ARENA_LEFT + Tuning.ARENA_MARGIN, Tuning.ARENA_RIGHT - Tuning.ARENA_MARGIN),
			randf_range(Tuning.ARENA_TOP + Tuning.ARENA_MARGIN, Tuning.ARENA_BOTTOM - Tuning.ARENA_MARGIN)
		)
	return best
