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
const SHIELD_PICKUP_SCENE: PackedScene = preload("res://entities/pickups/shield_pickup.tscn")
const SHOCKWAVE_SCRIPT: GDScript = preload("res://entities/effects/shockwave.gd")
const FLOAT_TEXT_SCRIPT: GDScript = preload("res://entities/effects/float_text.gd")
const BOSS_SCENE: PackedScene = preload("res://entities/enemies/boss_station.tscn")
const GALAXY_SCENE: String = "res://ui/galaxy_map.tscn"
const MENU_SCENE: String = "res://ui/main_menu.tscn"

## One sound per weapon, so the five guns never sound the same.
const WEAPON_SOUNDS: Dictionary = {
	&"pulse": "shoot_pulse",
	&"cannon": "shoot_cannon",
	&"scatter": "shoot_scatter",
	&"rail": "shoot_rail",
	&"missile": "missile_launch",
}

const HIT_SHAKE: float = 0.5
const KILL_SHAKE: float = 0.1
const DEATH_SHAKE: float = 0.9
const VICTORY_SHAKE: float = 0.3

@onready var ship: Ship = $World/Ship
@onready var bullets: Node2D = $World/Bullets
@onready var enemies: Node2D = $World/Enemies
@onready var enemy_bullets: Node2D = $World/EnemyBullets
@onready var asteroids: Node2D = $World/Asteroids
@onready var pickups: Node2D = $World/Pickups
@onready var orbs: Node2D = $World/Orbs
@onready var effects: Node2D = $World/Effects
@onready var director: WaveDirector = $World/WaveDirector
@onready var hazards: HazardField = $World/HazardField
@onready var backdrop: TextureRect = $World/Backdrop
@onready var shake_camera: ShakeCamera = $World/ShakeCamera
@onready var hud: BattleHUD = $HUD
@onready var difficulty_picker: DifficultyPicker = $DifficultyPicker

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
var _hp_at_start: int = 0
var _running: bool = false
var _combo_chain: int = 0
var _combo_time_left: float = 0.0
var _float_texts: int = 0
## Difficulty multipliers for this fight. The harness (no campaign) is left at
## 1.0 so the debug battle stays predictable.
var _score_scale: float = 1.0
var _energy_scale: float = 1.0
var _shield_drop_scale: float = 1.0
var _difficulty_title: String = "ARCADE"
## Set from the defeat result: "keep", "reset" or "wipe".
var _defeat_action: StringName = Difficulty.KEEP


func _ready() -> void:
	# The root keeps running while the tree is paused so R works on the end
	# card; World is explicitly pausable, so the arena freezes as usual.
	process_mode = Node.PROCESS_MODE_ALWAYS
	ship.weapon_fired.connect(_on_ship_weapon_fired)
	ship.hurt.connect(_on_ship_hurt)
	ship.shield_spent.connect(_on_ship_shield_spent)
	ship.shield_broken.connect(_on_ship_shield_broken)
	ship.shield_raised.connect(_on_ship_shield_raised)
	ship.shield_timer_changed.connect(hud.set_shield_active)
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
	hud.end_continue_requested.connect(_on_end_continue)
	hud.end_retry_requested.connect(_on_retry_campaign)
	hud.end_quit_requested.connect(_go_to_menu)
	hud.menu_requested.connect(_go_to_menu)
	hud.set_aim_origin(ship)
	difficulty_picker.chosen.connect(_on_new_difficulty)
	UITheme.apply(get_node("HUD/Root") as Control)
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
	hud.set_weapon_cooldowns(
		ship.weapon_cooldown_ratio(0), ship.weapon_cooldown_ratio(1)
	)
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
	score = 0
	energy = 0
	kills = 0
	_combo_chain = 0
	_combo_time_left = 0.0
	_float_texts = 0
	victory = false
	_running = true
	_apply_difficulty()
	if battle.background != null:
		backdrop.texture = battle.background
	hud.set_shield_active(0.0)
	hud.set_difficulty(_difficulty_title)
	ship.position = Tuning.SHIP_SPAWN_POSITION
	ship.apply_run_stats(Upgrades.stats_for(SaveData.upgrade_levels))
	ship.damage_scale = Difficulty.enemy_damage_scale() if _campaign else 1.0
	if _campaign:
		# Hull and shield charges carry from the previous battle of the run.
		ship.carry_over(SaveData.campaign_hp, SaveData.campaign_shields)
	ship.apply_loadout(SaveData.weapon_primary, SaveData.weapon_secondary)
	_hp_at_start = ship.hp
	hud.reset(battle)
	hud.set_energy(energy)
	hud.set_score(score)
	hud.set_hp(ship.hp, ship.max_hp)
	hud.set_shields(ship.shields)
	hud.set_weapons(ship.weapon_id(0), ship.weapon_id(1))
	hud.set_weapon_cooldowns(0.0, 0.0)
	director.start(battle, ship)
	hazards.start(battle.asteroid_density)
	# A citadel gets its own theme; every other fight uses the normal rotation.
	if battle.has_boss():
		AudioManager.play_context(&"boss")
	else:
		AudioManager.release_context()
	GameState.change_state(GameState.State.PLAYING)


