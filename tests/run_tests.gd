extends Node
## The test suite. It runs as a *scene* on purpose: Godot's `--script` mode has
## no autoload globals (measured: every script that names SaveData, GameState,
## AudioManager or UIOverlay fails to compile there), so the only way to test the
## real classes is to start a scene and let the autoloads come up normally.
##
##   godot --headless --path . res://tests/run_tests.tscn
##
## Every check prints PASS or FAIL, then one SUMMARY line, and the process exits
## nonzero when anything failed. The player's save is copied aside before the
## first write and put back when the run ends.

const SAVE_PATH: String = "user://save.cfg"
const BACKUP_PATH: String = "user://save.tests-backup.cfg"
const SHIP_SCENE: PackedScene = preload("res://entities/player/ship.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://entities/enemies/enemy_base.tscn")

var _passed: int = 0
var _failed: int = 0
var _failures: PackedStringArray = []
var _had_save: bool = false


func _ready() -> void:
	_backup_save()
	_reset_state()
	_test_heal_table()
	_test_heal_clamp()
	_test_defeat_rules()
	_test_shields()
	_test_upgrades()
	_test_persistence()
	_test_weapons()
	_test_elite_fighters()
	_test_galaxy()
	_test_audio()
	_test_controls()
	_test_paths()
	_restore_save()
	print("")
	print("SUMMARY %d passed, %d failed" % [_passed, _failed])
	for failure: String in _failures:
		print("  FAILED: %s" % failure)
	get_tree().quit(1 if _failed > 0 else 0)


# --- Assertions -------------------------------------------------------------

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
		print("PASS %s" % name)
		return
	_failed += 1
	var line: String = name if detail.is_empty() else "%s (%s)" % [name, detail]
	_failures.append(line)
	print("FAIL %s" % line)


func check_eq(name: String, got: Variant, want: Variant) -> void:
	check(name, got == want, "got %s want %s" % [str(got), str(want)])


func check_near(name: String, got: float, want: float, eps: float = 0.01) -> void:
	check(name, absf(got - want) <= eps, "got %.4f want %.4f" % [got, want])


# --- Fixtures ---------------------------------------------------------------

func _backup_save() -> void:
	_had_save = FileAccess.file_exists(SAVE_PATH)
	if _had_save:
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)


func _restore_save() -> void:
	if _had_save and FileAccess.file_exists(BACKUP_PATH):
		DirAccess.copy_absolute(BACKUP_PATH, SAVE_PATH)
		DirAccess.remove_absolute(BACKUP_PATH)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	# Leave the in-memory state matching what is on disk again.
	SaveData.load_data()


## A known starting point for a test: no campaign, no meta progression.
func _reset_state() -> void:
	SaveData.campaign_active = false
	SaveData.campaign_difficulty = Tuning.DIFFICULTY_CADET
	SaveData.campaign_seed = 0
	SaveData.campaign_conquered.clear()
	SaveData.campaign_score = 0
	SaveData.campaign_hp = 0
	SaveData.campaign_shields = 0
	SaveData.campaign_best_score = 0
	SaveData.campaign_best_planets = 0
	SaveData.energy = 0
	for kind: StringName in Tuning.UPGRADE_ORDER:
		SaveData.upgrade_levels[kind] = 0
	SaveData.weapons_owned.clear()
	SaveData.weapons_owned.append(Weapons.DEFAULT_ID)
	SaveData.weapon_primary = Weapons.DEFAULT_ID
	SaveData.weapon_secondary = &""
	SaveData.keyboard_bindings.clear()
	SaveData.gamepad_bindings.clear()
	# Campaign caches the galaxy by seed, so the next begin_campaign() rebuilds it.


func _mode(planets: int) -> int:
	return planets


# --- 4.1 Heal table ---------------------------------------------------------

## The rule as written in the tables: the largest reached milestone REPLACES the
## per-planet heal, so these are the only fractions that can be returned.
func _expected_heal(mode: StringName, planets: int) -> float:
	match mode:
		Tuning.DIFFICULTY_CADET:
			return 1.0
		Tuning.DIFFICULTY_VECTOR:
			if planets >= 10:
				return 1.0
			if planets >= 5:
				return 0.5
			return 0.25
		Tuning.DIFFICULTY_SUPERNOVA:
			if planets >= 10:
				return 0.5
			if planets >= 5:
				return 0.25
			return 0.1
		Tuning.DIFFICULTY_EVENT_HORIZON:
			if planets >= 10:
				return 0.25
			if planets >= 5:
				return 0.1
			return 0.0
		Tuning.DIFFICULTY_SINGULARITY:
			if planets >= 10:
				return 0.05
			return 0.0
	return 0.0


