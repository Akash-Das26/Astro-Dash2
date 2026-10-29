class_name Campaign
extends RefCounted
## Static helpers over the sector graph in Tuning.CAMPAIGN_SECTORS. No state
## lives here: who has conquered what is SaveData's business, so this file can
## answer "what is unlocked", "how hard is this sector" and "what waves does it
## spawn" without touching the runtime.

## Sectors the player may attack right now, in map order.
static func available_ids(conquered: Array[StringName]) -> Array[StringName]:
	var available: Array[StringName] = []
	for sector_id: StringName in Tuning.CAMPAIGN_ORDER:
		if conquered.has(sector_id):
			continue
		if _is_unlocked(sector_id, conquered):
			available.append(sector_id)
	return available


static func total_sectors() -> int:
	return Tuning.CAMPAIGN_ORDER.size()


static func exists(sector_id: StringName) -> bool:
	return Tuning.CAMPAIGN_SECTORS.has(sector_id)


static func sector(sector_id: StringName) -> Dictionary:
	return Tuning.CAMPAIGN_SECTORS.get(sector_id, {})


static func title(sector_id: StringName) -> String:
	return String(sector(sector_id).get("name", String(sector_id).to_upper()))


static func tier_of(sector_id: StringName) -> int:
	return maxi(int(sector(sector_id).get("tier", 1)), 1)


static func wave_count(sector_id: StringName) -> int:
	return maxi(int(sector(sector_id).get("waves", 1)), 1)


static func has_boss(sector_id: StringName) -> bool:
	return bool(sector(sector_id).get("boss", false))


static func position_of(sector_id: StringName) -> Vector2:
	return sector(sector_id).get("pos", Vector2.ZERO)


static func links_of(sector_id: StringName) -> Array:
	return sector(sector_id).get("links", [])


## The last sector has nowhere further to go.
static func is_final(sector_id: StringName) -> bool:
	return links_of(sector_id).is_empty()


## One composition per wave. Every wave uses the sector mix; a boss sector adds
## the boss to its last wave, so clearing the boss clears the sector.
static func waves_for(sector_id: StringName) -> Array[Dictionary]:
	var count: int = wave_count(sector_id)
	var mix: Dictionary = sector(sector_id).get("mix", {})
	var waves: Array[Dictionary] = []
	for index: int in count:
		var composition: Dictionary = mix.duplicate()
		if has_boss(sector_id) and index == count - 1:
			composition["boss"] = 1
		waves.append(composition)
	return waves


static func difficulty_for(sector_id: StringName) -> Dictionary:
	return difficulty_for_tier(tier_of(sector_id))


static func difficulty_for_tier(tier: int) -> Dictionary:
	var row: Dictionary = Tuning.CAMPAIGN_TIER_DIFFICULTY.get(tier, {})
	if row.is_empty():
		row = Tuning.CAMPAIGN_TIER_DIFFICULTY[1]
	return row


static func highest_tier(conquered: Array[StringName]) -> int:
	var best: int = 0
	for sector_id: StringName in conquered:
		best = maxi(best, tier_of(sector_id))
	return best


## A sector is tappable when it is not conquered and either it is a starting
## sector (nothing conquered yet) or a conquered sector links to it.
static func _is_unlocked(sector_id: StringName, conquered: Array[StringName]) -> bool:
	if conquered.is_empty():
		return Tuning.CAMPAIGN_START.has(sector_id)
	for done: StringName in conquered:
		if links_of(done).has(sector_id):
			return true
	return false
