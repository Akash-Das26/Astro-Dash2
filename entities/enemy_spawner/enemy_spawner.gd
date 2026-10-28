class_name EnemySpawner
extends Node
## Owns the spawn timer and hands brand-new enemies to whoever listens on
## `enemy_spawned`. It deliberately does not touch the Enemies container,
## the Boundary or the score.

signal enemy_spawned(enemy: Enemy)

@export var spawn_interval: float = 1.5
@export var enemy_scene: PackedScene = preload("res://entities/enemies/enemy.tscn")

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
	var enemy := enemy_scene.instantiate() as Enemy
	enemy_spawned.emit(enemy)
