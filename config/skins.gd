class_name Skins
extends RefCounted
## Hull skins: four plain ships, then the six stroked hulls. Each one unlocks at
## a planets-conquered milestone so the picker doubles as a progress readout.
##
## `SaveData.skin_id` stores only the id; validation lives here so the save file
## can never point at a hull the player has not unlocked (a hand-edited or old
## save simply falls back to the first skin).

const DEFAULT_ID: StringName = &"red"
const PLANETS_PER_UNLOCK: int = 5

const LIST: Array[Dictionary] = [
	{
		"id": &"red", "title": "CRIMSON", "unlock": 0, "scale": 0.4,
		"texture": preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship_red.png"),
	},
	{
		"id": &"blue", "title": "COBALT", "unlock": 5, "scale": 0.4,
		"texture": preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship_blue.png"),
	},
	{
		"id": &"green", "title": "JADE", "unlock": 10, "scale": 0.55,
		# The pack has no full-size green hull; this is its green interceptor.
		"texture": preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship_green_small_2.png"),
	},
	{
		"id": &"yellow", "title": "AMBER", "unlock": 15, "scale": 0.4,
		"texture": preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship_yellow.png"),
	},
	{
		"id": &"stroke_red", "title": "STROKED RED", "unlock": 20, "scale": 0.4,
		"texture": preload("res://assets/sprites/spacepixels_ships_stroked/space_pixels_ships_stroked/ship_red_stroked.png"),
	},
	{
		"id": &"stroke_blue", "title": "STROKED BLUE", "unlock": 25, "scale": 0.4,
		"texture": preload("res://assets/sprites/spacepixels_ships_stroked/space_pixels_ships_stroked/ship_blue_stroked.png"),
	},
	{
		"id": &"stroke_green", "title": "STROKED GREEN", "unlock": 30, "scale": 0.4,
		"texture": preload("res://assets/sprites/spacepixels_ships_stroked/space_pixels_ships_stroked/ship_green_stroked.png"),
	},
	{
		"id": &"stroke_orange", "title": "STROKED ORANGE", "unlock": 35, "scale": 0.4,
		"texture": preload("res://assets/sprites/spacepixels_ships_stroked/space_pixels_ships_stroked/ship_orange_stroked.png"),
	},
	{
		"id": &"stroke_purple", "title": "STROKED PURPLE", "unlock": 40, "scale": 0.4,
		"texture": preload("res://assets/sprites/spacepixels_ships_stroked/space_pixels_ships_stroked/ship_purple_stroked.png"),
	},
	{
		"id": &"stroke_yellow", "title": "STROKED YELLOW", "unlock": 45, "scale": 0.4,
		"texture": preload("res://assets/sprites/spacepixels_ships_stroked/space_pixels_ships_stroked/ship_yellow_stroked.png"),
	},
]


static func all() -> Array[Dictionary]:
	return LIST


static func has(id: StringName) -> bool:
	for skin: Dictionary in LIST:
		if skin["id"] == id:
			return true
	return false


static func entry(id: StringName) -> Dictionary:
	for skin: Dictionary in LIST:
		if skin["id"] == id:
			return skin
	return LIST[0]


static func title(id: StringName) -> String:
	return String(entry(id).get("title", "UNKNOWN"))


static func texture(id: StringName) -> Texture2D:
	return entry(id).get("texture") as Texture2D


static func scale_of(id: StringName) -> float:
	return float(entry(id).get("scale", 0.4))


## Planets conquered: the best run, the current run and the lifetime total. The
## lifetime count matters because a galaxy holds about 43-53 planets, so the top
## milestones (40 and 45) cannot be reached inside one campaign on a small map.
static func planets() -> int:
	return maxi(
		maxi(SaveData.campaign_best_planets, SaveData.campaign_conquered.size()),
		SaveData.lifetime_planets
	)


static func is_unlocked(id: StringName) -> bool:
	if not has(id):
		return false
	return planets() >= int(entry(id).get("unlock", 0))


## The id the ship should wear, with a fallback for a locked or unknown id.
static func selected() -> StringName:
	var id: StringName = SaveData.skin_id
	if is_unlocked(id):
		return id
	return DEFAULT_ID


static func select(id: StringName) -> bool:
	if not is_unlocked(id):
		return false
	SaveData.skin_id = id
	SaveData.save_data()
	return true


## The next locked hull, or an empty dictionary when everything is unlocked.
static func next_unlock() -> Dictionary:
	for skin: Dictionary in LIST:
		if not is_unlocked(skin["id"]):
			return skin
	return {}
