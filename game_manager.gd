class_name GameManager
extends Node2D
## Root of the playfield. Owns score, lives and the Bullets/Enemies
## containers, and connects the signal-emitting entities to each other.
##
## Collision layers (project-wide, see each scene's collision_layer/mask):
##   1 = player, 2 = player bullets, 3 = enemies, 4 = boundary, 5 = enemy bullets
## Bit masks: 1, 2, 4, 8, 16.
##   Bullet      layer 2,  mask 4   -> only reacts to enemies.
##   Enemy       layer 4,  mask 8   -> only reacts to the Boundary bar.
##   Boundary    layer 8,  mask 0   -> detects nothing, only got detected.
##   Player      layer 1,  mask 20  -> hurtbox sees enemy ships and enemy bullets.
##   EnemyBullet layer 16, mask 0   -> detected by the player hurtbox.
##
## Boundary rule: the blue bar at y=464 is the defence line. Every enemy that
## crosses it costs one life; the run ends when the last life is gone. The
## boss is the exception: it leaves quietly so its wave can end.
##
## Waves come from EnemySpawner; every fifth wave is a single boss.

const MAX_LIVES: int = 3

@onready var player: Player = $Player
@onready var bullets: Node = $Bullets
@onready var enemies: Node = $Enemies
@onready var enemy_bullets: Node = $EnemyBullets
@onready var spawner: EnemySpawner = $EnemySpawner
@onready var hud: HUD = $HUD

var score: int = 0
var lives: int = MAX_LIVES

var _bullet_scene: PackedScene = preload("res://entities/bullet/bullet.tscn")
var _enemy_bullet_scene: PackedScene = preload("res://entities/enemies/enemy_bullet.tscn")


func _ready() -> void:
	player.shot_fired.connect(_on_player_shot_fired)
	player.hurt.connect(_on_player_hurt)
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	spawner.wave_started.connect(_on_wave_started)
	hud.play_requested.connect(_start_run)
	hud.restart_requested.connect(_start_run)
	hud.resume_requested.connect(_resume)
	hud.menu_requested.connect(_go_to_menu)
	GameState.state_changed.connect(_on_state_changed)
	_reset_run()
	_on_state_changed(GameState.state)


# --- State handling ---------------------------------------------------------

func _on_state_changed(new_state: int) -> void:
	# Tree pausing is owned by GameState; this only reacts to it.
	match new_state:
		GameState.State.MENU:
			spawner.stop_run()
			_clear_playfield()
			_reset_run()
			hud.show_menu(SaveData.high_score)
		GameState.State.PLAYING:
			hud.show_playing()
		GameState.State.PAUSED:
			hud.show_paused()
		GameState.State.GAME_OVER:
			spawner.stop_run()
			var is_new_best: bool = SaveData.submit_score(score)
			hud.set_high_score(SaveData.high_score)
			hud.show_game_over(score, SaveData.high_score, is_new_best)


func _start_run() -> void:
	_clear_playfield()
	_reset_run()
	spawner.start_run()
	GameState.change_state(GameState.State.PLAYING)


func _resume() -> void:
	GameState.change_state(GameState.State.PLAYING)


func _go_to_menu() -> void:
	GameState.change_state(GameState.State.MENU)


func _end_run() -> void:
	GameState.change_state(GameState.State.GAME_OVER)


func _reset_run() -> void:
	score = 0
	lives = MAX_LIVES
	_refresh_hud()


func _refresh_hud() -> void:
	hud.set_score(score)
	hud.set_lives(lives, MAX_LIVES)
	hud.set_high_score(SaveData.high_score)


func _clear_playfield() -> void:
	_clear_container(bullets)
	_clear_container(enemy_bullets)
	_clear_container(enemies)


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		# Disable first so a queued-for-deletion node cannot fire its signals
		# into the new run during the frame it is removed.
		child.process_mode = Node.PROCESS_MODE_DISABLED
		child.queue_free()


# --- Entity signals ---------------------------------------------------------

func _on_player_shot_fired(spawn_position: Vector2) -> void:
	var bullet := _bullet_scene.instantiate() as Bullet
	bullet.position = spawn_position
	bullets.add_child(bullet)


func _on_enemy_spawned(enemy: EnemyBase) -> void:
	enemy.died.connect(_on_enemy_died)
	enemy.reached_boundary.connect(_on_enemy_reached_boundary)
	if enemy is Boss:
		(enemy as Boss).spread_shot.connect(_on_boss_spread_shot)
	enemies.add_child(enemy)


func _on_wave_started(wave_number: int, is_boss: bool) -> void:
	if is_boss:
		hud.show_wave_banner("BOSS WAVE")
	else:
		hud.show_wave_banner("WAVE %d" % wave_number)


func _on_boss_spread_shot(origin: Vector2, directions: PackedVector2Array) -> void:
	for direction: Vector2 in directions:
		var bullet := _enemy_bullet_scene.instantiate() as EnemyBullet
		bullet.position = origin
		bullet.direction = direction
		enemy_bullets.add_child(bullet)


func _on_enemy_died(points: int) -> void:
	score += points
	_refresh_hud()


func _on_enemy_reached_boundary(enemy: EnemyBase) -> void:
	if not enemy.costs_life_on_boundary:
		return
	_lose_life()


func _on_player_hurt() -> void:
	_lose_life()


func _lose_life() -> void:
	lives -= 1
	lives = maxi(lives, 0)
	_refresh_hud()
	if lives == 0:
		_end_run()
