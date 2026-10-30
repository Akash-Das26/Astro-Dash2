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


## Fresh seed, fresh conquests; energy and upgrades are kept.
static func begin_run() -> void:
	var fresh_seed: int = int(Time.get_unix_time_from_system()) ^ randi()
	SaveData.begin_campaign(fresh_seed)
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
	shields: int,
	bonus_energy: int
) -> Dictionary:
	var map: Galaxy = galaxy()
	var data: Dictionary = map.body(body_id)
	SaveData.add_energy(maxi(bonus_energy, 0))
	SaveData.record_campaign_progress(
		body_id,
		SaveData.campaign_score + maxi(score, 0),
		hp,
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
	}
	if completed:
		SaveData.submit_score(SaveData.campaign_score)
		SaveData.finish_campaign()
	last_result = result
	return result


## Ends the run on a lost battle. The conquests stay in the save so the map
## behind the summary still shows what was taken.
static func record_defeat(body_id: StringName, score: int) -> Dictionary:
	var map: Galaxy = galaxy()
	var data: Dictionary = map.body(body_id)
	SaveData.campaign_score += maxi(score, 0)
	var new_high: bool = SaveData.submit_score(SaveData.campaign_score)
	var result: Dictionary = {
		"won": false,
		"name": String(data.get("name", "")),
		"score": maxi(score, 0),
		"planets": planets_conquered(),
		"citadels": citadels_conquered(),
		"best": maxi(SaveData.campaign_best_score, SaveData.campaign_score),
		"high": SaveData.high_score,
		"new_high": new_high,
		"band": deepest_band(),
	}
	SaveData.finish_campaign()
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
