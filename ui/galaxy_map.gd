class_name GalaxyMap
extends Control
## The campaign hub: a pannable galaxy of bodies generated from the saved seed.
## It owns panning, the hover tooltip, the keyboard cursor, the confirm card and
## the campaign summaries; the battle scene owns the fight itself.
##
## GameState pauses the tree on MAP, so the root runs with PROCESS_MODE_ALWAYS
## and everything on this screen (markers included) keeps animating.

const BATTLE_SCENE: String = "res://battle_game.tscn"
const MENU_SCENE: String = "res://ui/main_menu.tscn"
const DEFAULT_HINT: String = "TAP SELECTS   |   DOUBLE-TAP CONQUERS   |   DRAG PANS   |   RIGHT STICK MOVES THE CURSOR"
## Seconds between frontier steps while the right stick is held.
const STICK_CURSOR_RATE: float = 0.25
const BANNER_SECONDS: float = 2.6
## Screen margin the keyboard cursor keeps between itself and the map edge.
const FOCUS_MARGIN: float = 110.0
## A press that moves less than this is a tap, not a drag.
const TAP_SLOP: float = 8.0

@onready var _world: Node2D = $View/World
@onready var _bodies_root: Node2D = $View/World/Bodies
@onready var _links: GalaxyLinks = $View/World/Links
@onready var _planets_label: Label = $TopBar/PlanetsLabel
@onready var _hull_label: Label = $TopBar/HullLabel
@onready var _difficulty_label: Label = $TopBar/DifficultyLabel
@onready var _score_label: Label = $TopBar/ScoreLabel
@onready var _energy_label: Label = $TopBar/EnergyLabel
@onready var _hint: Label = $Hint
@onready var _banner: Label = $Banner
@onready var _tooltip: PanelContainer = $Tooltip
@onready var _tooltip_label: Label = $Tooltip/Label
@onready var _confirm_card: Control = $ConfirmCard
@onready var _confirm_title: Label = $ConfirmCard/Panel/Margin/Box/Title
@onready var _confirm_info: Label = $ConfirmCard/Panel/Margin/Box/Info
@onready var _battle_button: Button = $ConfirmCard/Panel/Margin/Box/Buttons/BattleButton
@onready var _cancel_button: Button = $ConfirmCard/Panel/Margin/Box/Buttons/CancelButton
@onready var _result_card: Control = $ResultCard
@onready var _result_title: Label = $ResultCard/Panel/Margin/Box/Title
@onready var _result_detail: Label = $ResultCard/Panel/Margin/Box/Detail
@onready var _result_button: Button = $ResultCard/Panel/Margin/Box/ActionButton
@onready var _upgrade_button: Button = $UpgradeButton
@onready var _upgrade_panel: UpgradePanel = $UpgradePanel
@onready var _difficulty_picker: DifficultyPicker = $DifficultyPicker

var _galaxy: Galaxy
var _markers: Dictionary = {}
var _focused: StringName = &""
var _hovered: StringName = &""
## Set when Esc/Back dismissed a tooltip, so the still-hovered pointer does not
## bring it straight back. Cleared when the pointer leaves the body or pans.
var _hover_suppressed: bool = false
var _card_id: StringName = &""
var _dragging: bool = false
var _drag_moved: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _banner_tween: Tween
## Map zoom. `_zoom` is what is drawn, `_zoom_target` what the wheel asked for;
## the view eases between them around `_zoom_pivot`. Session-only on purpose.
var _zoom: float = 1.0
var _zoom_target: float = 1.0
var _zoom_pivot: Vector2 = Tuning.VIEW_SIZE * 0.5
## Finger positions while a pinch is running, by touch index.
var _touches: Dictionary = {}
var _pinching: bool = false
var _pinch_distance: float = 0.0


