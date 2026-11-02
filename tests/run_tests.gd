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
## Widest flame allowed relative to its hull: enough for a small hull to show a
## real flame, far short of the radius-driven hatch mark the geometry test was
## written for (that was about 2.6x the hull).
const FLAME_MAX_HULL_RATIO: float = 1.25
const SHIP_SCENE: PackedScene = preload("res://entities/player/ship.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://entities/enemies/enemy_base.tscn")
const BATTLE_SCENE: PackedScene = preload("res://game/battle/battle_game.tscn")
const MAP_SCENE: PackedScene = preload("res://ui/map/galaxy_map.tscn")
const UPGRADE_SCENE: PackedScene = preload("res://ui/panels/upgrade_panel.tscn")
const BOSS_SCENE: PackedScene = preload("res://entities/enemies/boss_station.tscn")
const CREDITS_SCENE: PackedScene = preload("res://ui/panels/credits_card.tscn")

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
	_test_save_robustness()
	_test_skin_reachability()
	_test_weapons()
	_test_elite_fighters()
	_test_thrusters()
	_test_boss_telegraph()
	_test_overlays()
	_test_banner_cards()
	await _test_upgrade_layout()
	_test_galaxy()
	_test_audio()
	await _test_credits()
	_test_controls()
	_test_keyboard_aim()
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
	SaveData.lifetime_planets = 0
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

## The wave banner must never sit on top of a card. Each card is opened while a
## banner is on screen, and the banner has to be gone immediately -- and stay
## gone when the card closes.
func _test_banner_cards() -> void:
	_reset_state()
	var battle := BATTLE_SCENE.instantiate()
	add_child(battle)
	var hud := battle.get_node_or_null("HUD")
	var banner: Label = null
	if hud != null:
		banner = hud.get_node_or_null("Root/BannerLabel") as Label
	check("banner label exists", banner != null)
	if banner == null:
		battle.queue_free()
		return
	hud.call("show_banner", "WAVE 1/1")
	check("banner shows on a wave call", banner.visible)
	hud.call("show_paused")
	check("banner hides for the pause card", not banner.visible)

	hud.call("show_banner", "WAVE 1/1")
	hud.call("show_victory", {})
	check("banner hides for the victory card", not banner.visible)

	hud.call("show_banner", "WAVE 2/2")
	hud.call("show_game_over", {})
	check("banner hides for the game-over card", not banner.visible)

	hud.call("show_banner", "WAVE 2/2")
	UIOverlay.open_card()
	check("banner hides for the C card", not banner.visible)
	var card := UIOverlay.get("_card") as ControlsCard
	if card != null:
		card.call("close")
	# Closing a card must not bring the banner back.
	check("the banner stays hidden after the card closes", not banner.visible)
	battle.queue_free()
	_reset_state()


## The Hull & Ship page must hold the stats, the preview with its flame, the
## name and status lines, EQUIP, the ten thumbnails and the wearing line inside
## the panel at 960x600 -- and the flame may never reach the name label.
func _test_upgrade_layout() -> void:
	var panel := UPGRADE_SCENE.instantiate() as Control
	add_child(panel)
	panel.call("open")
	await get_tree().process_frame
	await get_tree().process_frame
	var inner := panel.get_node_or_null("Panel/Margin") as Control
	var scroll := panel.get_node_or_null("Panel/Margin/Box/Scroll") as ScrollContainer
	var page := panel.get_node_or_null("Panel/Margin/Box/Scroll/Page") as Control
	if inner == null or scroll == null or page == null:
		check("upgrade panel nodes resolve", false)
		panel.queue_free()
		return
	var needed: Vector2 = page.get_combined_minimum_size()
	print(
		"LAYOUT panel=%s inner=%s scroll=%s page_min=%s"
		% [panel.get_global_rect(), inner.get_global_rect(), scroll.get_global_rect(), needed]
	)
	check(
		"the hull page fits its scroll box",
		needed.y <= scroll.size.y + 0.5,
		"page needs %.0f, scroll is %.0f" % [needed.y, scroll.size.y]
	)
	check(
		"the hull page fits across",
		needed.x <= scroll.size.x + 0.5,
		"page needs %.0f, scroll is %.0f" % [needed.x, scroll.size.x]
	)
	for child: Node in page.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		check(
			"page child %s sits inside the panel" % control.name,
			inner.get_global_rect().encloses(control.get_global_rect()),
			"%s vs %s" % [control.get_global_rect(), inner.get_global_rect()]
		)
	var flame := panel.get_node_or_null(
		"Panel/Margin/Box/Scroll/Page/Body/Stats/Preview/Thruster"
	) as Thruster
	var preview := panel.get_node_or_null(
		"Panel/Margin/Box/Scroll/Page/Body/Stats/Preview"
	) as Control
	var name_label := panel.get_node_or_null(
		"Panel/Margin/Box/Scroll/Page/Body/Stats/PreviewName"
	) as Label
	check(
		"preview flame and name resolve",
		flame != null and preview != null and name_label != null
	)
	if flame == null or preview == null or name_label == null:
		panel.queue_free()
		return
	for skin: Dictionary in Skins.all():
		var id: StringName = skin["id"]
		panel.call("_on_skin_pressed", id)
		await get_tree().process_frame
		var flame_rect := _flame_rect(flame)
		check(
			"flame clears the name label for %s" % String(id),
			not flame_rect.intersects(name_label.get_global_rect()),
			"flame %s name %s" % [flame_rect, name_label.get_global_rect()]
		)
		check(
			"flame stays inside the preview for %s" % String(id),
			preview.get_global_rect().encloses(flame_rect),
			"flame %s box %s" % [flame_rect, preview.get_global_rect()]
		)
	panel.queue_free()
	await get_tree().process_frame