## Stacks the mode's multipliers on top of the band and trait values already
## baked into the Battle resource. Enemies per wave never drop below one.
func _apply_difficulty() -> void:
	_score_scale = 1.0
	_energy_scale = 1.0
	_shield_drop_scale = 1.0
	_difficulty_title = "ARCADE"
	if not _campaign:
		return
	var mode: StringName = Difficulty.normalise(SaveData.campaign_difficulty)
	_difficulty_title = Difficulty.title(mode)
	_score_scale = Difficulty.score_scale(mode)
	_energy_scale = Difficulty.energy_scale(mode)
	_shield_drop_scale = Difficulty.shield_drop_scale(mode)
	battle.enemies_per_wave = maxi(
		roundi(float(battle.enemies_per_wave) * Difficulty.enemies_scale(mode)), 1
	)
	battle.hp_scale *= Difficulty.enemy_hp_scale(mode)


func _end_battle(won: bool) -> void:
	if not _running:
		return
	_running = false
	victory = won
	AudioManager.release_context()
	director.stop()
	hazards.stop()
	hud.set_combo(0, 1.0)
	hud.hide_boss()
	_break_combo()
	# No hull point lost this battle is a Perfect Victory. Damage carried into
	# the battle does not count against it.
	var perfect: bool = won and ship.hp >= _hp_at_start
	var bonus_energy: int = 0
	if won and perfect:
		score += Tuning.PERFECT_BONUS_SCORE
		bonus_energy = Tuning.PERFECT_BONUS_ENERGY
		energy += bonus_energy
	# The flat conquest reward also follows the mode's energy multiplier.
	var flat_energy: int = 0
	if _campaign:
		flat_energy = roundi(float(battle.reward_energy) * _energy_scale)
	var result: Dictionary = {}
	if _campaign:
		if won:
			result = Campaign.award_victory(
				planet_id, score, ship.hp, ship.max_hp, ship.shields,
				flat_energy + bonus_energy
			)
		else:
			result = Campaign.record_defeat(planet_id, score, ship.max_hp, ship.shields)
	elif won and perfect:
		# The harness has no campaign to bank the bonus, so bank it here.
		SaveData.add_energy(bonus_energy)
	_defeat_action = StringName(String(result.get("action", String(Difficulty.KEEP))))
	hud.set_score(score)
	hud.set_energy(energy)
	if won:
		AudioManager.play_sfx("victory")
		_shake(VICTORY_SHAKE)
		hud.show_victory({
			"name": String(result.get("name", battle.title)) if _campaign else battle.title,
			"wave": maxi(director.wave, 1),
			"waves": battle.waves,
			"kills": kills,
			"total": battle.enemy_total(),
			"score": score,
			"energy": flat_energy + bonus_energy,
			"total_score": SaveData.campaign_score if _campaign else score,
			"perfect": perfect,
			"difficulty": _difficulty_title,
			"heal": int(result.get("heal", 0)),
			"heal_fraction": float(result.get("heal_fraction", 0.0)),
			"hp": int(result.get("hp", ship.hp)),
			"max_hp": int(result.get("max_hp", ship.max_hp)),
		})
	else:
		AudioManager.play_sfx("defeat")
		_shake(DEATH_SHAKE)
		hud.show_game_over({
			"score": SaveData.campaign_score if _campaign else score,
			"high": int(result.get("high", SaveData.high_score_for())),
			"new_high": bool(result.get("new_high", false)),
			"planets": int(result.get("planets", 1 if _campaign else 0)),
			"bodies": Campaign.galaxy().body_count() if _campaign else 0,
			"band": String(result.get("band", "")),
			"wave": maxi(director.wave, 1),
			"difficulty": String(result.get("difficulty", _difficulty_title)),
			"action": String(result.get("action", String(Difficulty.KEEP))),
			"wiped": result.get("wiped", []),
		})
	GameState.change_state(
		GameState.State.BATTLE_WON if won else GameState.State.GAME_OVER
	)