func _ready() -> void:
	# MAP pauses the tree; this screen still has to animate and take input.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_confirm_card.visible = false
	_result_card.visible = false
	_tooltip.visible = false
	_banner.visible = false
	_hint.text = DEFAULT_HINT
	_battle_button.pressed.connect(_on_battle_pressed)
	_cancel_button.pressed.connect(_close_card)
	_result_button.pressed.connect(_on_result_pressed)
	_upgrade_button.pressed.connect(_open_upgrades)
	_upgrade_panel.closed.connect(_on_upgrades_closed)
	_upgrade_panel.changed.connect(_on_upgrades_changed)
	_difficulty_picker.chosen.connect(_on_difficulty_chosen)
	_difficulty_picker.closed.connect(_on_difficulty_closed)
	# A finished battle leaves its summary behind for this screen to show.
	var result: Dictionary = Campaign.take_result()
	if result.is_empty() and not SaveData.campaign_active:
		# Only an active run (or the summary of a finished campaign) has a map
		# to show; otherwise the front end keeps the player.
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	UITheme.apply(self)
	_galaxy = Campaign.galaxy()
	_links.setup(_galaxy)
	_build_markers()
	_center_on(_galaxy.home_id)
	_refresh()
	GameState.change_state(GameState.State.MAP)
	GameState.back_handler = _handle_back
	if not result.is_empty():
		_show_result(result)


## Last tapped body and when, for the double-tap window on the map.
var _last_tap_id: StringName = &""
var _last_tap_ms: int = 0
var _stick_cursor_cooldown: float = 0.0


func _process(delta: float) -> void:
	_update_zoom(delta)
	if _confirm_card.visible or _result_card.visible or _upgrade_panel.visible \
			or _difficulty_picker.picker_open():
		return
	_pan_with_stick(delta)
	_stick_cursor(delta)
	_update_hover()


# --- Map building -----------------------------------------------------------

func _build_markers() -> void:
	for body_id: StringName in _galaxy.order:
		var marker := MapBody.new()
		marker.setup(body_id, _galaxy.body(body_id))
		_bodies_root.add_child(marker)
		_markers[body_id] = marker


func _refresh() -> void:
	var conquered: Array[StringName] = SaveData.campaign_conquered
	var open: Array[StringName] = _galaxy.attackable(conquered)
	for body_id: StringName in _markers:
		var marker: MapBody = _markers[body_id]
		marker.set_state(
			_galaxy.is_conquered(body_id, conquered),
			open.has(body_id),
			body_id == _focused
		)
	_links.set_state(conquered, open)
	_planets_label.text = "PLANETS %d/%d" % [
		Campaign.planets_conquered(), _galaxy.body_count(),
	]
	# Low hull is visible before a planet is chosen: the carried value, or full
	# hull when this is the first battle of the run (nothing stored yet).
	var max_hp: int = int(Upgrades.stats_for(SaveData.upgrade_levels)["max_hp"])
	var hull: int = SaveData.campaign_hp if SaveData.campaign_hp > 0 else max_hp
	_hull_label.text = "HULL %d/%d" % [clampi(hull, 0, max_hp), max_hp]
	_difficulty_label.text = Difficulty.title(SaveData.campaign_difficulty)
	_score_label.text = "SCORE %d" % SaveData.campaign_score
	_energy_label.text = "ENERGY %d" % SaveData.energy


## Rebuild everything after a fresh campaign: new seed, new bodies, new pan.
func _reload_map() -> void:
	_galaxy = Campaign.galaxy()
	for marker: MapBody in _markers.values():
		_bodies_root.remove_child(marker)
		marker.queue_free()
	_markers.clear()
	_links.setup(_galaxy)
	_build_markers()
	_focused = &""
	_hovered = &""
	_tooltip.visible = false
	_zoom = 1.0
	_zoom_target = 1.0
	_zoom_pivot = Tuning.VIEW_SIZE * 0.5
	_center_on(_galaxy.home_id)
	_refresh()


# --- Camera -----------------------------------------------------------------