## The station has to warn before its fan, and its opening phase has to be the
## softer one: both are read from the station itself, exactly as the battle does.
func _test_boss_telegraph() -> void:
	var ship := SHIP_SCENE.instantiate() as Ship
	add_child(ship)
	ship.position = Vector2(480.0, 470.0)
	ship.process_mode = Node.PROCESS_MODE_DISABLED
	var boss := BOSS_SCENE.instantiate() as BossStation
	boss.configure(&"red", 300, Vector2(480.0, 220.0), ship)
	add_child(boss)
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	var scales: Array[float] = []
	boss.shot_requested.connect(
		func(_origin: Vector2, _direction: Vector2, scale: float) -> void:
			scales.append(scale)
	)
	boss.call("_tick_fire", 1.0)
	check("the station holds its fire while its cooldown runs", scales.is_empty())
	boss.call("_tick_fire", 0.5)
	check("the station telegraphs before its volley", boss.is_telegraphing())
	boss.call("_tick_fire", Tuning.BOSS_TELEGRAPH * 0.5)
	check("no shot lands halfway through the telegraph", scales.is_empty(), "%d shots" % scales.size())
	check("the telegraph lasts its full window", boss.is_telegraphing())
	boss.call("_tick_fire", Tuning.BOSS_TELEGRAPH * 0.6)
	check(
		"the volley fires when the telegraph ends",
		scales.size() == Tuning.BOSS_BULLETS_PER_VOLLEY,
		"%d shots" % scales.size()
	)
	check("the telegraph is over once the volley leaves", not boss.is_telegraphing())
	check(
		"the opening phase fires a softened volley",
		scales.size() > 0 and is_equal_approx(scales[0], Tuning.BOSS_EARLY_DAMAGE_SCALE),
		str(scales)
	)
	check(
		"the opening phase waits longer between fans",
		is_equal_approx(
			float(boss.get("_fire_cooldown")),
			Tuning.BOSS_FIRE_INTERVAL * Tuning.BOSS_EARLY_INTERVAL_SCALE
		)
	)
	boss.take_damage(int(float(boss.max_hp) * 0.5))
	check(
		"a hurt station fires at full strength",
		is_equal_approx(boss.damage_scale(), 1.0),
		"%.2f" % boss.damage_scale()
	)
	boss.queue_free()
	ship.queue_free()
	await get_tree().process_frame


## The visible flame: its top edge is pinned to the node origin and it is
## centred across the hull (see Thruster). Only the BAR_ROWS of the 32x32 texture
## are opaque, so the height is the longest frame's row count, not the file size.
func _flame_rect(flame: Thruster) -> Rect2:
	var size := Vector2(
		Tuning.THRUSTER_ART_SIZE, float(Tuning.THRUSTER_BAR_ROWS.back())
	) * flame.scale
	return Rect2(flame.global_position - Vector2(size.x * 0.5, 0.0), size)


