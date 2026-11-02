extends Node
## Captures one 960x600 viewport PNG of a scene, for eyeballing layouts.
##
##   godot --path . res://tests/screenshot_runner.tscn -- <scene> <name> [frames] [mode] [option]
##
## Modes:
##   (empty)      just run the scene
##   open         call the panel's own open()
##   reveal       open() and also show every hidden Control (geometry only)
##   tooltip      galaxy map: select a reachable body and show its tooltip
##   conquer      galaxy map: open the CONQUER card for the first reachable body
##   pause        battle: raise the pause card
##   victory      battle: stop the live battle, then fill the victory card; the
##                capture aborts if a wave banner is still on screen
##   defeat       battle: fill the game-over card with a sample run
##   bullets      battle: freeze four enemy bullets; option = background colour
##   thruster     option = "player" or an enemy kind; five copies at five headings
##
## Needs a real window and GPU (no `--headless`): the headless driver has no
## framebuffer, so the image would come back empty. The scene is added as a
## child of this node, which is enough for every screen in the project because
## they all anchor to the viewport.

const SHIP_SCENE: PackedScene = preload("res://entities/player/ship.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://entities/enemies/enemy_base.tscn")
const ENEMY_BULLET_SCENE: PackedScene = preload("res://entities/projectiles/enemy_bullet.tscn")
## Headings every thruster shot shows: nose up, right, down, left and 45 degrees.
const HEADINGS: Array[float] = [0.0, PI * 0.5, PI, -PI * 0.5, PI * 0.25]
const POSE_ROW_Y: float = 300.0
const POSE_START_X: float = 160.0
const POSE_STEP_X: float = 160.0


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
	var mode: String = args[3] if args.size() > 3 else ""
	var option: String = args[4] if args.size() > 4 else ""
	# The map leaves for the front end without an active run; a map capture needs
	# a galaxy, and a fixed seed in memory keeps captures comparable between
	# runs. Nothing is written to the save.
	if not SaveData.campaign_active and scene_path.ends_with("galaxy_map.tscn"):
		SaveData.campaign_active = true
		SaveData.campaign_seed = 20260101

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("screenshot runner: cannot load %s" % scene_path)
		get_tree().quit(1)
		return
	var node: Node = packed.instantiate()
	add_child(node)
	# The project theme, applied before any capture: a bare overlay panel has no
	# parent screen to inherit it from, so without this the shot would use the
	# engine defaults and look nothing like the game.
	var root := node as Control
	if root != null:
		UITheme.apply(root)
	if not mode.is_empty():
		await get_tree().process_frame
		_apply_mode(node, mode, option)
		# Container layout needs two passes to settle, then one more idle frame so
		# a card that was just opened has sorted its children. Capturing earlier
		# shows clipping that is capture timing, not a layout defect.
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		if mode == "victory":
			# A README frame that shows the card must not also show a wave banner.
			# An earlier capture of a live battle caught the director's next banner
			# on top of the card, which is what the published shot showed.
			var banner := node.get_node_or_null("HUD/Root/BannerLabel") as Label
			if banner != null and banner.visible:
				push_error("screenshot runner: a wave banner is visible over the victory card")
				get_tree().quit(1)
				return
		if mode == "credits":
			# Scroll first, then freeze the roll, so the still shows the position
			# the option asked for and not wherever the auto-roll had got to.
			_set_credits_scroll(node, option)
			node.set_process(false)
	for _frame: int in maxi(frames, 1):
		await get_tree().process_frame
	# Wait for the frame to actually be drawn before reading the framebuffer.
	await RenderingServer.frame_post_draw

	var image: Image = get_viewport().get_texture().get_image()
	_ensure_output_dir()
	var path: String = "res://test_output/%s.png" % shot_name
	var error: Error = image.save_png(path)
	print(
		"SHOT %s -> %s (%dx%d, err=%d)"
		% [scene_path, path, image.get_width(), image.get_height(), error]
	)
	get_tree().quit(0 if error == OK else 1)


## The capture folder is not part of the project. An empty .gdignore stops
## Godot from importing every PNG it collects (which used to leave a .import
## beside each shot and put the folder into the import scan), while .gitignore
## keeps the folder out of the tree. Written here so a fresh checkout gets it.
func _ensure_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute("res://test_output")
	var marker: String = "res://test_output/.gdignore"
	if FileAccess.file_exists(marker):
		return
	var file := FileAccess.open(marker, FileAccess.WRITE)
	if file != null:
		file.close()