## Victory card's CONTINUE: back to the map, or a fresh harness battle.
func _on_end_continue() -> void:
	if _campaign:
		get_tree().change_scene_to_file(GALAXY_SCENE)
		return
	_restart()


## The defeat rule already ran when the battle ended. KEEP goes straight back
## to the same galaxy (hull restored). RESET and WIPE start a fresh campaign and
## ask for a mode first, the same way NEW GAME does.
func _on_retry_campaign() -> void:
	if _defeat_action == Difficulty.KEEP:
		get_tree().change_scene_to_file(GALAXY_SCENE)
		return
	difficulty_picker.open()


func _on_new_difficulty(difficulty: StringName) -> void:
	Campaign.begin_run(difficulty)
	get_tree().change_scene_to_file(GALAXY_SCENE)


## Android Back on the game-over card: the mode picker is the top layer, so it
## closes first; otherwise Back leaves for the menu as before.
func _handle_game_over_back() -> void:
	GameState.back_handler = _handle_game_over_back
	if difficulty_picker.picker_open():
		difficulty_picker.close()
		return
	_go_to_menu()


func _go_to_menu() -> void:
	# Only this battle is abandoned: the campaign, the hull from the last victory
	# and the energy already banked stay in the save, so CONTINUE is offered.
	AudioManager.release_context()
	GameState.back_handler = Callable()
	get_tree().change_scene_to_file(MENU_SCENE)


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
			# Android Back resumes instead of leaving a screen with no menu on
			# it; the HUD gets the call first so an open controls card closes.
			GameState.back_handler = hud.handle_pause_back
			hud.show_paused()
		GameState.State.GAME_OVER:
			GameState.back_handler = _handle_game_over_back
		GameState.State.BATTLE_WON:
			GameState.back_handler = _on_end_continue
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
		KEY_F3:
			if not OS.is_debug_build():
				return
			# Hull circle + exhaust anchor on every ship, for alignment checks.
			Tuning.thruster_debug = not Tuning.thruster_debug
			ship.queue_redraw()
			for child: Node in enemies.get_children():
				(child as CanvasItem).queue_redraw()
		_:
			return
	get_viewport().set_input_as_handled()


# --- Ship signals -----------------------------------------------------------

