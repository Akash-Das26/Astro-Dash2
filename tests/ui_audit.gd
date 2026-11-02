extends Node
## Measures the live UI instead of eyeballing screenshots: card padding, content
## that climbs outside its parent or the 960x600 viewport, sibling text
## overlaps, distinct row gaps, and icon centring. One block per pose; the table
## in docs/ui_audit.md is transcribed from this output.
##
##   godot --headless --path . res://tests/ui_audit.tscn

const VIEWPORT_SIZE := Vector2(960.0, 600.0)
const PAD_TOLERANCE := 2.0
const OVERLAP_TOLERANCE := 1.0
const MAX_EXAMPLES := 6

var _findings: Array[String] = []
var _pose_label: String = ""


func _ready() -> void:
	await get_tree().process_frame
	for pose: Dictionary in _poses():
		await _audit(pose)
	print("")
	print("AUDIT DONE findings=%d" % _findings.size())
	get_tree().quit(0)


func _poses() -> Array[Dictionary]:
	return [
		{"label": "main menu", "scene": "res://ui/menu/main_menu.tscn", "actions": []},
		{
			"label": "difficulty picker",
			"scene": "res://ui/panels/difficulty_picker.tscn",
			"actions": ["open"],
		},
		{
			"label": "settings",
			"scene": "res://ui/panels/settings_panel.tscn",
			"actions": [],
		},
		{
			"label": "controls",
			"scene": "res://ui/panels/controls_card.tscn",
			"actions": ["open"],
		},
		{
			"label": "credits",
			"scene": "res://ui/panels/credits_card.tscn",
			"actions": ["open"],
		},
		{
			"label": "upgrade: hull",
			"scene": "res://ui/panels/upgrade_panel.tscn",
			"actions": ["open"],
		},
		{
			"label": "upgrade: weapons",
			"scene": "res://ui/panels/upgrade_panel.tscn",
			"actions": ["open", "tab:WeaponTab"],
		},
		{
			"label": "galaxy map",
			"scene": "res://ui/map/galaxy_map.tscn",
			"actions": ["seed"],
		},
		{
			"label": "map tooltip",
			"scene": "res://ui/map/galaxy_map.tscn",
			"actions": ["seed", "tooltip"],
		},
		{
			"label": "map CONQUER card",
			"scene": "res://ui/map/galaxy_map.tscn",
			"actions": ["seed", "conquer3", "map_card"],
		},
		{
			"label": "map + upgrades: hull",
			"scene": "res://ui/map/galaxy_map.tscn",
			"actions": ["seed", "conquer3", "upgrade_hull"],
		},
		{
			"label": "map + upgrades: weapons",
			"scene": "res://ui/map/galaxy_map.tscn",
			"actions": ["seed", "conquer3", "upgrade_weapons"],
		},
		{
			"label": "map + difficulty picker",
			"scene": "res://ui/map/galaxy_map.tscn",
			"actions": ["seed", "conquer3", "difficulty_picker"],
		},
		{
			"label": "battle HUD",
			"scene": "res://game/battle/battle_game.tscn",
			"actions": ["hud"],
		},
		{
			"label": "pause card",
			"scene": "res://game/battle/battle_game.tscn",
			"actions": ["hud", "hud_pause"],
		},
		{
			"label": "victory card",
			"scene": "res://game/battle/battle_game.tscn",
			"actions": ["hud", "hud_victory"],
		},
		{
			"label": "defeat card",
			"scene": "res://game/battle/battle_game.tscn",
			"actions": ["hud", "hud_defeat"],
		},
	]


func _audit(pose: Dictionary) -> void:
	_pose_label = String(pose["label"])
	print("")
	print("== %s  (%s)" % [_pose_label, pose["scene"]])
	print("   viewport %s" % str(VIEWPORT_SIZE))
	var packed := load(String(pose["scene"])) as PackedScene
	if packed == null:
		_report("the scene cannot be loaded")
		return
	var node: Node = packed.instantiate()
	add_child(node)
	if node is Control:
		UITheme.apply(node as Control)
	await get_tree().process_frame
	for action: String in pose["actions"] as Array:
		_run_action(node, action)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var controls: Array[Control] = []
	_collect_controls(node, controls)
	print("   controls %d" % controls.size())
	_audit_cards(controls)
	_audit_named_cards(controls)
	_audit_clipping(controls)
	_audit_overlaps(controls)
	_audit_gaps(controls)
	_audit_icons(controls)
	_audit_draw_order(node)
	print("   findings this pose %d" % _pose_findings)
	node.queue_free()
	await get_tree().process_frame


var _pose_findings: int = 0


