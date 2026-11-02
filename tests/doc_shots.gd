extends SceneTree
## Downscales the screenshots already captured by the screenshot runner into
## docs/screenshots/, small enough to commit.
##
##   godot --headless --path . --script tests/doc_shots.gd
##
## The captures live in test_output/ (git-ignored) because they are regenerated
## on every review; only the downscaled copies are kept in the repository. The
## width is fixed and the height follows the 960x600 aspect, so every image is
## 720x450 and lands well under the 300 KB budget.

const WIDTH: int = 720
## Published name -> the capture the runner actually wrote. Every entry is
## explicit on purpose: the old table only remapped three names and quietly fell
## back to test_output/<name>.png for the rest, which republished stale frames
## (a battle shot with empty weapon slots, a map shot from before the badge fix).
## A missing capture is now a hard error instead of a silent stale image.
const SOURCE_NAMES: Dictionary = {
	"menu": "readme_menu",
	"difficulty": "readme_difficulty",
	"map": "readme_map",
	"battle": "readme_battle",
	"upgrade": "readme_upgrade",
	"bullets_red": "readme_bullets_red",
	"victory": "readme_victory",
}
const SHOTS: Array[String] = [
	"menu", "difficulty", "map", "battle", "upgrade", "bullets_red", "victory",
]


func _initialize() -> void:
	var target_dir: String = ProjectSettings.globalize_path("res://docs/screenshots")
	var error: Error = DirAccess.make_dir_recursive_absolute(target_dir)
	if error != OK and error != ERR_ALREADY_EXISTS:
		printerr("doc shots: cannot create %s (%d)" % [target_dir, error])
		quit(1)
		return
	var failures: int = 0
	for shot: String in SHOTS:
		var source_name: String = String(SOURCE_NAMES.get(shot, "readme_%s" % shot))
		var from: String = ProjectSettings.globalize_path("res://test_output/%s.png" % source_name)
		var image := Image.new()
		var read_error: Error = image.load(from)
		if read_error != OK:
			printerr("doc shots: cannot read %s (%d)" % [from, read_error])
			failures += 1
			continue
		var height: int = roundi(
			float(image.get_height()) * float(WIDTH) / float(maxi(image.get_width(), 1))
		)
		image.resize(WIDTH, height, Image.INTERPOLATE_LANCZOS)
		var to: String = "%s/%s.png" % [target_dir, shot]
		var save_error: Error = image.save_png(to)
		if save_error != OK:
			printerr("doc shots: cannot write %s (%d)" % [to, save_error])
			failures += 1
			continue
		var size: int = FileAccess.get_file_as_bytes(to).size()
		print("DOC SHOT %s -> %dx%d, %d bytes" % [shot, WIDTH, height, size])
	quit(1 if failures > 0 else 0)
