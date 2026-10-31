extends Node
## Captures one 960x600 viewport PNG of a scene, for eyeballing layouts.
##
##   godot --path . res://tests/screenshot_runner.tscn -- <scene> <name> [frames]
##
## Needs a real window and GPU (no `--headless`): the headless driver has no
## framebuffer, so the image would come back empty. The scene is added as a
## child of this node, which is enough for every screen in the project because
## they all anchor to the viewport.

## Walks the instantiated scene and shows every Control, so the layout of a
## hidden card can be inspected.
func _show_controls(node: Node) -> void:
	var control := node as Control
	if control != null:
		control.visible = true
	for child: Node in node.get_children():
		_show_controls(child)


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://ui/menu/main_menu.tscn"
	var shot_name: String = args[1] if args.size() > 1 else "shot"
	var frames: int = int(args[2]) if args.size() > 2 else 60

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("screenshot runner: cannot load %s" % scene_path)
		get_tree().quit(1)
		return
	var node: Node = packed.instantiate()
	add_child(node)
	# Overlay scenes (upgrade panel, settings, controls, picker) start hidden and
	# are opened by their parent, so a bare instantiation captures nothing. The
	# fourth argument asks for the scene to be opened and every Control shown.
	# `open` calls the scene's own open path and nothing else, which is what the
	# player sees; `reveal` additionally shows every hidden Control, which is
	# only good for geometry, because it stacks layers that never coexist.
	var mode: String = args[3] if args.size() > 3 else ""
	if mode == "open" or mode == "reveal":
		await get_tree().process_frame
		if node.has_method("open"):
			node.call("open")
		if mode == "reveal":
			_show_controls(node)
	for _frame: int in maxi(frames, 1):
		await get_tree().process_frame
	# Wait for the frame to actually be drawn before reading the framebuffer.
	await RenderingServer.frame_post_draw

	var image: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://test_output")
	var path: String = "res://test_output/%s.png" % shot_name
	var error: Error = image.save_png(path)
	print(
		"SHOT %s -> %s (%dx%d, err=%d)"
		% [scene_path, path, image.get_width(), image.get_height(), error]
	)
	get_tree().quit(0 if error == OK else 1)
