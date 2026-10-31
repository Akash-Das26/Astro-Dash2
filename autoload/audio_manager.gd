extends Node
## Global audio service. SFX are looked up by logical name in SOUND_MAP, which
## points at the real files inside the two packs under res://assests/audio/.
## Several files may back one event; one is picked at random. Anything unmapped
## only produces one summary warning, so a build without audio still runs.
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

## The audio packs keep their own file names, so nothing is renamed to match
## code. Each logical event maps to a list of real files; one is picked at
## random per play, with a little pitch spread. All paths are under AUDIO_DIR.
##
## Two packs are in res://assests/audio/: the Juhani Junkala 512-sound set
## (weapons, explosions, UI, pickups) and Ove Melaa's Essential pack (gem,
## click, lvlup, win). No .zip archives were present; everything was already
## extracted, so there is no sfx/ copy and the originals stay where they are.
const PACK: String = "The Essential Retro Video Game Sound Effects Collection [512 sounds]/The Essential Retro Video Game Sound Effects Collection [512 sounds] By Juhani Junkala/"
const OVE: String = "EssentialGameAudiopackFixed/Sound Effects/RandomSfx/"
const LASER: String = PACK + "Weapons/Lasers/sfx_wpn_laser"
const CANNON: String = PACK + "Weapons/Cannon/sfx_wpn_cannon"
const SHOTGUN: String = PACK + "Weapons/Shotgun/sfx_weapon_shotgun"
const EXP_SHORT: String = PACK + "Explosions/Short/sfx_exp_short_hard"
const EXP_LONG: String = PACK + "Explosions/Long/sfx_exp_long"
const EXP_SHORTEST: String = PACK + "Explosions/Shortest/sfx_exp_shortest_hard"
const EXP_CLUSTER: String = PACK + "Explosions/Clusters/sfx_exp_cluster"
const EXP_MEDIUM: String = PACK + "Explosions/Medium Length/sfx_exp_medium"
const COIN: String = PACK + "General Sounds/Coins/sfx_coin_cluster"
const POWERUP: String = PACK + "General Sounds/Positive Sounds/sfx_sounds_powerup"
const ERROR: String = PACK + "General Sounds/Negative Sounds/sfx_sounds_error"
const DAMAGE: String = PACK + "General Sounds/Simple Damage Sounds/sfx_damage_hit"
const IMPACT: String = PACK + "General Sounds/Impacts/sfx_sounds_impact"
const BUTTON: String = PACK + "General Sounds/Buttons/sfx_sounds_button"
const MENU_SELECT: String = PACK + "General Sounds/Menu Sounds/sfx_menu_select"
const PORTAL: String = PACK + "Movement/Portals and Transitions/sfx_movement_portal"
const FANFARE: String = PACK + "General Sounds/Fanfares/sfx_sounds_fanfare"
const ALARM: String = PACK + "General Sounds/Alarms/Alarms/sfx_alarm_loop"
const NEUTRAL: String = PACK + "General Sounds/Neutral Sounds/sfx_sound_neutral"

