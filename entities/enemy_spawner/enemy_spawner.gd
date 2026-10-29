class_name EnemySpawner
extends Node
## Wave director. It decides what comes next, hands the enemies to whoever
## listens on `enemy_spawned`, and knows when a wave is over (every enemy it
## spawned has left the tree). It never touches the Enemies container.

signal enemy_spawned(enemy: EnemyBase)
signal wave_started(wave_number: int, is_boss: bool)
## Campaign battles only: every wave of the sector has been cleared.
signal battle_cleared

const ENEMY_SCENES: Dictionary = {
	"straight": preload("res://entities/enemies/enemy.tscn"),
	"zigzag": preload("res://entities/enemies/zigzag_enemy.tscn"),
	"tank": preload("res://entities/enemies/tank_enemy.tscn"),
}
const BOSS_SCENE: PackedScene = preload("res://entities/enemies/boss.tscn")

# Wave table, boss cadence and spawn ramp live in tuning.gd (Waves section).

# --- Runtime ----------------------------------------------------------------

var wave: int = 0

var _spawn_timer: Timer
var _gap_timer: Timer
var _queue: Array[PackedScene] = []
var _active_enemies: int = 0
var _running: bool = false
## Campaign battle: a fixed wave list and the sector's tier multipliers.
## Empty in arcade, which keeps using the endless WAVE_TABLE.
var _battle_waves: Array[Dictionary] = []
var _difficulty: Dictionary = {}
var _battle_active: bool = false


func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)

	_gap_timer = Timer.new()
	_gap_timer.name = "WaveGapTimer"
	_gap_timer.one_shot = true
	_gap_timer.wait_time = Tuning.WAVE_GAP
	_gap_timer.timeout.connect(_start_next_wave)
	add_child(_gap_timer)


func start_run() -> void:
	stop_run()
	_running = true
	_start_wave(1)


## Campaign sector: play the given wave compositions (last one may include the
## boss), then stop and emit `battle_cleared` instead of rolling into a new one.
func start_battle(waves: Array[Dictionary], difficulty: Dictionary) -> void:
	stop_run()
	_battle_active = true
	_battle_waves = waves
	_difficulty = difficulty
	_running = true
	_start_wave(1)


func is_battle() -> bool:
	return _battle_active


## Total waves of the running battle, or 0 in arcade.
func wave_total() -> int:
	return _battle_waves.size()


func stop_run() -> void:
	_running = false
	wave = 0
	_queue.clear()
	_active_enemies = 0
	_battle_active = false
	_battle_waves.clear()
	_difficulty.clear()
	_spawn_timer.stop()
	_gap_timer.stop()


## Testing helper: drops a boss into the current wave immediately.
func spawn_boss_now() -> void:
	if not _running:
		return
	_spawn_enemy(BOSS_SCENE)


func is_boss_wave(wave_number: int) -> bool:
	return wave_number > 0 and wave_number % Tuning.BOSS_EVERY == 0


func spawn_interval_for(wave_number: int) -> float:
	var ramp: float = Tuning.INTERVAL_STEP * float(wave_number - 1)
	return maxf(Tuning.MIN_SPAWN_INTERVAL, Tuning.FIRST_WAVE_INTERVAL - ramp)


func wave_composition(wave_number: int) -> Dictionary:
	if is_boss_wave(wave_number):
		return {"boss": 1}
	var table_wave: int = mini(wave_number, Tuning.WAVE_TABLE.size())
	return Tuning.WAVE_TABLE[table_wave]


func _start_wave(wave_number: int) -> void:
	wave = wave_number
	var composition: Dictionary = _composition_for(wave_number)
	_queue = _build_queue(composition)
	wave_started.emit(wave, composition.has("boss"))
	_spawn_timer.wait_time = _interval_for(wave_number)
	_spawn_timer.start()


func _composition_for(wave_number: int) -> Dictionary:
	if _battle_active:
		if wave_number >= 1 and wave_number <= _battle_waves.size():
			return _battle_waves[wave_number - 1]
		return {}
	return wave_composition(wave_number)


## Arcade ramp, tightened by the sector's tier (below 1 = faster spawns).
func _interval_for(wave_number: int) -> float:
	var scale: float = float(_difficulty.get("interval_scale", 1.0))
	return maxf(Tuning.MIN_SPAWN_INTERVAL, spawn_interval_for(wave_number) * scale)


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
	_apply_difficulty(enemy)
	_active_enemies += 1
	# Connect before the enemy reaches the tree, so every exit is counted.
	enemy.tree_exited.connect(_on_enemy_exited)
	enemy_spawned.emit(enemy)


## Tier scaling has to land before the enemy enters the tree, because that is
## where EnemyBase copies max_hp into the live hp.
func _apply_difficulty(enemy: EnemyBase) -> void:
	var hp_scale: float = float(_difficulty.get("hp_scale", 1.0))
	if hp_scale > 1.0:
		enemy.max_hp = maxi(1, ceili(float(enemy.max_hp) * hp_scale))
	var bullet_scale: float = float(_difficulty.get("bullet_scale", 1.0))
	if enemy is Boss and bullet_scale < 1.0:
		(enemy as Boss).spread_interval = maxf(0.4, (enemy as Boss).spread_interval * bullet_scale)


func _on_enemy_exited() -> void:
	_active_enemies = maxi(_active_enemies - 1, 0)
	_check_wave_cleared()


func _check_wave_cleared() -> void:
	if not _running:
		return
	if not _queue.is_empty() or _active_enemies > 0:
		return
	if _battle_active:
		if wave >= _battle_waves.size():
			_running = false
			battle_cleared.emit()
			return
	if _gap_timer.time_left > 0.0:
		return
	_gap_timer.start()