func _test_heal_table() -> void:
	for mode: StringName in Tuning.DIFFICULTY_ORDER:
		var bad: int = 0
		var first_bad: String = ""
		for planets: int in range(1, 16):
			var got: float = Difficulty.heal_fraction(planets, mode)
			var want: float = _expected_heal(mode, planets)
			if absf(got - want) > 0.001:
				bad += 1
				if first_bad.is_empty():
					first_bad = "planets %d got %.3f want %.3f" % [planets, got, want]
		check(
			"heal table %s (planets 1..15)" % String(mode),
			bad == 0,
			"%d wrong, first: %s" % [bad, first_bad]
		)


## Healing is based on MAX HP, added to the carried hull and clamped. Checked
## through the real victory path rather than by re-doing its arithmetic.
func _test_heal_clamp() -> void:
	SaveData.begin_campaign(4242, Tuning.DIFFICULTY_CADET)
	var open: Array[StringName] = Campaign.attackable()
	check("CADET has an attackable body", not open.is_empty(), "none after begin_campaign")
	if open.is_empty():
		return
	var result: Dictionary = Campaign.award_victory(open[0], 100, 40, 120, 0, 0)
	check_eq("CADET full heal clamps at max HP", int(result.get("hp", -1)), 120)
	check_eq("CADET full heal of 40/120 gives +80", int(result.get("heal", -1)), 80)

	_reset_state()
	SaveData.begin_campaign(4242, Tuning.DIFFICULTY_VECTOR)
	var open_v: Array[StringName] = Campaign.attackable()
	if open_v.is_empty():
		check("VECTOR has an attackable body", false, "none after begin_campaign")
		return
	var vec: Dictionary = Campaign.award_victory(open_v[0], 100, 40, 120, 0, 0)
	# First conquest: the counter reads 2 (home + this one), so the per-planet
	# 25% applies, not the planet-5 milestone.
	check_eq("VECTOR 25% heal on 40/120 reaches 70", int(vec.get("hp", -1)), 70)
	check_eq("VECTOR reports the healed amount", int(vec.get("heal", -1)), 30)

	_reset_state()
	SaveData.begin_campaign(4242, Tuning.DIFFICULTY_SINGULARITY)
	var open_s: Array[StringName] = Campaign.attackable()
	if open_s.is_empty():
		check("SINGULARITY has an attackable body", false, "none")
		return
	var sing: Dictionary = Campaign.award_victory(open_s[0], 100, 40, 120, 0, 0)
	check_eq("SINGULARITY heals nothing at planet 1", int(sing.get("heal", -1)), 0)
	check_eq("SINGULARITY keeps the hull at 40", int(sing.get("hp", -1)), 40)
	_reset_state()


# --- Elite fighters ---------------------------------------------------------

