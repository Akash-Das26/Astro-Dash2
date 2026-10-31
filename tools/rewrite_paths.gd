extends SceneTree
## One-shot migration helper for the folder reorganisation, deleted when the
## stage is done.
##
##   godot --headless --path . --script tools/rewrite_paths.gd
##
## Reads tools/move_map.tsv (`old/path<TAB>new/path`, relative to res://), then
## rewrites every occurrence of an old path with its new one in the project's
## text files: `res://` strings in .gd, `ext_resource path=` in .tscn/.tres,
## `source_file=` in .import, autoload and main-scene entries in project.godot,
## and the paths in .cfg/.md/.ps1 files.
##
## Entries are applied longest-first and exactly once per file, so a mapping
## whose destination contains its own source (tuning.gd -> config/tuning.gd)
## cannot cascade. UIDs are never touched.

const MAP_PATH := "res://tools/move_map.tsv"
const TEXT_EXTENSIONS: Array[String] = [
	"gd", "tscn", "tres", "godot", "cfg", "md", "ps1", "import", "yml",
	"gitignore", "gitattributes", "editorconfig",
]
## Folders never rewritten: engine cache, VCS, output, third-party footage.
const SKIP_DIRS: Array[String] = [".git", ".godot", "test_output", "export", "reference"]
## Documents that must keep recording the old paths.
const SKIP_FILES: Array[String] = [
	"res://docs/reorg_plan.md", "res://docs/orphans.md", "res://tools/rewrite_paths.gd",
]


func _initialize() -> void:
	var pairs: Array = _read_map()
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0].length() > b[0].length())
	if pairs.is_empty():
		print("REWRITE: no mapping rows, nothing to do")
		quit(0)
		return

	var changed: PackedStringArray = []
	var files: PackedStringArray = []
	_collect("res://", files)
	for path: String in files:
		var text: String = _read(path)
		if text.is_empty():
			continue
		var original: String = text
		for pair: Array in pairs:
			text = text.replace(String(pair[0]), String(pair[1]))
		if text != original:
			_write(path, text)
			changed.append(path)
	print("REWRITE: %d mapping row(s), %d file(s) changed" % [pairs.size(), changed.size()])
	for path: String in changed:
		print("  ", path)
	quit(0)


func _read_map() -> Array:
	var pairs: Array = []
	if not FileAccess.file_exists(MAP_PATH):
		push_error("rewrite: %s is missing" % MAP_PATH)
		return pairs
	var lines: PackedStringArray = _read(MAP_PATH).split("\n", false)
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		var parts: PackedStringArray = trimmed.split("\t")
		if parts.size() < 2:
			push_warning("rewrite: ignoring malformed row '%s'" % trimmed)
			continue
		var old_path: String = parts[0].strip_edges()
		var new_path: String = parts[1].strip_edges()
		if old_path != new_path:
			pairs.append([old_path, new_path])
	return pairs


func _collect(dir_path: String, files: PackedStringArray) -> void:
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


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("rewrite: cannot write %s" % path)
		return
	file.store_string(text)
	file.close()