## One hardpoint fired. The weapon table decides how many projectiles, how they
## spread and everything the projectile does on contact.
func _on_ship_weapon_fired(slot: int, origin: Vector2, direction: Vector2) -> void:
	var id: StringName = ship.weapon_id(slot)
	var data: Dictionary = Weapons.entry(id)
	if data.is_empty():
		return
	AudioManager.play_sfx(String(WEAPON_SOUNDS.get(id, "shoot_pulse")))
	var stats: Dictionary = ship.run_stats
	var damage: int = Weapons.damage(id, stats)
	var count: int = maxi(1, int(data["count"]))
	var spread: float = float(data["spread"])
	var middle: float = (float(count) - 1.0) * 0.5
	for index: int in count:
		var bullet := BULLET_SCENE.instantiate() as Bullet
		bullet.position = origin
		bullet.direction = direction.rotated((float(index) - middle) * spread)
		bullet.speed = float(data["speed"])
		bullet.damage = damage
		bullet.life_time = float(data["life"])
		bullet.tier = int(stats.get("bullet_tier", 0))
		bullet.texture_override = data["texture"]
		bullet.tint = Weapons.color(id)
		bullet.scale_factor = float(data["scale"])
		bullet.pierce = int(data["pierce"])
		bullet.homing = float(data["homing"])
		bullet.knockback = float(data["knockback"])
		bullet.area_radius = float(data["area"])
		if bullet.homing > 0.0:
			bullet.homing_target = _nearest_enemy(origin)
		bullet.area_hit.connect(_on_bullet_area_hit)
		bullets.add_child(bullet)


