class_name BattleGame
extends Node2D
## Root of the landscape arena. It owns the score, the combo, the energy of the
## current battle and the containers, and connects the signal-emitting entities
## to each other. Nothing here is a menu: the campaign map and the front end
## arrive on top of this scene in the next stage.
##
## Collision layers (project-wide, see each scene's collision_layer/mask):
##   1 = player, 2 = player bullets, 3 = enemies, 4 = asteroids, 5 = enemy bullets
## Bit values: 1, 2, 4, 8, 16.
##   Ship         layer 1,  mask 28 -> hurtbox sees fighters, rocks and shots.
##   Bullet       layer 2,  mask 12 -> fighters and rocks.
##   Fighter      layer 4,  mask 0  -> only detected by bullets and the ship.
##   Asteroid     layer 8,  mask 0  -> only detected by bullets and the ship.
##   EnemyBullet  layer 16, mask 0  -> only detected by the ship.
##
## Tree state: GameState owns pausing. This root runs while paused so R can
## restart from the end card; the World node is pausable and freezes with the
## tree, and the HUD is always-on so its buttons work.

const BULLET_SCENE: PackedScene = preload("res://entities/bullet/bullet.tscn")
const ENEMY_BULLET_SCENE: PackedScene = preload("res://entities/enemies/enemy_bullet.tscn")
const EXPLOSION_SCENE: PackedScene = preload("res://entities/effects/explosion.tscn")
const ORB_SCENE: PackedScene = preload("res://entities/effects/energy_mote.tscn")
const SHOCKWAVE_SCRIPT: GDScript = preload("res://entities/effects/shockwave.gd")
const FLOAT_TEXT_SCRIPT: GDScript = preload("res://entities/effects/float_text.gd")

const HIT_SHAKE: float = 0.5
const KILL_SHAKE: float = 0.1
const DEATH_SHAKE: float = 0.9
const VICTORY_SHAKE: float = 0.3
const END_HINT_TOUCH: String = "RESTART FROM THE PAUSE BUTTON OR R"

@onready var ship: Ship = $World/Ship
@onready var bullets: Node2D = $World/Bullets
@onready var enemies: Node2D = $World/Enemies
@onready var enemy_bullets: Node2D = $World/EnemyBullets
@onready var asteroids: Node2D = $World/Asteroids
@onready var orbs: Node2D = $World/Orbs
@onready var effects: Node2D = $World/Effects
@onready var director: WaveDirector = $World/WaveDirector
@onready var hazards: HazardField = $World/HazardField
@onready var backdrop: TextureRect = $World/Backdrop
@onready var shake_camera: ShakeCamera = $World/ShakeCamera
@onready var hud: BattleHUD = $HUD

var battle: Battle
var score: int = 0
## Energy collected in this battle, also banked into SaveData as it arrives.
var energy: int = 0
var kills: int = 0
var victory: bool = false

var _current_key: StringName = Tuning.DEFAULT_BATTLE
var _running: bool = false
var _combo_chain: int = 0
var _combo_time_left: float = 0.0
var _float_texts: int = 0


func _ready() -> void:
	# The root keeps running while the tree is paused so R works on the end
	# card; World is explicitly pausable, so the arena freezes as usual.
	process_mode = Node.PROCESS_MODE_ALWAYS
	ship.shot_fired.connect(_on_ship_shot_fired)
	ship.hurt.connect(_on_ship_hurt)
	ship.hp_changed.connect(hud.set_hp)
	ship.shields_changed.connect(hud.set_shields)
	ship.died.connect(_on_ship_died)
	director.enemy_spawned.connect(_on_enemy_spawned)
	director.wave_started.connect(_on_wave_started)
	director.wave_cleared.connect(_on_wave_cleared)
	director.battle_won.connect(_on_battle_won)
	hazards.asteroid_spawned.connect(_add_rock)
	hud.resume_requested.connect(_resume)
	hud.restart_requested.connect(_restart)
	hud.pause_requested.connect(_pause)
	hud.aim_changed.connect(ship.set_aim_override)
	hud.set_aim_origin(ship)
	GameState.state_changed.connect(_on_state_changed)
	# A debug build boots straight into the one-wave harness, so the arena can
	# be tested without the campaign map.
	_start_battle(Tuning.DEBUG_BATTLE if OS.is_debug_build() else Tuning.DEFAULT_BATTLE)


func _process(delta: float) -> void:
	if not GameState.is_playing() or not _running:
		return
	if _combo_time_left <= 0.0:
		return
	_combo_time_left -= delta
	if _combo_time_left <= 0.0:
		_break_combo()


# --- Battle lifecycle -------------------------------------------------------

