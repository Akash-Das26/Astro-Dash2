class_name Galaxy
extends RefCounted
## A seeded map of bodies: planets, minor rocks, citadels and one gate, laid out
## with a Poisson-disk scatter and wired to their nearest neighbours.
##
## Nothing here is stateful across sessions: the same seed always produces the
## same bodies, names and links, which is why SaveData only stores the seed and
## the set of conquered ids.

## Procedural names, one prefix plus one suffix from these two lists.
const NAME_PREFIXES: Array[String] = [
	"KEP", "VEL", "OR", "THAL", "NYX", "CER", "ARA", "VOS",
	"HEL", "MIR", "DRA", "SOL", "ZEN", "QUA", "IRI", "CAL",
]
const NAME_SUFFIXES: Array[String] = [
	"A", "OS", "IS", "UM", "AR", "UNE", "ION", "ARA", "ES", "OTH", "IX", "OVA",
]

var seed_value: int = 0
## Body id -> {id, pos, links, distance, type, trait, name, art, tint,
## station_color}. Kept in a dictionary so the map can look one up by id.
var bodies: Dictionary = {}
## Map order of every body, which is also the id order.
var order: Array[StringName] = []
var home_id: StringName = &""
var gate_id: StringName = &""


static func generate(map_seed: int) -> Galaxy:
	var galaxy := Galaxy.new()
	galaxy.seed_value = map_seed
	galaxy._build()
	return galaxy


# --- Queries ----------------------------------------------------------------

func body(body_id: StringName) -> Dictionary:
	return bodies.get(body_id, {})


func body_count() -> int:
	return order.size()


func position_of(body_id: StringName) -> Vector2:
	return body(body_id).get("pos", Vector2.ZERO)


func links_of(body_id: StringName) -> Array:
	return body(body_id).get("links", [])


func distance_of(body_id: StringName) -> int:
	return int(body(body_id).get("distance", 0))


func type_of(body_id: StringName) -> StringName:
	return body(body_id).get("type", &"minor")


func has_boss(body_id: StringName) -> bool:
	return type_of(body_id) == &"citadel"


func is_home(body_id: StringName) -> bool:
	return body_id == home_id


func is_gate(body_id: StringName) -> bool:
	return body_id == gate_id


## The home system counts as conquered without being stored, so a new run does
## not need to know its generated id before the galaxy exists.
func is_conquered(body_id: StringName, conquered: Array[StringName]) -> bool:
	return body_id == home_id or conquered.has(body_id)


## Bodies touching the conquered network that are not conquered themselves. The
## gate also needs GALAXY_CITADELS_FOR_GATE citadels down first.
func attackable(conquered: Array[StringName]) -> Array[StringName]:
	var open: Array[StringName] = []
	for body_id: StringName in order:
		if body_id == gate_id or is_conquered(body_id, conquered):
			continue
		if _touches_conquered(body_id, conquered):
			open.append(body_id)
	if gate_id != &"" and not conquered.has(gate_id) \
		and citadel_conquered(conquered) >= Tuning.GALAXY_CITADELS_FOR_GATE \
		and _touches_conquered(gate_id, conquered):
		open.append(gate_id)
	return open


func citadel_total() -> int:
	var total: int = 0
	for body_id: StringName in order:
		if has_boss(body_id):
			total += 1
	return total


func citadel_conquered(conquered: Array[StringName]) -> int:
	var total: int = 0
	for body_id: StringName in conquered:
		if bodies.has(body_id) and has_boss(body_id):
			total += 1
	return total


## Index into Tuning.GALAXY_BANDS for this body's hop distance from home.
func band_index_of(body_id: StringName) -> int:
	var hops: int = distance_of(body_id)
	for index: int in Tuning.GALAXY_BANDS.size():
		if hops <= int(Tuning.GALAXY_BANDS[index]["max_distance"]):
			return index
	return Tuning.GALAXY_BANDS.size() - 1


func band_row(body_id: StringName) -> Dictionary:
	return Tuning.GALAXY_BANDS[band_index_of(body_id)]


func trait_row(body_id: StringName) -> Dictionary:
	var trait: StringName = body(body_id).get("trait", &"minor")
	return Tuning.GALAXY_TRAITS.get(trait, Tuning.GALAXY_TRAITS[&"minor"])


## What the tooltip says about a body right now.
func status_of(body_id: StringName, conquered: Array[StringName]) -> String:
	if is_conquered(body_id, conquered):
		return "CONQUERED"
	if is_gate(body_id) and citadel_conquered(conquered) < Tuning.GALAXY_CITADELS_FOR_GATE:
		return "SEALED - %d/%d CITADELS DOWN" % [
			citadel_conquered(conquered), Tuning.GALAXY_CITADELS_FOR_GATE,
		]
	if attackable(conquered).has(body_id):
		return "READY TO ATTACK"
	return "LOCKED"


