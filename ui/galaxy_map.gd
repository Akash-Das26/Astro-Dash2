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
const DEFAULT_HINT: String = "DRAG TO PAN   |   TAP A GLOWING WORLD   |   LEFT/RIGHT CYCLE   |   ENTER ATTACK"
const BANNER_SECONDS: float = 2.6
## Screen margin the keyboard cursor keeps between itself and the map edge.
const FOCUS_MARGIN: float = 110.0
## A press that moves less than this is a tap, not a drag.
const TAP_SLOP: float = 8.0

@onready var _world: Node2D = $View/World
@onready var _bodies_root: Node2D = $View/World/Bodies
@onready var _links: GalaxyLinks = $View/World/Links
@onready var _planets_label: Label = $TopBar/PlanetsLabel
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

var _galaxy: Galaxy
var _markers: Dictionary = {}
var _focused: StringName = &""
var _hovered: StringName = &""
var _card_id: StringName = &""
var _dragging: bool = false
var _drag_moved: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _banner_tween: Tween


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


func _process(delta: float) -> void:
	if _confirm_card.visible or _result_card.visible or _upgrade_panel.visible:
		return
	_pan_with_stick(delta)
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
	_center_on(_galaxy.home_id)
	_refresh()


# --- Camera -----------------------------------------------------------------

func _center_on(body_id: StringName) -> void:
	_world.position = Tuning.VIEW_SIZE * 0.5 - _galaxy.position_of(body_id)
	_clamp_pan()


func _clamp_pan() -> void:
	var limit: Vector2 = Tuning.GALAXY_MAP_SIZE - Tuning.VIEW_SIZE
	_world.position.x = clampf(_world.position.x, -limit.x, 0.0)
	_world.position.y = clampf(_world.position.y, -limit.y, 0.0)


func _pan_with_stick(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() < 0.2:
		return
	_world.position += input * Tuning.GALAXY_PAN_SPEED * delta
	_clamp_pan()


## Screen point -> map point. There is no camera on this screen, so the pan is
## the only transform.
func _to_world(point: Vector2) -> Vector2:
	return point - _world.position


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
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_begin_drag(button.position)
		else:
			_end_drag(button.position)
		accept_event()
	elif event is InputEventMouseMotion:
		if _dragging:
			_drag_by((event as InputEventMouseMotion).relative)


func _begin_drag(point: Vector2) -> void:
	_dragging = true
	_drag_moved = false
	_drag_start = point


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
	if _galaxy.attackable(SaveData.campaign_conquered).has(body_id):
		_focused = body_id
		_refresh()
		_open_card(body_id)
	elif body_id == _galaxy.gate_id:
		_show_banner(_galaxy.status_of(body_id, SaveData.campaign_conquered))


# --- Tooltip ----------------------------------------------------------------

func _update_hover() -> void:
	if _dragging:
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


func _hide_tooltip() -> void:
	_tooltip.visible = false
	_hovered = &""


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


func _place_tooltip(body_id: StringName) -> void:
	var screen: Vector2 = _world.position + _galaxy.position_of(body_id)
	var size: Vector2 = _tooltip.size
	var point: Vector2 = screen + Vector2(30.0, -20.0)
	point.x = clampf(point.x, 8.0, Tuning.VIEW_SIZE.x - size.x - 8.0)
	point.y = clampf(
		point.y,
		Tuning.HUD_BAR_HEIGHT + 8.0,
		Tuning.VIEW_SIZE.y - size.y - 34.0
	)
	_tooltip.position = point


# --- Keyboard and gamepad ---------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.physical_keycode == KEY_F9 \
			and OS.is_debug_build():
			# Debug harness: boot straight into the one-wave battle.
			Campaign.pending_id = &""
			get_tree().change_scene_to_file(BATTLE_SCENE)
			get_viewport().set_input_as_handled()
			return
	if _result_card.visible:
		return
	if _upgrade_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			_upgrade_panel.close()
			get_viewport().set_input_as_handled()
		return
	if _confirm_card.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_card()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_cycle(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_cycle(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _focused != &"" and _galaxy.attackable(SaveData.campaign_conquered).has(_focused):
			_open_card(_focused)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		# The menu arrives with the next stage; until then Back stays here.
		get_viewport().set_input_as_handled()


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
	var screen: Vector2 = _world.position + _galaxy.position_of(body_id)
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
	if completed:
		_result_title.text = "GALAXY CONQUERED"
		_result_detail.text = "ALL %d PLANETS   |   %d CITADELS\nSCORE %d   |   BEST %d" % [
			Campaign.planets_conquered(),
			Campaign.citadels_conquered(),
			SaveData.campaign_score,
			SaveData.campaign_best_score,
		]
		_result_button.text = "NEW CAMPAIGN"
		_result_title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7))
	else:
		_result_title.text = "CAMPAIGN OVER"
		_result_detail.text = "PLANETS %d/%d   |   CITADELS %d/%d\nSCORE %d   |   BEST %d" % [
			int(result.get("planets", 0)),
			_galaxy.body_count(),
			int(result.get("citadels", 0)),
			_galaxy.citadel_total(),
			int(result.get("score", 0)),
			int(result.get("best", 0)),
		]
		_result_button.text = "RETRY"
		_result_title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	_result_card.visible = true
	_result_button.grab_focus()


func _on_result_pressed() -> void:
	_result_card.visible = false
	_result_button.release_focus()
	Campaign.begin_run()
	_reload_map()


func _handle_back() -> void:
	# Always re-arm: GameState consumes the handler on every request.
	GameState.back_handler = _handle_back
	if _result_card.visible:
		return
	if _upgrade_panel.visible:
		_upgrade_panel.close()
		return
	if _confirm_card.visible:
		_close_card()
		return
	get_tree().change_scene_to_file(MENU_SCENE)


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
