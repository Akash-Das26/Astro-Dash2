class_name Upgrades
extends RefCounted
## Prices, labels and ship stats for the upgrade shop. Every number comes from
## Tuning.UPGRADES, so the shop card and the ship can never disagree about what
## a level is worth.

const MAX_LEVEL: int = Tuning.UPGRADE_MAX_LEVEL


static func cost(kind: StringName, level: int) -> int:
	if level >= MAX_LEVEL or not Tuning.UPGRADES.has(kind):
		return 0
	var row: Dictionary = Tuning.UPGRADES[kind]
	return int(row["base_cost"]) + int(row["cost_step"]) * maxi(level, 0)


static func title(kind: StringName) -> String:
	var row: Dictionary = Tuning.UPGRADES.get(kind, {})
	if row.is_empty():
		return String(kind).to_upper()
	return String(row["title"])


## Ship totals for a set of levels; missing kinds count as level 0.
static func stats_for(levels: Dictionary) -> Dictionary:
	var hull: int = level_of(levels, &"hull")
	var speed: int = level_of(levels, &"speed")
	var shield: int = level_of(levels, &"shield")
	var fire: int = level_of(levels, &"fire")
	return {
		"max_hp": Tuning.BASE_MAX_HP + (hull / Tuning.HULL_LEVELS_PER_STEP) * Tuning.HP_PER_HULL_STEP,
		"move_speed": Tuning.BASE_MOVE_SPEED + float(speed) * Tuning.SPEED_PER_LEVEL,
		"shield_charges": mini(shield / Tuning.SHIELD_LEVELS_PER_CHARGE, Tuning.MAX_SHIELD_CHARGES),
		"bullet_damage": Tuning.BASE_BULLET_DAMAGE + fire / Tuning.FIRE_LEVELS_PER_DAMAGE,
		"fire_interval": maxf(
			Tuning.MIN_FIRE_INTERVAL,
			Tuning.BASE_FIRE_INTERVAL - float(fire) * Tuning.FIRE_INTERVAL_PER_LEVEL
		),
	}


## What one track gives at this level, e.g. "HP 120" or "DMG 2  5.0/s".
static func effect_text(kind: StringName, level: int) -> String:
	var levels: Dictionary = {}
	levels[kind] = level
	var stats: Dictionary = stats_for(levels)
	match kind:
		&"hull":
			return "HP %d" % int(stats["max_hp"])
		&"speed":
			var percent: int = roundi((float(stats["move_speed"]) / Tuning.BASE_MOVE_SPEED - 1.0) * 100.0)
			return "SPEED +%d%%" % percent
		&"shield":
			return "SHIELDS %d" % int(stats["shield_charges"])
		&"fire":
			return "DMG %d  %.1f/s" % [int(stats["bullet_damage"]), 1.0 / float(stats["fire_interval"])]
		_:
			return ""


static func level_of(levels: Dictionary, kind: StringName) -> int:
	return clampi(int(levels.get(kind, 0)), 0, MAX_LEVEL)