func _start_battle(key: StringName) -> void:
	_current_key = key
	battle = Battle.preset(key)
	_clear_playfield()
	score = 0
	energy = 0
	kills = 0
	_combo_chain = 0
	_combo_time_left = 0.0
	_float_texts = 0
	victory = false
	_running = true
	if battle.background != null:
		backdrop.texture = battle.background
	ship.position = Tuning.SHIP_SPAWN_POSITION
	ship.apply_run_stats(Upgrades.stats_for(SaveData.upgrade_levels))
	hud.reset(battle)
	hud.set_energy(energy)
	hud.set_score(score)
	hud.set_hp(ship.hp, ship.max_hp)
	hud.set_shields(ship.shields)
	director.start(battle, ship)
	hazards.start(battle.asteroid_density)
	GameState.change_state(GameState.State.PLAYING)


func _end_battle(won: bool) -> void:
	if not _running:
		return
	_running = false
	victory = won
	director.stop()
	hazards.stop()
	hud.set_combo(0, 1.0)
	_break_combo()
	if won:
		AudioManager.play_sfx("wave")
		_shake(VICTORY_SHAKE)
		hud.show_end(
			"VICTORY",
			"ALL WAVES CLEARED   SCORE %d   ENERGY +%d" % [score, energy],
			"R RESTARTS THE BATTLE"
		)
	else:
		AudioManager.play_sfx("game_over")
		_shake(DEATH_SHAKE)
		hud.show_end(
			"DEFEATED",
			"SCORE %d   WAVE %d/%d" % [score, maxi(director.wave, 1), battle.waves],
			END_HINT_TOUCH
		)
	GameState.change_state(GameState.State.GAME_OVER)


func _restart() -> void:
	if battle == null:
		_start_battle(Tuning.DEFAULT_BATTLE)
		return
	_start_battle(_current_key)


func _pause() -> void:
	if GameState.is_playing():
		GameState.change_state(GameState.State.PAUSED)


func _resume() -> void:
	if GameState.state == GameState.State.PAUSED:
		GameState.change_state(GameState.State.PLAYING)


func _on_state_changed(new_state: int) -> void:
	match new_state:
		GameState.State.PLAYING:
			GameState.back_handler = Callable()
			hud.show_playing()
		GameState.State.PAUSED:
			# Android Back resumes instead of leaving a screen with no menu on it.
			GameState.back_handler = _resume
			hud.show_paused()
		GameState.State.MENU:
			# No menu in this stage yet: a menu request starts a fresh battle.
			GameState.back_handler = Callable()
			_restart()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_R:
			if GameState.state != GameState.State.GAME_OVER:
				return
			_restart()
		KEY_F9:
			if not OS.is_debug_build():
				return
			_start_battle(Tuning.DEBUG_BATTLE)
		_:
			return
	get_viewport().set_input_as_handled()


# --- Ship signals -----------------------------------------------------------

func _on_ship_shot_fired(origin: Vector2, direction: Vector2) -> void:
	AudioManager.play_sfx("shoot")
	var bullet := BULLET_SCENE.instantiate() as Bullet
	bullet.position = origin
	bullet.direction = direction
	bullet.damage = ship.bullet_damage
	bullets.add_child(bullet)


func _on_ship_hurt(_amount: int) -> void:
	AudioManager.play_sfx("player_hit")
	_shake(HIT_SHAKE)
	_break_combo()


func _on_ship_died() -> void:
	_end_battle(false)


# --- Enemy signals ----------------------------------------------------------

func _on_enemy_spawned(enemy: EnemyBase) -> void:
	enemy.died.connect(_on_enemy_died.bind(enemy))
	enemy.damaged.connect(_on_enemy_damaged.bind(enemy))
	enemy.shot_requested.connect(_on_enemy_shot_requested)
	enemies.add_child(enemy)


func _on_enemy_damaged(at: Vector2, enemy: EnemyBase) -> void:
	_spawn_explosion(at, enemy.effect_color, 5, 0.6, 0.22)


func _on_enemy_died(points: int, enemy: EnemyBase) -> void:
	AudioManager.play_sfx("enemy_death")
	kills += 1
	_register_combo_kill()
	var gained: int = int(round(float(points) * _combo_multiplier()))
	score += gained
	hud.set_score(score)
	hud.set_enemies(kills, battle.enemy_total())
	_drop_energy(enemy.global_position, points)
	_spawn_explosion(enemy.global_position, enemy.effect_color, Tuning.EXPLOSION_PARTICLES, 1.0, Tuning.EXPLOSION_LIFE)
	_spawn_shockwave(enemy.global_position, enemy.effect_color)
	_spawn_float_text(enemy.global_position, "+%d COMBO!" % gained, Tuning.COMBO_FLOAT_COLOR)
	_shake(KILL_SHAKE)