func _center_on(body_id: StringName) -> void:
	_world.scale = Vector2.ONE * _zoom
	_world.position = Tuning.VIEW_SIZE * 0.5 - _galaxy.position_of(body_id) * _zoom
	_clamp_pan()


## The map may never show past its own edge. At a wide zoom the whole map can be
## smaller than the view, and then it is centred instead.
func _clamp_pan() -> void:
	var scaled: Vector2 = Tuning.GALAXY_MAP_SIZE * _zoom
	var limit: Vector2 = scaled - Tuning.VIEW_SIZE
	if limit.x <= 0.0:
		_world.position.x = (Tuning.VIEW_SIZE.x - scaled.x) * 0.5
	else:
		_world.position.x = clampf(_world.position.x, -limit.x, 0.0)
	if limit.y <= 0.0:
		_world.position.y = (Tuning.VIEW_SIZE.y - scaled.y) * 0.5
	else:
		_world.position.y = clampf(_world.position.y, -limit.y, 0.0)


## Asks for a new zoom; the view eases there and keeps `pivot` (a screen point)
## over the same patch of map, so the wheel zooms around the cursor.
func _zoom_to(target: float, pivot: Vector2) -> void:
	_zoom_pivot = pivot
	_zoom_target = clampf(target, Tuning.GALAXY_ZOOM_MIN, Tuning.GALAXY_ZOOM_MAX)


func _update_zoom(delta: float) -> void:
	if is_equal_approx(_zoom, _zoom_target):
		return
	var next: float = lerpf(_zoom, _zoom_target, 1.0 - exp(-Tuning.GALAXY_ZOOM_SMOOTH * delta))
	if absf(next - _zoom_target) < 0.001:
		next = _zoom_target
	_set_zoom(next, _zoom_pivot)


## Applies a zoom immediately, keeping the map point under the pivot fixed.
func _set_zoom(value: float, pivot: Vector2) -> void:
	var before: float = maxf(_zoom, 0.001)
	var world_point: Vector2 = (pivot - _world.position) / before
	_zoom = clampf(value, Tuning.GALAXY_ZOOM_MIN, Tuning.GALAXY_ZOOM_MAX)
	_world.scale = Vector2.ONE * _zoom
	_world.position = pivot - world_point * _zoom
	_zoom_target = _zoom
	_clamp_pan()


func _touch_distance() -> float:
	var points: Array = _touches.values()
	if points.size() < 2:
		return 0.0
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _touch_midpoint() -> Vector2:
	var points: Array = _touches.values()
	if points.size() < 2:
		return Tuning.VIEW_SIZE * 0.5
	return ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5


func _pan_with_stick(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() < 0.2:
		return
	_world.position += input * Tuning.GALAXY_PAN_SPEED * delta
	_clamp_pan()


## Right stick moves a cursor over the frontier: every nudge steps to the next
## attackable body, which is the only place the cursor may land.
func _stick_cursor(delta: float) -> void:
	if _stick_cursor_cooldown > 0.0:
		_stick_cursor_cooldown = maxf(0.0, _stick_cursor_cooldown - delta)
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() < 0.6 or _stick_cursor_cooldown > 0.0:
		return
	_stick_cursor_cooldown = STICK_CURSOR_RATE
	_cycle(1)


## Screen point -> map point. There is no camera on this screen, so the pan is
## the only transform.
func _to_world(point: Vector2) -> Vector2:
	return (point - _world.position) / maxf(_zoom, 0.001)


func _body_at(world_point: Vector2) -> StringName:
	var best: StringName = &""
	var best_distance: float = Tuning.GALAXY_TAP_RADIUS
	for body_id: StringName in _galaxy.order:
		var distance: float = _galaxy.position_of(body_id).distance_to(world_point)
		if distance <= best_distance:
			best_distance = distance
			best = body_id
	return best


# --- Pointer and touch ------------------------------------------------------

## Dragging pans, a press that does not move is a tap. Touch arrives through
## the engine's emulated mouse events, so a finger and a mouse share this path
## (project setting `emulate_mouse_from_touch` stays at its default).
func _gui_input(event: InputEvent) -> void:
	if _confirm_card.visible or _result_card.visible or _upgrade_panel.visible:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index in [
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN
		]:
			var step: float = Tuning.GALAXY_ZOOM_STEP
			if button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				step = -step
			_zoom_to(_zoom_target + step, button.position)
			accept_event()
			return
		if button.button_index != MOUSE_BUTTON_LEFT or _pinching:
			return
		if button.pressed:
			_begin_drag(button.position)
		else:
			_end_drag(button.position)
		accept_event()
	elif event is InputEventMouseMotion:
		if _dragging and not _pinching:
			_drag_by((event as InputEventMouseMotion).relative)
	elif event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event as InputEventScreenDrag)


