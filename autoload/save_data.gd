extends Node
## Persists progress between sessions (currently just the high score) in
## user://save.cfg. Works on desktop, web and Android because user:// is
## mapped per platform by the engine.

const SAVE_PATH: String = "user://save.cfg"
const SECTION: String = "progress"
const KEY_HIGH_SCORE: String = "high_score"

var high_score: int = 0


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
	high_score = int(config.get_value(SECTION, KEY_HIGH_SCORE, 0))


func save_data() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, KEY_HIGH_SCORE, high_score)
	var error: Error = config.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save high score to %s (error %d)." % [SAVE_PATH, error])