## Overlay smoke test: the C card, the F4 layout audit and the difficulty picker
## are opened on top of a live battle and of the map, then closed again. A card
## that only works on its own screen is what this catches.
func _test_overlays() -> void:
	_reset_state()
	var battle := BATTLE_SCENE.instantiate()
	add_child(battle)
	var card := UIOverlay.get("_card") as ControlsCard
	check("overlay card exists", card != null)
	if card == null:
		battle.queue_free()
		return
	UIOverlay.open_card()
	check("C card opens over a battle", card.visible)
	card.call("close")
	check("C card closes over a battle", not card.visible)

	UIOverlay.call("_toggle_layout_debug")
	var audit := UIOverlay.get("_layout_overlay") as Control
	check("F4 audit turns on", audit != null and audit.visible)
	UIOverlay.call("_toggle_layout_debug")
	check("F4 audit turns off", audit != null and not audit.visible)

	# The picker's root is a CanvasLayer, so it is a Node (not a Control) and is
	# asked for its own state instead of `visible`.
	var picker := battle.get_node_or_null("DifficultyPicker")
	check("the battle carries a difficulty picker", picker != null)
	if picker != null:
		picker.call("open")
		check("picker opens over a battle", bool(picker.call("picker_open")))
		picker.call("close")
		check("picker closes over a battle", not bool(picker.call("picker_open")))

	# The same three overlays on the map: the map owns a picker of its own.
	var map := MAP_SCENE.instantiate()
	add_child(map)
	UIOverlay.open_card()
	check("C card opens over the map", card.visible)
	card.call("close")
	check("C card closes over the map", not card.visible)
	UIOverlay.call("_toggle_layout_debug")
	check("F4 audit turns on over the map", audit != null and audit.visible)
	UIOverlay.call("_toggle_layout_debug")
	var map_picker := map.get_node_or_null("DifficultyPicker")
	check("the map carries a difficulty picker", map_picker != null)
	if map_picker != null:
		map_picker.call("open")
		check("picker opens over the map", bool(map_picker.call("picker_open")))
		map_picker.call("close")
		check("picker closes over the map", not bool(map_picker.call("picker_open")))
	map.queue_free()
	battle.queue_free()
	_reset_state()


## Exhaust geometry, measured on live nodes. Every enemy flame must sit behind
## its own hull, be no wider than that hull and keep its top edge on the anchor
## at full thrust; the player ship is the reference and must pass the same
## checks after the thruster offset follows the flame scale.
func _test_thrusters() -> void:
	var holder := Node2D.new()
	holder.name = "ThrusterHolder"
	add_child(holder)
	var kinds: Array[StringName] = [&"scout", &"gunner", &"heavy"]
	kinds.append_array(Tuning.ELITE_KINDS)
	for kind: StringName in kinds:
		var enemy := FIGHTER_SCENE.instantiate() as EnemyBase
		enemy.configure(kind, Vector2(300.0, 300.0), null)
		holder.add_child(enemy)
		var flame := enemy.get_node("Thruster") as Thruster
		flame.set_thrust(1.0)
		# The drawn hull, not the file: the alternate art has a wide transparent
		# margin, and the flame is anchored to the pixels that are there.
		var hull: Vector2 = enemy.drawn_size()
		var hull_half: float = hull.y * 0.5
		var hull_width: float = hull.x
		var flame_width: float = Tuning.THRUSTER_ART_SIZE * flame.scale.x
		check(
			"enemy flame %s is behind the hull" % String(kind),
			flame.position.y >= hull_half,
			"anchor %.1f hull half %.1f" % [flame.position.y, hull_half]
		)
		# A scout's hull is 18.6 px wide; a flame that reads at 960x600 is a little
		# wider than that, so the bound is 1.25x. The defect this guards against
		# was the radius-driven flame at ~2.6x the hull (the hatch-mark look).
		check(
			"enemy flame %s is not oversized for the hull" % String(kind),
			flame_width <= hull_width * FLAME_MAX_HULL_RATIO,
			"flame %.1f hull %.1f" % [flame_width, hull_width]
		)
		# Offset is in unscaled texture pixels, so the top edge is at the anchor
		# exactly when it is half the art with no scale factor folded in.
		check(
			"enemy flame %s keeps its top edge on the anchor" % String(kind),
			absf(flame.offset.y - Tuning.THRUSTER_ART_SIZE * 0.5) < 0.01,
			"offset %.2f" % flame.offset.y
		)

	var ship := SHIP_SCENE.instantiate() as Ship
	if ship != null:
		add_child(ship)
		var flame := ship.get_node_or_null("Thruster") as Thruster
		var sprite := ship.get_node_or_null("Sprite") as Sprite2D
		if flame != null and sprite != null:
			flame.set_thrust(1.0)
			var hull_half: float = sprite.get_rect().size.y * 0.5 * sprite.scale.y
			var hull_width: float = sprite.get_rect().size.x * sprite.scale.x
			check(
				"player flame is behind the hull",
				flame.position.y >= hull_half,
				"anchor %.1f hull half %.1f" % [flame.position.y, hull_half]
			)
			check(
				"player flame is not oversized for the hull",
				Tuning.THRUSTER_ART_SIZE * flame.scale.x <= hull_width * FLAME_MAX_HULL_RATIO,
				"flame %.1f hull %.1f" % [Tuning.THRUSTER_ART_SIZE * flame.scale.x, hull_width]
			)
			check(
				"player flame top edge sits on the anchor",
				absf(flame.offset.y - Tuning.THRUSTER_ART_SIZE * 0.5) < 0.01,
				"offset %.2f" % flame.offset.y
			)
		ship.queue_free()
	holder.queue_free()


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


