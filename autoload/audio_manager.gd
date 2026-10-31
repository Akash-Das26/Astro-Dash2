extends Node
## Global audio service. SFX streams are looked up by name in SOUND_FILES and
## loaded from res://assests/audio/; anything missing only produces a warning so
## a build without audio still runs normally.
##
## Music is a playlist, not a single track: every .ogg, .mp3 and .wav in
## res://assests/audio/music/ becomes a track, sorted by file name. The folder is
## rescanned once at startup. A track that is exported in more than one format
## is only played once (ogg beats mp3 beats wav). The old single
## res://assests/audio/music.ogg still works as a one-track playlist.

const AUDIO_DIR: String = "res://assests/audio/"
const MUSIC_DIR: String = "res://assests/audio/music/"
const LEGACY_MUSIC: String = "res://assests/audio/music.ogg"
const MUSIC_EXTENSIONS: Array[String] = ["ogg", "mp3", "wav"]
## When the same base name exists in several formats, the earlier one wins.
const MUSIC_FORMAT_PRIORITY: Array[String] = ["ogg", "mp3", "wav"]
## Suffixes an exported build leaves next to a packed file instead of the file.
const IMPORT_SUFFIXES: Array[String] = [".import", ".remap"]

const MASTER_BUS: String = "Master"
const MUSIC_BUS: String = "Music"
const SFX_BUS: String = "SFX"
const SFX_POOL_SIZE: int = 8
## Same sound repeated within this window is dropped (spread shot fires three
## bullets per volley; one report is enough).
const MIN_REPEAT_MS: int = 30

## Name -> file in res://assests/audio/. Rename entries to match your files.
## The first block is the current event table; the second keeps the older names
## working so an older drop-off still plays.
const SOUND_FILES: Dictionary = {
	# Weapons
	"shoot_pulse": "shoot_pulse.ogg",
	"shoot_cannon": "shoot_cannon.ogg",
	"shoot_scatter": "shoot_scatter.ogg",
	"shoot_rail": "shoot_rail.ogg",
	"missile_launch": "missile_launch.ogg",
	# Combat
	"explosion_small": "explosion_small.ogg",
	"explosion_large": "explosion_large.ogg",
	"energy_pickup": "energy_pickup.ogg",
	"shield_pickup": "shield_pickup.ogg",
	"shield_hit": "shield_hit.ogg",
	"shield_down": "shield_down.ogg",
	"combo_up": "combo_up.ogg",
	"warp_in": "warp_in.ogg",
	# Progression and screens
	"upgrade_buy": "upgrade_buy.ogg",
	"upgrade_denied": "upgrade_denied.ogg",
	"victory": "victory.ogg",
	"defeat": "defeat.ogg",
	"map_click": "map_click.ogg",
	"ui_click": "ui_click.ogg",
	# Kept from the first sound table
	"shoot": "shoot.ogg",
	"enemy_death": "enemy_death.ogg",
	"player_hit": "player_hit.ogg",
	"pickup": "pickup.ogg",
	"bomb": "bomb.ogg",
	"boss_spawn": "boss_spawn.ogg",
	"wave": "wave.ogg",
	"game_over": "game_over.ogg",
	# Music loops (the playlist scans the folder; this is the legacy slot)
	"music": "music.ogg",
}
## Random pitch spread per sound, as a fraction of 1.0 (+/-5% = 0.05).
const PITCH_JITTER: Dictionary = {
	"shoot": 0.05,
	"shoot_pulse": 0.05,
	"shoot_scatter": 0.06,
	"enemy_death": 0.05,
	"explosion_small": 0.08,
}

## Emitted whenever a real volume or mute change happens, so every settings
## panel (menu and pause are separate instances) can stay in step.
signal settings_changed
## The track that just started, as a display name (file name without extension).
signal track_changed(track: String)

var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0
var _music_player: AudioStreamPlayer
var _muted: bool = false
var _music_volume: float = 0.8
var _sfx_volume: float = 0.8
## Playlist: res:// paths and display names, same order.
var _tracks: Array[String] = []
var _track_names: Array[String] = []
var _current: int = -1


func _ready() -> void:
	# Keep running while the tree is paused so music and UI clicks survive.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_streams()
	_build_players()
	_build_playlist()
	_apply_saved_settings()
	start_music()


# --- SFX --------------------------------------------------------------------

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


# --- Music playlist ---------------------------------------------------------

## Every track found at startup, as display names, in playlist order.
func music_tracks() -> Array[String]:
	return _track_names.duplicate()


func track_count() -> int:
	return _tracks.size()


func current_track_name() -> String:
	if _current < 0 or _current >= _track_names.size():
		return ""
	return _track_names[_current]


## Starts the playlist at the current (or first) track. Safe to call twice.
func start_music() -> void:
	if _music_player == null or _tracks.is_empty() or _music_player.playing:
		return
	_play_index(0 if _current < 0 else _current)


## Kept for callers from the single-track era. A known name or path plays that
## track; anything else just resumes the playlist.
func play_music(track: String = "") -> void:
	var index: int = _index_of(track)
	if index >= 0:
		_play_index(index)
	else:
		start_music()


func next_track() -> void:
	if _tracks.is_empty():
		return
	_play_index((_current + 1) % _tracks.size() if _current >= 0 else 0)


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()


