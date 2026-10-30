class_name Weapons
extends RefCounted
## The data-driven weapon table. Every number lives in Tuning.WEAPONS, so the
## upgrade screen, the HUD and the battle can never disagree about what a
## weapon is worth.
##
## FIRE POWER is the one shared upgrade: it multiplies the damage of both slots
## and shortens their cooldowns. Only the PULSE LASER still changes sprite with
## the fire-power tier, because its art is the laser itself.

const DEFAULT_ID: StringName = &"pulse"


static func exists(id: StringName) -> bool:
	return Tuning.WEAPONS.has(id)


static func entry(id: StringName) -> Dictionary:
	return Tuning.WEAPONS.get(id, {})


static func all() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id: StringName in Tuning.WEAPON_ORDER:
		var data: Dictionary = entry(id)
		if not data.is_empty():
			rows.append(data)
	return rows


static func ids() -> Array[StringName]:
	return Tuning.WEAPON_ORDER.duplicate()


static func title(id: StringName) -> String:
	return String(entry(id).get("title", String(id).to_upper()))


static func description(id: StringName) -> String:
	return String(entry(id).get("desc", ""))


static func texture(id: StringName) -> Texture2D:
	return entry(id).get("texture") as Texture2D


static func color(id: StringName) -> Color:
	return entry(id).get("color", Color.WHITE)


static func cost(id: StringName) -> int:
	return int(entry(id).get("cost", 0))


## Planets conquered needed before the weapon can be bought or equipped.
static func unlock_planets(id: StringName) -> int:
	return int(entry(id).get("unlock", 0))


static func is_unlocked(id: StringName) -> bool:
	if not exists(id):
		return false
	# The live campaign owns the conquest count; between campaigns the best run
	# ever stands in, so a weapon earned once is not taken away.
	var conquered: int = SaveData.campaign_best_planets
	if SaveData.campaign_active:
		conquered = maxi(conquered, SaveData.campaign_conquered.size())
	return conquered >= unlock_planets(id)


static func owned(id: StringName) -> bool:
	return SaveData.owns_weapon(id)


## Bought and unlocked: the only state that may be equipped.
static func usable(id: StringName) -> bool:
	return exists(id) and owned(id) and is_unlocked(id)


## Damage per projectile after the FIRE POWER multiplier.
static func damage(id: StringName, stats: Dictionary) -> int:
	var base: float = float(entry(id).get("damage", 1.0))
	var mult: float = float(stats.get("damage_mult", 1.0))
	return maxi(1, roundi(base * mult))


## Seconds between shots after the FIRE POWER cooldown multiplier.
static func interval(id: StringName, stats: Dictionary) -> float:
	var base: float = float(entry(id).get("interval", 0.2))
	var mult: float = float(stats.get("cooldown_mult", 1.0))
	return maxf(0.05, base * mult)


static func projectile_count(id: StringName) -> int:
	return maxi(1, int(entry(id).get("count", 1)))


## Whole-volley damage per second, for the upgrade card.
static func dps(id: StringName, stats: Dictionary) -> float:
	if not exists(id):
		return 0.0
	var per_shot: int = damage(id, stats)
	var shots: int = projectile_count(id)
	return float(per_shot * shots) / interval(id, stats)
