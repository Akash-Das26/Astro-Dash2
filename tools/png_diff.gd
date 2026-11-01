extends SceneTree
## Pixel-diffs two PNGs, for comparing the screenshots taken before and after
## the reorganisation. Animated scenes are expected to differ; what matters is
## WHERE they differ, so this prints the differing pixel count and the bounding
## box of the changes.
##
##   godot --headless --path . --script tools/png_diff.gd -- <a.png> <b.png>

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: png_diff.gd -- <a.png> <b.png>")
		quit(2)
		return
	var a: Image = Image.load_from_file(args[0])
	var b: Image = Image.load_from_file(args[1])
	if a == null or b == null:
		printerr("cannot load %s / %s" % [args[0], args[1]])
		quit(2)
		return
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		print("SIZE differs: %dx%d vs %dx%d" % [
			a.get_width(), a.get_height(), b.get_width(), b.get_height(),
		])
		quit(1)
		return
	var first_x: int = a.get_width()
	var first_y: int = a.get_height()
	var last_x: int = -1
	var last_y: int = -1
	var changed: int = 0
	var total: int = a.get_width() * a.get_height()
	for y: int in a.get_height():
		for x: int in a.get_width():
			var pa: Color = a.get_pixel(x, y)
			var pb: Color = b.get_pixel(x, y)
			if not pa.is_equal_approx(pb):
				changed += 1
				first_x = mini(first_x, x)
				first_y = mini(first_y, y)
				last_x = maxi(last_x, x)
				last_y = maxi(last_y, y)
	var percent: float = 100.0 * float(changed) / float(total)
	if changed == 0:
		print("PIXELS identical (%dx%d)" % [a.get_width(), a.get_height()])
	else:
		print("PIXELS %d of %d differ (%.3f%%), bbox x %d..%d y %d..%d" % [
			changed, total, percent, first_x, last_x, first_y, last_y,
		])
	quit(0)
