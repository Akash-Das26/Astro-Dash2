extends Node
## Persists progress and settings between sessions in user://save.cfg.
## Works on desktop, web and Android because user:// is mapped per platform
## by the engine.

const SAVE_PATH: String = "user://save.cfg"
const SECTION_PROGRESS: String = "progress"
const SECTION_AUDIO: String = "audio"
const SECTION_GAMEPLAY: String = "gameplay"
const SECTION_UPGRADES: String = "upgrades"
const SECTION_CAMPAIGN: String = "campaign"
const SECTION_WEAPONS: String = "weapons"
const SECTION_CONTROLS: String = "controls"
const KEY_HIGH_SCORE: String = "high_score"
const KEY_ENERGY: String = "energy"
const KEY_SKIN: String = "skin"
const KEY_REDUCE_MOTION: String = "reduce_motion"
const KEY_MUSIC_VOLUME: String = "music_volume"
const KEY_SFX_VOLUME: String = "sfx_volume"
const KEY_MUTED: String = "muted"
const KEY_AUTO_FIRE: String = "auto_fire"
const KEY_HIGH_CONTRAST: String = "high_contrast_bullets"
const KEY_MUSIC_ORDER: String = "music_order"
const KEY_CONTROL_SCHEME: String = "control_scheme"
const KEY_SHIELD_MODE: String = "shield_mode"
const KEY_CAMPAIGN_ACTIVE: String = "active"
const KEY_CAMPAIGN_SEED: String = "seed"
const KEY_CAMPAIGN_SCORE: String = "score"
const KEY_CAMPAIGN_HP: String = "hp"
const KEY_CAMPAIGN_SHIELDS: String = "shields"
const KEY_CAMPAIGN_CONQUERED: String = "conquered"
const KEY_CAMPAIGN_BEST_SCORE: String = "best_score"
const KEY_CAMPAIGN_BEST_PLANETS: String = "best_planets"
const KEY_WEAPONS_OWNED: String = "owned"
const KEY_WEAPON_PRIMARY: String = "primary"
const KEY_WEAPON_SECONDARY: String = "secondary"

var high_score: int = 0
## Spendable currency, earned by killing enemies and spent in the upgrade shop.
var energy: int = 0
## Upgrade kind (StringName) -> level 0..Tuning.UPGRADE_MAX_LEVEL.
var upgrade_levels: Dictionary = {}
## Hull the ship wears. Skins.selected() checks the id against the unlocks, so
## an unknown or locked id simply falls back to the first hull.
var skin_id: StringName = &"red"
## Campaign run in progress: the map seed, the conquered body ids, the carried
## hull and shields, and the accumulated score. Energy and upgrades are
## meta-progression and live outside the run.
var campaign_active: bool = false
var campaign_seed: int = 0
var campaign_conquered: Array[StringName] = []
var campaign_score: int = 0
var campaign_hp: int = 0
var campaign_shields: int = 0
## Best campaign ever finished, for the summaries and the menu.
var campaign_best_score: int = 0
var campaign_best_planets: int = 0
## Weapons are meta-progression: bought once with energy, kept across campaigns.
## The pulse laser is always owned, so an old save with no weapon keys works.
var weapons_owned: Array[StringName] = [Weapons.DEFAULT_ID]
var weapon_primary: StringName = Weapons.DEFAULT_ID
## Empty means the secondary hardpoint has no gun equipped yet.
var weapon_secondary: StringName = &""
## Rebound inputs, serialized InputEvents per action. A missing entry means
## "use the project's own binding", so old saves keep working unchanged.
var keyboard_bindings: Dictionary = {}
var gamepad_bindings: Dictionary = {}
## FREE AIM (twin-stick) or CLASSIC (turn/thrust); see Tuning.CONTROL_SCHEME_*.
var control_scheme: StringName = Tuning.CONTROL_SCHEME_DEFAULT
## AUTO or MANUAL shield (see Tuning.SHIELD_MODE_*).
var shield_mode: StringName = Tuning.SHIELD_MODE_DEFAULT
## Playlist rotation, `shuffle` or `in_order` (see Tuning.MUSIC_ORDER_*).
var music_order: StringName = Tuning.MUSIC_ORDER_SHUFFLE
var music_volume: float = 0.8
var sfx_volume: float = 0.8
var muted: bool = false
var reduce_motion: bool = false
## Touch only: fire while a finger is on the screen. On by default because a
## phone has no fire key.
var auto_fire: bool = true
## Enemy bullets get a thicker outline and a brighter halo when this is on.
var high_contrast_bullets: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_upgrade_levels()
	load_data()
	# The InputMap is rebuilt once, before any screen reads an action.
	Controls.apply_saved()


