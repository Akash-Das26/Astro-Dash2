class_name EnemySpawner
extends Node
## Wave director. It decides what comes next, hands the enemies to whoever
## listens on `enemy_spawned`, and knows when a wave is over (every enemy it
## spawned has left the tree). It never touches the Enemies container.

signal enemy_spawned(enemy: EnemyBase)
signal wave_started(wave_number: int, is_boss: bool)

const ENEMY_SCENES: Dictionary = {
	"straight": preload("res://entities/enemies/enemy.tscn"),
	"zigzag": preload("res://entities/enemies/zigzag_enemy.tscn"),
	"tank": preload("res://entities/enemies/tank_enemy.tscn"),
}
const BOSS_SCENE: PackedScene = preload("res://entities/enemies/boss.tscn")

# --- Tunables: edit these to rebalance without touching the logic -----------

## Wave number -> { enemy key: how many }. Beyond the last entry the last
## mix is reused; the spawn interval keeps shrinking down to its floor.
const WAVE_TABLE: Dictionary = {
	1: {"straight": 4},
	2: {"straight": 5, "zigzag": 3},
	3: {"zigzag": 5, "tank": 1},
	4: {"straight": 4, "zigzag": 4, "tank": 2},
}
## Every Nth wave is a single boss instead of a mix.
const BOSS_EVERY: int = 5
## Seconds between spawns on wave 1, shrunk per wave, but never below the floor.
const FIRST_WAVE_INTERVAL: float = 1.4
const MIN_SPAWN_INTERVAL: float = 0.45
const INTERVAL_STEP: float = 0.08
## Beat between "wave cleared" and the next wave.
const WAVE_GAP: float = 2.0

# --- Runtime ----------------------------------------------------------------

var wave: int = 0

var _spawn_timer: Timer
var _gap_timer: Timer
var _queue: Array[PackedScene] = []
var _active_enemies: int = 0
var _running: bool = false


func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)

	_gap_timer = Timer.new()
	_gap_timer.name = "WaveGapTimer"
	_gap_timer.one_shot = true
	_gap_timer.wait_time = WAVE_GAP
	_gap_timer.timeout.connect(_start_next_wave)
	add_child(_gap_timer)


func start_run() -> void:
	stop_run()
	_running = true
	_start_wave(1)


func stop_run() -> void:
	_running = false
	wave = 0
	_queue.clear()
	_active_enemies = 0
	_spawn_timer.stop()
	_gap_timer.stop()


## Testing helper: drops a boss into the current wave immediately.
func spawn_boss_now() -> void:
	if not _running:
		return
	_spawn_enemy(BOSS_SCENE)


func is_boss_wave(wave_number: int) -> bool:
	return wave_number > 0 and wave_number % BOSS_EVERY == 0


func spawn_interval_for(wave_number: int) -> float:
	var ramp: float = INTERVAL_STEP * float(wave_number - 1)
	return maxf(MIN_SPAWN_INTERVAL, FIRST_WAVE_INTERVAL - ramp)


func wave_composition(wave_number: int) -> Dictionary:
	if is_boss_wave(wave_number):
		return {"boss": 1}
	var table_wave: int = mini(wave_number, WAVE_TABLE.size())
	return WAVE_TABLE[table_wave]


func _start_wave(wave_number: int) -> void:
	wave = wave_number
	_queue = _build_queue(wave_composition(wave_number))
	wave_started.emit(wave, is_boss_wave(wave))
	_spawn_timer.wait_time = spawn_interval_for(wave)
	_spawn_timer.start()


func _start_next_wave() -> void:
	if not _running:
		return
	_start_wave(wave + 1)


func _build_queue(composition: Dictionary) -> Array[PackedScene]:
	var queue: Array[PackedScene] = []
	for key: String in composition:
		var scene: PackedScene = BOSS_SCENE if key == "boss" else ENEMY_SCENES[key]
		for _i: int in int(composition[key]):
			queue.append(scene)
	queue.shuffle()
	return queue


func _on_spawn_timer_timeout() -> void:
	if not _running or _queue.is_empty():
		return
	_spawn_enemy(_queue.pop_front())
	if not _queue.is_empty():
		_spawn_timer.start()


func _spawn_enemy(scene: PackedScene) -> void:
	var enemy := scene.instantiate() as EnemyBase
	if enemy == null:
		return
	_active_enemies += 1
	# Connect before the enemy reaches the tree, so every exit is counted.
	enemy.tree_exited.connect(_on_enemy_exited)
	enemy_spawned.emit(enemy)


func _on_enemy_exited() -> void:
	_active_enemies = maxi(_active_enemies - 1, 0)
	_check_wave_cleared()


func _check_wave_cleared() -> void:
	if not _running:
		return
	if not _queue.is_empty() or _active_enemies > 0:
		return
	if _gap_timer.time_left > 0.0:
		return
	_gap_timer.start()