## Homing shots steer to the closest live fighter; the station counts too.
func _nearest_enemy(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance: float = INF
	for child: Node in enemies.get_children():
		if child.is_queued_for_deletion() or not child is Node2D:
			continue
		var body := child as Node2D
		var distance: float = body.global_position.distance_squared_to(from)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best


## A burst weapon landed: splash every other fighter inside the radius for half
## the damage. The direct target already took the full shot.
func _on_bullet_area_hit(at: Vector2, radius: float, damage: int) -> void:
	_spawn_explosion(
		at, Tuning.WEAPON_BURST_COLOR, Tuning.WEAPON_BURST_PARTICLES, 1.2, 0.3
	)
	_spawn_shockwave(at, Tuning.WEAPON_BURST_COLOR)
	_shake(0.15)
	var splash: int = maxi(roundi(damage * 0.5), 1)
	for child: Node in enemies.get_children():
		if child.is_queued_for_deletion() or not child is Node2D:
			continue
		var body := child as Node2D
		if body.global_position.distance_to(at) > radius:
			continue
		child.call("take_damage", splash)


func _on_ship_hurt(_amount: int) -> void:
	AudioManager.play_sfx("player_hit")
	_shake(HIT_SHAKE)
	_break_combo()


func _on_ship_shield_spent() -> void:
	AudioManager.play_sfx("shield_hit")
	_shake(0.25)


func _on_ship_shield_broken() -> void:
	AudioManager.play_sfx("shield_down")


func _on_ship_shield_raised() -> void:
	AudioManager.play_sfx("shield_up")


func _on_ship_died() -> void:
	_end_battle(false)


# --- Enemy signals ----------------------------------------------------------

func _on_enemy_spawned(enemy: EnemyBase) -> void:
	AudioManager.play_sfx("warp_in")
	enemy.died.connect(_on_enemy_died.bind(enemy))
	enemy.damaged.connect(_on_enemy_damaged.bind(enemy))
	enemy.shot_requested.connect(_on_enemy_shot_requested)
	enemies.add_child(enemy)


func _on_enemy_damaged(at: Vector2, enemy: EnemyBase) -> void:
	_spawn_explosion(at, enemy.effect_color, 5, 0.6, 0.22)


func _on_enemy_died(points: int, enemy: EnemyBase) -> void:
	AudioManager.play_sfx("enemy_death")
	AudioManager.play_sfx("explosion_small")
	kills += 1
	_register_combo_kill()
	var gained: int = roundi(float(points) * _combo_multiplier() * _score_scale)
	score += gained
	hud.set_score(score)
	hud.set_enemies(kills, battle.enemy_total())
	_drop_energy(enemy.global_position, points)
	if randf() < clampf(Tuning.SHIELD_DROP_CHANCE * _shield_drop_scale, 0.0, 1.0):
		_drop_shield(enemy.global_position)
	_spawn_explosion(enemy.global_position, enemy.effect_color, Tuning.EXPLOSION_PARTICLES, 1.0, Tuning.EXPLOSION_LIFE)
	_spawn_shockwave(enemy.global_position, enemy.effect_color)
	_spawn_float_text(enemy.global_position, "+%d COMBO!" % gained, Tuning.COMBO_FLOAT_COLOR)
	_shake(KILL_SHAKE)


func _on_enemy_shot_requested(origin: Vector2, direction: Vector2) -> void:
	var bullet := ENEMY_BULLET_SCENE.instantiate() as EnemyBullet
	bullet.position = origin
	bullet.direction = direction
	bullet.high_contrast = SaveData.high_contrast_bullets
	bullet.hot_backdrop = battle != null and battle.hot_backdrop
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
	AudioManager.play_sfx("explosion_large")
	kills += 1
	score += roundi(float(points) * _score_scale)
	hud.set_score(score)
	hud.set_enemies(kills, battle.enemy_total() + 1)
	hud.hide_boss()
	# A citadel always leaves a shield charge behind.
	_drop_shield(at)
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
	# Debris is built from a bullet's area_entered callback. Adding an Area2D
	# while the physics server flushes queries is illegal, so the rock enters
	# the tree after the physics step, when its _ready may build its collider.
	if not _running:
		rock.queue_free()
		return
	# A big rock must never materialise on top of the ship: push it out along
	# the direction it came from until it is clear of the hull.
	if rock.large and ship != null:
		var offset: Vector2 = rock.position - ship.position
		if offset.length() < Tuning.ASTEROID_SHIP_CLEARANCE:
			var away: Vector2 = offset.normalized() if offset.length() > 0.5 \
				else Vector2.RIGHT.rotated(randf() * TAU)
			rock.position = ship.position + away * Tuning.ASTEROID_SHIP_CLEARANCE
	asteroids.call_deferred("add_child", rock)


func _on_rock_shattered(at: Vector2, was_large: bool) -> void:
	_spawn_explosion(at, Color(0.8, 0.82, 0.9), 8, 0.7, 0.3)
	AudioManager.play_sfx("explosion_small")
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
	if _combo_chain % 5 == 0:
		AudioManager.play_sfx("combo_up")
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
	# Orbs carry whole energy on purpose: a kill's energy floors to an integer.
	@warning_ignore("integer_division")
	# The mode's energy multiplier scales the drop, rounded to whole orbs.
	var base_energy: int = maxi(
		Tuning.MIN_ENERGY_PER_KILL, int(points / Tuning.SCORE_POINTS_PER_ENERGY)
	)
	var total: int = maxi(roundi(float(base_energy) * _energy_scale), 1)
	var orb_count: int = mini(total, Tuning.MAX_ORBS_PER_KILL)
	@warning_ignore("integer_division")
	var each: int = total / orb_count
	var remainder: int = total % orb_count
	for index: int in orb_count:
		var orb := ORB_SCENE.instantiate() as EnergyMote
		orb.position = at + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		orb.setup(ship, each + (1 if index < remainder else 0))
		orb.collected.connect(_on_energy_collected)
		orbs.add_child(orb)


## Shield drops follow the same deferred rule as debris: a fall may come out of
## a damage callback, so the Area2D enters the tree after the physics step.
func _drop_shield(at: Vector2) -> void:
	if not _running:
		return
	var pickup := SHIELD_PICKUP_SCENE.instantiate() as ShieldPickup
	pickup.position = at
	pickup.collected.connect(_on_shield_collected)
	pickups.call_deferred("add_child", pickup)


func _on_shield_collected() -> void:
	if not _running:
		return
	ship.add_shield(1)
	AudioManager.play_sfx("shield_pickup")
	_spawn_float_text(ship.global_position, "+1 SHIELD", Color(0.55, 0.95, 1.0))


func _on_energy_collected(value: int) -> void:
	energy += value
	SaveData.add_energy(value)
	hud.set_energy(energy)
	AudioManager.play_sfx("energy_pickup")


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
	for container: Node in [bullets, enemies, enemy_bullets, asteroids, pickups, orbs, effects]:
		for child: Node in container.get_children():
			# Disable first, so a queued-for-deletion node cannot fire its
			# signals into the new battle during the frame it is removed.
			child.process_mode = Node.PROCESS_MODE_DISABLED
			child.queue_free()
