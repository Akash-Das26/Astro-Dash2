extends SceneTree
## Re-saves every scene and resource once, so the `path=` stored next to each
## `uid=` in the file matches where the resource actually lives after the move.
##
##   godot --headless --path . --script tools/resave.gd
##
## Godot resolves moved resources by UID and only rewrites the stored path when
## the file is saved, which is why this exists. Files whose bytes did not change
## are reported as unchanged.

const EXTENSIONS: Array[String] = ["tscn", "tres"]
const SKIP_DIRS: Array[String] = [".git", ".godot", "test_output", "export", "reference"]


func _initialize() -> void:
	var files: PackedStringArray = []
	_collect("res://", files)
	files.sort()
	var changed: PackedStringArray = []
	var failed: PackedStringArray = []
	for path: String in files:
		var before: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null:
			failed.append("%s (cannot load)" % path)
			continue
		var error: Error = ResourceSaver.save(resource, path)
		if error != OK:
			failed.append("%s (save error %d)" % [path, error])
			continue
		var after: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if before != after:
			changed.append(path)
	print("RESAVE: %d file(s) checked, %d rewritten, %d failed" % [
		files.size(), changed.size(), failed.size(),
	])
	for path: String in changed:
		print("  rewritten ", path)
	for path: String in failed:
		print("  FAILED ", path)
	quit(1 if not failed.is_empty() else 0)


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
		elif EXTENSIONS.has(path.get_extension()):
			files.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
