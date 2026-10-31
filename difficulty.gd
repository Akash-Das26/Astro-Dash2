class_name Difficulty
extends RefCounted
## The five campaign modes: the between-planet heal, what a defeat costs, and
## the battle multipliers. Every number lives in Tuning.DIFFICULTIES; this class
## only reads the table and turns it into text.

const KEEP: StringName = &"keep"
const RESET: StringName = &"reset"
const WIPE: StringName = &"wipe"


static func row(id: StringName) -> Dictionary:
	if not Tuning.DIFFICULTIES.has(id):
		return Tuning.DIFFICULTIES[Tuning.DIFFICULTY_DEFAULT]
	return Tuning.DIFFICULTIES[id]


## The mode of the run that is playing. A battle outside a campaign (the debug
## harness) is unscaled, so the harness stays predictable.
static func active() -> StringName:
	if not SaveData.campaign_active:
		return Tuning.DIFFICULTY_DEFAULT
	return normalise(SaveData.campaign_difficulty)


static func normalise(id: StringName) -> StringName:
	if Tuning.DIFFICULTIES.has(id):
		return id
	return Tuning.DIFFICULTY_DEFAULT


static func title(id: StringName = &"") -> String:
	var mode: StringName = active() if id == &"" else normalise(id)
	return String(row(mode)["title"])


static func color(id: StringName = &"") -> Color:
	var mode: StringName = active() if id == &"" else normalise(id)
	return row(mode)["color"]


static func on_defeat(id: StringName = &"") -> StringName:
	var mode: StringName = active() if id == &"" else normalise(id)
	return StringName(String(row(mode)["on_defeat"]))


static func defeat_hp(id: StringName = &"") -> float:
	var mode: StringName = active() if id == &"" else normalise(id)
	return float(row(mode)["defeat_hp"])


static func enemy_hp_scale(id: StringName = &"") -> float:
	var mode: StringName = active() if id == &"" else normalise(id)
	return float(row(mode)["enemy_hp"])


static func enemy_damage_scale(id: StringName = &"") -> float:
	var mode: StringName = active() if id == &"" else normalise(id)
	return float(row(mode)["enemy_damage"])


static func enemies_scale(id: StringName = &"") -> float:
	var mode: StringName = active() if id == &"" else normalise(id)
	return float(row(mode)["enemies"])


static func energy_scale(id: StringName = &"") -> float:
	var mode: StringName = active() if id == &"" else normalise(id)
	return float(row(mode)["energy"])


static func score_scale(id: StringName = &"") -> float:
	var mode: StringName = active() if id == &"" else normalise(id)
	return float(row(mode)["score"])


static func shield_drop_scale(id: StringName = &"") -> float:
	var mode: StringName = active() if id == &"" else normalise(id)
	return float(row(mode)["shield_drop"])


## Fraction of MAX HP healed by conquering the planet that brought the count to
## `planets`. The largest reached milestone replaces the per-planet heal.
static func heal_fraction(planets: int, id: StringName = &"") -> float:
	var mode: StringName = active() if id == &"" else normalise(id)
	var data: Dictionary = row(mode)
	var best_key: int = -1
	var best_value: float = 0.0
	var milestones: Dictionary = data.get("milestones", {})
	for key: Variant in milestones:
		var at: int = int(key)
		if planets >= at and at > best_key:
			best_key = at
			best_value = float(milestones[key])
	if best_key >= 0:
		return clampf(best_value, 0.0, 1.0)
	return clampf(float(data.get("heal_per_planet", 0.0)), 0.0, 1.0)


## HP after a defeat: a fraction of max, clamped, never negative.
static func hp_after_defeat(max_hp: int, id: StringName = &"") -> int:
	return clampi(roundi(float(max_hp) * defeat_hp(id)), 0, maxi(max_hp, 1))


## The one-line rule shown on the picker button, generated from the table.
static func summary(id: StringName) -> String:
	var mode: StringName = normalise(id)
	var data: Dictionary = row(mode)
	var parts: PackedStringArray = []
	var per_planet: float = float(data.get("heal_per_planet", 0.0))
	if per_planet > 0.0 and per_planet >= 0.999:
		parts.append("FULL HEAL PER PLANET")
	elif per_planet > 0.0:
		parts.append("HEAL %d%% PER PLANET" % roundi(per_planet * 100.0))
	else:
		parts.append("NO HEAL PER PLANET")
	var milestones: Dictionary = data.get("milestones", {})
	var keys: Array = milestones.keys()
	keys.sort()
	for key: Variant in keys:
		var fraction: float = float(milestones[key])
		var label: String = "FULL" if fraction >= 0.999 else "%d%%" % roundi(fraction * 100.0)
		parts.append("%s AT %d" % [label, int(key)])
	parts.append(defeat_text(mode))
	return " | ".join(parts)


static func defeat_text(id: StringName) -> String:
	match on_defeat(id):
		KEEP:
			return "DEATH KEEPS PLANETS"
		RESET:
			return "DEATH: NEW GALAXY"
		_:
			return "DEATH WIPES EVERYTHING"


## Button caption on the game-over card, straight from the on_defeat rule.
static func defeat_button(id: StringName = &"") -> String:
	match on_defeat(id):
		KEEP:
			return "RETURN TO MAP"
		RESET:
			return "NEW GALAXY"
		_:
			return "START OVER"


static func defeat_hint(id: StringName = &"") -> String:
	match on_defeat(id):
		KEEP:
			return "PROGRESS KEPT   |   HULL %d%%" % roundi(defeat_hp(id) * 100.0)
		RESET:
			return "PLANETS RESET   |   ENERGY AND UPGRADES KEPT"
		_:
			return "WIPED: %s" % ", ".join(Tuning.DIFFICULTY_WIPE_LIST)
