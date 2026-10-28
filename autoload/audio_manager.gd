extends Node
## Global audio service. Streams are looked up by name in SOUND_FILES and
## loaded from res://assests/audio/; anything missing only produces a warning
## so a build without audio still runs normally.

const AUDIO_DIR: String = "res://assests/audio/"
const MASTER_BUS: String = "Master"
const MUSIC_BUS: String = "Music"
const SFX_BUS: String = "SFX"
const SFX_POOL_SIZE: int = 8
## Same sound repeated within this window is dropped (spread shot fires three
## bullets per volley; one report is enough).
const MIN_REPEAT_MS: int = 30

## Name -> file in res://assests/audio/. Rename entries to match your files.
const SOUND_FILES: Dictionary = {
	"shoot": "shoot.ogg",
	"enemy_death": "enemy_death.ogg",
	"player_hit": "player_hit.ogg",
	"pickup": "pickup.ogg",
	"bomb": "bomb.ogg",
	"boss_spawn": "boss_spawn.ogg",
	"wave": "wave.ogg",
	"game_over": "game_over.ogg",
	"ui_click": "ui_click.ogg",
	"music": "music.ogg",
}
## Random pitch spread per sound, as a fraction of 1.0 (+/-5% = 0.05).
const PITCH_JITTER: Dictionary = {
	"shoot": 0.05,
	"enemy_death": 0.05,
}

var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0
var _music_player: AudioStreamPlayer
var _muted: bool = false
var _music_volume: float = 0.8
var _sfx_volume: float = 0.8


func _ready() -> void:
	# Keep running while the tree is paused so music and UI clicks survive.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_streams()
	_build_players()


func play_sfx(sound: String) -> void:
	var stream := _streams.get(sound) as AudioStream
	if stream == null or _sfx_players.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < MIN_REPEAT_MS:
		return
	_last_played[sound] = now
	var player: AudioStreamPlayer = _sfx_players[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()
	player.stream = stream
	var jitter: float = float(PITCH_JITTER.get(sound, 0.0))
	player.pitch_scale = 1.0 + randf_range(-jitter, jitter)
	player.play()


func play_music(track: String) -> void:
	var stream := _streams.get(track) as AudioStream
	if stream == null:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


## linear is 0.0 (silent) to 1.0 (full).
func set_bus_volume(bus: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var clamped: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clamped, 0.001)))
	AudioServer.set_bus_mute(index, clamped <= 0.001)
	if bus == MUSIC_BUS:
		_music_volume = clamped
	elif bus == SFX_BUS:
		_sfx_volume = clamped


func get_bus_volume(bus: String) -> float:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(index)), 0.0, 1.0)


func music_volume() -> float:
	return _music_volume


func sfx_volume() -> float:
	return _sfx_volume


func set_mute(enabled: bool) -> void:
	_muted = enabled
	var index: int = AudioServer.get_bus_index(MASTER_BUS)
	if index >= 0:
		AudioServer.set_bus_mute(index, _muted)


func is_muted() -> bool:
	return _muted


func toggle_mute() -> bool:
	set_mute(not _muted)
	return _muted


func _load_streams() -> void:
	for sound: String in SOUND_FILES:
		var path: String = AUDIO_DIR + String(SOUND_FILES[sound])
		if not ResourceLoader.exists(path):
			push_warning("AudioManager: missing %s for \"%s\"; that sound is disabled." % [path, sound])
			continue
		var stream := load(path) as AudioStream
		if stream != null:
			_streams[sound] = stream


func _build_players() -> void:
	var music_bus: String = _resolve_bus(MUSIC_BUS)
	var sfx_bus: String = _resolve_bus(SFX_BUS)

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = music_bus
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	for index: int in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % index
		player.bus = sfx_bus
		add_child(player)
		_sfx_players.append(player)


## Falls back to Master if default_bus_layout.tres was not picked up.
func _resolve_bus(bus: String) -> String:
	return bus if AudioServer.get_bus_index(bus) >= 0 else MASTER_BUS


func _on_music_finished() -> void:
	# Only loops for streams that are not already flagged as looping.
	if _music_player.stream != null:
		_music_player.play()