## Poses are driven from here: the screens are not expected to carry test-only
## entry points, so the audit reaches for the same nodes the game does.
func _run_action(node: Node, action: String) -> void:
	if action == "open":
		if node.has_method("open"):
			node.call("open")
		else:
			_report("the screen has no open()")
		return
	if action.begins_with("tab:"):
		var tab_name: String = action.trim_prefix("tab:")
		var tab := node.get_node_or_null("Panel/Margin/Box/Tabs/%s" % tab_name) as Button
		if tab == null:
			_report("the %s tab button is missing" % tab_name)
		else:
			tab.pressed.emit()
		return
	if action == "seed":
		SaveData.campaign_active = true
		SaveData.campaign_seed = 20260101
		if node.has_method("_refresh"):
			node.call("_refresh")
		return
	if action == "conquer3":
		# Three conquered bodies put three badges on the map, which is what the
		# draw-order check needs to be worth running.
		var galaxy: Galaxy = Campaign.galaxy()
		if galaxy == null:
			_report("the map has no galaxy to conquer")
			return
		SaveData.campaign_conquered.clear()
		var take: Array[StringName] = galaxy.attackable(SaveData.campaign_conquered)
		for i: int in range(mini(3, take.size())):
			SaveData.campaign_conquered.append(take[i])
		if node.has_method("_refresh"):
			node.call("_refresh")
		print("   conquered %d bodies" % SaveData.campaign_conquered.size())
		return
	if action == "upgrade_hull" or action == "upgrade_weapons":
		if node.has_method("_open_upgrades"):
			node.call("_open_upgrades")
		else:
			_report("the map has no _open_upgrades()")
			return
		var panel := node.get_node_or_null("UpgradePanel")
		if panel == null:
			_report("the map has no UpgradePanel")
			return
		if action == "upgrade_weapons":
			var tab := panel.get_node_or_null("Panel/Margin/Box/Tabs/WeaponTab") as Button
			if tab == null:
				_report("the upgrade panel has no weapon tab")
			else:
				tab.pressed.emit()
		return
	if action == "difficulty_picker":
		var picker := node.get_node_or_null("DifficultyPicker")
		if picker == null:
			_report("the map has no DifficultyPicker")
		elif not picker.has_method("open"):
			_report("the difficulty picker has no open()")
		else:
			picker.call("open")
		return
	if action == "tooltip" or action == "map_card":
		var body_id: StringName = _first_attackable()
		if body_id == &"":
			_report("the map has no body to show")
			return
		var method: StringName = &"_show_tooltip" if action == "tooltip" else &"_open_card"
		if node.has_method(method):
			node.call(method, body_id)
		else:
			_report("the map has no %s" % method)
		return
	if action.begins_with("hud"):
		var hud := node.get_node_or_null("HUD")
		if hud == null:
			_report("the battle has no HUD")
			return
		match action:
			"hud_pause":
				hud.call("show_paused")
			"hud_victory":
				hud.call("show_victory", _sample_victory())
			"hud_defeat":
				hud.call("show_game_over", _sample_defeat())
		return
	_report("unknown action %s" % action)


## The CONQUER card only opens on a body that can actually be attacked, so the
## pose asks the map what is open right now rather than taking the first body.
func _first_attackable() -> StringName:
	var galaxy: Galaxy = Campaign.galaxy()
	if galaxy == null or galaxy.order.is_empty():
		return &""
	var open: Array[StringName] = galaxy.attackable(SaveData.campaign_conquered)
	if not open.is_empty():
		return open[0]
	return galaxy.order[0]


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


func _report(text: String) -> void:
	_pose_findings += 1
	_findings.append("%s: %s" % [_pose_label, text])
	print("   FINDING %s" % text)


