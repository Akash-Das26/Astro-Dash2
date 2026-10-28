extends Node
## Persists progress and settings between sessions in user://save.cfg.
## Works on desktop, web and Android because user:// is mapped per platform
## by the engine.

const SAVE_PATH: String = "user://save.cfg"
const SECTION_PROGRESS: String = "progress"
const SECTION_AUDIO: String = "audio"
const SECTION_GAMEPLAY: String = "gameplay"
const KEY_HIGH_SCORE: String = "high_score"
const KEY_REDUCE_MOTION: String = "reduce_motion"
const KEY_MUSIC_VOLUME: String = "music_volume"
const KEY_SFX_VOLUME: String = "sfx_volume"
const KEY_MUTED: String = "muted"

var high_score: int = 0
var music_volume: float = 0.8
var sfx_volume: float = 0.8
var muted: bool = false
var reduce_motion: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()


## Records a finished run. Returns true when it beat the stored record.
func submit_score(score: int) -> bool:
	if score <= high_score:
		return false
	high_score = score
	save_data()
	return true


func load_data() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	high_score = int(config.get_value(SECTION_PROGRESS, KEY_HIGH_SCORE, 0))
	music_volume = clampf(float(config.get_value(SECTION_AUDIO, KEY_MUSIC_VOLUME, 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value(SECTION_AUDIO, KEY_SFX_VOLUME, 0.8)), 0.0, 1.0)
	muted = bool(config.get_value(SECTION_AUDIO, KEY_MUTED, false))
	reduce_motion = bool(config.get_value(SECTION_GAMEPLAY, KEY_REDUCE_MOTION, false))


func save_data() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_PROGRESS, KEY_HIGH_SCORE, high_score)
	config.set_value(SECTION_AUDIO, KEY_MUSIC_VOLUME, music_volume)
	config.set_value(SECTION_AUDIO, KEY_SFX_VOLUME, sfx_volume)
	config.set_value(SECTION_AUDIO, KEY_MUTED, muted)
	config.set_value(SECTION_GAMEPLAY, KEY_REDUCE_MOTION, reduce_motion)
	var error: Error = config.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save data to %s (error %d)." % [SAVE_PATH, error])
