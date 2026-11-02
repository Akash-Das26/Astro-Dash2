extends Node
## Debug-only battle bot for the headless smoke run.
##
##   godot --headless --path . res://tests/battle_bot.tscn
##
## It starts a real campaign battle for each of three difficulty/loadout rows,
## flies a sweeping path (so the arena wrap is exercised), aims at the nearest
## fighter via Ship.set_aim_override, and holds the real `shoot` / `shoot_alt`
## actions so the normal firing path runs. Every 10 s it prints the live node
## count and the frame rate; at 25 s it opens and closes the pause card through
## the HUD signal; the CADET row then force-clears waves to reach the victory
## card, and the SINGULARITY row kills the ship to reach the game-over card.
##
## It never asserts: the judgement happens in the terminal run (errors, growth),
## so a pass here means "no error was printed", not "the game is correct".

const BATTLE_SCENE: PackedScene = preload("res://game/battle/battle_game.tscn")
## Seconds before the bot starts firing, so the arena stays live for the pause
## and wrap checks.
const FIRE_AFTER: float = 12.0
## When the pause card is opened and closed, while the fight is certainly live.
const PAUSE_AT: float = 10.0
## Balance rows fly at this engine time scale, so 60 s of game time costs ~15 s
## of wall time. Stated in the report; the physics stays the same, just faster.
const BALANCE_TIME_SCALE: float = 4.0
## Every weapon is owned here so both hardpoints can hold any pair.
const ALL_WEAPONS: Array[StringName] = [&"pulse", &"cannon", &"scatter", &"rail", &"missile"]
## A boss row runs this long, so even a losing loadout has time to bring the
## station down before the row ends.
const BOSS_SECONDS: float = 90.0

var _rows: Array[Dictionary] = []
var _battle: Node = null
var _ship: Ship = null
var _samples: Array[int] = []
var _fps_samples: Array[float] = []
var _min_x: float = INF
var _max_x: float = -INF
var _min_y: float = INF
var _max_y: float = -INF
var _out_of_bounds: int = 0
var _wraps: int = 0
var _last_x: float = 0.0
var _pause_tested: bool = false
var _problems: PackedStringArray = []
## HP lost per damage source, for the balance report (no tuning reads this).
var _damage_by_kind: Dictionary = {}
var _last_hp_tracked: int = 0
## Set when a station appears in the run, so a boss row can prove it was flown
## against the boss and not only against its escort.
var _boss_seen: bool = false
## The station's HP every 10 s of a boss row, as "t=10s 120/140" strings.
var _boss_hp_log: PackedStringArray = []
## The station's largest HP, kept after it dies and the battle drops the node.
var _boss_max_seen: int = 0
## Seconds into the row when the ship died, or -1 while it is still flying.
var _ship_death_at: float = -1.0
var _run_seconds: float = 0.0
## HP the ship lost while the station was in each third of its health bar.
var _phase_damage: Dictionary = {}
## `-- --probe` runs a single 12 s row with a frame-by-frame log, for working
## out why a battle is not simulating.
var _probe: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_probe = OS.get_cmdline_user_args().has("--probe")
	_rows = [
		{
			"mode": Tuning.DIFFICULTY_CADET, "primary": &"pulse",
			"secondary": &"cannon", "seconds": 60.0, "victory": true,
		},
		{
			"mode": Tuning.DIFFICULTY_SUPERNOVA, "primary": &"missile",
			"secondary": &"rail", "seconds": 60.0, "victory": false,
		},
		{
			"mode": Tuning.DIFFICULTY_SINGULARITY, "primary": &"scatter",
			"secondary": &"pulse", "seconds": 60.0, "victory": false, "defeat": true,
		},
		# Never fires, so the wave cannot be cleared before the forced kill: this
		# is the row that reaches the game-over card instead of the victory card.
		{
			"mode": Tuning.DIFFICULTY_CADET, "primary": &"pulse",
			"secondary": &"cannon", "seconds": 35.0, "victory": false,
			"defeat": true, "verify_defeat": true, "fire_after": 999.0,
			"kill_at": 14.0, "label": "DEFEAT CARD",
		},
	]
	if _probe:
		var first: Dictionary = _rows[0].duplicate()
		first["seconds"] = 12.0
		_rows = [first]
	# Balance run: `-- <difficulty>` flies exactly one 60 s row of that mode, with
	# no forced victory or kill, and prints the hull left plus who hurt the ship.
	var balance_mode: StringName = _requested_mode()
	var band_token: String = _requested_band()
	if balance_mode != &"" and band_token == "boss":
		# A station row starts its own fight: the escort waves are stopped and
		# the station flies in on the first frame, so the whole 90 s measures it.
		_rows = [{
			"mode": balance_mode, "primary": &"pulse", "secondary": &"cannon",
			"seconds": BOSS_SECONDS, "balance": true, "boss_mode": true,
			"body": &"", "band_token": "boss",
			"label": "BOSS %s" % String(balance_mode).to_upper(),
		}]
	elif balance_mode != &"":
		_rows = [{
			"mode": balance_mode, "primary": &"pulse", "secondary": &"cannon",
			"seconds": 60.0, "balance": true,
			# A citadel has to reach its station to be worth measuring, so the
			# waves are cleared at 40 s and the boss fight fills the rest.
			"victory": band_token == "citadel" or band_token == "gate",
			# A station only flies in after its last escort wave, so those rows
			# clear the escorts from the first second: the point is to measure the
			# boss, and a fresh hull is what makes that comparable across runs.
			"clear_at": 0.0 if band_token == "citadel" or band_token == "gate" else 40.0,
			"body": &"", "band_token": band_token,
			"label": "BALANCE %s band %s" % [String(balance_mode).to_upper(), band_token],
		}]
	for row: Dictionary in _rows:
		await _run_row(row)
	Input.action_release(&"shoot")
	Input.action_release(&"shoot_alt")
	print("BOT DONE (%d problems)" % _problems.size())
	for problem: String in _problems:
		print("  PROBLEM: %s" % problem)
	get_tree().quit(1 if not _problems.is_empty() else 0)