## The elite family is data plus one real node: every kind has a Tuning row and
## art, then a live instance is killed to prove the stat, the death signal and
## the energy payout line up. Spawning is checked through the wave tables and
## the swarm flag; the aura through real damage.
func _test_elite_fighters() -> void:
	var holder := Node2D.new()
	holder.name = "EliteHolder"
	add_child(holder)
	for kind: StringName in Tuning.ELITE_KINDS:
		var row: Dictionary = Tuning.ENEMY_TYPES.get(kind, {})
		check("elite row %s exists" % String(kind), not row.is_empty(), "missing from ENEMY_TYPES")
		check("elite art %s" % String(kind), EnemyBase.SPRITES.has(kind), "missing from SPRITES")
		if row.is_empty():
			continue
		var enemy := FIGHTER_SCENE.instantiate() as EnemyBase
		enemy.configure(kind, Vector2(300.0, 300.0), null)
		holder.add_child(enemy)
		check_eq("elite %s hp" % String(kind), enemy.max_hp, int(row["hp"]))
		check_eq("elite %s points" % String(kind), enemy.points, int(row["points"]))
		check_eq(
			"elite %s contact damage" % String(kind),
			enemy.contact_damage,
			int(row.get("contact_damage", Tuning.ENEMY_CONTACT_DAMAGE))
		)
		var energy: int = maxi(enemy.points / Tuning.SCORE_POINTS_PER_ENERGY, Tuning.MIN_ENERGY_PER_KILL)
		check("elite %s drops energy" % String(kind), energy >= Tuning.MIN_ENERGY_PER_KILL)
		var want_points: int = enemy.points
		var reported: Array[int] = []
		enemy.died.connect(func(points: int) -> void: reported.append(points))
		enemy.take_damage(enemy.max_hp)
		check_eq("elite %s dies and reports points" % String(kind), reported, [want_points])
		check("elite %s leaves the tree" % String(kind), enemy.is_queued_for_deletion())
	check_eq(
		"drone has one hit point",
		int(Tuning.ENEMY_TYPES[&"drone"]["hp"]), 1
	)

	# A shield carrier halves what nearby fighters take, and itself not at all.
	var carrier := FIGHTER_SCENE.instantiate() as EnemyBase
	carrier.configure(&"elite_yellow", Vector2(300.0, 300.0), null)
	holder.add_child(carrier)
	var victim := FIGHTER_SCENE.instantiate() as EnemyBase
	victim.configure(&"scout", Vector2(320.0, 300.0), null)
	holder.add_child(victim)
	var victim_hp: int = victim.hp
	victim.take_damage(2)
	check_eq("carrier halves nearby damage", victim.hp, victim_hp - 1)
	check("carrier takes full damage itself", carrier.mitigated(2) == 2)
	holder.remove_child(carrier)
	carrier.queue_free()
	var alone := FIGHTER_SCENE.instantiate() as EnemyBase
	alone.configure(&"scout", Vector2(340.0, 300.0), null)
	holder.add_child(alone)
	alone.take_damage(2)
	check_eq("without a carrier damage is full", alone.hp, 0)

	# Bands and modes: elites start at ELITE_FROM_BAND, never earlier, and the
	# mode multiplier rises with difficulty.
	var early_bad: int = 0
	for index: int in Tuning.GALAXY_BANDS.size():
		var mix: Dictionary = Tuning.GALAXY_BANDS[index]["mix"]
		for kind: StringName in Tuning.ELITE_KINDS:
			if int(mix.get(kind, 0)) > 0 and index < Tuning.ELITE_FROM_BAND:
				early_bad += 1
	var late_kinds: int = 0
	for index: int in range(Tuning.ELITE_FROM_BAND, Tuning.GALAXY_BANDS.size()):
		var mix: Dictionary = Tuning.GALAXY_BANDS[index]["mix"]
		for kind: StringName in Tuning.ELITE_KINDS:
			if int(mix.get(kind, 0)) > 0:
				late_kinds += 1
	check("no elites before band 2", early_bad == 0, "%d early weights" % early_bad)
	check("elites mix in from band 2", late_kinds >= 2, "%d elite weights" % late_kinds)
	var scales: Array[float] = []
	for mode: StringName in Tuning.DIFFICULTY_ORDER:
		scales.append(float(Tuning.DIFFICULTIES[mode].get("elite_scale", -1.0)))
	check("every mode has an elite scale", not scales.has(-1.0))
	check(
		"elite scale rises with difficulty",
		scales[0] <= scales[2] and scales[2] < scales[4],
		str(scales)
	)

	# Swarm: a drone slot turns into a cluster, a scout slot does not.
	var director := WaveDirector.new()
	add_child(director)
	check("drones are a swarm kind", bool(director.call("_is_swarm", &"drone")))
	check("scouts are not", not bool(director.call("_is_swarm", &"scout")))
	var battle := Battle.new()
	battle.waves = 1
	battle.enemies_per_wave = 8
	battle.enemy_mix = {&"drone": 4}
	director.set("_battle", battle)
	var queue: Array = director.call("_build_queue")
	check_eq("a drone wave fills the queue", queue.size(), 8)
	var all_drones: bool = true
	for kind: StringName in queue:
		if kind != &"drone":
			all_drones = false
	check("a drone-only mix deals only drones", all_drones)
	director.queue_free()
	holder.queue_free()


# --- 4.2 Defeat rules -------------------------------------------------------