## Records a finished run. Returns true when it beat the stored record.
func submit_score(score: int) -> bool:
	if score <= high_score:
		return false
	high_score = score
	save_data()
	return true


## Energy is banked as it is collected, so a run that is abandoned still keeps it.
func add_energy(amount: int) -> void:
	energy = maxi(energy + amount, 0)


func level_of(kind: StringName) -> int:
	return Upgrades.level_of(upgrade_levels, kind)


## 0 when the track is already maxed.
func next_upgrade_cost(kind: StringName) -> int:
	return Upgrades.cost(kind, level_of(kind))


## Spends energy and raises one track by a level. Saves on success.
func buy_upgrade(kind: StringName) -> bool:
	var price: int = next_upgrade_cost(kind)
	if price <= 0 or energy < price:
		return false
	energy -= price
	upgrade_levels[kind] = level_of(kind) + 1
	save_data()
	return true


func owns_weapon(id: StringName) -> bool:
	return weapons_owned.has(id)


## Buys a weapon with energy. The planet gate is checked here as well, so a
## purchase can never outrun the campaign that unlocked it.
func buy_weapon(id: StringName) -> bool:
	if not Weapons.exists(id) or owns_weapon(id) or not Weapons.is_unlocked(id):
		return false
	var price: int = Weapons.cost(id)
	if price <= 0 or energy < price:
		return false
	energy -= price
	weapons_owned.append(id)
	save_data()
	return true


## Equips an owned, unlocked weapon in slot 0 (primary) or 1 (secondary). A
## weapon may not sit in both slots, so equipping it in the other one frees it.
func equip_weapon(id: StringName, slot: int) -> bool:
	if not Weapons.usable(id):
		return false
	if slot == 0:
		if weapon_primary == id:
			return false
		if weapon_secondary == id:
			weapon_secondary = &""
		weapon_primary = id
	elif slot == 1:
		if weapon_secondary == id or weapon_primary == id:
			return false
		weapon_secondary = id
	else:
		return false
	save_data()
	return true


## Starts (or restarts) a campaign on a fresh galaxy. Conquests, hull and score
## reset; energy and upgrades are meta-progression and deliberately survive.
func begin_campaign(map_seed: int) -> void:
	campaign_active = true
	campaign_seed = map_seed
	campaign_conquered.clear()
	campaign_score = 0
	campaign_hp = 0
	campaign_shields = 0
	save_data()


## Saves the campaign after a body is conquered, without ending it. The hull and
## shields are the ones the ship finished the battle with, so they carry into
## the next battle (and survive a quit).
func record_campaign_progress(body_id: StringName, score: int, hp: int, shields: int) -> void:
	if not campaign_conquered.has(body_id):
		campaign_conquered.append(body_id)
	campaign_score = maxi(score, 0)
	campaign_hp = maxi(hp, 0)
	campaign_shields = clampi(shields, 0, Tuning.MAX_SHIELD_CHARGES)
	save_data()


## Ends the campaign (completion or defeat) and records the best result. The
## conquests and the seed stay in the file, so the summary can show the run that
## just ended; the next begin_campaign() clears them.
func finish_campaign() -> bool:
	var planets: int = campaign_conquered.size()
	var is_new_best: bool = campaign_score > campaign_best_score \
		or (campaign_score == campaign_best_score and planets > campaign_best_planets)
	campaign_best_score = maxi(campaign_best_score, campaign_score)
	campaign_best_planets = maxi(campaign_best_planets, planets)
	campaign_active = false
	campaign_hp = 0
	campaign_shields = 0
	save_data()
	return is_new_best