## Credits: every shipped music file has an entry, every attributing license
## names its author, NOW PLAYING shows "title — author", and the exclude list is
## the same predicate the playlist uses.
func _test_credits() -> void:
	var files: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open("res://assets/audio/music/")
	if dir != null:
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while entry != "":
			if not dir.current_is_dir() and not entry.ends_with(".import"):
				if ["ogg", "mp3", "wav"].has(entry.get_extension().to_lower()):
					files.append(entry)
			entry = dir.get_next()
		dir.list_dir_end()
	check("the music folder lists its tracks", files.size() >= 4, "%d files" % files.size())
	var missing: PackedStringArray = Credits.uncredited_music(files)
	check("every music file has a credits entry", missing.is_empty(), ", ".join(missing))
	for track_name: String in Credits.MUSIC_ORDER:
		var credit: Dictionary = Credits.music_entry(track_name)
		check("credits entry for %s" % track_name, Credits.has_credit(credit))
	check(
		"NOW PLAYING shows title and author",
		Credits.music_label("Orbital Colossus") == "Space Boss Battle Theme — Matthew Pablo",
		Credits.music_label("Orbital Colossus")
	)
	for group: Dictionary in Credits.groups():
		for credit: Dictionary in group.get("entries", []):
			if not Credits.needs_attribution(credit):
				continue
			check(
				"CC-BY credit names author and license: %s" % String(credit.get("title", "")),
				not String(credit.get("author", "")).is_empty() \
					and not String(credit.get("license", "")).is_empty()
			)
	check(
		"an excluded track is filtered out",
		AudioManager.is_excluded("Preparing for War", ["Preparing for War"])
	)
	check(
		"a track that is not excluded survives",
		not AudioManager.is_excluded("8bit", ["Preparing for War"])
	)
	check(
		"the default exclude list is empty",
		Tuning.MUSIC_EXCLUDE.is_empty(),
		str(Tuning.MUSIC_EXCLUDE)
	)
	# A real rebuild: with the default (empty) exclude list every banked track has
	# to come back, which is the state the menu and the tests run against.
	var bases: Dictionary = {}
	for file_name: String in files:
		bases[file_name.get_basename()] = true
	AudioManager.call("_build_playlist")
	check(
		"the default playlist keeps every track",
		AudioManager.track_count() == bases.size(),
		"%d tracks for %d files" % [AudioManager.track_count(), bases.size()]
	)
	# The card itself: it opens, its panel stays inside the 960x600 viewport and it
	# builds the whole roll (no missing section, no scrollbar).
	var card := CREDITS_SCENE.instantiate() as CreditsCard
	add_child(card)
	card.open()
	await get_tree().process_frame
	await get_tree().process_frame
	# Freeze the roll: the card scrolls itself in _process, which would move every
	# row again between the measurement and the assert.
	card.set_process(false)
	check("the credits card opens", card.visible)
	var panel := card.get_node("Panel") as Control
	check(
		"the credits panel fits the viewport",
		Rect2(Vector2.ZERO, Tuning.VIEW_SIZE).encloses(panel.get_global_rect()),
		str(panel.get_global_rect())
	)
	var roll := card.get_node("Panel/Margin/Box/Roll/RollBox") as VBoxContainer
	var expected: int = 0
	for group: Dictionary in Credits.groups():
		expected += 1 + (group.get("entries", []) as Array).size()
	check(
		"the credits roll lists every group and entry",
		roll.get_child_count() >= expected,
		"%d lines for %d entries" % [roll.get_child_count(), expected]
	)
	# Scrolling: every row must sit inside the clip once the roll is parked on it,
	# and no two rows may overlap whatever the scroll position.
	var clip := card.get_node("Panel/Margin/Box/Roll") as Control
	var rows: Array[Control] = []
	for child: Node in roll.get_children():
		var control := child as Control
		if control != null and control.size.y > 0.0:
			rows.append(control)
	check("the credits roll has rows to scroll", rows.size() >= expected, "%d rows" % rows.size())
	var span: float = maxf(roll.size.y - clip.size.y, 0.0)
	var outside: int = 0
	var first: String = ""
	for row: Control in rows:
		# Park the roll on the row: 0 is the top, -span the end of the list.
		roll.position = Vector2(0.0, clampf(-row.position.y, -span, 0.0))
		# A moved container only publishes its new transforms on the next frame.
		await get_tree().process_frame
		var clip_rect: Rect2 = clip.get_global_rect().grow(0.5)
		if not clip_rect.encloses(row.get_global_rect()):
			outside += 1
			if first.is_empty():
				first = "%s vs %s" % [row.get_global_rect(), clip_rect]
	check("every credits row fits the clip when scrolled to", outside == 0, "%d outside: %s" % [outside, first])
	var overlaps: int = 0
	for index: int in rows.size() - 1:
		if rows[index].get_global_rect().intersects(rows[index + 1].get_global_rect()):
			overlaps += 1
	check("credits rows do not overlap", overlaps == 0, "%d overlaps" % overlaps)
	roll.position = Vector2.ZERO
	check(
		"the credits card stays inside 960x600",
		Rect2(Vector2.ZERO, Tuning.VIEW_SIZE).encloses(card.get_global_rect()),
		str(card.get_global_rect())
	)
	card.close()
	check("the credits card closes", not card.visible)
	card.queue_free()
	await get_tree().process_frame


