extends Node
## Persists progress and settings between sessions in user://save.cfg.
## Works on desktop, web and Android because user:// is mapped per platform
## by the engine.

const SAVE_PATH: String = "user://save.cfg"
const SECTION_PROGRESS: String = "progress"
const SECTION_AUDIO: String = "audio"
const SECTION_GAMEPLAY: String = "gameplay"
const SECTION_UPGRADES: String = "upgrades"
const KEY_HIGH_SCORE: String = "high_score"
const KEY_ENERGY: String = "energy"
const KEY_REDUCE_MOTION: String = "reduce_motion"
const KEY_MUSIC_VOLUME: String = "music_volume"
const KEY_SFX_VOLUME: String = "sfx_volume"
const KEY_MUTED: String = "muted"
const KEY_AUTO_FIRE: String = "auto_fire"

var high_score: int = 0
## Spendable currency, earned by killing enemies and spent in the upgrade shop.
var energy: int = 0
## Upgrade kind (StringName) -> level 0..Tuning.UPGRADE_MAX_LEVEL.
var upgrade_levels: Dictionary = {}
var music_volume: float = 0.8
var sfx_volume: float = 0.8
var muted: bool = false
var reduce_motion: bool = false
## Touch only: fire while a finger is on the screen. On by default because a
## phone has no fire key.
var auto_fire: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_upgrade_levels()
	load_data()


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
	for kind: StringName in Tuning.UPGRADE_ORDER:
		upgrade_levels[kind] = clampi(
			int(config.get_value(SECTION_UPGRADES, String(kind) + "_level", 0)),
			0,
			Tuning.UPGRADE_MAX_LEVEL
		)
	music_volume = clampf(float(config.get_value(SECTION_AUDIO, KEY_MUSIC_VOLUME, 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value(SECTION_AUDIO, KEY_SFX_VOLUME, 0.8)), 0.0, 1.0)
	muted = bool(config.get_value(SECTION_AUDIO, KEY_MUTED, false))
	reduce_motion = bool(config.get_value(SECTION_GAMEPLAY, KEY_REDUCE_MOTION, false))
	auto_fire = bool(config.get_value(SECTION_GAMEPLAY, KEY_AUTO_FIRE, true))


func save_data() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_PROGRESS, KEY_HIGH_SCORE, high_score)
	config.set_value(SECTION_PROGRESS, KEY_ENERGY, energy)
	for kind: StringName in Tuning.UPGRADE_ORDER:
		config.set_value(SECTION_UPGRADES, String(kind) + "_level", level_of(kind))
	config.set_value(SECTION_AUDIO, KEY_MUSIC_VOLUME, music_volume)
	config.set_value(SECTION_AUDIO, KEY_SFX_VOLUME, sfx_volume)
	config.set_value(SECTION_AUDIO, KEY_MUTED, muted)
	config.set_value(SECTION_GAMEPLAY, KEY_REDUCE_MOTION, reduce_motion)
	config.set_value(SECTION_GAMEPLAY, KEY_AUTO_FIRE, auto_fire)
	var error: Error = config.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save data to %s (error %d)." % [SAVE_PATH, error])