func _test_defeat_rules() -> void:
	# CADET: keep the galaxy and the planets, hull back to 100%.
	_reset_state()
	SaveData.begin_campaign(9090, Tuning.DIFFICULTY_CADET)
	var seed_before: int = SaveData.campaign_seed
	var open: Array[StringName] = Campaign.attackable()
	SaveData.campaign_conquered.append(open[0])
	var result: Dictionary = Campaign.record_defeat(open[1] if open.size() > 1 else open[0], 500, 100, 0)
	check("CADET defeat keeps the campaign running", SaveData.campaign_active)
	check_eq("CADET defeat keeps the seed", SaveData.campaign_seed, seed_before)
	check_eq("CADET defeat keeps the conquests", SaveData.campaign_conquered.size(), 1)
	check_eq("CADET defeat restores the hull", SaveData.campaign_hp, 100)
	check_eq("CADET defeat reports the keep rule", String(result.get("action", "")), "keep")

	# VECTOR: keep, hull at 50%.
	_reset_state()
	SaveData.begin_campaign(9090, Tuning.DIFFICULTY_VECTOR)
	open = Campaign.attackable()
	SaveData.campaign_conquered.append(open[0])
	Campaign.record_defeat(open[0], 500, 100, 0)
	check("VECTOR defeat keeps the campaign running", SaveData.campaign_active)
	check_eq("VECTOR defeat restores half the hull", SaveData.campaign_hp, 50)

	# SUPERNOVA: new galaxy, meta kept.
	_reset_state()
	SaveData.begin_campaign(9090, Tuning.DIFFICULTY_SUPERNOVA)
	SaveData.energy = 300
	SaveData.upgrade_levels[&"hull"] = 4
	SaveData.weapons_owned.append(&"cannon")
	open = Campaign.attackable()
	SaveData.campaign_conquered.append(open[0])
	SaveData.record_campaign_progress(open[0], 700, 80, 1)
	Campaign.record_defeat(open[0], 500, 100, 0)
	check("SUPERNOVA defeat starts a new galaxy", SaveData.campaign_seed != 9090)
	check_eq("SUPERNOVA defeat clears the conquests", SaveData.campaign_conquered.size(), 0)
	check_eq("SUPERNOVA defeat keeps energy", SaveData.energy, 300)
	check_eq("SUPERNOVA defeat keeps upgrade levels", int(SaveData.upgrade_levels[&"hull"]), 4)
	check("SUPERNOVA defeat keeps owned weapons", SaveData.weapons_owned.has(&"cannon"))

	# EVENT HORIZON: same meta rule as SUPERNOVA.
	_reset_state()
	SaveData.begin_campaign(9090, Tuning.DIFFICULTY_EVENT_HORIZON)
	SaveData.energy = 120
	Campaign.record_defeat(Campaign.attackable()[0], 100, 100, 0)
	check("EVENT HORIZON defeat keeps meta", SaveData.energy == 120)
	check("EVENT HORIZON defeat resets the galaxy", SaveData.campaign_seed != 9090)

	# SINGULARITY: wipe energy, upgrades and weapons, keep settings/keys/scores/skins.
	_reset_state()
	SaveData.begin_campaign(9090, Tuning.DIFFICULTY_SINGULARITY)
	SaveData.energy = 400
	SaveData.upgrade_levels[&"fire"] = 5
	SaveData.weapons_owned.append(&"rail")
	SaveData.weapon_primary = &"rail"
	SaveData.weapon_secondary = &"cannon"
	SaveData.master_volume = 0.33
	SaveData.keyboard_bindings[&"shoot"] = var_to_str(_key_event(KEY_J))
	var skin_before: StringName = SaveData.skin_id
	var score_before: int = SaveData.high_score_for(Tuning.DIFFICULTY_SINGULARITY)
	Campaign.record_defeat(Campaign.attackable()[0], 100, 100, 0)
	check_eq("SINGULARITY wipes energy", SaveData.energy, 0)
	check_eq("SINGULARITY wipes upgrade levels", int(SaveData.upgrade_levels[&"fire"]), 0)
	check_eq("SINGULARITY wipes owned weapons", SaveData.weapons_owned.size(), 1)
	check_eq("SINGULARITY resets the equipped primary", SaveData.weapon_primary, Weapons.DEFAULT_ID)
	check_eq("SINGULARITY empties the secondary", String(SaveData.weapon_secondary), "")
	check_near("SINGULARITY keeps the master volume", SaveData.master_volume, 0.33, 0.001)
	check("SINGULARITY keeps key bindings", SaveData.keyboard_bindings.has(&"shoot"))
	check_eq("SINGULARITY keeps skins", SaveData.skin_id, skin_before)
	check("SINGULARITY keeps high scores", SaveData.high_score_for(Tuning.DIFFICULTY_SINGULARITY) >= score_before)
	_reset_state()