# --- One difficulty / loadout row -------------------------------------------

func _run_row(row: Dictionary) -> void:
	var mode: StringName = row["mode"]
	var label: String = String(row.get("label", String(mode).to_upper()))
	print("")
	print("BOT == %s | %s + %s ==" % [label, row["primary"], row["secondary"]])
	SaveData.begin_campaign(int(Time.get_unix_time_from_system()) & 0xFFFF, mode)
	SaveData.energy = 500
	SaveData.campaign_best_planets = 40
	SaveData.weapons_owned = ALL_WEAPONS.duplicate()
	SaveData.weapon_primary = row["primary"]
	SaveData.weapon_secondary = row["secondary"]
	SaveData.shield_mode = Tuning.SHIELD_MODE_AUTO

	var target: StringName = StringName(row.get("body", &""))
	if target == &"" and bool(row.get("balance", false)):
		# After begin_campaign, never before: the id has to come from this row's
		# galaxy, or a "citadel" id can belong to a plain planet in the new one.
		var token: String = String(row.get("band_token", ""))
		target = _pick_body("citadel" if token == "boss" else token)
		if target == &"":
			_problems.append("%s: no body in band %s" % [mode, token])
			return
	if target == &"":
		var open: Array[StringName] = Campaign.attackable()
		if open.is_empty():
			_problems.append("%s: no attackable body" % mode)
			return
		target = open[0]
	if bool(row.get("balance", false)):
		Engine.time_scale = BALANCE_TIME_SCALE
	Campaign.start_battle(target)
	_battle = BATTLE_SCENE.instantiate()
	if _probe:
		# Signals first, so nothing the scene does on its first frame is missed.
		var director: WaveDirector = _battle.get_node("World/WaveDirector")
		director.wave_started.connect(_probe_wave)
		director.battle_won.connect(_probe_won)
		director.enemy_spawned.connect(_probe_enemy)
	add_child(_battle)
	# The scene's _ready already picked the body up and started the fight.
	_ship = _battle.ship
	if _ship == null:
		_problems.append("%s: no ship in the battle scene" % mode)
		return
	_last_hp_tracked = _ship.hp
	_damage_by_kind.clear()
	if bool(row.get("boss_mode", false)):
		_start_boss_fight()
	print(
		"BOT hull %d/%d  shield %d/%d  primary %s  secondary %s"
		% [
			_ship.hp, _ship.max_hp, _ship.shields, _ship.shield_limit(),
			_ship.weapon_id(0), _ship.weapon_id(1),
		]
	)

	_samples.clear()
	_fps_samples.clear()
	_pause_tested = false
	_boss_seen = false
	_boss_hp_log.clear()
	_phase_damage.clear()
	_boss_max_seen = 0
	_ship_death_at = -1.0
	_run_seconds = float(row["seconds"])
	_wraps = 0
	_out_of_bounds = 0
	_min_x = INF
	_max_x = -INF
	_min_y = INF
	_max_y = -INF
	_last_x = _ship.global_position.x

	await _drive(row)
	await _finish_row(row, mode)


