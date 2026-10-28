class_name GameManager
extends Node2D
## Root of the playfield. Owns score, lives, power-up timers and the
## Bullets/Enemies/EnemyBullets/Pickups containers, and connects the
## signal-emitting entities to each other.
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
const PICKUP_DROP_CHANCE: float = 0.1
const POWERUP_DURATION: float = 8.0
const DEBUG_SAMPLE_INTERVAL: float = 0.25
## Distance the debug pickup spawns above the player when a key is pressed.
const DEBUG_PICKUP_OFFSET: float = 70.0

@onready var player: Player = $Player
@onready var bullets: Node = $Bullets
@onready var enemies: Node = $Enemies
@onready var enemy_bullets: Node = $EnemyBullets
@onready var pickups: Node = $Pickups
@onready var spawner: EnemySpawner = $EnemySpawner
@onready var hud: HUD = $HUD

var score: int = 0
var lives: int = MAX_LIVES

var _bullet_scene: PackedScene = preload("res://entities/bullet/bullet.tscn")
var _enemy_bullet_scene: PackedScene = preload("res://entities/enemies/enemy_bullet.tscn")
var _pickup_scene: PackedScene = preload("res://entities/pickups/pickup.tscn")
## Pickup.Kind -> seconds left, only for the timed effects.
var _powerup_time_left: Dictionary = {}
var _debug_sample_timer: float = 0.0


func _ready() -> void:
	player.shot_fired.connect(_on_player_shot_fired)
	player.hurt.connect(_on_player_hurt)
	player.shield_changed.connect(_on_shield_changed)
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	spawner.wave_started.connect(_on_wave_started)
	hud.play_requested.connect(_start_run)
	hud.restart_requested.connect(_start_run)
	hud.resume_requested.connect(_resume)
	hud.menu_requested.connect(_go_to_menu)
	GameState.state_changed.connect(_on_state_changed)
	hud.set_debug_visible(OS.is_debug_build())
	_reset_run()
	_on_state_changed(GameState.state)


func _process(delta: float) -> void:
	_tick_powerups(delta)
	_update_debug_counter(delta)


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
	_powerup_time_left.clear()
	player.clear_powerups()
	_refresh_hud()
	_refresh_powerup_hud()


func _refresh_hud() -> void:
	hud.set_score(score)
	hud.set_lives(lives, MAX_LIVES)
	hud.set_high_score(SaveData.high_score)


func _clear_playfield() -> void:
	_clear_container(bullets)
	_clear_container(enemy_bullets)
	_clear_container(pickups)
	_clear_container(enemies)


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		# Disable first so a queued-for-deletion node cannot fire its signals
		# into the new run during the frame it is removed.
		child.process_mode = Node.PROCESS_MODE_DISABLED
		child.queue_free()


# --- Player signals ---------------------------------------------------------

func _on_player_shot_fired(spawn_position: Vector2, direction: Vector2) -> void:
	var bullet := _bullet_scene.instantiate() as Bullet
	bullet.position = spawn_position
	bullet.direction = direction
	bullets.add_child(bullet)


func _on_player_hurt() -> void:
	_lose_life()


func _on_shield_changed(_active: bool) -> void:
	_refresh_powerup_hud()


# --- Enemy signals ----------------------------------------------------------

func _on_enemy_spawned(enemy: EnemyBase) -> void:
	enemy.died.connect(_on_enemy_died.bind(enemy))
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


func _on_enemy_died(points: int, enemy: EnemyBase) -> void:
	score += points
	_refresh_hud()
	if enemy.is_boss:
		return
	if randf() < PICKUP_DROP_CHANCE:
		_spawn_pickup(_random_pickup_kind(), enemy.global_position)


func _on_enemy_reached_boundary(enemy: EnemyBase) -> void:
	if not enemy.costs_life_on_boundary:
		return
	_lose_life()


func _lose_life() -> void:
	lives -= 1
	lives = maxi(lives, 0)
	_refresh_hud()
	if lives == 0:
		_end_run()