## Two fingers pinch-zoom around their midpoint; one finger keeps using the
## emulated-mouse drag and tap path.
func _handle_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		_touches[touch.index] = touch.position
		if _touches.size() >= 2:
			_pinching = true
			_dragging = false
			_pinch_distance = _touch_distance()
	else:
		_touches.erase(touch.index)
		if _touches.size() < 2:
			_pinching = false
			_pinch_distance = 0.0
	accept_event()


func _handle_touch_drag(drag: InputEventScreenDrag) -> void:
	if not _touches.has(drag.index):
		return
	_touches[drag.index] = drag.position
	if _touches.size() < 2:
		return
	var distance: float = _touch_distance()
	if _pinch_distance > 1.0 and distance > 1.0:
		_set_zoom(_zoom * (distance / _pinch_distance), _touch_midpoint())
	_pinch_distance = distance
	_pinching = true
	accept_event()


func _begin_drag(point: Vector2) -> void:
	_dragging = true
	_drag_moved = false
	_drag_start = point
	_hover_suppressed = false


func _drag_by(relative: Vector2) -> void:
	if relative.length() >= 0.5:
		_drag_moved = true
	_world.position += relative
	_clamp_pan()


func _end_drag(point: Vector2) -> void:
	_dragging = false
	if _drag_moved or point.distance_to(_drag_start) > TAP_SLOP:
		return
	var body_id: StringName = _body_at(_to_world(point))
	if body_id == &"":
		_hovered = &""
		_tooltip.visible = false
		return
	_hovered = body_id
	_show_tooltip(body_id)
	_focused = body_id
	_refresh()
	if not _galaxy.attackable(SaveData.campaign_conquered).has(body_id):
		if body_id == _galaxy.gate_id:
			_show_banner(_galaxy.status_of(body_id, SaveData.campaign_conquered))
		return
	# The first tap only selects, so panning the map never starts a battle by
	# accident; a second tap inside the window opens the CONQUER card.
	var now: int = Time.get_ticks_msec()
	var window_ms: int = int(Tuning.MAP_DOUBLE_CLICK_TIME * 1000.0)
	if body_id == _last_tap_id and now - _last_tap_ms <= window_ms:
		_last_tap_id = &""
		_last_tap_ms = 0
		_open_card(body_id)
		return
	_last_tap_id = body_id
	_last_tap_ms = now
	_hint.text = "DOUBLE-TAP OR PRESS ENTER TO CONQUER"


# --- Tooltip ----------------------------------------------------------------

func _update_hover() -> void:
	if _dragging:
		return
	if _hover_suppressed:
		if _body_at(_to_world(get_global_mouse_position())) == &"":
			_hover_suppressed = false
		return
	var found: StringName = _body_at(_to_world(get_global_mouse_position()))
	if found != _hovered:
		_hovered = found
		if found == &"":
			_tooltip.visible = false
			return
		_show_tooltip(found)
		return
	if found != &"":
		_place_tooltip(found)


func _show_tooltip(body_id: StringName) -> void:
	_tooltip_label.text = _tooltip_text(body_id)
	_tooltip.visible = true
	_place_tooltip(body_id)


