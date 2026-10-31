class_name Campaign
extends RefCounted
## The run the galaxy map and a battle share.
##
## The map itself is rebuilt from `SaveData.campaign_seed`, so quitting mid-run
## (or mid-battle) and relaunching brings back the same worlds, the same
## conquests and the same hull. Only the two transient fields below live for a
## single session; a cold launch simply returns to the map.

## Body chosen on the map, read and cleared by the battle scene.
static var pending_id: StringName = &""
## Summary of the last finished battle, read once by the map.
static var last_result: Dictionary = {}

static var _galaxy: Galaxy
static var _galaxy_seed: int = -1


## The map's galaxy, regenerated only when the stored seed changed.
static func galaxy() -> Galaxy:
	if _galaxy != null and _galaxy_seed == SaveData.campaign_seed:
		return _galaxy
	_galaxy_seed = SaveData.campaign_seed
	_galaxy = Galaxy.generate(_galaxy_seed)
	return _galaxy


## Fresh seed, fresh conquests; energy and upgrades are kept. With no mode the
## difficulty of the previous campaign is reused.
static func begin_run(difficulty: StringName = &"") -> void:
	var fresh_seed: int = int(Time.get_unix_time_from_system()) ^ randi()
	SaveData.begin_campaign(fresh_seed, difficulty)
	_galaxy = null
	_galaxy_seed = -1
	last_result = {}
	pending_id = &""


static func start_battle(body_id: StringName) -> void:
	pending_id = body_id


static func take_pending_id() -> StringName:
	var body_id: StringName = pending_id
	pending_id = &""
	return body_id


static func battle_for(body_id: StringName) -> Battle:
	return galaxy().battle_for(body_id)


static func attackable() -> Array[StringName]:
	return galaxy().attackable(SaveData.campaign_conquered)


static func can_attack(body_id: StringName) -> bool:
	return attackable().has(body_id)


## Home is conquered from the start without being stored in the save.
static func planets_conquered() -> int:
	return mini(SaveData.campaign_conquered.size() + 1, galaxy().body_count())


static func citadels_conquered() -> int:
	return galaxy().citadel_conquered(SaveData.campaign_conquered)


## Banks a won battle: conquest, carried hull, score, flat energy and, for the
## final gate, the end of the campaign. Returns the summary for the map.
static func award_victory(
	body_id: StringName,
	score: int,
	hp: int,
	max_hp: int,
	shields: int,
	bonus_energy: int
) -> Dictionary:
	var map: Galaxy = galaxy()
	var data: Dictionary = map.body(body_id)
	SaveData.add_energy(maxi(bonus_energy, 0))
	# Healing is computed from MAX HP and added to the carried hull, clamped.
	var planets: int = planets_conquered() + (0 if SaveData.is_body_conquered(body_id) else 1)
	var fraction: float = Difficulty.heal_fraction(planets)
	var healed: int = clampi(roundi(float(max_hp) * fraction), 0, maxi(max_hp, 1))
	var new_hp: int = clampi(hp + healed, 0, maxi(max_hp, 1))
	SaveData.record_campaign_progress(
		body_id,
		SaveData.campaign_score + maxi(score, 0),
		new_hp,
		shields
	)
	var completed: bool = body_id == map.gate_id
	var result: Dictionary = {
		"won": true,
		"name": String(data.get("name", "")),
		"score": maxi(score, 0),
		"energy": maxi(bonus_energy, 0),
		"planets": planets_conquered(),
		"citadels": citadels_conquered(),
		"completed": completed,
		"difficulty": Difficulty.title(),
		"difficulty_id": SaveData.campaign_difficulty,
		"heal": new_hp - hp,
		"heal_fraction": fraction,
		"hp": new_hp,
		"max_hp": maxi(max_hp, 1),
	}
	if completed:
		SaveData.submit_score(SaveData.campaign_score)
		SaveData.finish_campaign()
	last_result = result
	return result


## Ends the run on a lost battle. The conquests stay in the save so the map
## behind the summary still shows what was taken.
## Applies the mode's on_defeat rule right away, so quitting on the game-over
## card cannot dodge it. The summary keeps the numbers of the run that ended.
static func record_defeat(
	body_id: StringName,
	score: int,
	max_hp: int = 0,
	shields: int = 0
) -> Dictionary:
	var map: Galaxy = galaxy()
	var data: Dictionary = map.body(body_id)
	var mode: StringName = Difficulty.normalise(SaveData.campaign_difficulty)
	var action: StringName = Difficulty.on_defeat(mode)
	var planets_before: int = planets_conquered()
	var citadels_before: int = citadels_conquered()
	var band: String = deepest_band()
	SaveData.campaign_score += maxi(score, 0)
	var new_high: bool = SaveData.submit_score(SaveData.campaign_score)
	var result: Dictionary = {
		"won": false,
		"name": String(data.get("name", "")),
		"score": maxi(score, 0),
		"planets": planets_before,
		"citadels": citadels_before,
		"best": maxi(SaveData.campaign_best_score, SaveData.campaign_score),
		"high": SaveData.high_score_for(mode),
		"new_high": new_high,
		"band": band,
		"difficulty": Difficulty.title(mode),
		"difficulty_id": mode,
		"action": action,
		"wiped": Tuning.DIFFICULTY_WIPE_LIST if action == Difficulty.WIPE else [],
		"hp": Difficulty.hp_after_defeat(max_hp, mode),
		"max_hp": maxi(max_hp, 0),
	}
	SaveData.finish_campaign()
	match action:
		Difficulty.KEEP:
			# The galaxy, its conquests and the score stay; only the hull is
			# restored, so the run continues from the map.
			SaveData.campaign_active = true
			SaveData.campaign_hp = Difficulty.hp_after_defeat(max_hp, mode)
			SaveData.campaign_shields = clampi(shields, 0, Tuning.MAX_SHIELD_CHARGES)
			SaveData.save_data()
		_:
			# A fresh galaxy on the same mode. SINGULARITY also loses the meta
			# progression, which is exactly what its picker warned about.
			if action == Difficulty.WIPE:
				SaveData.wipe_meta_progress()
			begin_run(mode)
	last_result = result
	return result


## Label of the deepest band the run reached, for the game-over card.
static func deepest_band() -> String:
	var map: Galaxy = galaxy()
	var deepest: StringName = map.home_id
	var best: int = -1
	for body_id: StringName in SaveData.campaign_conquered:
		var hops: int = map.distance_of(body_id)
		if hops > best:
			best = hops
			deepest = body_id
	return String(map.band_row(deepest).get("label", ""))


## Reads the pending summary (empty when there is none).
static func take_result() -> Dictionary:
	var result: Dictionary = last_result.duplicate()
	last_result = {}
	return result
