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

const PICKUP_DROP_CHANCE: float = 0.1
const POWERUP_DURATION: float = 8.0
## Energy is dropped as motes that fly to the ship; see Tuning for the rates.
const DEBUG_SAMPLE_INTERVAL: float = 0.25
## Hard cap so a bomb chain cannot spawn hundreds of emitters at once.
const MAX_LIVE_EXPLOSIONS: int = 12
const BOSS_EXPLOSION_COUNT: int = 30
## Distance the debug pickup spawns above the player when a key is pressed.
const DEBUG_PICKUP_OFFSET: float = 70.0

@onready var player: Player = $Player
@onready var bullets: Node = $Bullets
@onready var enemies: Node = $Enemies
@onready var enemy_bullets: Node = $EnemyBullets
@onready var pickups: Node = $Pickups
@onready var effects: Node = $Effects
@onready var shake_camera: ShakeCamera = $ShakeCamera
@onready var spawner: EnemySpawner = $EnemySpawner
@onready var hud: HUD = $HUD

var score: int = 0
## Lives for this run: the base count plus whatever the hull upgrade adds.
var max_lives: int = Tuning.BASE_LIVES
var lives: int = Tuning.BASE_LIVES
## Energy collected during the current run, for the game-over summary.
var run_energy: int = 0
## Best combo reached this run, for the game-over summary.
var best_combo_multiplier: int = 1
var best_combo_chain: int = 0

var _combo_chain: int = 0
var _combo_time_left: float = 0.0

var _bullet_scene: PackedScene = preload("res://entities/bullet/bullet.tscn")
var _enemy_bullet_scene: PackedScene = preload("res://entities/enemies/enemy_bullet.tscn")
var _pickup_scene: PackedScene = preload("res://entities/pickups/pickup.tscn")
var _explosion_scene: PackedScene = preload("res://entities/effects/explosion.tscn")
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
	hud.upgrade_requested.connect(_on_upgrade_requested)
	hud.pause_requested.connect(_on_pause_requested)
	hud.restart_requested.connect(_start_run)
	hud.resume_requested.connect(_resume)
	hud.menu_requested.connect(_go_to_menu)
	GameState.state_changed.connect(_on_state_changed)
	hud.set_debug_visible(OS.is_debug_build())
	_reset_run()
	_on_state_changed(GameState.state)


func _process(delta: float) -> void:
	_tick_powerups(delta)
	_tick_combo(delta)
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
			AudioManager.play_sfx("game_over")
			var is_new_best: bool = SaveData.submit_score(score)
			# Energy is banked per mote; flush it now that the run is over.
			SaveData.save_data()
			hud.set_high_score(SaveData.high_score)
			hud.show_game_over(score, SaveData.high_score, is_new_best)


func _start_run() -> void:
	# This runs from the PLAY / RETRY button press, so the music starts on a
	# real user gesture. Browsers block audio until then, and starting it in
	# _ready() would silently leave the Web build silent.
	AudioManager.play_music("music")
	AudioManager.play_sfx("ui_click")
	_clear_playfield()
	_reset_run()
	spawner.start_run()
	GameState.change_state(GameState.State.PLAYING)


## On-screen pause button (touch). Keyboard and gamepad use GameState's own
## `pause` action handling.
func _on_pause_requested() -> void:
	if GameState.is_playing():
		GameState.change_state(GameState.State.PAUSED)


func _resume() -> void:
	AudioManager.play_sfx("ui_click")
	GameState.change_state(GameState.State.PLAYING)


## Shop purchase. The HUD owns the card, SaveData owns the money and the
## levels, and a new run is the only place the ship picks the result up.
func _on_upgrade_requested(kind: StringName) -> void:
	var bought: bool = SaveData.buy_upgrade(kind)
	AudioManager.play_sfx("pickup" if bought else "ui_click")
	hud.refresh_shop()


func _go_to_menu() -> void:
	AudioManager.play_sfx("ui_click")
	# A run can be abandoned from the pause menu; keep the energy it earned.
	SaveData.save_data()
	GameState.change_state(GameState.State.MENU)


func _end_run() -> void:
	GameState.change_state(GameState.State.GAME_OVER)


func _reset_run() -> void:
	var stats: Dictionary = Upgrades.stats_for(SaveData.upgrade_levels)
	score = 0
	max_lives = int(stats["lives"])
	lives = max_lives
	run_energy = 0
	best_combo_multiplier = 1
	best_combo_chain = 0
	_combo_chain = 0
	_combo_time_left = 0.0
	hud.hide_combo()
	_powerup_time_left.clear()
	player.apply_run_stats(stats)
	player.clear_powerups()
	_refresh_hud()
	_refresh_powerup_hud()
	hud.set_energy(SaveData.energy)


func _refresh_hud() -> void:
	hud.set_score(score)
	hud.set_lives(lives, max_lives)
	hud.set_high_score(SaveData.high_score)


func _clear_playfield() -> void:
	_clear_container(bullets)
	_clear_container(enemy_bullets)
	_clear_container(pickups)
	_clear_container(effects)
	_clear_container(enemies)


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		# Disable first so a queued-for-deletion node cannot fire its signals
		# into the new run during the frame it is removed.
		child.process_mode = Node.PROCESS_MODE_DISABLED
		child.queue_free()


# --- Player signals ---------------------------------------------------------

func _on_player_shot_fired(spawn_position: Vector2, direction: Vector2) -> void:
	AudioManager.play_sfx("shoot")
	var bullet := _bullet_scene.instantiate() as Bullet
	bullet.position = spawn_position
	bullet.direction = direction
	bullet.damage = player.bullet_damage
	bullets.add_child(bullet)