# --- Battle construction ----------------------------------------------------

## The battle for one body: the distance band sets the size and the backdrop,
## the trait bends the mix, the rock field and the payout, and a citadel adds a
## station boss on top of its last wave.
func battle_for(body_id: StringName) -> Battle:
	var data: Dictionary = body(body_id)
	var band: Dictionary = band_row(body_id)
	var trait: Dictionary = trait_row(body_id)
	var battle := Battle.new()
	battle.title = String(data.get("name", "UNKNOWN"))
	battle.waves = maxi(int(band["waves"]), 1)
	battle.enemies_per_wave = maxi(int(band["enemies"]) + int(trait["enemies_delta"]), 3)
	var mix: Dictionary = (band["mix"] as Dictionary).duplicate()
	var bonus: Dictionary = trait["mix_bonus"]
	for kind: StringName in bonus:
		mix[kind] = int(mix.get(kind, 0)) + int(bonus[kind])
	battle.enemy_mix = mix
	battle.asteroid_density = maxf(float(band["density"]) * float(trait["density_scale"]), 0.0)
	battle.background = band["background"]
	battle.hp_scale = float(band["hp_scale"]) * float(trait["hp_scale"])
	battle.fire_interval_scale = float(band["interval_scale"])
	var payout: int = roundi(float(Tuning.GALAXY_CONQUEST_ENERGY) * float(trait["energy_scale"]))
	if is_gate(body_id):
		battle.waves = maxi(battle.waves, 3)
		payout += Tuning.GALAXY_GATE_ENERGY
	if has_boss(body_id):
		battle.waves = maxi(battle.waves, 2)
		battle.boss_color = body_id_color(body_id)
		battle.boss_title = String(data.get("name", "CITADEL"))
		battle.boss_hp = Tuning.BOSS_HP + Tuning.BOSS_HP_PER_DISTANCE * distance_of(body_id)
		payout += Tuning.GALAXY_CITADEL_ENERGY
	battle.reward_energy = payout
	return battle


## The station colour a citadel fights with, kept next to the art index so the
## map sprite and the boss sprite always match.
func body_id_color(body_id: StringName) -> StringName:
	return body(body_id).get("station_color", &"red")


# --- Generation -------------------------------------------------------------

func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wanted: int = rng.randi_range(Tuning.GALAXY_BODY_COUNT_MIN, Tuning.GALAXY_BODY_COUNT_MAX)
	var points: Array[Vector2] = _poisson_points(rng, wanted)
	order.clear()
	bodies.clear()
	for index: int in points.size():
		var body_id := StringName("b%d" % index)
		order.append(body_id)
		bodies[body_id] = {
			"id": body_id,
			"pos": points[index],
			"links": [],
			"distance": 999,
			"type": &"minor",
			"trait": &"minor",
			"name": "",
			"art": 0,
			"tint": Color.WHITE,
			"station_color": &"red",
		}
	if order.is_empty():
		push_warning("Galaxy seed %d produced no bodies." % seed_value)
		return
	home_id = _closest_to(Tuning.GALAXY_HOME_ANCHOR)
	_link_neighbours()
	_connect_components()
	_compute_distances()
	gate_id = _farthest_from_home()
	_assign_types(rng)
	_assign_names(rng)


## Dart throwing with a shrinking radius: the first pass is proper blue noise,
## and only a very unlucky seed needs the relaxed ones.
func _poisson_points(rng: RandomNumberGenerator, wanted: int) -> Array[Vector2]:
	var spacing: float = Tuning.GALAXY_MIN_SPACING
	var best: Array[Vector2] = []
	for _relax: int in 3:
		var points: Array[Vector2] = _dart_throw(rng, wanted, spacing)
		if points.size() > best.size():
			best = points
		if best.size() >= wanted:
			break
		spacing *= 0.86
	return best