func is_body_conquered(body_id: StringName) -> bool:
	return campaign_conquered.has(body_id)


func _reset_upgrade_levels() -> void:
	upgrade_levels.clear()
	for kind: StringName in Tuning.UPGRADE_ORDER:
		upgrade_levels[kind] = 0


func load_data() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	high_score = int(config.get_value(SECTION_PROGRESS, KEY_HIGH_SCORE, 0))
	energy = maxi(int(config.get_value(SECTION_PROGRESS, KEY_ENERGY, 0)), 0)
	skin_id = StringName(String(config.get_value(SECTION_PROGRESS, KEY_SKIN, "red")))
	for kind: StringName in Tuning.UPGRADE_ORDER:
		upgrade_levels[kind] = clampi(
			int(config.get_value(SECTION_UPGRADES, String(kind) + "_level", 0)),
			0,
			Tuning.UPGRADE_MAX_LEVEL
		)
	music_volume = clampf(float(config.get_value(SECTION_AUDIO, KEY_MUSIC_VOLUME, 0.8)), 0.0, 1.0)
	music_order = StringName(String(config.get_value(SECTION_AUDIO, KEY_MUSIC_ORDER, "shuffle")))
	control_scheme = StringName(
		String(config.get_value(SECTION_GAMEPLAY, KEY_CONTROL_SCHEME, String(Tuning.CONTROL_SCHEME_DEFAULT)))
	)
	if control_scheme != Tuning.CONTROL_SCHEME_CLASSIC:
		control_scheme = Tuning.CONTROL_SCHEME_FREE
	shield_mode = StringName(
		String(config.get_value(SECTION_GAMEPLAY, KEY_SHIELD_MODE, String(Tuning.SHIELD_MODE_DEFAULT)))
	)
	if shield_mode != Tuning.SHIELD_MODE_MANUAL:
		shield_mode = Tuning.SHIELD_MODE_AUTO
	sfx_volume = clampf(float(config.get_value(SECTION_AUDIO, KEY_SFX_VOLUME, 0.8)), 0.0, 1.0)
	muted = bool(config.get_value(SECTION_AUDIO, KEY_MUTED, false))
	reduce_motion = bool(config.get_value(SECTION_GAMEPLAY, KEY_REDUCE_MOTION, false))
	auto_fire = bool(config.get_value(SECTION_GAMEPLAY, KEY_AUTO_FIRE, true))
	high_contrast_bullets = bool(config.get_value(SECTION_GAMEPLAY, KEY_HIGH_CONTRAST, true))
	campaign_active = bool(config.get_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_ACTIVE, false))
	campaign_seed = int(config.get_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_SEED, 0))
	campaign_score = maxi(int(config.get_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_SCORE, 0)), 0)
	campaign_hp = maxi(int(config.get_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_HP, 0)), 0)
	campaign_shields = clampi(
		int(config.get_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_SHIELDS, 0)),
		0,
		Tuning.MAX_SHIELD_CHARGES
	)
	campaign_best_score = maxi(int(config.get_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_BEST_SCORE, 0)), 0)
	campaign_best_planets = maxi(int(config.get_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_BEST_PLANETS, 0)), 0)
	campaign_conquered.clear()
	var conquered: PackedStringArray = config.get_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_CONQUERED, PackedStringArray())
	for sector: String in conquered:
		campaign_conquered.append(StringName(sector))
	# A stored campaign without a seed cannot be rebuilt, so treat it as finished
	# instead of showing a map that does not match the conquests.
	if campaign_active and campaign_seed == 0:
		campaign_active = false
	weapons_owned.clear()
	var owned_weapons: PackedStringArray = config.get_value(
		SECTION_WEAPONS, KEY_WEAPONS_OWNED, PackedStringArray([String(Weapons.DEFAULT_ID)])
	)
	for weapon: String in owned_weapons:
		var id := StringName(weapon)
		if Weapons.exists(id) and not weapons_owned.has(id):
			weapons_owned.append(id)
	if not weapons_owned.has(Weapons.DEFAULT_ID):
		weapons_owned.append(Weapons.DEFAULT_ID)
	var stored_primary := StringName(
		String(config.get_value(SECTION_WEAPONS, KEY_WEAPON_PRIMARY, String(Weapons.DEFAULT_ID)))
	)
	weapon_primary = stored_primary if weapons_owned.has(stored_primary) else Weapons.DEFAULT_ID
	var stored_secondary := StringName(
		String(config.get_value(SECTION_WEAPONS, KEY_WEAPON_SECONDARY, ""))
	)
	if stored_secondary == weapon_primary or not weapons_owned.has(stored_secondary):
		weapon_secondary = &""
	else:
		weapon_secondary = stored_secondary
	keyboard_bindings.clear()
	gamepad_bindings.clear()
	for action: StringName in Tuning.CONTROL_ACTIONS:
		var key_text: String = String(
			config.get_value(SECTION_CONTROLS, String(action) + "_key", "")
		)
		var pad_text: String = String(
			config.get_value(SECTION_CONTROLS, String(action) + "_pad", "")
		)
		if not key_text.is_empty():
			keyboard_bindings[action] = key_text
		if not pad_text.is_empty():
			gamepad_bindings[action] = pad_text