func _apply_mode(node: Node, mode: String, option: String) -> void:
	match mode:
		"open", "reveal":
			if node.has_method("open"):
				node.call("open")
			if mode == "reveal":
				_show_controls(node)
		"tooltip":
			var body_id: StringName = _first_body()
			if body_id != &"" and node.has_method("_show_tooltip"):
				node.call("_show_tooltip", body_id)
		"conquer":
			var body_id: StringName = _first_body()
			if body_id != &"" and node.has_method("_open_card"):
				node.call("_open_card", body_id)
		"pause":
			_hud(node, "show_paused", [])
		"victory":
			_pose_victory(node)
		"defeat":
			_hud(node, "show_game_over", [_sample_defeat()])
		"bullets":
			_show_bullets(node, option)
		"thruster":
			_pose_thrusters(node, option)
		"elite":
			_pose_elites(node, option)
		"upgrade":
			_pose_upgrade(node, option)
		"credits":
			if node.has_method("open"):
				node.call("open")
		"badges":
			_pose_map_badges(node, option)


## The map with every body conquered, at the zoom the shot asks for, so the
## check badges can be judged on a rock, a big planet, a citadel and a warpgate
## in one still.
func _pose_map_badges(node: Node, option: String) -> void:
	var map := node as GalaxyMap
	if map == null:
		push_warning("screenshot runner: the badges mode needs the galaxy map scene")
		return
	var zoom: float = float(option) if not option.is_empty() else 1.0
	var galaxy: Galaxy = Campaign.galaxy()
	SaveData.campaign_conquered.clear()
	for body_id: StringName in galaxy.order:
		SaveData.campaign_conquered.append(body_id)
	map.call("_refresh")
	map.call("_set_zoom", zoom, Tuning.VIEW_SIZE * 0.5)
	map.call("_center_on", galaxy.home_id)


## The victory card, built through the HUD's own show_victory. The live director
## is stopped and the arena frozen first: a running battle raises its next wave
## banner a few frames later, which is how one got onto the published shot.
func _pose_victory(node: Node) -> void:
	var director := node.get_node_or_null("World/WaveDirector") as WaveDirector
	if director != null:
		director.stop()
	var world := node.get_node_or_null("World") as Node2D
	if world != null:
		world.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := node.get_node_or_null("HUD") as BattleHUD
	if hud == null:
		push_warning("screenshot runner: the victory mode needs the battle HUD")
		return
	hud.show_victory(_sample_victory())


## The first body the player may attack, which is what a tap on the map picks.
func _first_body() -> StringName:
	var open: Array[StringName] = Campaign.attackable()
	if open.is_empty():
		push_warning("screenshot runner: no reachable body (no campaign in the save)")
		return &""
	return open[0]


func _hud(node: Node, method: StringName, args: Array) -> void:
	var hud := node.get_node_or_null("HUD")
	if hud == null or not hud.has_method(method):
		push_warning("screenshot runner: %s has no HUD.%s" % [node.name, method])
		return
	hud.callv(method, args)


func _sample_victory() -> Dictionary:
	return {
		"name": "KEPLER REACH", "wave": 2, "waves": 2, "kills": 17, "total": 18,
		"score": 1250, "total_score": 4320, "perfect": true, "energy": 40,
		"difficulty": "VECTOR", "heal": 30, "max_hp": 120, "hp": 120,
		"heal_fraction": 0.25,
	}


func _sample_defeat() -> Dictionary:
	return {
		"score": 9820, "high": 9820, "new_high": true, "planets": 7, "bodies": 56,
		"band": "PURPLE DEEP", "difficulty": "SUPERNOVA", "wave": 2,
		"action": String(Difficulty.RESET), "wiped": [],
	}


## Swaps the arena backdrop, so the same subject can be judged on all four
## distance bands.
func _set_background(node: Node, background: String) -> void:
	if background.is_empty():
		return
	var world := node.get_node_or_null("World")
	if world == null:
		return
	var backdrop := world.get_node_or_null("Backdrop") as TextureRect
	var path := "res://assets/backgrounds/background-%s.png" % background
	if backdrop != null and ResourceLoader.exists(path):
		backdrop.texture = load(path) as Texture2D


## Three copies of one elite kind on a chosen backdrop: the shot that answers
## "can this silhouette be read here?".
func _pose_elites(node: Node, option: String) -> void:
	var parts := option.split(";")
	var kind: StringName = StringName(parts[0]) if parts.size() > 0 and not parts[0].is_empty() else &"elite_red"
	_set_background(node, parts[1] if parts.size() > 1 else "")
	var world := node.get_node_or_null("World")
	if world == null:
		return
	var holder := Node2D.new()
	holder.name = "ElitePoses"
	world.add_child(holder)
	for index: int in 3:
		var enemy := FIGHTER_SCENE.instantiate() as EnemyBase
		enemy.configure(kind, Vector2(240.0 + float(index) * 240.0, 320.0), null)
		holder.add_child(enemy)
		var warp := enemy.get_node_or_null("Warp") as CanvasItem
		if warp != null:
			warp.visible = false
		var sprite := enemy.get_node_or_null("Sprite") as CanvasItem
		if sprite != null:
			sprite.visible = true
		var flash := enemy.get_node_or_null("FlashSprite") as CanvasItem
		if flash != null:
			flash.visible = true
			flash.modulate.a = 0.0
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.rotation = 0.0
		_pin_flame(enemy)