func _drive(row: Dictionary) -> void:
	var seconds: float = float(row["seconds"])
	var elapsed: float = 0.0
	var next_sample: float = 10.0
	var killed_ship: bool = false
	# One clear only: the check below runs every frame, and a repeat clear would
	# kill the station on the frame it spawns, leaving the boss unmeasured.
	var cleared: bool = false
	var next_probe: float = 0.0
	var firing: bool = false
	var fire_after: float = float(row.get("fire_after", FIRE_AFTER))
	var kill_at: float = float(row.get("kill_at", 48.0))
	while elapsed < seconds:
		await get_tree().process_frame
		if not is_instance_valid(_battle) or not is_instance_valid(_ship):
			break
		elapsed += get_process_delta_time()
		if _probe and elapsed >= next_probe:
			next_probe += 1.0
			_probe_tick(elapsed)
		# The first 12 s are a no-fire window: the arena has to stay live long
		# enough for the pause card and the wrap runs to be meaningful. Firing
		# from frame zero cleared a one-wave CADET battle in about four seconds.
		var should_fire: bool = elapsed >= fire_after
		if should_fire != firing:
			firing = should_fire
			if firing:
				Input.action_press(&"shoot")
				Input.action_press(&"shoot_alt")
			else:
				Input.action_release(&"shoot")
				Input.action_release(&"shoot_alt")
		_track_bounds()
		_track_damage()
		_track_boss()
		if _ship_death_at < 0.0 and not _ship.alive:
			_ship_death_at = elapsed
		_steer(elapsed)
		if elapsed >= next_sample:
			next_sample += 10.0
			_boss_hp_log.append(_boss_hp_line(elapsed))
			_samples.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
			_fps_samples.append(Engine.get_frames_per_second())
			print(
				"BOT t=%.0fs nodes=%d fps=%.0f alive=%s hull=%d/%d shield=%d/%d"
				% [
					elapsed, _samples[-1], _fps_samples[-1], _ship.alive,
					_ship.hp, _ship.max_hp, _ship.shields, _ship.shield_limit(),
				]
			)
		# Only worth testing on a live fight: a ship that already died on a hard
		# mode leaves nothing to pause, and that is not a failure.
		if not _pause_tested and elapsed >= PAUSE_AT and _ship.alive \
				and bool(_battle.get("_running")):
			_pause_tested = true
			await _exercise_pause()
		if bool(row.get("victory", false)) and elapsed >= float(row.get("clear_at", 40.0)):
			# A citadel or gate row exists to be shot at by the station, so it
			# keeps clearing escorts until the station is on the field and never
			# touches the station itself.
			var token: String = String(row.get("band_token", ""))
			var station_row: bool = token == "citadel" or token == "gate"
			if station_row:
				if not _boss_seen:
					_clear_wave(true)
			elif not cleared:
				cleared = true
				_clear_wave(false)
		if bool(row.get("defeat", false)) and elapsed >= kill_at and not killed_ship:
			killed_ship = true
			await _kill_ship()
	Input.action_release(&"shoot")
	Input.action_release(&"shoot_alt")
	_hold_move(Vector2.ZERO)