func _hide_tooltip(persistent: bool = false) -> void:
	_tooltip.visible = false
	_hovered = &""
	_hover_suppressed = persistent


func _tooltip_text(body_id: StringName) -> String:
	var data: Dictionary = _galaxy.body(body_id)
	var body_trait: Dictionary = _galaxy.trait_row(body_id)
	var band: Dictionary = _galaxy.band_row(body_id)
	var battle: Battle = _galaxy.battle_for(body_id)
	var lines: PackedStringArray = []
	lines.append(String(data.get("name", "UNKNOWN")))
	lines.append("%s   |   %s" % [String(body_trait.get("title", "")), String(band.get("label", ""))])
	lines.append("%d WAVE%s   |   %d ENEMIES EACH" % [
		battle.waves, "" if battle.waves == 1 else "S", battle.enemies_per_wave,
	])
	if battle.has_boss():
		lines.append("STATION BOSS")
	lines.append(_galaxy.status_of(body_id, SaveData.campaign_conquered))
	return "\n".join(lines)


## Beside the body, never on top of it: right first, then left, above, below,
## with the first candidate that fits the visible area. The size comes from the
## label (the panel is content-sized) and the whole thing lives in the map's UI
## layer, so zoom never scales or moves it relative to the screen.
func _place_tooltip(body_id: StringName) -> void:
	var screen: Vector2 = _world.position + _galaxy.position_of(body_id) * _zoom
	var tooltip_size: Vector2 = _tooltip.get_combined_minimum_size()
	var gap: float = Tuning.GALAXY_TAP_RADIUS + Tuning.GALAXY_TOOLTIP_GAP
	var margin: float = 8.0
	var top: float = Tuning.HUD_BAR_HEIGHT + 6.0
	var bottom: float = Tuning.VIEW_SIZE.y - 34.0
	var candidates: Array[Vector2] = [
		screen + Vector2(gap, -tooltip_size.y * 0.5),
		screen + Vector2(-gap - tooltip_size.x, -tooltip_size.y * 0.5),
		screen + Vector2(-tooltip_size.x * 0.5, -gap - tooltip_size.y),
		screen + Vector2(-tooltip_size.x * 0.5, gap),
	]
	var point: Vector2 = candidates[0]
	for candidate: Vector2 in candidates:
		if candidate.x >= margin \
				and candidate.x + tooltip_size.x <= Tuning.VIEW_SIZE.x - margin \
				and candidate.y >= top \
				and candidate.y + tooltip_size.y <= bottom:
			point = candidate
			break
	point.x = clampf(point.x, margin, Tuning.VIEW_SIZE.x - tooltip_size.x - margin)
	point.y = clampf(point.y, top, bottom - tooltip_size.y)
	_tooltip.size = tooltip_size
	_tooltip.position = point


# --- Keyboard and gamepad ---------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Captured once, as a local: the Esc branch below leaves for the menu, which
	# frees this whole scene, so get_viewport() is null by the time that branch
	# would otherwise finish.
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.physical_keycode == KEY_F9 \
			and OS.is_debug_build():
			# Debug harness: boot straight into the one-wave battle. Mark the
			# input handled *before* the scene change.
			vp.set_input_as_handled()
			Campaign.pending_id = &""
			get_tree().change_scene_to_file(BATTLE_SCENE)
			return
	if _difficulty_picker.picker_open():
		# The picker owns Esc / Back while it is up.
		return
	if _result_card.visible:
		return
	if _upgrade_panel.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			_upgrade_panel.close()
			vp.set_input_as_handled()
		return
	if _confirm_card.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			_close_card()
			vp.set_input_as_handled()
		return
	if event is InputEventKey:
		var zoom_key := event as InputEventKey
		if zoom_key.pressed and not zoom_key.echo:
			if zoom_key.physical_keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
				_zoom_to(_zoom_target + Tuning.GALAXY_ZOOM_STEP, Tuning.VIEW_SIZE * 0.5)
				vp.set_input_as_handled()
				return
			if zoom_key.physical_keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
				_zoom_to(_zoom_target - Tuning.GALAXY_ZOOM_STEP, Tuning.VIEW_SIZE * 0.5)
				vp.set_input_as_handled()
				return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_cycle(1)
		vp.set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_cycle(-1)
		vp.set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _focused != &"" and _galaxy.attackable(SaveData.campaign_conquered).has(_focused):
			_open_card(_focused)
			vp.set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		# Back out one layer at a time: first the tooltip, then the front end.
		# Marked before _open_menu(): that changes the scene and frees this node
		# with it, so the call has to happen while the viewport is still ours.
		vp.set_input_as_handled()
		if _tooltip.visible:
			_hide_tooltip(true)
		else:
			_open_menu()