func _dart_throw(rng: RandomNumberGenerator, wanted: int, spacing: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var spacing_squared: float = spacing * spacing
	var min_x: float = Tuning.GALAXY_EDGE_MARGIN
	var max_x: float = Tuning.GALAXY_MAP_SIZE.x - Tuning.GALAXY_EDGE_MARGIN
	var min_y: float = Tuning.GALAXY_EDGE_MARGIN
	var max_y: float = Tuning.GALAXY_MAP_SIZE.y - Tuning.GALAXY_EDGE_MARGIN
	var attempts: int = 0
	while points.size() < wanted and attempts < 4000:
		attempts += 1
		var candidate := Vector2(
			rng.randf_range(min_x, max_x),
			rng.randf_range(min_y, max_y)
		)
		var clear: bool = true
		for other: Vector2 in points:
			if candidate.distance_squared_to(other) < spacing_squared:
				clear = false
				break
		if clear:
			points.append(candidate)
	return points


func _closest_to(target: Vector2) -> StringName:
	var best: StringName = order[0]
	var best_distance: float = INF
	for body_id: StringName in order:
		var distance: float = position_of(body_id).distance_squared_to(target)
		if distance < best_distance:
			best_distance = distance
			best = body_id
	return best


## Every body reaches out to its nearest neighbours, so the graph is local and
## the map reads as a starmap instead of a hairball.
func _link_neighbours() -> void:
	for body_id: StringName in order:
		var scored: Array[Dictionary] = []
		for other: StringName in order:
			if other == body_id:
				continue
			scored.append({
				"id": other,
				"d": position_of(body_id).distance_to(position_of(other)),
			})
		scored.sort_custom(_closer)
		var made: int = 0
		for row: Dictionary in scored:
			if made >= Tuning.GALAXY_LINKS_PER_BODY:
				break
			if float(row["d"]) > Tuning.GALAXY_MAX_LINK_LENGTH:
				break
			_add_link(body_id, row["id"])
			made += 1


static func _closer(a: Dictionary, b: Dictionary) -> bool:
	return float(a["d"]) < float(b["d"])


static func _farther(a: Dictionary, b: Dictionary) -> bool:
	return int(a["d"]) > int(b["d"])


func _add_link(a: StringName, b: StringName) -> void:
	if a == b or not bodies.has(a) or not bodies.has(b):
		return
	var a_links: Array = bodies[a]["links"]
	var b_links: Array = bodies[b]["links"]
	if not a_links.has(b):
		a_links.append(b)
	if not b_links.has(a):
		b_links.append(a)


func _reachable(from_id: StringName) -> Array[StringName]:
	var seen: Array[StringName] = []
	if from_id == &"":
		return seen
	var queue: Array[StringName] = [from_id]
	seen.append(from_id)
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		for other: StringName in links_of(current):
			if seen.has(other):
				continue
			seen.append(other)
			queue.append(other)
	return seen


## Nearest-neighbour links can leave islands. Bridge the closest pair between
## the reachable network and each island until every body is reachable.
func _connect_components() -> void:
	var seen: Array[StringName] = _reachable(home_id)
	var guard: int = 0
	while seen.size() < order.size() and guard < 256:
		guard += 1
		var best_a: StringName = &""
		var best_b: StringName = &""
		var best_distance: float = INF
		for a: StringName in seen:
			for b: StringName in order:
				if seen.has(b):
					continue
				var distance: float = position_of(a).distance_to(position_of(b))
				if distance < best_distance:
					best_distance = distance
					best_a = a
					best_b = b
		if best_b == &"":
			return
		_add_link(best_a, best_b)
		seen = _reachable(home_id)


## Hop count from home, which is what every difficulty table is keyed to.
func _compute_distances() -> void:
	for body_id: StringName in order:
		bodies[body_id]["distance"] = 999
	bodies[home_id]["distance"] = 0
	var queue: Array[StringName] = [home_id]
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		var next_distance: int = int(bodies[current]["distance"]) + 1
		for other: StringName in links_of(current):
			if int(bodies[other]["distance"]) <= next_distance:
				continue
			bodies[other]["distance"] = next_distance
			queue.append(other)


func _farthest_from_home() -> StringName:
	var best: StringName = &""
	var best_hops: int = -1
	var best_distance: float = -1.0
	for body_id: StringName in order:
		if body_id == home_id:
			continue
		var hops: int = distance_of(body_id)
		var distance: float = position_of(body_id).distance_to(position_of(home_id))
		if hops > best_hops or (hops == best_hops and distance > best_distance):
			best = body_id
			best_hops = hops
			best_distance = distance
	return best


func _assign_types(rng: RandomNumberGenerator) -> void:
	bodies[home_id]["type"] = &"home"
	bodies[home_id]["trait"] = &"home"
	bodies[home_id]["tint"] = Tuning.GALAXY_MARKER_TINTS[&"home"]
	if gate_id != &"":
		bodies[gate_id]["type"] = &"gate"
		bodies[gate_id]["trait"] = &"gate"
		bodies[gate_id]["tint"] = Tuning.GALAXY_MARKER_TINTS[&"gate"]

	# One station colour per citadel, cycling through all four.
	var color_index: int = 0
	for body_id: StringName in _citadel_slots():
		var color: StringName = Tuning.GALAXY_STATION_COLORS[
			color_index % Tuning.GALAXY_STATION_COLORS.size()
		]
		bodies[body_id]["type"] = &"citadel"
		bodies[body_id]["trait"] = &"citadel"
		bodies[body_id]["station_color"] = color
		bodies[body_id]["art"] = color_index % Tuning.GALAXY_STATION_COLORS.size()
		var station_tints: Array = Tuning.GALAXY_TINTS[&"citadel"]
		bodies[body_id]["tint"] = station_tints[color_index % station_tints.size()]
		color_index += 1

	# Everything else cycles through the six planet sprites and the three rocks,
	# with a per-kind counter so both variants of every planet appear.
	var cycle: Array[StringName] = [
		&"minor", &"gas", &"ocean", &"rocky", &"minor", &"ocean", &"gas", &"rocky",
	]
	var counters: Dictionary = {&"minor": 0, &"rocky": 0, &"ocean": 0, &"gas": 0}
	var step: int = 0
	for body_id: StringName in order:
		var current: StringName = bodies[body_id]["type"]
		if current == &"home" or current == &"gate" or current == &"citadel":
			continue
		var kind: StringName = cycle[step % cycle.size()]
		step += 1
		var art: int = int(counters[kind])
		counters[kind] = art + 1
		bodies[body_id]["type"] = kind
		bodies[body_id]["art"] = art
		var tints: Array = Tuning.GALAXY_TINTS.get(kind, Tuning.GALAXY_TINTS[&"minor"])
		bodies[body_id]["tint"] = tints[art % tints.size()]
		bodies[body_id]["trait"] = _trait_for(kind, rng)


## Citadels are spread across the far half of the graph so they read as guarded
## strongholds rather than a cluster next to home.
func _citadel_slots() -> Array[StringName]:
	var scored: Array[Dictionary] = []
	for body_id: StringName in order:
		if body_id == home_id or body_id == gate_id:
			continue
		if distance_of(body_id) < 2:
			continue
		scored.append({"id": body_id, "d": distance_of(body_id)})
	scored.sort_custom(_farther)
	var wanted: int = mini(Tuning.GALAXY_CITADEL_COUNT, scored.size())
	var slots: Array[StringName] = []
	for index: int in wanted:
		var pick: int = 0
		if wanted > 1:
			pick = roundi(float(index) * float(scored.size() - 1) / float(wanted - 1))
		pick = clampi(pick, 0, scored.size() - 1)
		while slots.has(scored[pick]["id"]) and slots.size() < scored.size():
			pick = (pick + 1) % scored.size()
		slots.append(scored[pick]["id"])
	return slots


func _trait_for(kind: StringName, rng: RandomNumberGenerator) -> StringName:
	match kind:
		&"rocky":
			return _pick(rng, [&"resource", &"fortress", &"minor"])
		&"ocean":
			return _pick(rng, [&"fertile", &"resource"])
		&"gas":
			return _pick(rng, [&"resource", &"fortress", &"fertile"])
		_:
			return &"minor"


static func _pick(rng: RandomNumberGenerator, options: Array) -> StringName:
	return options[rng.randi() % options.size()]


func _assign_names(rng: RandomNumberGenerator) -> void:
	var used: Dictionary = {}
	for body_id: StringName in order:
		var kind: StringName = bodies[body_id]["type"]
		if kind == &"home":
			bodies[body_id]["name"] = "HOME SYSTEM"
			continue
		if kind == &"gate":
			bodies[body_id]["name"] = "THE FINAL GATE"
			continue
		bodies[body_id]["name"] = _make_name(rng, used)


func _make_name(rng: RandomNumberGenerator, used: Dictionary) -> String:
	for _try: int in 16:
		var candidate: String = NAME_PREFIXES[rng.randi() % NAME_PREFIXES.size()] \
			+ NAME_SUFFIXES[rng.randi() % NAME_SUFFIXES.size()]
		if used.has(candidate):
			continue
		used[candidate] = true
		return candidate
	var fallback: String = NAME_PREFIXES[rng.randi() % NAME_PREFIXES.size()] + " %d" % (used.size() + 1)
	used[fallback] = true
	return fallback


func _touches_conquered(body_id: StringName, conquered: Array[StringName]) -> bool:
	for other: StringName in links_of(body_id):
		if is_conquered(other, conquered):
			return true
	return false