## Scans the music folder once and builds the playlist. Missing folder or no
## playable file is not an error: music stays off with a single warning.
func _build_playlist() -> void:
	_tracks.clear()
	_track_names.clear()
	var candidates: Array[String] = []
	for entry: String in _list_music_entries():
		var file_name: String = _strip_import_suffix(entry)
		if file_name.is_empty():
			continue
		if not MUSIC_EXTENSIONS.has(file_name.get_extension().to_lower()):
			continue
		var path: String = MUSIC_DIR + file_name
		# A name listed from an export pack is only usable if the resource (or
		# the source file) is actually there; skip anything ordinal-looking or
		# half-remapped instead of failing later.
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			continue
		candidates.append(path)
	candidates.sort()
	# One entry per base name, in format-priority order.
	var by_base: Dictionary = {}
	for path: String in candidates:
		var base_name: String = path.get_file().get_basename().to_lower()
		if by_base.has(base_name):
			var existing: String = String(by_base[base_name])
			if _format_rank(path) < _format_rank(existing):
				by_base[base_name] = path
		else:
			by_base[base_name] = path
	for path: String in by_base.values():
		_tracks.append(path)
		_track_names.append(path.get_file().get_basename())
	if _tracks.is_empty() and ResourceLoader.exists(LEGACY_MUSIC):
		_tracks.append(LEGACY_MUSIC)
		_track_names.append("music")
	if _tracks.is_empty():
		push_warning(
			"AudioManager: no music found in %s and no %s; music is off."
			% [MUSIC_DIR, LEGACY_MUSIC]
		)


## Raw directory entries in the music folder. Two sources on purpose:
## - ResourceLoader.list_directory (Godot 4.5+) reads the resource pack, which
##   is the only listing that works in a Web or Android export: the imported
##   audio does not live next to the source path there.
## - DirAccess lists the real folder, which covers the editor and any export
##   whose preset includes the source files (see export_presets.cfg).
## Exported names may carry ".import" / ".remap"; both are stripped later.
func _list_music_entries() -> PackedStringArray:
	var entries: PackedStringArray = PackedStringArray()
	if ResourceLoader.has_method("list_directory"):
		var listed: Variant = ResourceLoader.call("list_directory", MUSIC_DIR)
		if listed is PackedStringArray:
			entries.append_array(listed as PackedStringArray)
		elif listed is Array:
			for item: Variant in (listed as Array):
				entries.append(String(item))
	var dir := DirAccess.open(MUSIC_DIR)
	if dir != null:
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while entry != "":
			if not dir.current_is_dir():
				entries.append(entry)
			entry = dir.get_next()
		dir.list_dir_end()
	return entries


func _strip_import_suffix(entry: String) -> String:
	var file_name: String = entry.get_file()
	for suffix: String in IMPORT_SUFFIXES:
		if file_name.ends_with(suffix):
			return file_name.substr(0, file_name.length() - suffix.length())
	return file_name


func _format_rank(path: String) -> int:
	var rank: int = MUSIC_FORMAT_PRIORITY.find(path.get_extension().to_lower())
	return rank if rank >= 0 else MUSIC_FORMAT_PRIORITY.size()


func _index_of(track: String) -> int:
	if track.is_empty():
		return -1
	var index: int = _tracks.find(track)
	if index >= 0:
		return index
	return _track_names.find(track)


## Loads a track and skips past unreadable files, so one bad file cannot stop
## the playlist. Returns false when nothing could be played at all.
func _play_index(index: int) -> bool:
	if _tracks.is_empty():
		return false
	index = clampi(index, 0, _tracks.size() - 1)
	for _attempt: int in _tracks.size():
		var stream: AudioStream = _load_track(_tracks[index])
		if stream != null:
			_current = index
			_music_player.stream = stream
			_music_player.play()
			track_changed.emit(_track_names[index])
			return true
		push_warning("AudioManager: could not load %s; skipping it." % _tracks[index])
		index = (index + 1) % _tracks.size()
	push_warning("AudioManager: no music track could be loaded.")
	return false


func _load_track(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


# --- Volume and settings ----------------------------------------------------

## linear is 0.0 (silent) to 1.0 (full).
func set_bus_volume(bus: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var clamped: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clamped, 0.001)))
	AudioServer.set_bus_mute(index, clamped <= 0.001)
	if bus == MUSIC_BUS:
		var music_changed: bool = not is_equal_approx(_music_volume, clamped)
		_music_volume = clamped
		if music_changed:
			settings_changed.emit()
	elif bus == SFX_BUS:
		var sfx_changed: bool = not is_equal_approx(_sfx_volume, clamped)
		_sfx_volume = clamped
		if sfx_changed:
			settings_changed.emit()


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
	var changed: bool = _muted != enabled
	_muted = enabled
	var index: int = AudioServer.get_bus_index(MASTER_BUS)
	if index >= 0:
		AudioServer.set_bus_mute(index, _muted)
	if changed:
		settings_changed.emit()


func is_muted() -> bool:
	return _muted


func toggle_mute() -> bool:
	set_mute(not _muted)
	return _muted


func _apply_saved_settings() -> void:
	set_bus_volume(MUSIC_BUS, SaveData.music_volume)
	set_bus_volume(SFX_BUS, SaveData.sfx_volume)
	set_mute(SaveData.muted)


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
	if _tracks.size() <= 1:
		return
	next_track()