func _cycle(step: int) -> void:
	var open: Array[StringName] = _galaxy.attackable(SaveData.campaign_conquered)
	if open.is_empty():
		_show_banner("NO WORLD IN RANGE")
		return
	open.sort_custom(_before)
	var index: int = open.find(_focused)
	var next: int = 0 if index < 0 else posmod(index + step, open.size())
	_focus_on(open[next])


## Nearest rings first, then left to right, so the cursor walks the frontier.
func _before(a: StringName, b: StringName) -> bool:
	var hops_a: int = _galaxy.distance_of(a)
	var hops_b: int = _galaxy.distance_of(b)
	if hops_a != hops_b:
		return hops_a < hops_b
	return _galaxy.position_of(a).x < _galaxy.position_of(b).x


func _focus_on(body_id: StringName) -> void:
	_focused = body_id
	_refresh()
	_show_tooltip(body_id)
	_ensure_visible(body_id)


## Nudge the pan until the focused body is inside the safe area.
func _ensure_visible(body_id: StringName) -> void:
	var screen: Vector2 = _world.position + _galaxy.position_of(body_id) * _zoom
	var wanted: Vector2 = screen
	if screen.x < FOCUS_MARGIN:
		wanted.x = FOCUS_MARGIN
	elif screen.x > Tuning.VIEW_SIZE.x - FOCUS_MARGIN:
		wanted.x = Tuning.VIEW_SIZE.x - FOCUS_MARGIN
	if screen.y < FOCUS_MARGIN + Tuning.HUD_BAR_HEIGHT:
		wanted.y = FOCUS_MARGIN + Tuning.HUD_BAR_HEIGHT
	elif screen.y > Tuning.VIEW_SIZE.y - FOCUS_MARGIN:
		wanted.y = Tuning.VIEW_SIZE.y - FOCUS_MARGIN
	_world.position += wanted - screen
	_clamp_pan()
	_place_tooltip(body_id)


# --- Confirm card -----------------------------------------------------------

func _open_card(body_id: StringName) -> void:
	if not _galaxy.attackable(SaveData.campaign_conquered).has(body_id):
		return
	AudioManager.play_sfx("map_click")
	_card_id = body_id
	var data: Dictionary = _galaxy.body(body_id)
	var body_trait: Dictionary = _galaxy.trait_row(body_id)
	var battle: Battle = _galaxy.battle_for(body_id)
	_confirm_title.text = "CONQUER %s?" % String(data.get("name", "THIS WORLD"))
	var lines: PackedStringArray = []
	lines.append("%s   |   %s" % [
		String(body_trait.get("title", "")), String(_galaxy.band_row(body_id).get("label", "")),
	])
	lines.append("%d WAVE%s   |   %d ENEMIES EACH" % [
		battle.waves, "" if battle.waves == 1 else "S", battle.enemies_per_wave,
	])
	if battle.has_boss():
		lines.append("STATION BOSS   |   +%d ENERGY" % battle.reward_energy)
	else:
		lines.append("CONQUEST BONUS   |   +%d ENERGY" % battle.reward_energy)
	lines.append("CITADELS %d/%d" % [
		Campaign.citadels_conquered(), Tuning.GALAXY_CITADELS_FOR_GATE,
	])
	_confirm_info.text = "\n".join(lines)
	_hide_tooltip()
	_confirm_card.visible = true
	_battle_button.grab_focus()