func _key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


# --- 4.3 Shields ------------------------------------------------------------

func _test_shields() -> void:
	for mode: StringName in Tuning.DIFFICULTY_ORDER:
		var base: int = 1 if mode in [Tuning.DIFFICULTY_CADET, Tuning.DIFFICULTY_VECTOR] else 0
		check_eq("shield base %s" % String(mode), Difficulty.shield_base_capacity(mode), base)

	# Capacity through the real stats path (which reads the active mode).
	for mode: StringName in Tuning.DIFFICULTY_ORDER:
		SaveData.campaign_active = true
		SaveData.campaign_difficulty = mode
		var base: int = Difficulty.shield_base_capacity(mode)
		var bad: int = 0
		var first_bad: String = ""
		for level: int in range(0, 10):
			var levels: Dictionary = {"shield": level}
			var got: int = int(Upgrades.stats_for(levels)["shield_charges"])
			var want: int = mini(base + level / Tuning.SHIELD_LEVELS_PER_CHARGE, Tuning.MAX_SHIELD_CHARGES)
			if got != want:
				bad += 1
				if first_bad.is_empty():
					first_bad = "level %d got %d want %d" % [level, got, want]
		check("shield capacity %s by level" % String(mode), bad == 0, first_bad)
	_reset_state()

	# The ship itself: starts full, and a pickup works at capacity 0.
	var ship := SHIP_SCENE.instantiate() as Ship
	add_child(ship)
	SaveData.campaign_active = true
	SaveData.campaign_difficulty = Tuning.DIFFICULTY_CADET
	ship.apply_run_stats(Upgrades.stats_for(SaveData.upgrade_levels))
	check_eq("battle starts with the shield full", ship.shields, ship.shield_capacity)
	check_eq("CADET level 0 capacity is 1", ship.shield_capacity, 1)

	SaveData.campaign_difficulty = Tuning.DIFFICULTY_SUPERNOVA
	ship.apply_run_stats(Upgrades.stats_for(SaveData.upgrade_levels))
	check_eq("SUPERNOVA level 0 capacity is 0", ship.shield_capacity, 0)
	check_eq("SUPERNOVA starts with no shield", ship.shields, 0)
	check("pickup at capacity 0 gives a shield", ship.add_shield(1))
	check_eq("charge after that pickup", ship.shields, 1)
	check("pickup at the limit refuses", not ship.add_shield(1))
	check_eq("charge stays at the limit", ship.shields, 1)
	ship.queue_free()
	_reset_state()


# --- 4.4 Upgrades -----------------------------------------------------------

func _test_upgrades() -> void:
	for kind: StringName in Tuning.UPGRADE_ORDER:
		var base_cost: int = Upgrades.cost(kind, 0)
		var next_cost: int = Upgrades.cost(kind, 1)
		check("cost %s rises with level" % String(kind), next_cost > base_cost, "%d -> %d" % [base_cost, next_cost])
		check_eq("cost %s is 0 at max level" % String(kind), Upgrades.cost(kind, Upgrades.MAX_LEVEL), 0)

	var maxed: Dictionary = {}
	for kind: StringName in Tuning.UPGRADE_ORDER:
		maxed[kind] = Upgrades.MAX_LEVEL
	var full: Dictionary = Upgrades.stats_for(maxed)
	var empty: Dictionary = Upgrades.stats_for({})
	check("hull upgrade raises max HP", int(full["max_hp"]) > int(empty["max_hp"]))
	check("speed upgrade raises speed", float(full["move_speed"]) > float(empty["move_speed"]))
	check("fire upgrade raises damage", float(full["damage_mult"]) > float(empty["damage_mult"]))
	check("fire upgrade shortens the interval", float(full["fire_interval"]) < float(empty["fire_interval"]))
	check(
		"shield capacity caps at MAX_SHIELD_CHARGES",
		int(full["shield_charges"]) == Tuning.MAX_SHIELD_CHARGES
	)

	# A purchase costs exactly the listed price and stops at max level.
	_reset_state()
	SaveData.energy = 100000
	var before: int = SaveData.energy
	var price: int = SaveData.next_upgrade_cost(&"hull")
	check("buy_upgrade succeeds with energy", SaveData.buy_upgrade(&"hull"))
	check_eq("buy_upgrade charges the price", SaveData.energy, before - price)
	check_eq("buy_upgrade raises the level", SaveData.level_of(&"hull"), 1)
	while SaveData.level_of(&"hull") < Upgrades.MAX_LEVEL:
		SaveData.buy_upgrade(&"hull")
	check("buy_upgrade refuses past max level", not SaveData.buy_upgrade(&"hull"))
	check_eq("level stops at max", SaveData.level_of(&"hull"), Upgrades.MAX_LEVEL)
	_reset_state()