## A missing, empty, truncated, mistyped or old save must never stop the game:
## every value is coerced and the defaults come back.
func _test_save_robustness() -> void:
	var cases: Array[Dictionary] = [
		{"name": "missing file", "text": "", "delete": true},
		{"name": "empty file", "text": ""},
		{"name": "truncated file", "text": "[progress]\nenergy = 42\n[campaign\nseed = 1"},
		{"name": "wrong value types", "text": "[progress]\nenergy = \"lots\"\nskin = 3\n[audio]\nmusic_volume = \"loud\"\nmuted = \"yes\"\n[campaign]\nactive = \"sure\"\nconquered = 7\nseed = [1, 2]\n[weapons]\nowned = 5\n[controls]\nmove_left_key = 12\n"},
		{"name": "unknown keys", "text": "[mystery]\nfoo = 1\nbar = \"baz\"\n"},
		{"name": "oldest schema", "text": "[progress]\nhigh_score = 100\nenergy = 7\n"},
	]
	for case: Dictionary in cases:
		if bool(case.get("delete", false)):
			if FileAccess.file_exists(SAVE_PATH):
				DirAccess.remove_absolute(SAVE_PATH)
		else:
			var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
			check("save fixture is writable: %s" % case["name"], file != null)
			if file != null:
				file.store_string(String(case["text"]))
				file.close()
		SaveData.load_data()
		check(
			"a %s loads" % case["name"], true,
			"reached the end of load_data"
		)
		check("... energy is a sane int", SaveData.energy >= 0, str(SaveData.energy))
		check(
			"... volumes stay in range",
			SaveData.music_volume >= 0.0 and SaveData.music_volume <= 1.0 \
				and SaveData.master_volume >= 0.0 and SaveData.master_volume <= 1.0
		)
		check(
			"... the difficulty is a known mode",
			Tuning.DIFFICULTY_ORDER.has(SaveData.campaign_difficulty),
			str(SaveData.campaign_difficulty)
		)
		check("... the conquests are a list", SaveData.campaign_conquered is Array)
		check("... the skin is a known hull", Skins.has(SaveData.skin_id), str(SaveData.skin_id))
	# The game still saves and loads after the worst of them.
	SaveData.energy = 31
	SaveData.save_data()
	SaveData.energy = 0
	SaveData.load_data()
	check_eq("a save written after a broken file round-trips", SaveData.energy, 31)


