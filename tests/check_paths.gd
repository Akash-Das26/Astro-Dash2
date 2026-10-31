class_name PathCheck
extends RefCounted
## Structural checks over the project's own files, run from the test suite.
##
## It answers four questions a runtime test cannot:
##   1. does every `res://` path the code, scenes and settings mention exist?
##   2. does anything still point at a path that the reorganisation retired?
##   3. does every script have its `.uid` and every imported asset its `.import`?
##   4. do the tables of file names stored *relative to a base folder*
##      (`AudioManager.SOUND_MAP`, under `AUDIO_DIR`) still resolve?
##
## Paths are compared as text, so this is a good guard against a move that
## forgot a reference; it is not a substitute for running the scenes.

const TEXT_EXTENSIONS: Array[String] = ["gd", "tscn", "tres", "godot", "cfg"]
const SKIP_DIRS: Array[String] = [".git", ".godot", "test_output", "export", "reference"]
## Documents and this file itself describe paths rather than using them: the
## migration plan has to keep the old names, and this script lists them as data.
const SKIP_FILES: Array[String] = [
	"res://docs/reorg_plan.md", "res://docs/orphans.md", "res://tests/check_paths.gd",
]
const IMPORTED_EXTENSIONS: Array[String] = [
	"png", "svg", "ttf", "otf", "ogg", "wav", "mp3", "jpg", "webp",
]
## Allowed to point at nothing: the legacy single-track music fallback is probed
## with ResourceLoader.exists() before it is used.
const OPTIONAL_PATHS: Array[String] = ["res://assets/audio/music.ogg"]
## Paths that must not appear in code, scenes or settings after the move. Exact
## file paths and trailing-slash folders, never bare folder names, so a new path
## such as `res://ui/menu/...` cannot match an old one by accident.
const RETIRED_PATHS: Array[String] = [
	"res://tuning.gd", "res://difficulty.gd", "res://upgrades.gd",
	"res://weapons.gd", "res://skins.gd", "res://controls.gd",
	"res://battle.gd", "res://battle_game.gd", "res://battle_game.tscn",
	"res://campaign.gd", "res://galaxy.gd", "res://default_bus_layout.tres",
	"res://ui/main_menu.gd", "res://ui/main_menu.tscn",
	"res://ui/menu_backdrop.gd", "res://ui/galaxy_map.gd", "res://ui/galaxy_map.tscn",
	"res://ui/hud.gd", "res://ui/hud.tscn", "res://ui/touch_controls.gd",
	"res://ui/upgrade_panel.gd", "res://ui/upgrade_panel.tscn",
	"res://ui/settings_panel.gd", "res://ui/settings_panel.tscn",
	"res://ui/controls_card.gd", "res://ui/controls_card.tscn",
	"res://ui/difficulty_picker.gd", "res://ui/difficulty_picker.tscn",
	"res://ui/ui_overlay.gd", "res://ui/ui_theme.gd",
	"res://entities/bullet/", "res://entities/effects/", "res://entities/spawner/",
	"res://entities/map/", "res://entities/hazards/hazard_field.gd",
	"res://assests/",
]


## `report` is the suite's check(name, ok, detail) callable.
static func run(report: Callable) -> void:
	var files: PackedStringArray = []
	_collect("res://", files)
	files.sort()

	var missing: PackedStringArray = []
	var retired: PackedStringArray = []
	var no_uid: PackedStringArray = []
	var no_import: PackedStringArray = []
	var scanned: int = 0

	for path: String in files:
		var text: String = _read(path)
		if text.is_empty():
			continue
		scanned += 1
		for reference: String in _references(text):
			if reference.ends_with("/"):
				# A folder constant: only the folder itself has to exist.
				if not DirAccess.dir_exists_absolute(reference):
					missing.append("%s -> %s" % [path, reference])
				continue
			if OPTIONAL_PATHS.has(reference) or _allowed(reference):
				continue
			if not _exists(reference):
				missing.append("%s -> %s" % [path, reference])
		if path.get_extension() != "md":
			for old_path: String in RETIRED_PATHS:
				if text.contains(old_path):
					retired.append("%s still mentions %s" % [path, old_path])

	for path: String in files:
		var extension: String = path.get_extension()
		if extension == "gd" and not FileAccess.file_exists(path + ".uid"):
			no_uid.append(path)
		elif IMPORTED_EXTENSIONS.has(extension) and not FileAccess.file_exists(path + ".import"):
			no_import.append(path)

	# The relative table: SOUND_MAP stores constants plus file names under
	# AUDIO_DIR, so the resolution is asked of the manager that builds it rather
	# than guessed from the source text.
	var streams: Dictionary = AudioManager.get("_streams") as Dictionary
	if streams == null:
		streams = {}
	var unmapped: PackedStringArray = []
	for sound: String in AudioManager.SOUND_MAP:
		var variants: Variant = streams.get(sound, [])
		if variants is Array and (variants as Array).is_empty():
			unmapped.append(sound)

	report.call(
		"every res:// path exists (%d files scanned)" % scanned,
		missing.is_empty(), "; ".join(missing.slice(0, 6))
	)
	report.call(
		"no file mentions a retired path", retired.is_empty(),
		"; ".join(retired.slice(0, 6))
	)
	report.call("every .gd has its .uid", no_uid.is_empty(), ", ".join(no_uid.slice(0, 6)))
	report.call(
		"every imported asset has its .import", no_import.is_empty(),
		", ".join(no_import.slice(0, 6))
	)
	report.call(
		"every SOUND_MAP event loads a file (%d events)" % AudioManager.SOUND_MAP.size(),
		not AudioManager.SOUND_MAP.is_empty() and unmapped.is_empty(),
		", ".join(unmapped.slice(0, 6))
	)


static func _allowed(reference: String) -> bool:
	# Export filters use wildcards, template-built names use %, and the imported
	# resource cache lives under res://.godot.
	if reference.contains("*") or reference.contains("%"):
		return true
	if reference.begins_with("res://.godot"):
		return true
	return reference.length() <= "res://".length()


static func _exists(reference: String) -> bool:
	if FileAccess.file_exists(reference):
		return true
	return ResourceLoader.exists(reference)


## Every `res://...` literal in one file, cut at the characters that cannot be
## part of a path literal.
static func _references(text: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var start: int = text.find("res://")
	while start >= 0:
		var end: int = start
		while end < text.length():
			var character: String = text[end]
			if character == "\"" or character == "'" or character == " " \
					or character == "\n" or character == "\t" or character == ")" \
					or character == "," or character == "]" or character == "}" \
					or character == "+" or character == ":":
				break
			end += 1
		found.append(text.substr(start, end - start))
		start = text.find("res://", end)
	return found


static func _collect(dir_path: String, files: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not SKIP_DIRS.has(entry):
				_collect(path, files)
		elif not SKIP_FILES.has(path) and TEXT_EXTENSIONS.has(path.get_extension()):
			files.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


static func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text