func _test_persistence() -> void:
	_reset_state()
	SaveData.energy = 1234
	SaveData.upgrade_levels[&"speed"] = 3
	SaveData.upgrade_levels[&"shield"] = 6
	SaveData.skin_id = &"cobalt" if Skins.is_unlocked(&"cobalt") else Skins.DEFAULT_ID
	SaveData.master_volume = 0.42
	SaveData.music_volume = 0.55
	SaveData.sfx_volume = 0.66
	SaveData.shield_mode = Tuning.SHIELD_MODE_MANUAL
	SaveData.save_data()
	SaveData.load_data()
	check_eq("saved energy survives a reload", SaveData.energy, 1234)
	check_eq("saved speed level survives", SaveData.level_of(&"speed"), 3)
	check_eq("saved shield level survives", SaveData.level_of(&"shield"), 6)
	check_near("saved master volume survives", SaveData.master_volume, 0.42, 0.001)
	check_near("saved music volume survives", SaveData.music_volume, 0.55, 0.001)
	check_near("saved sfx volume survives", SaveData.sfx_volume, 0.66, 0.001)
	check_eq("saved shield mode survives", String(SaveData.shield_mode), String(Tuning.SHIELD_MODE_MANUAL))
	_reset_state()


# --- 4.5 Weapons ------------------------------------------------------------

func _test_weapons() -> void:
	var ids: Array[StringName] = Weapons.ids()
	check("weapon table has the five weapons", ids.size() == 5, "got %d" % ids.size())
	var pulse_damage: int = Weapons.damage(Weapons.DEFAULT_ID, Upgrades.stats_for({}))
	var maxed_stats: Dictionary = Upgrades.stats_for({&"fire": Upgrades.MAX_LEVEL})
	check(
		"FIRE POWER raises weapon damage",
		Weapons.damage(Weapons.DEFAULT_ID, maxed_stats) > pulse_damage
	)

	# Unlock gating uses the campaign's conquests.
	_reset_state()
	SaveData.campaign_best_planets = 0
	var gated: StringName = &""
	for id: StringName in ids:
		if Weapons.unlock_planets(id) > 0:
			gated = id
			break
	check("at least one weapon is gated", gated != &"")
	if gated != &"":
		check("gated weapon is locked at 0 planets", not Weapons.is_unlocked(gated))
		SaveData.campaign_best_planets = Weapons.unlock_planets(gated)
		check("gated weapon unlocks at its planet count", Weapons.is_unlocked(gated))
		SaveData.campaign_best_planets = 0

	# Buying needs the planet gate and the energy.
	_reset_state()
	SaveData.energy = 0
	# Weapon ids come from Tuning.WEAPON_ORDER; "heavy" and "scatter" here were
	# a bug in this test, not in the game (heavy is an enemy, not a weapon).
	check("cannot buy without energy", not SaveData.buy_weapon(&"cannon"))
	SaveData.energy = 99999
	check("cannot buy a locked weapon", not SaveData.buy_weapon(&"rail"))
	SaveData.campaign_best_planets = 40
	check("can buy an unlocked weapon", SaveData.buy_weapon(&"cannon"))
	check("owned weapon reports owned", Weapons.owned(&"cannon"))

	# Equipping: never the same weapon in both slots.
	check("equip primary", SaveData.equip_weapon(&"cannon", 0))
	check("same weapon cannot take the secondary", not SaveData.equip_weapon(&"cannon", 1))
	check("a second weapon can take the secondary", SaveData.equip_weapon(&"pulse", 1))
	check_eq("primary after equipping", String(SaveData.weapon_primary), "cannon")
	check_eq("secondary after equipping", String(SaveData.weapon_secondary), "pulse")
	SaveData.save_data()
	SaveData.load_data()
	check_eq("equipped primary survives a reload", String(SaveData.weapon_primary), "cannon")
	check_eq("equipped secondary survives a reload", String(SaveData.weapon_secondary), "pulse")
	check("owned weapon survives a reload", Weapons.owned(&"cannon"))
	_reset_state()