## Flies toward the nearest fighter while it is far, strafes once it is close,
## and spends two windows of every row running one direction to force wraps.
func _steer(elapsed: float) -> void:
	if _ship == null or not _ship.alive:
		_hold_move(Vector2.ZERO)
		_ship.set_aim_override(Vector2.ZERO)
		return
	# Two run windows in fixed directions: one crosses a side edge, the other a
	# top/bottom edge, which is the only way the wrap is actually exercised.
	var running: bool = (elapsed > 2.0 and elapsed < 8.0) or (elapsed > 30.0 and elapsed < 36.0)
	var target: Node2D = _nearest_target()
	var aim: Vector2 = Vector2.UP
	if target != null:
		aim = (target.global_position - _ship.global_position).normalized()
	_ship.set_aim_override(aim)
	if running:
		# A long run in one direction, so the hull leaves one edge and returns
		# from the opposite one with the thruster restarting instead of streaking.
		var run_direction: Vector2 = Vector2.LEFT if elapsed < 20.0 else Vector2.UP
		_hold_move(run_direction)
		return
	if target == null:
		_hold_move(Vector2(0.0, -1.0))
		return
	var offset: Vector2 = target.global_position - _ship.global_position
	var distance: float = offset.length()
	if distance > 180.0:
		_hold_move(offset.normalized())
	else:
		# Close range: circle the target so shots cross from a moving ship.
		_hold_move(offset.normalized().orthogonal())


func _nearest_target() -> Node2D:
	if _battle == null or not is_instance_valid(_battle):
		return null
	var best: Node2D = null
	var best_distance: float = INF
	var containers: Array[Node] = [_battle.enemies, _battle.asteroids]
	for container: Node in containers:
		if container == null or not is_instance_valid(container):
			continue
		for child: Node in container.get_children():
			var body := child as Node2D
			if body == null or not body.has_method("take_damage"):
				continue
			var distance: float = body.global_position.distance_squared_to(_ship.global_position)
			if distance < best_distance:
				best_distance = distance
				best = body
	var boss: Node = _battle.get("_boss") as Node
	if boss != null and is_instance_valid(boss) and boss is Node2D:
		var boss_distance: float = (boss as Node2D).global_position.distance_squared_to(
			_ship.global_position
		)
		if boss_distance < best_distance:
			best = boss as Node2D
	return best


func _hold_move(direction: Vector2) -> void:
	_toggle(&"move_left", direction.x < -0.2)
	_toggle(&"move_right", direction.x > 0.2)
	_toggle(&"move_up", direction.y < -0.2)
	_toggle(&"move_down", direction.y > 0.2)


func _toggle(action: StringName, pressed: bool) -> void:
	if pressed and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not pressed and Input.is_action_pressed(action):
		Input.action_release(action)


## Pause and resume through the HUD signals, exactly like the pause card, and
## check that the arena actually froze and came back.
func _exercise_pause() -> void:
	_battle.hud.pause_requested.emit()
	await get_tree().process_frame
	var paused: bool = GameState.state == GameState.State.PAUSED
	var before: Vector2 = _ship.global_position
	await get_tree().create_timer(0.4).timeout
	var moved: float = _ship.global_position.distance_to(before)
	_battle.hud.resume_requested.emit()
	await get_tree().process_frame
	var resumed: bool = GameState.state == GameState.State.PLAYING
	print("BOT pause=%s frozen=%.1fpx resumed=%s" % [paused, moved, resumed])
	if not paused or not resumed:
		_problems.append("pause card did not toggle the state")
	if moved > 2.0:
		_problems.append("the ship kept moving while paused (%.1f px)" % moved)


