class_name GameManager
extends Node2D
## Root of the playfield. Owns the score, lives and the Bullets/Enemies
## containers, and connects the signal-emitting entities to each other.
##
## Collision layers (project-wide, see each scene's collision_layer/mask):
##   1 = player, 2 = bullets, 3 = enemies, 4 = boundary
## Bit masks: 1 = 1, 2 = 2, 3 = 4, 4 = 8.
##   Bullet   layer 2, mask 4  -> only reacts to enemies.
##   Enemy    layer 4, mask 8  -> only reacts to the Boundary bar.
##   Boundary layer 8, mask 0  -> detects nothing, only got detected.
##   Player   layer 1 is reserved for its hurtbox (added with enemy contact damage).
##
## Boundary rule: the blue bar at y=464 is the defence line. Any enemy that
## crosses it costs the player one life; the run ends at zero lives.

const MAX_LIVES: int = 3
const LIVES_LOST_PER_BOUNDARY_CROSSING: int = 1

@onready var player: Player = $Player
@onready var bullets: Node = $Bullets
@onready var enemies: Node = $Enemies
@onready var spawner: EnemySpawner = $EnemySpawner

var score: int = 0
var lives: int = MAX_LIVES

var _bullet_scene: PackedScene = preload("res://entities/bullet/bullet.tscn")


func _ready() -> void:
	player.shot_fired.connect(_on_player_shot_fired)
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	GameState.state_changed.connect(_on_state_changed)
	GameState.change_state(GameState.State.PLAYING)


func _on_state_changed(new_state: int) -> void:
	# Pausing is handled by GameState; enemies simply stop spawning.
	if new_state == GameState.State.PLAYING:
		spawner.start()
	else:
		spawner.stop()


func _on_player_shot_fired(spawn_position: Vector2) -> void:
	var bullet := _bullet_scene.instantiate() as Bullet
	bullet.position = spawn_position
	bullets.add_child(bullet)


func _on_enemy_spawned(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_died)
	enemy.reached_boundary.connect(_on_enemy_reached_boundary)
	enemies.add_child(enemy)


func _on_enemy_died(points: int) -> void:
	score += points


func _on_enemy_reached_boundary() -> void:
	lives -= LIVES_LOST_PER_BOUNDARY_CROSSING
	lives = maxi(lives, 0)
	if lives == 0:
		_end_run()


func _end_run() -> void:
	GameState.change_state(GameState.State.GAME_OVER)