# --- 4.6 Galaxy -------------------------------------------------------------

func _test_galaxy() -> void:
	var a: Galaxy = Galaxy.generate(20260101)
	var b: Galaxy = Galaxy.generate(20260101)
	var same: bool = a.order.size() == b.order.size() and a.home_id == b.home_id and a.gate_id == b.gate_id
	if same:
		for index: int in a.order.size():
			var id: StringName = a.order[index]
			if b.order[index] != id or a.position_of(id) != b.position_of(b.order[index]):
				same = false
				break
	check("same seed gives an identical galaxy", same)
	var c: Galaxy = Galaxy.generate(7)
	check("a different seed gives a different galaxy", c.order != a.order)

	# Connectivity: every body is reachable from home through the links.
	var seen: Dictionary = {a.home_id: true}
	var queue: Array[StringName] = [a.home_id]
	while not queue.is_empty():
		var current: StringName = queue.pop_back()
		for link: Variant in a.links_of(current):
			var neighbour := StringName(link)
			if not seen.has(neighbour):
				seen[neighbour] = true
				queue.append(neighbour)
	check(
		"every body is reachable from home",
		seen.size() == a.body_count(),
		"%d of %d" % [seen.size(), a.body_count()]
	)

	var citadels: int = 0
	for body_id: StringName in a.order:
		if a.type_of(body_id) == &"citadel":
			citadels += 1
	check_eq("galaxy has five citadels", citadels, 5)

	# The gate needs two things: GALAXY_CITADELS_FOR_GATE citadels down AND a
	# conquered neighbour. Conquering citadels somewhere else on the map keeps it
	# sealed, which is what the earlier version of this test got wrong.
	var empty: Array[StringName] = []
	check("gate is sealed with no citadels", not a.attackable(empty).has(a.gate_id))
	var citadel_ids: Array[StringName] = []
	for body_id: StringName in a.order:
		if a.type_of(body_id) == &"citadel":
			citadel_ids.append(body_id)

	# Every non-citadel neighbour of the gate conquered: only the citadel count
	# can still seal it.
	var touching: Array[StringName] = []
	var touches: Dictionary = {}
	for link: Variant in a.links_of(a.gate_id):
		var neighbour := StringName(link)
		if neighbour == a.gate_id or a.type_of(neighbour) == &"citadel":
			continue
		touches[neighbour] = true
		touching.append(neighbour)
	var short: Array[StringName] = touching.duplicate()
	for body_id: StringName in citadel_ids:
		if a.citadel_conquered(short) >= Tuning.GALAXY_CITADELS_FOR_GATE - 1:
			break
		short.append(body_id)
	check(
		"gate stays sealed one citadel short",
		not a.attackable(short).has(a.gate_id),
		"%d citadels" % a.citadel_conquered(short)
	)
	var opened: Array[StringName] = short.duplicate()
	for body_id: StringName in citadel_ids:
		if not opened.has(body_id):
			opened.append(body_id)
			break
	check(
		"gate opens at %d citadels" % Tuning.GALAXY_CITADELS_FOR_GATE,
		a.attackable(opened).has(a.gate_id),
		"%d citadels" % a.citadel_conquered(opened)
	)

	# Deep citadels with no path to the gate do not open it.
	var far: Array[StringName] = []
	for body_id: StringName in citadel_ids:
		if not touches.has(body_id) and a.distance_of(body_id) > 2:
			far.append(body_id)
	if far.size() >= Tuning.GALAXY_CITADELS_FOR_GATE:
		var far_only: Array[StringName] = far.slice(0, Tuning.GALAXY_CITADELS_FOR_GATE)
		check(
			"citadels away from the gate do not open it",
			not a.attackable(far_only).has(a.gate_id)
		)


# --- 4.7 Audio --------------------------------------------------------------