## The upgrade panel with a real tab, a real skin and a focused card.
## option = "hull:equipped" / "weapons:locked" etc.
func _pose_upgrade(node: Node, option: String) -> void:
	if node.has_method("open"):
		node.call("open")
	var parts := option.split(":")
	var tab: String = parts[0] if parts.size() > 0 else "hull"
	var skin: String = parts[1] if parts.size() > 1 else ""
	var tab_path: String = "Panel/Margin/Box/Tabs/WeaponTab" if tab == "weapons" \
		else "Panel/Margin/Box/Tabs/HullTab"
	var tab_button := node.get_node_or_null(tab_path) as Button
	if tab_button != null:
		tab_button.pressed.emit()
	if not skin.is_empty():
		var skin_button := node.get_node_or_null(
			"Panel/Margin/Box/Scroll/Page/Skins/Row/Skin_%s" % skin
		) as Button
		if skin_button != null:
			skin_button.pressed.emit()
	if tab == "weapons":
		var row := node.get_node_or_null("Panel/Margin/Box/Scroll/Page/Body/Weapons/Row")
		if row != null and row.get_child_count() > 0:
			var first := row.get_child(0) as Button
			if first != null:
				first.grab_focus()
		return
	var card := node.get_node_or_null(
		"Panel/Margin/Box/Scroll/Page/Body/Grid/HullCard"
	) as Button
	if card != null:
		card.grab_focus()


## Where to park the credits roll: start, middle or end. The card scrolls itself
## through its own _process, so the still sets the roll's position directly.
func _set_credits_scroll(node: Node, option: String) -> void:
	var roll := node.get_node_or_null("Panel/Margin/Box/Roll/RollBox") as Control
	var clip := node.get_node_or_null("Panel/Margin/Box/Roll") as Control
	if roll == null or clip == null:
		push_warning("screenshot runner: the credits card has no roll")
		return
	var progress: float = 0.0
	match option:
		"middle":
			progress = 0.5
		"end":
			progress = 1.0
	var span: float = maxf(roll.size.y - clip.size.y, 0.0)
	roll.position = Vector2(0.0, -span * progress)


## Four frozen bullets of the real art, on whichever backdrop the shot asks for,
## so the contrast of the enemy shots can be judged on every band.
func _show_bullets(node: Node, background: String) -> void:
	_set_background(node, background)
	var world := node.get_node_or_null("World")
	if world == null:
		return
	var holder := world.get_node_or_null("EnemyBullets")
	if holder == null:
		return
	for index: int in 4:
		var bullet := ENEMY_BULLET_SCENE.instantiate()
		bullet.set("position", Vector2(300.0 + float(index) * 100.0, 300.0))
		bullet.set("direction", Vector2.DOWN)
		bullet.set("high_contrast", SaveData.high_contrast_bullets)
		bullet.set("hot_backdrop", background == "red")
		# Frozen: the shot is a still, and a flying bullet would be off screen.
		bullet.process_mode = Node.PROCESS_MODE_DISABLED
		holder.add_child(bullet)


## Five copies of one hull, each at a different heading, all at full thrust:
## one still that shows the flame's anchor and width at every rotation.
func _pose_thrusters(node: Node, option: String) -> void:
	var world := node.get_node_or_null("World")
	if world == null:
		return
	var holder := Node2D.new()
	holder.name = "ThrusterPoses"
	world.add_child(holder)
	var is_player: bool = option.is_empty() or option == "player"
	for index: int in HEADINGS.size():
		var at := Vector2(POSE_START_X + POSE_STEP_X * float(index), POSE_ROW_Y)
		var hull: Node2D
		if is_player:
			var ship := SHIP_SCENE.instantiate() as Node2D
			holder.add_child(ship)
			ship.position = at
			hull = ship
		else:
			var enemy := FIGHTER_SCENE.instantiate() as EnemyBase
			enemy.configure(StringName(option), at, null)
			holder.add_child(enemy)
			# Out of the warp and visible immediately; the AI is frozen so the
			# pose below is what the shot shows.
			var warp := enemy.get_node_or_null("Warp") as CanvasItem
			if warp != null:
				warp.visible = false
			var sprite := enemy.get_node_or_null("Sprite") as CanvasItem
			if sprite != null:
				sprite.visible = true
			hull = enemy
		hull.process_mode = Node.PROCESS_MODE_DISABLED
		hull.rotation = HEADINGS[index]
		_pin_flame(hull)


## Full thrust, pinned to the longest frame: a frozen node will not animate, so
## a still would otherwise show the two-row first frame instead of a flame.
func _pin_flame(hull: Node) -> void:
	var flame := hull.get_node_or_null("Thruster") as Thruster
	if flame == null:
		return
	flame.set_thrust(1.0)
	var frames := flame.sprite_frames
	if frames != null and frames.has_animation(&"burn"):
		flame.frame = frames.get_frame_count(&"burn") - 1