func _close_card() -> void:
	_confirm_card.visible = false
	_card_id = &""
	_battle_button.release_focus()
	_cancel_button.release_focus()
	# Let the next frame re-detect the body under the pointer and show its
	# tooltip again.
	_hovered = &""


func _on_battle_pressed() -> void:
	if _card_id == &"":
		return
	var body_id: StringName = _card_id
	_close_card()
	AudioManager.play_sfx("wave")
	Campaign.start_battle(body_id)
	get_tree().change_scene_to_file(BATTLE_SCENE)


# --- Upgrades ---------------------------------------------------------------

func _open_upgrades() -> void:
	_hide_tooltip()
	_upgrade_panel.open()


func _on_upgrades_closed() -> void:
	# Back to the map: the pointer re-detects whatever it is over and the
	# energy readout picks up anything that was just bought.
	_upgrade_button.release_focus()
	_hovered = &""
	_refresh()


func _on_upgrades_changed() -> void:
	_refresh()


# --- Summaries --------------------------------------------------------------

func _show_result(result: Dictionary) -> void:
	var completed: bool = bool(result.get("completed", false))
	var won: bool = bool(result.get("won", false))
	if won and not completed:
		_show_banner("%s CONQUERED   +%d ENERGY" % [
			String(result.get("name", "SECTOR")), int(result.get("energy", 0)),
		])
		return
	# A defeat was already summarised by the battle's game-over card, and the
	# mode's rule has been applied; the map just shows the run's state.
	if not completed:
		return
	_result_title.text = "GALAXY CONQUERED"
	var mode: StringName = Difficulty.normalise(SaveData.campaign_difficulty)
	_result_detail.text = "ALL %d PLANETS   |   %d CITADELS\nSCORE %d   |   %s HIGH %d" % [
		Campaign.planets_conquered(),
		Campaign.citadels_conquered(),
		SaveData.campaign_score,
		Difficulty.title(mode),
		SaveData.high_score_for(mode),
	]
	_result_button.text = "NEW CAMPAIGN"
	_result_title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7))
	_result_card.visible = true
	_result_button.grab_focus()


## Finishing the galaxy starts a fresh campaign, so the mode is chosen again.
## The result card stays behind the picker: cancelling returns to it.
func _on_result_pressed() -> void:
	_result_button.release_focus()
	_difficulty_picker.open()


func _on_difficulty_chosen(difficulty: StringName) -> void:
	_result_card.visible = false
	Campaign.begin_run(difficulty)
	_reload_map()
	_show_banner("NEW %s CAMPAIGN" % Difficulty.title(difficulty))


func _on_difficulty_closed() -> void:
	if _result_card.visible:
		_result_button.grab_focus()


## Leave for the front end. Every conquest and the carried hull are already in
## the save, so the menu's CONTINUE comes back to this exact galaxy.
func _open_menu() -> void:
	AudioManager.play_sfx("ui_click")
	GameState.back_handler = Callable()
	get_tree().change_scene_to_file(MENU_SCENE)


func _handle_back() -> void:
	# Always re-arm: GameState consumes the handler on every request.
	GameState.back_handler = _handle_back
	if _difficulty_picker.picker_open():
		_difficulty_picker.close()
		return
	if _result_card.visible:
		return
	if _upgrade_panel.visible:
		_upgrade_panel.close()
		return
	if _confirm_card.visible:
		_close_card()
		return
	if _tooltip.visible:
		_hide_tooltip(true)
		return
	_open_menu()


# --- Banner -----------------------------------------------------------------

func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true
	_banner.modulate.a = 1.0
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(BANNER_SECONDS)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
	_banner_tween.tween_callback(_banner.hide)