func _on_enemy_shot_requested(origin: Vector2, direction: Vector2) -> void:
	var bullet := ENEMY_BULLET_SCENE.instantiate() as EnemyBullet
	bullet.position = origin
	bullet.direction = direction
	enemy_bullets.add_child(bullet)


# --- Waves ------------------------------------------------------------------

func _on_wave_started(index: int, total: int) -> void:
	AudioManager.play_sfx("wave")
	hud.set_wave(index, total)
	hud.show_banner("WAVE %d/%d" % [index, total])


func _on_wave_cleared(index: int) -> void:
	hud.show_banner("WAVE %d CLEARED" % index)


func _on_battle_won() -> void:
	_end_battle(true)


# --- Rocks ------------------------------------------------------------------

func _add_rock(rock: Asteroid) -> void:
	rock.shattered.connect(_on_rock_shattered)
	asteroids.add_child(rock)


func _on_rock_shattered(at: Vector2, was_large: bool) -> void:
	_spawn_explosion(at, Color(0.8, 0.82, 0.9), 8, 0.7, 0.3)
	if not was_large:
		return
	var debris: Array[Asteroid] = hazards.make_debris(
		at,
		randi_range(Tuning.ASTEROID_SPLIT_MIN, Tuning.ASTEROID_SPLIT_MAX)
	)
	for rock: Asteroid in debris:
		_add_rock(rock)


# --- Combo ------------------------------------------------------------------

## 1.0 with no chain, then one step every COMBO_SCORE_STEP kills. No cap.
func _combo_multiplier() -> float:
	return 1.0 + float(_combo_chain) / float(Tuning.COMBO_SCORE_STEP)


func _register_combo_kill() -> void:
	_combo_chain += 1
	_combo_time_left = Tuning.COMBO_WINDOW
	hud.set_combo(_combo_chain, _combo_multiplier())


func _break_combo() -> void:
	if _combo_chain == 0:
		return
	_combo_chain = 0
	_combo_time_left = 0.0
	hud.set_combo(0, 1.0)


# --- Energy -----------------------------------------------------------------

## Splits a kill's energy into a few orbs, so a heavy reads as a shower.
func _drop_energy(at: Vector2, points: int) -> void:
	var total: int = maxi(Tuning.MIN_ENERGY_PER_KILL, points / Tuning.SCORE_POINTS_PER_ENERGY)
	var orb_count: int = mini(total, Tuning.MAX_ORBS_PER_KILL)
	var each: int = total / orb_count
	var remainder: int = total % orb_count
	for index: int in orb_count:
		var orb := ORB_SCENE.instantiate() as EnergyMote
		orb.position = at + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		orb.setup(ship, each + (1 if index < remainder else 0))
		orb.collected.connect(_on_energy_collected)
		orbs.add_child(orb)


func _on_energy_collected(value: int) -> void:
	energy += value
	SaveData.add_energy(value)
	hud.set_energy(energy)
	AudioManager.play_sfx("pickup")


# --- Effects ----------------------------------------------------------------

func _shake(amount: float) -> void:
	shake_camera.add_trauma(amount)


func _spawn_explosion(at: Vector2, tint: Color, count: int, size_scale: float, life_time: float) -> void:
	if _live_explosions() >= Tuning.MAX_LIVE_EXPLOSIONS:
		return
	var explosion := EXPLOSION_SCENE.instantiate() as Explosion
	explosion.position = at
	explosion.tint = tint
	explosion.particle_count = count
	explosion.size_scale = size_scale
	explosion.life_time = life_time
	effects.add_child(explosion)


func _live_explosions() -> int:
	var count: int = 0
	for child: Node in effects.get_children():
		if child is Explosion:
			count += 1
	return count


func _spawn_shockwave(at: Vector2, tint: Color) -> void:
	var wave := SHOCKWAVE_SCRIPT.new() as Shockwave
	wave.position = at
	wave.tint = tint
	effects.add_child(wave)


func _spawn_float_text(at: Vector2, label: String, tint: Color) -> void:
	if _float_texts >= Tuning.MAX_LIVE_FLOAT_TEXTS:
		return
	var text := FLOAT_TEXT_SCRIPT.new() as FloatText
	text.position = at
	text.setup(label, tint)
	text.tree_exited.connect(_on_float_text_exited)
	_float_texts += 1
	effects.add_child(text)


func _on_float_text_exited() -> void:
	_float_texts = maxi(_float_texts - 1, 0)


# --- Housekeeping -----------------------------------------------------------

func _clear_playfield() -> void:
	for container: Node in [bullets, enemies, enemy_bullets, asteroids, orbs, effects]:
		for child: Node in container.get_children():
			# Disable first, so a queued-for-deletion node cannot fire its
			# signals into the new battle during the frame it is removed.
			child.process_mode = Node.PROCESS_MODE_DISABLED
			child.queue_free()