## Every hull milestone has to be reachable: a galaxy holds 50-60 bodies, so only
## about 43-53 planets, which is less than the top milestone. The lifetime count
## is what makes the last hulls reachable at all.
func _test_skin_reachability() -> void:
	var top: int = 0
	for skin: Dictionary in Skins.all():
		top = maxi(top, int(skin.get("unlock", 0)))
	check(
		"the top hull milestone exceeds one small galaxy",
		top > Tuning.GALAXY_BODY_COUNT_MIN - 7,
		"top %d vs %d planets" % [top, Tuning.GALAXY_BODY_COUNT_MIN - 7]
	)
	var locked: int = 0
	for skin: Dictionary in Skins.all():
		SaveData.lifetime_planets = int(skin.get("unlock", 0))
		if not Skins.is_unlocked(skin["id"]):
			locked += 1
	check("every hull unlocks at its own milestone", locked == 0, "%d locked" % locked)
	# Conquests across campaigns feed the lifetime count.
	SaveData.lifetime_planets = 0
	SaveData.begin_campaign(20261102, Tuning.DIFFICULTY_CADET)
	for index: int in 45:
		SaveData.record_campaign_progress(StringName("body_%d" % index), 100, 100, 0)
	check_eq("conquests raise the lifetime count", SaveData.lifetime_planets, 45)
	check("the last hull unlocks from lifetime conquests", Skins.is_unlocked(&"stroke_yellow"))
	var kept: int = SaveData.lifetime_planets
	SaveData.save_data()
	SaveData.lifetime_planets = 0
	SaveData.load_data()
	check_eq("the lifetime count survives a reload", SaveData.lifetime_planets, kept)
	# SINGULARITY wipes upgrades and energy, never the cosmetic hulls.
	SaveData.wipe_meta_progress()
	check("SINGULARITY keeps the lifetime count", SaveData.lifetime_planets >= kept)
	check("SINGULARITY keeps the unlocked hulls", Skins.is_unlocked(&"stroke_yellow"))
	SaveData.finish_campaign()


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

	# Every action the game itself uses must be playable with both device
	# families. The engine's own ui_* actions are out of scope: they are editor
	# navigation, not gameplay, and many of them are keyboard-only on purpose.
	# Tuning.CONTROL_PAD_ONLY carries the intentional exceptions and the reason.
	var actions: Array[StringName] = Tuning.CONTROL_ACTIONS.duplicate()
	for action: StringName in Tuning.CONTROL_AIM_ACTIONS:
		if not actions.has(action):
			actions.append(action)
	var no_pad: PackedStringArray = []
	var no_key: PackedStringArray = []
	for action: StringName in actions:
		var has_key: bool = false
		var has_pad: bool = false
		for existing: InputEvent in InputMap.action_get_events(action):
			if existing is InputEventKey or existing is InputEventMouseButton:
				has_key = true
			elif existing is InputEventJoypadButton or existing is InputEventJoypadMotion:
				has_pad = true
		if not has_pad:
			no_pad.append(String(action))
		if not has_key and not Tuning.CONTROL_PAD_ONLY.has(action):
			no_key.append(String(action))
	check("every gameplay action has a gamepad binding", no_pad.is_empty(), ", ".join(no_pad))
	check("no gameplay action is keyboard-only", no_key.is_empty(), ", ".join(no_key))

	# The exception list has to stay honest: a declared pad-only action really
	# has a pad binding and no keyboard one, so the list cannot hide a gap.
	var mislabelled: PackedStringArray = []
	for action: StringName in Tuning.CONTROL_PAD_ONLY:
		var pad_seen: bool = false
		var key_seen: bool = false
		for existing: InputEvent in InputMap.action_get_events(action):
			if existing is InputEventKey or existing is InputEventMouseButton:
				key_seen = true
			elif existing is InputEventJoypadButton or existing is InputEventJoypadMotion:
				pad_seen = true
		if not pad_seen or key_seen:
			mislabelled.append(String(action))
		else:
			print("INFO pad-only %s: %s" % [action, Tuning.CONTROL_PAD_ONLY[action]])
	check("the pad-only list matches the InputMap", mislabelled.is_empty(), ", ".join(mislabelled))

	# H-1: a pad-only player can open the controls card with Select/Back.
	var back_bound: bool = false
	for existing: InputEvent in InputMap.action_get_events(&"controls"):
		if existing is InputEventJoypadButton \
				and (existing as InputEventJoypadButton).button_index == JOY_BUTTON_BACK:
			back_bound = true
	check("the controls card opens from gamepad BACK", back_bound)
	check("the controls binding is remappable", not Controls.is_fixed(&"controls"))
	check(
		"the help text names the gamepad controls binding",
		Controls.help_text().contains(Controls.binding_text(&"controls", true))
	)