func _on_player_hurt() -> void:
	AudioManager.play_sfx("player_hit")
	_shake(0.55)
	# Losing a life breaks the chain; a shield eating the hit does not, because
	# the ship never emits `hurt` in that case.
	_break_combo()
	_lose_life()


func _on_shield_changed(_active: bool) -> void:
	_refresh_powerup_hud()


# --- Enemy signals ----------------------------------------------------------

func _on_enemy_spawned(enemy: EnemyBase) -> void:
	enemy.died.connect(_on_enemy_died.bind(enemy))
	enemy.reached_boundary.connect(_on_enemy_reached_boundary)
	enemy.damaged.connect(_on_enemy_damaged.bind(enemy))
	if enemy is Boss:
		(enemy as Boss).spread_shot.connect(_on_boss_spread_shot)
		AudioManager.play_sfx("boss_spawn")
	enemies.add_child(enemy)


func _on_wave_started(wave_number: int, is_boss: bool) -> void:
	AudioManager.play_sfx("wave")
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


func _on_enemy_damaged(at: Vector2, enemy: EnemyBase) -> void:
	_spawn_explosion(at, enemy.effect_color, 5, 0.7, 0.25)


func _on_enemy_died(points: int, enemy: EnemyBase) -> void:
	AudioManager.play_sfx("enemy_death")
	_register_combo_kill()
	score += points * combo_multiplier()
	_refresh_hud()
	_drop_energy(enemy.global_position, points)
	if enemy.is_boss:
		_spawn_explosion(enemy.global_position, enemy.effect_color, BOSS_EXPLOSION_COUNT, 2.0, 0.8)
		_shake(0.8)
		return
	_spawn_explosion(enemy.global_position, enemy.effect_color, 14, 1.0, 0.5)
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


# --- Combo ------------------------------------------------------------------

## 1.0 for no chain, then one step every COMBO_KILLS_PER_STEP kills.
func combo_multiplier() -> int:
	return mini(1 + _combo_chain / Tuning.COMBO_KILLS_PER_STEP, Tuning.COMBO_MAX_MULTIPLIER)


func _register_combo_kill() -> void:
	_combo_chain += 1
	_combo_time_left = Tuning.COMBO_WINDOW
	var multiplier: int = combo_multiplier()
	best_combo_chain = maxi(best_combo_chain, _combo_chain)
	best_combo_multiplier = maxi(best_combo_multiplier, multiplier)
	if multiplier > 1:
		hud.show_combo(multiplier, Tuning.COMBO_WINDOW)
	else:
		hud.hide_combo()


func _tick_combo(delta: float) -> void:
	if _combo_time_left <= 0.0:
		return
	_combo_time_left -= delta
	if _combo_time_left <= 0.0:
		_break_combo()


## Resets the chain and the label. Safe to call when there is no chain.
func _break_combo() -> void:
	if _combo_chain == 0:
		return
	_combo_chain = 0
	_combo_time_left = 0.0
	hud.hide_combo()


# --- Energy -----------------------------------------------------------------

## Splits a kill's energy into a few motes so a boss reads as a shower of them
## instead of one huge pickup.
func _drop_energy(at: Vector2, points: int) -> void:
	var total: int = maxi(Tuning.MIN_ENERGY_PER_KILL, points / Tuning.SCORE_POINTS_PER_ENERGY)
	var mote_count: int = mini(total, Tuning.MAX_MOTES_PER_KILL)
	var each: int = total / mote_count
	var remainder: int = total % mote_count
	for index: int in mote_count:
		var mote := EnergyMote.new()
		mote.position = at + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		mote.setup(player, each + (1 if index < remainder else 0))
		mote.collected.connect(_on_energy_collected)
		pickups.add_child(mote)


func _on_energy_collected(value: int) -> void:
	run_energy += value
	SaveData.add_energy(value)
	hud.set_energy(SaveData.energy)


# --- Effects ----------------------------------------------------------------

func _shake(amount: float) -> void:
	shake_camera.add_trauma(amount)


func _spawn_explosion(at: Vector2, tint: Color, count: int, size_mult: float, life_time: float) -> void:
	if effects.get_child_count() >= MAX_LIVE_EXPLOSIONS:
		return
	var explosion := _explosion_scene.instantiate() as Explosion
	explosion.position = at
	explosion.tint = tint
	explosion.particle_count = count
	explosion.size_scale = size_mult
	explosion.life_time = life_time
	effects.add_child(explosion)


# --- Pickups and power-ups --------------------------------------------------

func _spawn_pickup(kind: Pickup.Kind, at: Vector2) -> void:
	var pickup := _pickup_scene.instantiate() as Pickup
	pickup.kind = kind
	pickup.position = at
	pickup.collected.connect(_on_pickup_collected)
	pickups.add_child(pickup)


func _random_pickup_kind() -> Pickup.Kind:
	# Spelled out so the roll returns a real Pickup.Kind, and so the weights
	# stay easy to tweak later.
	match randi() % 4:
		0:
			return Pickup.Kind.RAPID_FIRE
		1:
			return Pickup.Kind.SPREAD_SHOT
		2:
			return Pickup.Kind.SHIELD
		_:
			return Pickup.Kind.BOMB


func _on_pickup_collected(kind: Pickup.Kind) -> void:
	AudioManager.play_sfx("pickup")
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
	AudioManager.play_sfx("bomb")
	_shake(0.35)
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
	var charges: int = player.shield_charges()
	if charges > 0:
		parts.append("SHIELD" if charges == 1 else "SHIELD x%d" % charges)
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
