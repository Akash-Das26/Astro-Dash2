class_name EnemySpawner
extends Node
## Owns the spawn timer and hands brand-new enemies to whoever listens on
## `enemy_spawned`. It deliberately does not touch the Enemies container,
## the Boundary or the score.

signal enemy_spawned(enemy: EnemyBase)

const ENEMY_SCENES: Array[PackedScene] = [
	preload("res://entities/enemies/enemy.tscn"),
	preload("res://entities/enemies/zigzag_enemy.tscn"),
	preload("res://entities/enemies/tank_enemy.tscn"),
]

@export var spawn_interval: float = 1.5

var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.name = "SpawnTimer"
	_timer.wait_time = spawn_interval
	_timer.timeout.connect(_spawn_enemy)
	add_child(_timer)


func start() -> void:
	_timer.start()


func stop() -> void:
	_timer.stop()


## Restart the interval from zero (used when a new run begins).
func restart() -> void:
	_timer.stop()
	_timer.start()


func _spawn_enemy() -> void:
	var scene: PackedScene = ENEMY_SCENES.pick_random()
	var enemy := scene.instantiate() as EnemyBase
	enemy_spawned.emit(enemy)