## Kills every fighter on the field, so the waves clear quickly and the victory
## card is reached inside the run. With `keep_boss` the station is left alive:
## killing it here would make every boss row measure the escort, not the boss.
func _clear_wave(keep_boss: bool = false) -> void:
	for container: Node in [_battle.enemies]:
		for child: Node in container.get_children():
			if child.has_method("take_damage"):
				child.take_damage(99999)
	if keep_boss:
		return
	var boss: Node = _battle.get("_boss") as Node
	if boss != null and is_instance_valid(boss) and boss.has_method("take_damage"):
		boss.take_damage(99999)


## Stops the escort waves and calls the station in immediately, through the
## battle's own spawn path: this is the only way to guarantee 90 s against the
## station, since it normally arrives after the director's last wave.
func _start_boss_fight() -> void:
	var director: WaveDirector = _battle.director
	if director != null:
		director.stop()
	for child: Node in _battle.enemies.get_children():
		child.queue_free()
	_battle.call("_spawn_boss")
	var boss: Node = _battle.get("_boss") as Node
	if boss == null:
		_problems.append("boss row: the station did not spawn")
		return
	var board: Battle = _battle.get("battle") as Battle
	print(
		"BOT boss spawn station_hp=%d battle=%s mode_hp=%d color=%s"
		% [
			int(boss.get("max_hp")), board.title if board != null else "-",
			board.boss_hp if board != null else -1,
			String(board.boss_color) if board != null else "-",
		]
	)


## "t=10s 120/140", or "t=10s gone" once the station has died.
func _boss_hp_line(elapsed: float) -> String:
	var boss: Node = _battle.get("_boss") as Node if _battle != null else null
	if boss == null or not is_instance_valid(boss):
		return "t=%ds gone" % int(elapsed)
	return "t=%ds %d/%d" % [int(elapsed), int(boss.get("hp")), int(boss.get("max_hp"))]


## The station has one attack (a five-dot fan), so the phases here are the
## thirds of its health bar: which stage of the fight actually hurt the ship.
func _boss_phase(hp_fraction: float) -> String:
	if hp_fraction > 0.66:
		return "100-66%"
	if hp_fraction > 0.33:
		return "66-33%"
	return "33-0%"


## Everything a boss row exists to answer: did the station die, how long did the
## hull hold, and which third of the fight did the damage.
func _report_boss() -> void:
	var boss: Node = _battle.get("_boss") as Node if _battle != null else null
	var boss_alive: bool = boss != null and is_instance_valid(boss)
	var boss_hp: int = int(boss.get("hp")) if boss_alive else 0
	var boss_max: int = int(boss.get("max_hp")) if boss_alive else _boss_max_seen
	var outcome: String = "STATION LEFT"
	if not _ship.alive:
		outcome = "SHIP DOWN"
	elif _battle.victory:
		outcome = "STATION DOWN"
	var survived: float = _ship_death_at if _ship_death_at >= 0.0 else _run_seconds
	print(
		"BOT boss outcome=%s station=%d/%d hull=%d/%d survived=%.0fs boss_damage=%d damage: %s"
		% [
			outcome, boss_hp, boss_max, _ship.hp, _ship.max_hp, survived,
			int(_damage_by_kind.get(&"boss", 0)), _damage_report(),
		]
	)
	print("BOT boss hp %s" % ", ".join(_boss_hp_log))
	for phase: String in ["100-66%", "66-33%", "33-0%"]:
		print("BOT boss phase %s damage=%d" % [phase, int(_phase_damage.get(phase, 0))])


func _kill_ship() -> void:
	for attempt: int in 8:
		if not _ship.alive:
			return
		_ship.take_damage(99999)
		await get_tree().create_timer(0.8).timeout


# --- Probe ----------------------------------------------------------------

