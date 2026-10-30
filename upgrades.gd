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
	# Step sizes are whole levels, so these divisions floor on purpose:
	# 3 hull levels = +20 HP, 3 shield levels = +1 charge, 3 fire levels = +1 damage.
	@warning_ignore("integer_division")
	var hull_steps: int = hull / Tuning.HULL_LEVELS_PER_STEP
	@warning_ignore("integer_division")
	var shield_steps: int = shield / Tuning.SHIELD_LEVELS_PER_CHARGE
	@warning_ignore("integer_division")
	var damage_steps: int = fire / Tuning.FIRE_LEVELS_PER_DAMAGE
	return {
		"max_hp": Tuning.BASE_MAX_HP + hull_steps * Tuning.HP_PER_HULL_STEP,
		"move_speed": Tuning.BASE_MOVE_SPEED + float(speed) * Tuning.SPEED_PER_LEVEL,
		"shield_charges": mini(shield_steps, Tuning.MAX_SHIELD_CHARGES),
		"bullet_damage": Tuning.BASE_BULLET_DAMAGE + damage_steps,
		"bullet_tier": mini(damage_steps, 2),
		"shield_recharge": shield_recharge(shield),
		"fire_interval": maxf(
			Tuning.MIN_FIRE_INTERVAL,
			Tuning.BASE_FIRE_INTERVAL - float(fire) * Tuning.FIRE_INTERVAL_PER_LEVEL
		),
	}


## Seconds per recharged shield charge for a SHIELDS level. Level 0 means no
## recharge at all; drops still work, so a shield is always reachable.
static func shield_recharge(level: int) -> float:
	if level <= 0:
		return 0.0
	return maxf(
		Tuning.SHIELD_RECHARGE_MIN,
		Tuning.SHIELD_RECHARGE_BASE - float(level - 1) * Tuning.SHIELD_RECHARGE_STEP
	)


## The label on an upgrade card, naming the direction of the track.
static func card_title(kind: StringName) -> String:
	match kind:
		&"hull":
			return "HEALTH +20"
		&"speed":
			return "SPEED +1"
		&"shield":
			return "SHIELDS +1"
		&"fire":
			return "FIRE POWER +1"
		_:
			return title(kind)


## Precise effect of one level, for the card tooltip.
static func tooltip(kind: StringName) -> String:
	match kind:
		&"hull":
			return "+20 MAX HP every %d levels." % Tuning.HULL_LEVELS_PER_STEP
		&"speed":
			return "+%d px/s flight speed per level." % roundi(Tuning.SPEED_PER_LEVEL)
		&"shield":
			return "+1 starting charge every %d levels, max %d. At level 1+ one charge recharges every %.0fs once you have not been hit for %.0fs, down to %.0fs at max. Drops always give +1." % [
				Tuning.SHIELD_LEVELS_PER_CHARGE, Tuning.MAX_SHIELD_CHARGES,
				Tuning.SHIELD_RECHARGE_BASE,
				Tuning.SHIELD_RECHARGE_DAMAGE_DELAY,
				shield_recharge(MAX_LEVEL),
			]
		&"fire":
			return "+1 bullet damage every %d levels; the laser turns green at level %d and yellow at level %d." % [
				Tuning.FIRE_LEVELS_PER_DAMAGE,
				Tuning.FIRE_LEVELS_PER_DAMAGE,
				Tuning.FIRE_LEVELS_PER_DAMAGE * 2,
			]
		_:
			return ""


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