func save_data() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_PROGRESS, KEY_HIGH_SCORE, high_score)
	config.set_value(SECTION_PROGRESS, KEY_ENERGY, energy)
	config.set_value(SECTION_PROGRESS, KEY_SKIN, String(skin_id))
	for kind: StringName in Tuning.UPGRADE_ORDER:
		config.set_value(SECTION_UPGRADES, String(kind) + "_level", level_of(kind))
	config.set_value(SECTION_AUDIO, KEY_MUSIC_VOLUME, music_volume)
	config.set_value(SECTION_AUDIO, KEY_MUSIC_ORDER, String(music_order))
	config.set_value(SECTION_AUDIO, KEY_SFX_VOLUME, sfx_volume)
	config.set_value(SECTION_AUDIO, KEY_MUTED, muted)
	config.set_value(SECTION_GAMEPLAY, KEY_REDUCE_MOTION, reduce_motion)
	config.set_value(SECTION_GAMEPLAY, KEY_AUTO_FIRE, auto_fire)
	config.set_value(SECTION_GAMEPLAY, KEY_HIGH_CONTRAST, high_contrast_bullets)
	config.set_value(SECTION_GAMEPLAY, KEY_CONTROL_SCHEME, String(control_scheme))
	config.set_value(SECTION_GAMEPLAY, KEY_SHIELD_MODE, String(shield_mode))
	config.set_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_ACTIVE, campaign_active)
	config.set_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_SEED, campaign_seed)
	config.set_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_SCORE, campaign_score)
	config.set_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_HP, campaign_hp)
	config.set_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_SHIELDS, campaign_shields)
	config.set_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_BEST_SCORE, campaign_best_score)
	config.set_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_BEST_PLANETS, campaign_best_planets)
	var conquered := PackedStringArray()
	for sector: StringName in campaign_conquered:
		conquered.append(String(sector))
	config.set_value(SECTION_CAMPAIGN, KEY_CAMPAIGN_CONQUERED, conquered)
	var owned_weapons := PackedStringArray()
	for weapon: StringName in weapons_owned:
		owned_weapons.append(String(weapon))
	config.set_value(SECTION_WEAPONS, KEY_WEAPONS_OWNED, owned_weapons)
	config.set_value(SECTION_WEAPONS, KEY_WEAPON_PRIMARY, String(weapon_primary))
	config.set_value(SECTION_WEAPONS, KEY_WEAPON_SECONDARY, String(weapon_secondary))
	for action: StringName in Tuning.CONTROL_ACTIONS:
		config.set_value(
			SECTION_CONTROLS, String(action) + "_key", String(keyboard_bindings.get(action, ""))
		)
		config.set_value(
			SECTION_CONTROLS, String(action) + "_pad", String(gamepad_bindings.get(action, ""))
		)
	var error: Error = config.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save data to %s (error %d)." % [SAVE_PATH, error])
