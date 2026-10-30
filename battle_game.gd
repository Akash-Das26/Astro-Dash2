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
const BOSS_SCENE: PackedScene = preload("res://entities/enemies/boss_station.tscn")
const GALAXY_SCENE: String = "res://ui/galaxy_map.tscn"
## How long the end card stays up after a campaign battle before the map returns.
const RETURN_SECONDS: float = 2.2

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

## Body fought in this battle; empty means the debug harness.
var planet_id: StringName = &""
var _campaign: bool = false
var _current_key: StringName = Tuning.DEFAULT_BATTLE
var _boss: BossStation
var _returning: bool = false
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
	director.battle_won.connect(_on_waves_cleared)
	hazards.asteroid_spawned.connect(_add_rock)
	hud.resume_requested.connect(_resume)
	hud.restart_requested.connect(_restart)
	hud.pause_requested.connect(_pause)
	hud.aim_changed.connect(ship.set_aim_override)
	hud.set_aim_origin(ship)
	GameState.state_changed.connect(_on_state_changed)
	# The map picks the body and hands it over; with nothing pending (the scene
	# opened directly, or F9 from the map) a debug build boots the harness.
	planet_id = Campaign.take_pending_id()
	_campaign = planet_id != &""
	if _campaign:
		_start_fight(Campaign.battle_for(planet_id))
	else:
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
	_start_fight(Battle.preset(key))


## One fight: a galaxy body or a preset. Resets the run totals, the hull, the
## wave director and the rock field, and freezes the arena into PLAYING.
func _start_fight(fight: Battle) -> void:
	battle = fight
	_clear_playfield()
	_boss = null
	_returning = false
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
	if _campaign:
		# Hull and shield charges carry from the previous battle of the run.
		ship.carry_over(SaveData.campaign_hp, SaveData.campaign_shields)
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
	hud.hide_boss()
	_break_combo()
	var result: Dictionary = {}
	if _campaign:
		if won:
			result = Campaign.award_victory(
				planet_id, score, ship.hp, ship.shields, battle.reward_energy
			)
		else:
			result = Campaign.record_defeat(planet_id, score)
	if won:
		AudioManager.play_sfx("wave")
		_shake(VICTORY_SHAKE)
		var win_detail: String = "ALL WAVES CLEARED   SCORE %d   ENERGY +%d" % [score, energy]
		var win_hint: String = "R RESTARTS THE BATTLE"
		if _campaign:
			win_detail = "%s SECURED   SCORE %d   ENERGY +%d" % [
				battle.title, score, int(result.get("energy", 0)),
			]
			win_hint = "RETURNING TO THE GALAXY MAP"
		hud.show_end("VICTORY", win_detail, win_hint)
	else:
		AudioManager.play_sfx("game_over")
		_shake(DEATH_SHAKE)
		var loss_detail: String = "SCORE %d   WAVE %d/%d" % [
			score, maxi(director.wave, 1), battle.waves,
		]
		var loss_hint: String = END_HINT_TOUCH
		if _campaign:
			loss_detail = "CAMPAIGN OVER   PLANETS %d   SCORE %d" % [
				int(result.get("planets", 0)), score,
			]
			loss_hint = "RETURNING TO THE GALAXY MAP"
		hud.show_end("DEFEATED", loss_detail, loss_hint)
	GameState.change_state(GameState.State.GAME_OVER)
	if _campaign:
		_returning = true
		# A tree timer, not an await: it keeps ticking while the tree is paused.
		var timer := get_tree().create_timer(RETURN_SECONDS, true, false, true)
		timer.timeout.connect(_return_to_map)


## Back to the map with the result already banked by Campaign.
func _return_to_map() -> void:
	if not _returning:
		return
	_returning = false
	get_tree().change_scene_to_file(GALAXY_SCENE)


func _restart() -> void:
	if _campaign:
		_start_fight(Campaign.battle_for(planet_id))
		return
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
			# No menu in this stage yet: leaving a campaign battle goes back to
			# the map (progress already saved), the harness just restarts.
			GameState.back_handler = Callable()
			if _campaign:
				get_tree().change_scene_to_file(GALAXY_SCENE)
			else:
				_restart()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_R:
			if _campaign or GameState.state != GameState.State.GAME_OVER:
				return
			_restart()
		KEY_F9:
			if not OS.is_debug_build() or _campaign:
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
	bullet.tier = ship.bullet_tier
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


## The wave director cleared its last wave. A citadel sends its station in
## first; everything else is a victory.
func _on_waves_cleared() -> void:
	if battle != null and battle.has_boss() and _boss == null:
		_spawn_boss()
		return
	_end_battle(true)


func _spawn_boss() -> void:
	var boss := BOSS_SCENE.instantiate() as BossStation
	if boss == null:
		_end_battle(true)
		return
	boss.configure(
		battle.boss_color,
		battle.boss_hp,
		Vector2(Tuning.VIEW_SIZE.x * 0.5, Tuning.ARENA_TOP + 170.0),
		ship
	)
	boss.hp_changed.connect(hud.set_boss_hp)
	boss.damaged.connect(_on_boss_damaged)
	boss.died.connect(_on_boss_died)
	boss.shot_requested.connect(_on_enemy_shot_requested)
	enemies.add_child(boss)
	_boss = boss
	hud.show_boss(battle.boss_title, boss.hp, boss.max_hp)
	hud.show_banner("CITADEL %s" % battle.boss_title)
	AudioManager.play_sfx("wave")
	_shake(0.6)


func _on_boss_damaged(at: Vector2) -> void:
	_spawn_explosion(at, Color(1.0, 0.6, 0.4), 6, 0.7, 0.22)


func _on_boss_died(points: int) -> void:
	var at: Vector2 = _boss.global_position if _boss != null else Tuning.VIEW_SIZE * 0.5
	AudioManager.play_sfx("enemy_death")
	kills += 1
	score += points
	hud.set_score(score)
	hud.set_enemies(kills, battle.enemy_total() + 1)
	hud.hide_boss()
	_spawn_explosion(
		at, Color(1.0, 0.6, 0.4), Tuning.EXPLOSION_PARTICLES, 1.8, Tuning.EXPLOSION_LIFE
	)
	_spawn_shockwave(at, Color(1.0, 0.7, 0.4))
	_shake(DEATH_SHAKE)
	_boss = null
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