func _probe_tick(elapsed: float) -> void:
	var director: WaveDirector = _battle.director
	var live: PackedStringArray = []
	for child: Node in _battle.enemies.get_children():
		var enemy := child as EnemyBase
		if enemy != null:
			live.append("%s:%d" % [enemy.kind, enemy.hp])
	print(
		"PROBE t=%.1f state=%d running=%s wave=%d/%d live=%s enemies=%d [%s] ship=%s shield=%d"
		% [
			elapsed, int(GameState.state), str(director.is_running()), director.wave,
			director.wave_total(), str(_battle.get("_running")), live.size(),
			", ".join(live), str(_ship.global_position.round()), _ship.shields,
		]
	)


func _probe_wave(index: int, total: int) -> void:
	print("PROBE signal wave_started %d/%d" % [index, total])


func _probe_won() -> void:
	print("PROBE signal battle_won")


func _probe_enemy(enemy: EnemyBase) -> void:
	print("PROBE signal enemy_spawned %s hp=%d" % [enemy.kind, enemy.hp])
	enemy.died.connect(func(_points: int) -> void:
		print("PROBE signal enemy died %s" % enemy.kind)
	)


## The ship records the source of the last hit as metadata, so the report can
## name the attacker without any gameplay code knowing about it.
func _track_boss() -> void:
	if _battle == null or not is_instance_valid(_battle):
		return
	var boss: Node = _battle.get("_boss") as Node
	if boss != null and is_instance_valid(boss):
		_boss_seen = true
		_boss_max_seen = maxi(_boss_max_seen, int(boss.get("max_hp")))


func _track_damage() -> void:
	if _ship == null or not is_instance_valid(_ship):
		return
	if _ship.hp < _last_hp_tracked:
		var source: StringName = StringName(_ship.get_meta("last_damage_source", &"unknown"))
		var lost: int = _last_hp_tracked - _ship.hp
		_damage_by_kind[source] = int(_damage_by_kind.get(source, 0)) + lost
		var boss: Node = _battle.get("_boss") as Node if _battle != null else null
		if boss != null and is_instance_valid(boss):
			var max_hp: int = maxi(int(boss.get("max_hp")), 1)
			var phase: String = _boss_phase(float(int(boss.get("hp"))) / float(max_hp))
			_phase_damage[phase] = int(_phase_damage.get(phase, 0)) + lost
		_last_hp_tracked = _ship.hp


## The band token on the command line: "1".."4" (GALAXY_BANDS index + 1), or
## "citadel" / "gate". Empty means "the first attackable body".
func _requested_band() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "citadel" or arg == "gate" or arg == "boss":
			return arg
		if arg.length() == 1 and arg.is_valid_int():
			return arg
	return ""


## A body in the requested band, skipping home, gate and citadels so a band row
## really measures that band's mix. Returns an empty id when the seed has none.
func _pick_body(token: String) -> StringName:
	var map: Galaxy = Campaign.galaxy()
	if token == "citadel" or token == "gate" or token == "boss":
		for body_id: StringName in map.order:
			if token == "gate" and map.is_gate(body_id):
				return body_id
			if (token == "citadel" or token == "boss") and map.has_boss(body_id):
				return body_id
		return &""
	if token.is_empty():
		return &""
	var band: int = int(token) - 1
	for body_id: StringName in map.order:
		if map.is_home(body_id) or map.is_gate(body_id) or map.has_boss(body_id):
			continue
		if map.band_index_of(body_id) == band:
			return body_id
	return &""


## The difficulty named on the command line, or an empty name for the full run.
func _requested_mode() -> StringName:
	for arg: String in OS.get_cmdline_user_args():
		var candidate: StringName = StringName(arg)
		if Tuning.DIFFICULTY_ORDER.has(candidate):
			return candidate
	return &""


## "scout=12 heavy=8" worst first, so the biggest threat reads first.
func _damage_report() -> String:
	var kinds: Array = _damage_by_kind.keys()
	kinds.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(_damage_by_kind[a]) > int(_damage_by_kind[b])
	)
	var parts: PackedStringArray = []
	for kind: Variant in kinds:
		parts.append("%s=%d" % [String(kind), int(_damage_by_kind[kind])])
	return "none" if parts.is_empty() else ", ".join(parts)