# --- Pickups and power-ups --------------------------------------------------

func _spawn_pickup(kind: Pickup.Kind, at: Vector2) -> void:
	var pickup := _pickup_scene.instantiate() as Pickup
	pickup.kind = kind
	pickup.position = at
	pickup.collected.connect(_on_pickup_collected)
	pickups.add_child(pickup)


func _random_pickup_kind() -> Pickup.Kind:
	var kinds: Array = Pickup.Kind.values()
	return int(kinds.pick_random())


func _on_pickup_collected(kind: Pickup.Kind) -> void:
	match kind:
		Pickup.Kind.RAPID_FIRE:
			# Same effect again refreshes the timer instead of stacking it.
			_powerup_time_left[kind] = POWERUP_DURATION
			player.set_rapid_fire(true)
		Pickup.Kind.SPREAD_SHOT:
			_powerup_time_left[kind] = POWERUP_DURATION
			player.set_spread_shot(true)
		Pickup.Kind.SHIELD:
			player.grant_shield()
		Pickup.Kind.BOMB:
			_detonate_bomb()
	_refresh_powerup_hud()


func _tick_powerups(delta: float) -> void:
	if _powerup_time_left.is_empty():
		return
	for kind: int in _powerup_time_left.keys():
		var remaining: float = float(_powerup_time_left[kind]) - delta
		if remaining <= 0.0:
			_powerup_time_left.erase(kind)
			_deactivate_powerup(kind)
		else:
			_powerup_time_left[kind] = remaining
	_refresh_powerup_hud()


func _deactivate_powerup(kind: int) -> void:
	match kind:
		Pickup.Kind.RAPID_FIRE:
			player.set_rapid_fire(false)
		Pickup.Kind.SPREAD_SHOT:
			player.set_spread_shot(false)


## Bomb: clears every non-boss enemy on screen, points included.
func _detonate_bomb() -> void:
	for child: Node in enemies.get_children():
		if child is EnemyBase and not (child as EnemyBase).is_boss:
			(child as EnemyBase).die()


func _refresh_powerup_hud() -> void:
	var parts: PackedStringArray = []
	var rapid: float = float(_powerup_time_left.get(Pickup.Kind.RAPID_FIRE, 0.0))
	if rapid > 0.0:
		parts.append("RAPID %ds" % ceili(rapid))
	var spread: float = float(_powerup_time_left.get(Pickup.Kind.SPREAD_SHOT, 0.0))
	if spread > 0.0:
		parts.append("SPREAD %ds" % ceili(spread))
	if player.has_shield():
		parts.append("SHIELD")
	hud.set_powerups("   ".join(parts))


# --- Debug tooling (debug builds only) --------------------------------------

func _update_debug_counter(delta: float) -> void:
	if not OS.is_debug_build():
		return
	_debug_sample_timer += delta
	if _debug_sample_timer < DEBUG_SAMPLE_INTERVAL:
		return
	_debug_sample_timer = 0.0
	hud.set_debug_text("live nodes  bullets %d  enemies %d  enemy bullets %d  pickups %d" % [
		bullets.get_child_count(),
		enemies.get_child_count(),
		enemy_bullets.get_child_count(),
		pickups.get_child_count(),
	])


## B = force boss, 1-4 = drop a rapid/spread/shield/bomb pickup.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_B:
			spawner.spawn_boss_now()
		KEY_1:
			_debug_spawn_pickup(Pickup.Kind.RAPID_FIRE)
		KEY_2:
			_debug_spawn_pickup(Pickup.Kind.SPREAD_SHOT)
		KEY_3:
			_debug_spawn_pickup(Pickup.Kind.SHIELD)
		KEY_4:
			_debug_spawn_pickup(Pickup.Kind.BOMB)
		_:
			return
	get_viewport().set_input_as_handled()


func _debug_spawn_pickup(kind: Pickup.Kind) -> void:
	_spawn_pickup(kind, player.position + Vector2(0.0, -DEBUG_PICKUP_OFFSET))