const SOUND_MAP: Dictionary = {
	# Weapons
	"shoot_pulse": [LASER + "1.wav", LASER + "2.wav", LASER + "3.wav", LASER + "4.wav"],
	"shoot_cannon": [CANNON + "1.wav", CANNON + "2.wav", CANNON + "3.wav"],
	"shoot_scatter": [SHOTGUN + "1.wav", SHOTGUN + "2.wav", SHOTGUN + "3.wav"],
	"shoot_rail": [LASER + "10.wav", LASER + "11.wav", LASER + "12.wav"],
	"missile_launch": [PACK + "Weapons/Grenade Whistles/sfx_wpn_missilelaunch.wav"],
	# Combat
	"explosion_small": [EXP_SHORT + "1.wav", EXP_SHORT + "2.wav", EXP_SHORT + "3.wav"],
	"explosion_large": [EXP_LONG + "1.wav", EXP_LONG + "2.wav", EXP_LONG + "3.wav"],
	"energy_pickup": [OVE + "gem.ogg", COIN + "1.wav", COIN + "2.wav"],
	"shield_pickup": [POWERUP + "1.wav", POWERUP + "2.wav", POWERUP + "3.wav"],
	"shield_hit": [IMPACT + "1.wav", IMPACT + "2.wav", IMPACT + "3.wav"],
	"shield_up": [POWERUP + "11.wav", POWERUP + "12.wav", POWERUP + "13.wav"],
	"shield_down": [ERROR + "1.wav", ERROR + "2.wav", ERROR + "3.wav"],
	"combo_up": [POWERUP + "16.wav", POWERUP + "17.wav", POWERUP + "18.wav"],
	"warp_in": [PORTAL + "1.wav", PORTAL + "2.wav", PORTAL + "3.wav"],
	# Progression and screens
	"upgrade_buy": [OVE + "lvlup.ogg"],
	"upgrade_denied": [ERROR + "9.wav", ERROR + "10.wav", ERROR + "11.wav"],
	"victory": [OVE + "win.ogg", FANFARE + "1.wav", FANFARE + "2.wav"],
	"defeat": [DAMAGE + "1.wav", DAMAGE + "2.wav", EXP_MEDIUM + "1.wav"],
	"map_click": [OVE + "click.ogg", MENU_SELECT + "1.wav"],
	"ui_click": [BUTTON + "1.wav", BUTTON + "2.wav", BUTTON + "3.wav"],
	# Kept from the first sound table
	"shoot": [LASER + "5.wav", LASER + "6.wav", LASER + "7.wav"],
	"enemy_death": [EXP_SHORTEST + "1.wav", EXP_SHORTEST + "2.wav", EXP_SHORTEST + "3.wav"],
	"player_hit": [DAMAGE + "1.wav", DAMAGE + "2.wav", DAMAGE + "3.wav"],
	"pickup": [OVE + "gem.ogg", COIN + "1.wav"],
	"bomb": [EXP_CLUSTER + "1.wav", EXP_CLUSTER + "2.wav", EXP_CLUSTER + "3.wav"],
	"boss_spawn": [ALARM + "1.wav", ALARM + "2.wav"],
	"wave": [NEUTRAL + "1.wav", NEUTRAL + "2.wav"],
	"game_over": [ERROR + "13.wav", ERROR + "14.wav", ERROR + "15.wav"],
}
## Per-sound level trim in dB. Negative keeps loud effects under the music,
## which stays the quietest layer on the bus layout.
const SOUND_VOLUME_DB: Dictionary = {
	"shoot_pulse": -7.0,
	"shoot_cannon": -5.0,
	"shoot_scatter": -6.0,
	"shoot_rail": -5.0,
	"missile_launch": -5.0,
	"shoot": -7.0,
	"explosion_small": -5.0,
	"explosion_large": -3.0,
	"bomb": -3.0,
	"energy_pickup": -7.0,
	"pickup": -7.0,
	"shield_pickup": -6.0,
	"shield_up": -5.0,
	"shield_hit": -5.0,
	"shield_down": -5.0,
	"combo_up": -6.0,
	"warp_in": -6.0,
	"upgrade_buy": -4.0,
	"upgrade_denied": -6.0,
	"victory": -3.0,
	"defeat": -3.0,
	"game_over": -4.0,
	"map_click": -8.0,
	"ui_click": -8.0,
	"enemy_death": -6.0,
	"player_hit": -4.0,
	"boss_spawn": -4.0,
	"wave": -8.0,
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
## Shuffle / in-order was changed (from the settings card or the API).
signal music_order_changed(order: StringName)

## Logical name -> array of loaded variants. Empty when nothing was mapped.
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0
## Two players on the Music bus, cross-faded when the track changes.
var _music_players: Array[AudioStreamPlayer] = []
var _active_player: int = 0
var _fade_tween: Tween
## Mild dip of the Music bus while the pause card is up.
var _pause_gain: float = 1.0
var _pause_target: float = 1.0
var _muted: bool = false
var _master_volume: float = 0.8
var _music_volume: float = 0.8
var _sfx_volume: float = 0.8
## Playlist: res:// paths and display names, same order.
var _tracks: Array[String] = []
var _track_names: Array[String] = []
var _current: int = -1
## Web will not play audio until a user gesture; the first key, click, tap or
## pad press starts the playlist, once.
var _music_started: bool = false
## Shuffle bag: each track lands in it once per reshuffle, so a full pass plays
## everything before anything repeats, and the bag never starts with the track
## that just ended.
var _order: StringName = Tuning.MUSIC_ORDER_SHUFFLE
## Context track currently playing (empty during the normal rotation).
var _context: StringName = &""
var _bag: Array[int] = []
## Tracks played before the current one, newest last, for PREVIOUS.
var _history: Array[int] = []


func _ready() -> void:
	# Keep running while the tree is paused so music and UI clicks survive.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Buses first: the players are given their bus by name, so they have to
	# exist before the pools are built.
	_ensure_buses()
	_load_streams()
	_build_players()
	_build_playlist()
	_order = _normalise_order(SaveData.music_order)
	_apply_saved_settings()
	GameState.state_changed.connect(_on_game_state_changed)
	_pause_target = Tuning.MUSIC_PAUSE_GAIN if GameState.state == GameState.State.PAUSED else 1.0
	_pause_gain = _pause_target


func _process(delta: float) -> void:
	if is_equal_approx(_pause_gain, _pause_target):
		return
	_pause_gain = move_toward(_pause_gain, _pause_target, delta * Tuning.MUSIC_PAUSE_FADE)
	_apply_music_bus()


## The first user gesture unlocks audio (a Web requirement) and starts the
## playlist. From then on the autoload keeps it running across the menu, the
## map and battles, so a scene change never restarts the music.
func _input(event: InputEvent) -> void:
	if _music_started or not event.is_pressed():
		return
	if event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventScreenTouch or event is InputEventJoypadButton:
		start_music()


## Quitting stops cleanly instead of leaving a stream running into teardown.
func _exit_tree() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	for player: AudioStreamPlayer in _music_players:
		player.stop()


# --- SFX --------------------------------------------------------------------

func play_sfx(sound: String) -> void:
	var variants: Array = _streams.get(sound, [])
	if variants.is_empty() or _sfx_players.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < MIN_REPEAT_MS:
		return
	_last_played[sound] = now
	var player: AudioStreamPlayer = _sfx_players[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()
	player.stream = variants[randi() % variants.size()] as AudioStream
	player.volume_db = float(SOUND_VOLUME_DB.get(sound, 0.0))
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
	_music_started = true
	if _music_players.is_empty() or _tracks.is_empty():
		return
	if _music_players[_active_player].playing:
		return
	var index: int = _first_index()
	if index < 0:
		return
	_play_index(index)


## Kept for callers from the single-track era. A known name or path plays that
## track; anything else just resumes the playlist.
func play_music(track: String = "") -> void:
	var index: int = _index_of(track)
	if index >= 0:
		_play_index(index)
	else:
		start_music()


## Plays the track mapped to `context` in Tuning.MUSIC_CONTEXTS, crossfading
## like any other change. Unknown or missing context does nothing at all.
func play_context(context: StringName) -> void:
	var index: int = _context_index(context)
	if index < 0:
		return
	_context = context
	_music_started = true
	if _music_players.is_empty():
		return
	if index == _current and _music_players[_active_player].playing:
		return
	_play_index(index)


## Ends the context: the boss track is replaced by the normal rotation.
func release_context() -> void:
	if _context == &"":
		return
	var was_context: bool = _context_index(_context) == _current
	_context = &""
	if was_context:
		next_track()


func _context_index(context: StringName) -> int:
	for index: int in _track_names.size():
		var mapped: String = String(Tuning.MUSIC_CONTEXTS.get(_track_names[index], ""))
		if mapped == String(context):
			return index
	return -1


func _is_context_index(index: int) -> bool:
	if index < 0 or index >= _track_names.size():
		return false
	return Tuning.MUSIC_CONTEXTS.has(_track_names[index])


func next_track() -> void:
	if _tracks.is_empty():
		return
	var index: int = _pick_next_index()
	if index < 0:
		return
	if _current >= 0:
		_history.append(_current)
	_play_index(index)


func previous_track() -> void:
	if _tracks.is_empty():
		return
	var index: int = -1
	if not _history.is_empty():
		index = _history.pop_back()
	elif _current >= 0:
		index = (_current - 1 + _tracks.size()) % _tracks.size()
	if index >= 0:
		_play_index(index)


func music_order() -> StringName:
	return _order


## Shuffle (default) or in order. Survives relaunches through SaveData.
func set_music_order(order: StringName) -> void:
	var normalised: StringName = _normalise_order(order)
	if normalised == _order:
		return
	_order = normalised
	_bag.clear()
	SaveData.music_order = _order
	music_order_changed.emit(_order)


func toggle_music_order() -> StringName:
	set_music_order(
		Tuning.MUSIC_ORDER_IN_ORDER if _order == Tuning.MUSIC_ORDER_SHUFFLE \
			else Tuning.MUSIC_ORDER_SHUFFLE
	)
	return _order


func _normalise_order(order: StringName) -> StringName:
	return Tuning.MUSIC_ORDER_IN_ORDER if order == Tuning.MUSIC_ORDER_IN_ORDER \
		else Tuning.MUSIC_ORDER_SHUFFLE


func _first_index() -> int:
	var candidates: Array[int] = []
	for index: int in _tracks.size():
		if not _is_context_index(index):
			candidates.append(index)
	if candidates.is_empty():
		return -1
	if _order == Tuning.MUSIC_ORDER_IN_ORDER or candidates.size() == 1:
		return candidates[0]
	return candidates[randi() % candidates.size()]


## In order: the next slot. Shuffle: draw from the bag, reshuffling when it is
## empty and never putting the current track first in a fresh bag.
func _pick_next_index() -> int:
	if _tracks.is_empty():
		return -1
	if _tracks.size() == 1:
		return 0
	if _order == Tuning.MUSIC_ORDER_IN_ORDER:
		return _next_in_order()
	if _bag.is_empty():
		_bag.clear()
		for index: int in _tracks.size():
			# Boss and other context tracks never enter the normal rotation.
			if not _is_context_index(index):
				_bag.append(index)
		_bag.shuffle()
		if _bag.size() > 1 and _bag[0] == _current:
			var last: int = _bag.size() - 1
			var swapped: int = _bag[0]
			_bag[0] = _bag[last]
			_bag[last] = swapped
	if _bag.is_empty():
		return -1
	return _bag.pop_front()


## In-order walk that skips context tracks, so a boss theme never lands in the
## middle of normal play.
func _next_in_order() -> int:
	var start: int = _current + 1 if _current >= 0 else 0
	for step: int in _tracks.size():
		var index: int = (start + step) % _tracks.size()
		if not _is_context_index(index):
			return index
	return -1


func stop_music() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	for player: AudioStreamPlayer in _music_players:
		player.stop()


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
	if _tracks.is_empty() or _music_players.is_empty():
		return false
	index = clampi(index, 0, _tracks.size() - 1)
	for _attempt: int in _tracks.size():
		var stream: AudioStream = _load_track(_tracks[index])
		if stream != null:
			_start_stream(index, stream)
			return true
		push_warning("AudioManager: could not load %s; skipping it." % _tracks[index])
		index = (index + 1) % _tracks.size()
	push_warning("AudioManager: no music track could be loaded.")
	return false


## Cross-fades onto the idle player: the new track rises from silence while
## the old one falls, both over Tuning.MUSIC_CROSSFADE, then the old stops.
func _start_stream(index: int, stream: AudioStream) -> void:
	var previous: AudioStreamPlayer = _music_players[_active_player]
	var next_index: int = 1 - _active_player
	var player: AudioStreamPlayer = _music_players[next_index]
	_active_player = next_index
	_current = index
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	player.stream = stream
	player.volume_db = Tuning.MUSIC_SILENT_DB
	player.play()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(player, "volume_db", 0.0, Tuning.MUSIC_CROSSFADE)
	if previous.playing and previous != player:
		_fade_tween.tween_property(
			previous, "volume_db", Tuning.MUSIC_SILENT_DB, Tuning.MUSIC_CROSSFADE
		)
		_fade_tween.chain().tween_callback(previous.stop)
	track_changed.emit(_track_names[index])


func _load_track(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		return null
	_set_loop(stream, _tracks.size() <= 1)
	return stream


## Looping is a property of the stream, and an imported file may have it on.
## A multi-track playlist must not loop one track or `finished` never fires; a
## one-track playlist is the exception and loops that track.
func _set_loop(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = (
			AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED
		)
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = enabled
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = enabled


# --- Volume and settings ----------------------------------------------------

## linear is 0.0 (silent) to 1.0 (full). Every slider goes through here, so a
## missing bus is repaired instead of silently doing nothing.
func set_bus_volume(bus: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		_ensure_buses()
		index = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var clamped: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clamped, 0.001)))
	if bus == MASTER_BUS:
		# Master mute belongs to the mute button; 0 on the slider is already
		# -60 dB, so the bus is never muted behind the button's back.
		var master_changed: bool = not is_equal_approx(_master_volume, clamped)
		_master_volume = clamped
		if master_changed:
			_log_buses("master")
			settings_changed.emit()
		return
	AudioServer.set_bus_mute(index, clamped <= 0.001)
	if bus == MUSIC_BUS:
		var music_changed: bool = not is_equal_approx(_music_volume, clamped)
		_music_volume = clamped
		_apply_music_bus()
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


func master_volume() -> float:
	return _master_volume


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
	# Master first, then the two child buses, and all of it before the first
	# track can start, so the game never opens louder than the saved level.
	set_bus_volume(MASTER_BUS, SaveData.master_volume)
	set_bus_volume(MUSIC_BUS, SaveData.music_volume)
	set_bus_volume(SFX_BUS, SaveData.sfx_volume)
	set_mute(SaveData.muted)
	_log_buses("saved settings")


## The Music bus is the user's slider multiplied by the pause dip. The fades
## themselves run on the players, so the two never overwrite each other.
func _apply_music_bus() -> void:
	var index: int = AudioServer.get_bus_index(MUSIC_BUS)
	if index < 0:
		return
	var linear: float = clampf(_music_volume * _pause_gain, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


func _on_game_state_changed(new_state: int) -> void:
	_pause_target = Tuning.MUSIC_PAUSE_GAIN if new_state == GameState.State.PAUSED else 1.0


## Loads every mapped variant. One summary warning lists the logical names that
## found no file at all, instead of one warning per missing path.
func _load_streams() -> void:
	_streams.clear()
	var unmapped: PackedStringArray = []
	for sound: String in SOUND_MAP:
		var variants: Array = []
		for relative: String in SOUND_MAP[sound]:
			var path: String = AUDIO_DIR + relative
			if not ResourceLoader.exists(path):
				continue
			var stream := load(path) as AudioStream
			if stream != null:
				variants.append(stream)
		if variants.is_empty():
			unmapped.append(sound)
		else:
			_streams[sound] = variants
	if not unmapped.is_empty():
		push_warning(
			"AudioManager: no file mapped for %d sound(s): %s"
			% [unmapped.size(), ", ".join(unmapped)]
		)


func _build_players() -> void:
	var music_bus: String = _resolve_bus(MUSIC_BUS)
	var sfx_bus: String = _resolve_bus(SFX_BUS)

	for index: int in 2:
		var music := AudioStreamPlayer.new()
		music.name = "MusicPlayer%d" % index
		music.bus = music_bus
		music.volume_db = Tuning.MUSIC_SILENT_DB
		music.finished.connect(_on_music_finished.bind(music))
		add_child(music)
		_music_players.append(music)

	for index: int in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % index
		player.bus = sfx_bus
		add_child(player)
		_sfx_players.append(player)


## Falls back to Master if default_bus_layout.tres was not picked up.
func _resolve_bus(bus: String) -> String:
	return bus if AudioServer.get_bus_index(bus) >= 0 else MASTER_BUS


## The buses normally come from res://default_bus_layout.tres (pinned in
## project.godot). If that layout was not loaded -- a stripped export, a moved
## file, a project saved before the layout existed -- every player would fall
## back to Master and the sliders would write to buses that are not there, so
## the volume controls would do nothing. Creating them here makes the mixer
## work either way; the names match the layout file exactly.
func _ensure_buses() -> void:
	var created: bool = false
	for bus: String in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, MASTER_BUS)
		created = true
	if OS.is_debug_build():
		_log_buses("startup" if not created else "buses created")


## One line in the debug log: every bus, its dB and whether it is muted. Enough
## to tell a working slider from a slider writing to nothing.
func _log_buses(reason: String) -> void:
	if not OS.is_debug_build():
		return
	var parts: PackedStringArray = []
	for index: int in AudioServer.get_bus_count():
		parts.append(
			"%s %.1f dB%s" % [
				AudioServer.get_bus_name(index),
				AudioServer.get_bus_volume_db(index),
				" MUTED" if AudioServer.is_bus_mute(index) else "",
			]
		)
	print("AudioManager [%s]: %s" % [reason, " | ".join(parts)])


## Only the track that is actually on air advances the playlist; the player
## fading out finishes nothing because it is stopped, not run out.
func _on_music_finished(player: AudioStreamPlayer) -> void:
	if _tracks.size() <= 1 or _music_players.is_empty():
		return
	if player != _music_players[_active_player]:
		return
	next_track()