## H-2: a keyboard-only player in FREE AIM can swing the nose with J/L, the
## mouse still aims, and the two never both drive the same tick.
func _test_keyboard_aim() -> void:
	check("keyboard aim is bound", Controls.binding_text(&"aim_left", false) != "UNBOUND")
	check(
		"keyboard aim is remappable",
		Tuning.CONTROL_ACTIONS.has(&"aim_left") and not Controls.is_fixed(&"aim_left")
	)
	var ship := SHIP_SCENE.instantiate() as Ship
	if ship == null:
		check("ship scene loads for the aim test", false)
		return
	add_child(ship)
	ship.control_scheme = Tuning.CONTROL_SCHEME_FREE
	ship.aim = Vector2.UP
	ship.rotation = 0.0

	# J holds left for half a second: the aim direction turns anticlockwise at
	# the tuned rate and the nose follows it.
	Input.action_press("aim_left")
	for tick: int in 10:
		ship._update_aim(0.05)
	Input.action_release("aim_left")
	# Vector2.UP is -PI/2, so the expected angle is that plus the turn.
	check_near(
		"keyboard aim rotates at the tuned rate",
		ship.aim.angle(),
		-PI * 0.5 - Tuning.KEYBOARD_AIM_TURN_RATE * 0.5,
		0.03
	)
	check("keyboard aim turns the nose", ship.rotation < -0.2, "rotation %.2f" % ship.rotation)

	# L turns back the other way from wherever the aim now points.
	Input.action_press("aim_right")
	for tick: int in 10:
		ship._update_aim(0.05)
	Input.action_release("aim_right")
	check_near("keyboard aim turns both ways", ship.aim.angle(), -PI * 0.5, 0.03)

	# A mouse movement arms pointer aim again; the direction is the pointer's.
	ship.global_position = Vector2(200.0, 200.0)
	ship.aim = Vector2.UP
	ship._mouse_idle = 0.0
	ship._unhandled_input(InputEventMouseMotion.new())
	check("a mouse movement arms pointer aim", ship._mouse_idle > 0.0)
	var to_pointer: Vector2 = ship.get_global_mouse_position() - ship.global_position
	ship._update_aim(0.05)
	if to_pointer.length() > Tuning.SHIP_AIM_DEADZONE:
		check_near("mouse aim still points at the pointer", ship.aim.angle(), to_pointer.angle(), 0.02)
	else:
		check("the headless pointer is far from the hull", false, "pointer at the hull")

	# With the keys held, the keys own the tick even while the pointer is live.
	ship.aim = Vector2.UP
	ship._mouse_idle = Tuning.SHIP_MOUSE_AIM_HOLD
	Input.action_press("aim_right")
	ship._update_aim(0.05)
	Input.action_release("aim_right")
	check_near(
		"aim keys win over a live pointer",
		ship.aim.angle(),
		-PI * 0.5 + Tuning.KEYBOARD_AIM_TURN_RATE * 0.05,
		0.02
	)

	# The pointer's claim expires, so it cannot recapture the nose later.
	ship._mouse_idle = 0.2
	ship._update_aim(0.5)
	check("a resting pointer stops aiming", ship._mouse_idle <= 0.0)
	ship.queue_free()