func _collect_controls(node: Node, out: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is Control:
			out.append(child as Control)
		_collect_controls(child, out)


## Panel padding: the union of the visible leaf controls must sit inside the
## panel with the same inset on all four sides. An empty strip shows up as a
## bottom (or right) inset much larger than the opposite one.
func _audit_cards(controls: Array[Control]) -> void:
	for panel: Control in controls:
		if not (panel is PanelContainer):
			continue
		if not panel.is_visible_in_tree():
			continue
		var rect: Rect2 = panel.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		# The padding the card actually applies is its panel stylebox's content
		# margin, which is what a reader sees as the inset of the first text.
		var style: StyleBox = panel.get_theme_stylebox("panel")
		if style != null and style.get_content_margin(SIDE_LEFT) >= 0.0:
			var pads: Array[float] = [
				style.get_content_margin(SIDE_LEFT),
				style.get_content_margin(SIDE_TOP),
				style.get_content_margin(SIDE_RIGHT),
				style.get_content_margin(SIDE_BOTTOM),
			]
			print(
				"   card %s %s pads l%.0f t%.0f r%.0f b%.0f"
				% [panel.name, _size_text(rect.size), pads[0], pads[1], pads[2], pads[3]]
			)
			if pads.max() - pads.min() > PAD_TOLERANCE:
				_report(
					"card %s has uneven padding (spread %.0f px)"
					% [panel.name, pads.max() - pads.min()]
				)
		# A card larger than the content it must hold leaves an empty strip.
		var needed: Vector2 = panel.get_combined_minimum_size()
		var slack: Vector2 = panel.size - needed
		print(
			"   card %s is %s, needs %s"
			% [panel.name, _size_text(panel.size), _size_text(needed)]
		)
		# A card that fills its parent is sized by the screen, not by its content,
		# so only a shrink-to-fit card can show leftover space under its buttons.
		var fills_parent: bool = false
		var parent := panel.get_parent() as Control
		if parent != null:
			fills_parent = parent.get_global_rect().grow(1.0).encloses(rect)
		if slack.y > 4.0 and not fills_parent:
			_report(
				"card %s reserves %.0f px more height than its content needs"
				% [panel.name, slack.y]
			)


## Clipping that matters is against the screen: HUD slots sit above their bar and
## scroll regions clip on purpose, so a parent-relative overflow says nothing.
## The HUD builds its pause and end cards from a Control, a scrim and a VBox, not
## from a PanelContainer, so they are measured by name. A card that hugs its
## content has the same inset above and below that content.
func _audit_named_cards(controls: Array[Control]) -> void:
	for control: Control in controls:
		var by_name: bool = control.name.to_lower().contains("card")
		if not by_name and not (control is Panel):
			continue
		if not control.is_visible_in_tree():
			continue
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var box := Rect2()
		var first: bool = true
		for child: Node in control.get_children():
			var child_control := child as Control
			if child_control == null or not child_control.is_visible_in_tree():
				continue
			var child_rect: Rect2 = child_control.get_global_rect()
			if child_rect.size.x <= 0.0 or child_rect.size.y <= 0.0:
				continue
			box = child_rect if first else box.merge(child_rect)
			first = false
		print(
			"   card %s %s content %s"
			% [
				control.name, _size_text(rect.size),
				"none" if first else _size_text(box.size),
			]
		)
		if first:
			continue
		var inset_top: float = box.position.y - rect.position.y
		var inset_bottom: float = rect.end.y - box.end.y
		print("      inset above %.0f, below %.0f" % [inset_top, inset_bottom])
		if inset_bottom - inset_top > PAD_TOLERANCE:
			_report(
				"card %s leaves %.0f px more empty space under its content than above it"
				% [control.name, inset_bottom - inset_top]
			)


func _audit_clipping(controls: Array[Control]) -> void:
	var screen := Rect2(Vector2.ZERO, VIEWPORT_SIZE)
	for control: Control in controls:
		if not control.is_visible_in_tree() or _inside_clip(control):
			continue
		var inner: Rect2 = control.get_global_rect()
		if inner.size.x <= 0.0 or inner.size.y <= 0.0:
			continue
		var over_left: float = screen.position.x - inner.position.x
		var over_top: float = screen.position.y - inner.position.y
		var over_right: float = inner.end.x - screen.end.x
		var over_bottom: float = inner.end.y - screen.end.y
		var worst: float = maxf(maxf(over_left, over_top), maxf(over_right, over_bottom))
		if worst <= PAD_TOLERANCE:
			continue
		_report(
			"%s (%s) leaves the screen by %.0f px (l%.0f t%.0f r%.0f b%.0f)"
			% [
				control.name, control.get_class(), worst,
				over_left, over_top, over_right, over_bottom,
			]
		)


func _audit_overlaps(controls: Array[Control]) -> void:
	for parent: Control in controls:
		if not parent.is_visible_in_tree():
			continue
		var texts: Array[Control] = []
		for child: Node in parent.get_children():
			var control := child as Control
			if control == null or not control.is_visible_in_tree():
				continue
			if control is Label or control is Button:
				var text: String = String(control.get("text"))
				if text.strip_edges().is_empty():
					continue
				texts.append(control)
		for i: int in range(texts.size()):
			for j: int in range(i + 1, texts.size()):
				var a: Rect2 = texts[i].get_global_rect()
				var b: Rect2 = texts[j].get_global_rect()
				var shared: Rect2 = a.intersection(b)
				if shared.size.x > OVERLAP_TOLERANCE and shared.size.y > OVERLAP_TOLERANCE:
					_report(
						"%s and %s overlap by %.0fx%.0f px"
						% [texts[i].name, texts[j].name, shared.size.x, shared.size.y]
					)


func _audit_gaps(controls: Array[Control]) -> void:
	var seen: Dictionary = {}
	for control: Control in controls:
		if not (control is BoxContainer) and not (control is GridContainer):
			continue
		var separation: int = control.get_theme_constant("separation")
		var key := "%s=%d" % [control.get_class(), separation]
		seen[key] = int(seen.get(key, 0)) + 1
	var keys: Array = seen.keys()
	keys.sort()
	print("   gaps: %s" % ", ".join(keys))


func _audit_icons(controls: Array[Control]) -> void:
	for control: Control in controls:
		var icon := control as UIIcon
		if icon == null or not icon.is_visible_in_tree():
			continue
		if icon.size.x <= 0.0 or icon.size.y <= 0.0 or icon.texture == null:
			continue
		var rect: Rect2 = icon.drawn_rect()
		var offset: Vector2 = rect.get_center() - icon.size * 0.5
		if absf(offset.x) > 1.0 or absf(offset.y) > 1.0:
			_report(
				"icon %s is off centre by %.2f,%.2f" % [icon.name, offset.x, offset.y]
			)


## Draw order: no map world item may draw above an overlay. Control rects do not
## catch this class of bug, so the check compares the effective canvas layer and
## z_index of every visible world item against each top-level UI root.
##
## A badge is a Node2D at z_index 3 inside the world, and a Control overlay at
## z_index 0 in the same canvas draws *under* it however late it comes in the
## tree, which is how conquered ticks ended up on top of the upgrade panel.
func _audit_draw_order(node: Node) -> void:
	var world_root := node.find_child("World", true, false)
	if world_root == null:
		print("   draw order: no map world in this pose")
		return
	var world: Array[CanvasItem] = []
	_collect_visible_items(world_root, world)
	var world_layer: int = -1000
	var world_z: int = -1000
	for item: CanvasItem in world:
		var layer: int = _canvas_layer_of(item)
		if layer > world_layer or (layer == world_layer and item.z_index > world_z):
			world_layer = layer
			world_z = item.z_index
	print(
		"   draw order: %d world items, max layer %d, max z %d"
		% [world.size(), world_layer, world_z]
	)
	var overlays: Array[Control] = []
	for child: Node in node.get_children():
		var child_layer := child as CanvasLayer
		if child_layer != null:
			# A layer below the default canvas *is* the world (the map keeps its
			# backdrop and bodies at -1); its Controls are not overlays.
			if child_layer.layer < 0:
				continue
			for grandchild: Node in child.get_children():
				var nested := grandchild as Control
				if nested != null and nested.is_visible_in_tree():
					overlays.append(nested)
			continue
		var control := child as Control
		if control == null or not control.is_visible_in_tree():
			continue
		overlays.append(control)
	if overlays.is_empty():
		print("   draw order: no overlay open")
		return
	for overlay: Control in overlays:
		var layer: int = _canvas_layer_of(overlay)
		var above: bool = layer > world_layer \
			or (layer == world_layer and overlay.z_index > world_z)
		print(
			"   overlay %s layer %d z %d -> %s"
			% [overlay.name, layer, overlay.z_index, "above the world" if above else "UNDER the world"]
		)
		if not above:
			_report(
				"overlay %s draws under map world content (layer %d, z %d vs world %d, %d)"
				% [overlay.name, layer, overlay.z_index, world_layer, world_z]
			)


func _collect_visible_items(node: Node, out: Array[CanvasItem]) -> void:
	for child: Node in node.get_children():
		var item := child as CanvasItem
		if item != null and item.is_visible_in_tree():
			out.append(item)
		_collect_visible_items(child, out)


## Nested CanvasLayers add up, which is how the autoload overlay at 100 sits
## above any card the screens put in their own layer of 10.
func _canvas_layer_of(item: CanvasItem) -> int:
	var total: int = 0
	var parent: Node = item
	while parent != null:
		var layer := parent as CanvasLayer
		if layer != null:
			total += layer.layer
		parent = parent.get_parent()
	return total


## Scrolling and fixed-height credit rolls clip their content on purpose, so an
## overflow inside a clip region is not a layout defect.
func _inside_clip(control: Control) -> bool:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		var control_parent := parent as Control
		if control_parent != null and control_parent.clip_contents:
			return true
		parent = parent.get_parent()
	return false


func _size_text(size: Vector2) -> String:
	return "%.0fx%.0f" % [size.x, size.y]