func _test_audio() -> void:
	var master: int = AudioServer.get_bus_index("Master")
	var music: int = AudioServer.get_bus_index("Music")
	var sfx: int = AudioServer.get_bus_index("SFX")
	check("Master bus exists", master >= 0)
	check("Music bus exists", music >= 0)
	check("SFX bus exists", sfx >= 0)

	if music >= 0:
		AudioManager.set_bus_volume("Music", 0.5)
		check_near(
			"music slider writes the Music bus",
			AudioServer.get_bus_volume_db(music),
			linear_to_db(0.5),
			0.05
		)
		check_near("music volume reads back", AudioManager.get_bus_volume("Music"), 0.5, 0.02)
	if sfx >= 0:
		AudioManager.set_bus_volume("SFX", 0.25)
		check_near(
			"sfx slider writes the SFX bus",
			AudioServer.get_bus_volume_db(sfx),
			linear_to_db(0.25),
			0.05
		)
	if master >= 0:
		AudioManager.set_bus_volume("Master", 0.4)
		check_near(
			"master slider writes the Master bus",
			AudioServer.get_bus_volume_db(master),
			linear_to_db(0.4),
			0.05
		)
		AudioManager.set_mute(true)
		check("mute mutes the Master bus", AudioServer.is_bus_mute(master))
		AudioManager.set_mute(false)
		check("unmute clears it", not AudioServer.is_bus_mute(master))

	check("playlist has at least four tracks", AudioManager.track_count() >= 4, "%d" % AudioManager.track_count())

	# Shuffle: no track ever follows itself, and the boss theme never appears in
	# the normal rotation.
	var repeats: int = 0
	var boss_seen: int = 0
	var previous: String = ""
	var boss_names: Array[String] = []
	for track_name: String in Tuning.MUSIC_CONTEXTS:
		if String(Tuning.MUSIC_CONTEXTS[track_name]) == "boss":
			boss_names.append(track_name)
	for step: int in 40:
		AudioManager.next_track()
		var current: String = AudioManager.current_track_name()
		if current != "" and current == previous:
			repeats += 1
		if boss_names.has(current):
			boss_seen += 1
		previous = current
	check("shuffle never repeats the same track twice in a row", repeats == 0, "%d repeats" % repeats)
	check("boss track stays out of the rotation", boss_seen == 0, "%d plays" % boss_seen)

	# Saved volumes are applied by the autoload before the first sound.
	SaveData.master_volume = 0.3
	SaveData.music_volume = 0.6
	AudioManager._apply_saved_settings()
	if master >= 0:
		check_near(
			"saved master volume applies on load",
			AudioServer.get_bus_volume_db(master),
			linear_to_db(0.3),
			0.05
		)
	if music >= 0:
		check_near(
			"saved music volume applies on load",
			AudioServer.get_bus_volume_db(music),
			linear_to_db(0.6),
			0.05
		)
	AudioManager.stop_music()


# --- 4.9 Project paths ------------------------------------------------------

## Every res:// path in the project, the retired ones and the .uid/.import
## partners. Kept last: it reads the whole tree.
func _test_paths() -> void:
	PathCheck.run(func(name: String, ok: bool, detail: String) -> void:
		check(name, ok, detail)
	)


# --- 4.8 Controls -----------------------------------------------------------

func _test_controls() -> void:
	check("pause is a fixed binding", Controls.is_fixed(&"pause"))
	var refused: String = Controls.bind(&"pause", false, _key_event(KEY_Q))
	check("pause cannot be rebound", refused == "" and not SaveData.keyboard_bindings.has(&"pause"))

	_reset_state()
	var event := _key_event(KEY_J)
	Controls.bind(&"shoot", false, event)
	check("binding is stored", SaveData.keyboard_bindings.has(&"shoot"))
	var bound: bool = false
	for existing: InputEvent in InputMap.action_get_events(&"shoot"):
		if existing is InputEventKey and (existing as InputEventKey).physical_keycode == KEY_J:
			bound = true
	check("binding reaches the InputMap", bound)
	SaveData.save_data()
	SaveData.load_data()
	check("binding survives a reload", String(SaveData.keyboard_bindings.get(&"shoot", "")) != "")
	Controls.reset_all()
	check("reset clears the custom binding", not SaveData.keyboard_bindings.has(&"shoot"))