func _finish_row(row: Dictionary, mode: StringName) -> void:
	Engine.time_scale = 1.0
	await get_tree().process_frame
	var growth: int = 0
	if _samples.size() >= 2:
		growth = _samples[-1] - _samples[0]
	var lowest_fps: float = 0.0
	for value: float in _fps_samples:
		if lowest_fps == 0.0 or value < lowest_fps:
			lowest_fps = value
	print(
		"BOT result %s: victory=%s hull_alive=%s state=%d wraps=%d out_of_bounds=%d nodes %s growth=%+d min_fps=%.0f"
		% [
			String(row.get("label", String(mode).to_upper())), _battle.victory, _ship.alive,
			int(GameState.state), _wraps,
			_out_of_bounds, str(_samples), growth, lowest_fps,
		]
	)
	if bool(row.get("balance", false)):
		print(
			"BOT balance %s band=%s seed=%d: result=%s hull=%d/%d (%.0f%%) damage: %s"
			% [
				String(mode), String(row.get("band_token", "1")), SaveData.campaign_seed,
				"WIN" if _battle.victory else ("LOSS" if not _ship.alive else "TIMEOUT"),
				_ship.hp, _ship.max_hp,
				100.0 * float(_ship.hp) / float(maxi(_ship.max_hp, 1)), _damage_report(),
			]
		)
		if bool(row.get("boss_mode", false)):
			_report_boss()
		if String(row.get("band_token")) in ["citadel", "gate"]:
			print("BOT bossed seen=%s boss_damage=%d" % [
				str(_boss_seen), int(_damage_by_kind.get(&"boss", 0)),
			])
	if _out_of_bounds > 0:
		_problems.append("%s: ship left the arena %d times" % [mode, _out_of_bounds])
	# Station rows hold station near the middle of the arena to shoot the boss,
	# so only the band rows are expected to cross an edge.
	if _wraps == 0 and String(row.get("band_token", "")) not in ["citadel", "gate"]:
		_problems.append("%s: the ship never wrapped" % mode)
	if growth > 200:
		_problems.append("%s: node count grew by %d" % [mode, growth])
	# Only the dedicated row can assert this: the difficulty rows are allowed to
	# win their wave before the forced kill lands.
	if bool(row.get("verify_defeat", false)) and _ship.alive:
		_problems.append("%s: the ship survived the forced defeat" % mode)
	# Only the dedicated row asserts the game-over card: the SINGULARITY row can
	# legitimately win the wave before its forced kill lands.
	if bool(row.get("verify_defeat", false)) and GameState.state != GameState.State.GAME_OVER:
		_problems.append("%s: the game-over card was not reached" % mode)
	if _battle.victory and not bool(row.get("victory", false)):
		print("BOT note: the battle was won before the forced clear")
	_battle.queue_free()
	_battle = null
	_ship = null
	await get_tree().process_frame


func _track_bounds() -> void:
	var position_now: Vector2 = _ship.global_position
	if position_now.x < _min_x:
		_min_x = position_now.x
	if position_now.x > _max_x:
		_max_x = position_now.x
	if position_now.y < _min_y:
		_min_y = position_now.y
	if position_now.y > _max_y:
		_max_y = position_now.y
	# A wrap shows up as a jump across the whole arena in one frame.
	if absf(position_now.x - _last_x) > Tuning.ARENA_RIGHT * 0.5:
		_wraps += 1
	_last_x = position_now.x
	var limit: float = 80.0
	if position_now.x < Tuning.ARENA_LEFT - limit or position_now.x > Tuning.ARENA_RIGHT + limit \
			or position_now.y < Tuning.ARENA_TOP - limit \
			or position_now.y > Tuning.ARENA_BOTTOM + limit:
		_out_of_bounds += 1
