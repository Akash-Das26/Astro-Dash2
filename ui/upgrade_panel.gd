class_name UpgradePanel
extends Control
## The ship upgrade screen, opened from the map. Reads everything from SaveData
## and Upgrades and writes only through SaveData.buy_upgrade(), so the panel and
## the ship can never disagree about a level.
##
## It holds no run state: `changed` lets the map refresh its energy readout and
## `closed` lets the map put the keyboard cursor back on its own buttons.

signal closed
signal changed

const PAGE: String = "Panel/Margin/Box/Scroll/Page"
const CARD_ROOT: Dictionary = {
	&"hull": PAGE + "/Body/Grid/HullCard",
	&"speed": PAGE + "/Body/Grid/SpeedCard",
	&"shield": PAGE + "/Body/Grid/ShieldCard",
	&"fire": PAGE + "/Body/Grid/FireCard",
}
const SKIN_ICON_SIZE: Vector2 = Vector2(56.0, 40.0)
## The preview box (must match the 210x150 control in the scene) and the column
## the hull and flame are centred on.
const PREVIEW_SIZE: Vector2 = Vector2(210.0, 150.0)
const PREVIEW_CENTER_X: float = 105.0
## The multiplier applied to the skin's own battle scale, so every skin is
## drawn at the same size whatever the source texture is.
const PREVIEW_HULL_ZOOM: float = 2.0
## Battle mounts the flame at 1.1 against the hull's scale (thruster.tscn).
## Keeping that ratio is what makes the preview match the real ship: the whole
## ship is scaled here, never the flame on its own.
const PREVIEW_FLAME_SCALE: float = 1.1
## The thrust the preview shows. 0.9 is nearly full, so the flame is long.
const PREVIEW_THRUST: float = 0.9
const PREVIEW_MARGIN: float = 4.0
const LASER_NAMES: Array[String] = ["BLUE", "GREEN", "YELLOW"]
const LASER_COLORS: Array[Color] = [
	Color(0.55, 0.78, 1.0),
	Color(0.6, 1.0, 0.7),
	Color(1.0, 0.88, 0.35),
]
## Each weapon row is a fixed height so its three text lines never overlap.
const WEAPON_CARD_HEIGHT: float = 60.0
## The preview column is narrower on the hull tab, where the 2x2 grid needs
## the room, and wider on the weapon tab, which has no grid.
const STATS_WIDTH_HULL: float = 210.0
const STATS_WIDTH_WEAPONS: float = 300.0
const FEEDBACK_SECONDS: float = 2.0

## The panel has two views: ship upgrades plus hull skins, or the weapon rack.
## Both share the left column preview.
enum Tab { HULL, WEAPONS }

@onready var _energy_label: Label = $Panel/Margin/Box/Header/EnergyLabel
@onready var _close_button: Button = $Panel/Margin/Box/Header/CloseButton
@onready var _scroll: ScrollContainer = $Panel/Margin/Box/Scroll
@onready var _body: HBoxContainer = $Panel/Margin/Box/Scroll/Page/Body
@onready var _stats_column: VBoxContainer = $Panel/Margin/Box/Scroll/Page/Body/Stats
@onready var _stats_label: Label = $Panel/Margin/Box/Scroll/Page/Body/Stats/Value
@onready var _preview_box: Control = $Panel/Margin/Box/Scroll/Page/Body/Stats/Preview
@onready var _preview_ship: Sprite2D = $Panel/Margin/Box/Scroll/Page/Body/Stats/Preview/ShipSprite
@onready var _preview_thruster: Thruster = $Panel/Margin/Box/Scroll/Page/Body/Stats/Preview/Thruster
@onready var _preview_name: Label = $Panel/Margin/Box/Scroll/Page/Body/Stats/PreviewName
@onready var _preview_status: Label = $Panel/Margin/Box/Scroll/Page/Body/Stats/PreviewStatus
@onready var _laser_label: Label = $Panel/Margin/Box/Scroll/Page/Body/Stats/LaserLabel
@onready var _equip_button: Button = $Panel/Margin/Box/Scroll/Page/Body/Stats/EquipButton
@onready var _skin_row: HBoxContainer = $Panel/Margin/Box/Scroll/Page/Skins/Row
@onready var _skin_hint: Label = $Panel/Margin/Box/Scroll/Page/Skins/Hint
@onready var _hull_tab: Button = $Panel/Margin/Box/Tabs/HullTab
@onready var _weapon_tab: Button = $Panel/Margin/Box/Tabs/WeaponTab
@onready var _grid: GridContainer = $Panel/Margin/Box/Scroll/Page/Body/Grid
@onready var _skins: VBoxContainer = $Panel/Margin/Box/Scroll/Page/Skins
@onready var _weapon_box: VBoxContainer = $Panel/Margin/Box/Scroll/Page/Body/Weapons
@onready var _weapon_row: VBoxContainer = $Panel/Margin/Box/Scroll/Page/Body/Weapons/Row
@onready var _weapon_hint: Label = $Panel/Margin/Box/Scroll/Page/Body/Weapons/Hint
@onready var _weapon_icon: TextureRect = $Panel/Margin/Box/Scroll/Page/Body/Stats/WeaponIcon
@onready var _buy_button: Button = $Panel/Margin/Box/Scroll/Page/Body/Stats/BuyButton
@onready var _equip_primary_button: Button = $Panel/Margin/Box/Scroll/Page/Body/Stats/EquipPrimaryButton
@onready var _equip_secondary_button: Button = $Panel/Margin/Box/Scroll/Page/Body/Stats/EquipSecondaryButton
@onready var _feedback: Label = $Panel/Margin/Box/Feedback

## Hull shown in the preview. Picking a skin only previews it; EQUIP commits.
var _preview_id: StringName = Skins.DEFAULT_ID
## Weapon shown in the preview while the WEAPONS tab is open. Picking a card
## only previews it; the three buttons commit buy / equip.
var _preview_weapon: StringName = Weapons.DEFAULT_ID
var _tab: int = Tab.HULL
var _skin_buttons: Dictionary = {}
var _weapon_buttons: Dictionary = {}
var _style_normal: StyleBoxFlat
var _style_preview: StyleBoxFlat
var _style_equipped: StyleBoxFlat
var _feedback_tween: Tween


func _ready() -> void:
	_preview_id = Skins.selected()
	_preview_weapon = SaveData.weapon_primary
	_close_button.pressed.connect(close)
	_equip_button.pressed.connect(_on_equip_pressed)
	_hull_tab.pressed.connect(_select_tab.bind(Tab.HULL))
	_weapon_tab.pressed.connect(_select_tab.bind(Tab.WEAPONS))
	_buy_button.pressed.connect(_on_buy_pressed)
	_equip_primary_button.pressed.connect(_on_equip_weapon_pressed.bind(0))
	_equip_secondary_button.pressed.connect(_on_equip_weapon_pressed.bind(1))
	_laser_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for kind: StringName in Tuning.UPGRADE_ORDER:
		var card := get_node(CARD_ROOT[kind]) as Button
		card.pressed.connect(_on_card_pressed.bind(kind))
	_build_skins()
	_build_weapons()
	_apply_tab_visibility()
	refresh()


func open() -> void:
	visible = true
	_preview_id = Skins.selected()
	_preview_weapon = SaveData.weapon_primary
	_tab = Tab.HULL
	_apply_tab_visibility()
	refresh()
	AudioManager.play_sfx("ui_click")
	var first: Button = get_node(CARD_ROOT[&"hull"]) as Button
	first.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func refresh() -> void:
	_energy_label.text = "ENERGY %d" % SaveData.energy
	_render_stats()
	for kind: StringName in Tuning.UPGRADE_ORDER:
		_render_card(kind)
	_refresh_skins()
	_refresh_weapons()
	_refresh_preview()


func _render_stats() -> void:
	var stats: Dictionary = Upgrades.stats_for(SaveData.upgrade_levels)
	var max_hp: int = int(stats["max_hp"])
	var hp: int = max_hp
	# Every battle starts with the shield full, so this reads current/capacity
	# with current already at capacity.
	var capacity: int = int(stats["shield_charges"])
	if SaveData.campaign_active and SaveData.campaign_hp > 0:
		hp = clampi(SaveData.campaign_hp, 1, max_hp)
	_stats_label.text = "HEALTH    %d/%d\nSPEED      %d\nSHIELDS   %d/%d\nFIRE       %d%%" % [
		hp,
		max_hp,
		roundi(float(stats["move_speed"])),
		capacity,
		capacity,
		roundi(float(stats["damage_mult"]) * 100.0),
	]


func _render_card(kind: StringName) -> void:
	var card: Button = get_node(CARD_ROOT[kind]) as Button
	var level: int = SaveData.level_of(kind)
	var name_label: Label = card.get_node("Box/Name") as Label
	var level_label: Label = card.get_node("Box/Level") as Label
	var cost_label: Label = card.get_node("Box/Cost") as Label
	name_label.text = Upgrades.card_title(kind)
	level_label.text = "LEVEL %d/%d" % [level, Upgrades.MAX_LEVEL]
	card.tooltip_text = Upgrades.tooltip(kind)
	if level >= Upgrades.MAX_LEVEL:
		cost_label.text = "MAXED"
		cost_label.add_theme_color_override("font_color", UITheme.COLOR_MUTED)
		card.disabled = true
	else:
		var price: int = SaveData.next_upgrade_cost(kind)
		cost_label.text = "COST %d" % price
		if SaveData.energy >= price:
			cost_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD)
		else:
			cost_label.add_theme_color_override("font_color", UITheme.COLOR_WARN)
		card.disabled = SaveData.energy < price
	var dimmed: float = 0.45 if card.disabled else 1.0
	(card.get_node("Box") as Control).modulate.a = dimmed


func _on_card_pressed(kind: StringName) -> void:
	if SaveData.buy_upgrade(kind):
		AudioManager.play_sfx("upgrade_buy")
		changed.emit()
		refresh()
		return
	AudioManager.play_sfx("upgrade_denied")
	if SaveData.level_of(kind) >= Upgrades.MAX_LEVEL:
		_show_feedback("MAX LEVEL", UITheme.COLOR_MUTED)
	else:
		_show_feedback(
			"NOT ENOUGH ENERGY: NEED %d" % SaveData.next_upgrade_cost(kind), UITheme.COLOR_WARN
		)


func _build_skins() -> void:
	var group := ButtonGroup.new()
	_style_normal = _skin_style(UITheme.BUTTON_FILL, UITheme.BUTTON_BORDER)
	_style_preview = _skin_style(UITheme.CARD_FILL, UITheme.COLOR_GOLD)
	_style_equipped = _skin_style(UITheme.CARD_FILL, UITheme.COLOR_ACCENT)
	for skin: Dictionary in Skins.all():
		var button := Button.new()
		button.name = "Skin_%s" % String(skin["id"])
		button.custom_minimum_size = SKIN_ICON_SIZE
		button.toggle_mode = true
		button.button_group = group
		button.expand_icon = true
		button.icon = skin["texture"]
		button.pressed.connect(_on_skin_pressed.bind(skin["id"]))
		_skin_row.add_child(button)
		_skin_buttons[skin["id"]] = button


## Picking a hull only previews it: it changes the big sprite, never the save.
func _on_skin_pressed(id: StringName) -> void:
	_preview_id = id
	AudioManager.play_sfx("ui_click")
	_refresh_skins()
	_refresh_preview()


## Left/right walks the hull row while a skin button has focus, previewing as it
## goes. Enter activates whatever is focused: a skin previews, EQUIP equips.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	# One viewport for the whole call: EQUIP and a purchase can both change
	# what is focusable while this handler is still running.
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var focused: Control = vp.gui_get_focus_owner()
	if focused == null:
		return
	# Up/down walks the weapon rack, left/right walks the hull row.
	if _tab == Tab.WEAPONS and _weapon_buttons.values().has(focused):
		if event.is_action_pressed("ui_up"):
			_step_weapon(-1)
			vp.set_input_as_handled()
		elif event.is_action_pressed("ui_down"):
			_step_weapon(1)
			vp.set_input_as_handled()
		return
	if not _skin_buttons.values().has(focused):
		return
	if event.is_action_pressed("ui_left"):
		_step_skin(-1)
		vp.set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_step_skin(1)
		vp.set_input_as_handled()


func _step_skin(step: int) -> void:
	var ids: Array[StringName] = []
	for skin: Dictionary in Skins.all():
		ids.append(skin["id"])
	var index: int = ids.find(_preview_id)
	if index < 0:
		index = 0
	var next: StringName = ids[posmod(index + step, ids.size())]
	_preview_id = next
	var button: Button = _skin_buttons[next]
	button.grab_focus()
	_refresh_skins()
	_refresh_preview()


## Commits the previewed hull. Disabled for a locked hull or the worn one.
func _on_equip_pressed() -> void:
	if not Skins.select(_preview_id):
		AudioManager.play_sfx("upgrade_denied")
		if not Skins.is_unlocked(_preview_id):
			_show_feedback(
				"LOCKED: %d PLANETS" % int(Skins.entry(_preview_id).get("unlock", 0)),
				UITheme.COLOR_WARN
			)
		return
	AudioManager.play_sfx("upgrade_buy")
	changed.emit()
	refresh()


func _refresh_skins() -> void:
	var worn: StringName = Skins.selected()
	for skin: Dictionary in Skins.all():
		var id: StringName = skin["id"]
		var button: Button = _skin_buttons[id]
		var unlocked: bool = Skins.is_unlocked(id)
		# Locked hulls stay clickable so they can be previewed; only EQUIP is
		# unavailable, and the dimming says so.
		button.modulate.a = 1.0 if unlocked else 0.45
		button.button_pressed = id == worn
		var style: StyleBoxFlat = _style_normal
		if id == worn:
			style = _style_equipped
		elif id == _preview_id:
			style = _style_preview
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		if unlocked:
			button.tooltip_text = "%s   (EQUIPPED)" % Skins.title(id) if id == worn \
				else "%s   CLICK TO PREVIEW" % Skins.title(id)
		else:
			button.tooltip_text = "%s   UNLOCKS AT %d PLANETS" % [
				Skins.title(id), int(skin["unlock"]),
			]
	var next: Dictionary = Skins.next_unlock()
	var next_text: String = "ALL SKINS UNLOCKED"
	if not next.is_empty():
		next_text = "NEXT SKIN AT %d PLANETS" % int(next["unlock"])
	_skin_hint.text = "WEARING %s   |   %s" % [Skins.title(worn), next_text]


## Hull, tail gap and flame are laid out as one block and centred in the box,
## the same way the ship is built in battle: the flame starts at the tail and
## burns away from the nose. The block is sized below the box so the skin name
## underneath stays clear at every skin size.
func _place_preview_pair(hull_height: float, alpha: float) -> void:
	var amount: float = lerpf(
		Tuning.THRUSTER_IDLE_SCALE, Tuning.THRUSTER_FULL_SCALE, PREVIEW_THRUST
	)
	var flame_scale: float = PREVIEW_FLAME_SCALE * PREVIEW_HULL_ZOOM
	# The bars run across the heading, so the flame is as wide as the 32 px art
	# and only as long as the tallest frame's stack of rows.
	var flame_length: float = Tuning.THRUSTER_BAR_ROWS.back() * flame_scale * amount
	var block: float = hull_height + Tuning.THRUSTER_TAIL_GAP + flame_length
	var top: float = maxf(PREVIEW_MARGIN, (PREVIEW_SIZE.y - block) * 0.5)
	var tail: float = top + hull_height + Tuning.THRUSTER_TAIL_GAP
	_preview_ship.position = Vector2(PREVIEW_CENTER_X, top + hull_height * 0.5)
	_preview_thruster.position = Vector2(PREVIEW_CENTER_X, tail)
	# The base scale is what `set_thrust` lerps from, so it stays separate.
	_preview_thruster.set_base_scale(Vector2.ONE * flame_scale)
	_preview_thruster.set_thrust(PREVIEW_THRUST)
	_preview_thruster.modulate = Color(1.0, 1.0, 1.0, alpha)


## The preview under CURRENT STATS: hull large, thruster lit, and exactly what
## it takes to wear it. Locked hulls are dimmed rather than hidden.
func _refresh_preview() -> void:
	if _tab == Tab.WEAPONS:
		_refresh_weapon_preview()
		return
	var id: StringName = _preview_id
	var unlocked: bool = Skins.is_unlocked(id)
	var equipped: bool = id == Skins.selected()
	var texture: Texture2D = Skins.texture(id)
	var zoom: float = PREVIEW_HULL_ZOOM * Skins.scale_of(id)
	var alpha: float = 1.0 if unlocked else 0.4
	_preview_ship.texture = texture
	_preview_ship.scale = Vector2.ONE * zoom
	_preview_ship.modulate = Color(1.0, 1.0, 1.0, alpha)
	var height: float = 0.0
	if texture != null:
		height = float(texture.get_height()) * zoom
	_place_preview_pair(height, alpha)
	_preview_name.text = Skins.title(id)
	_preview_name.add_theme_color_override(
		"font_color", UITheme.COLOR_TEXT if unlocked else UITheme.COLOR_MUTED
	)
	if equipped:
		_preview_status.text = "EQUIPPED"
		_preview_status.add_theme_color_override("font_color", UITheme.COLOR_ACCENT)
	elif unlocked:
		_preview_status.text = "UNLOCKED"
		_preview_status.add_theme_color_override("font_color", UITheme.COLOR_TEXT)
	else:
		_preview_status.text = "UNLOCKS AT %d PLANETS" % int(Skins.entry(id).get("unlock", 0))
		_preview_status.add_theme_color_override("font_color", UITheme.COLOR_WARN)
	var tier: int = int(Upgrades.stats_for(SaveData.upgrade_levels).get("bullet_tier", 0))
	_laser_label.text = "LASER %s" % LASER_NAMES[tier]
	_laser_label.add_theme_color_override("font_color", LASER_COLORS[tier])
	_equip_button.text = "EQUIPPED" if equipped else "EQUIP"
	_equip_button.disabled = equipped or not unlocked


# --- Weapons ----------------------------------------------------------------

## One button per weapon, built in code so the Tuning table stays the single
## source of truth for how many weapons exist.
func _build_weapons() -> void:
	for id: StringName in Weapons.ids():
		var card := Button.new()
		card.name = "Weapon_%s" % String(id)
		card.custom_minimum_size = Vector2(0.0, WEAPON_CARD_HEIGHT)
		card.tooltip_text = Weapons.description(id)
		var box := VBoxContainer.new()
		box.name = "Box"
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 10.0
		box.offset_top = 3.0
		box.offset_right = -10.0
		box.offset_bottom = -3.0
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 1)
		# Name, numbers and status each get their own fixed row, so a long
		# "UNLOCKS AT 12 PLANETS" never rides over the stats line above it.
		for row_name: String in ["Name", "Stats", "Status"]:
			var label := Label.new()
			label.name = row_name
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", 15 if row_name == "Name" else 10)
			label.custom_minimum_size = Vector2(0.0, 17.0 if row_name == "Name" else 12.0)
			label.clip_text = true
			box.add_child(label)
		card.add_child(box)
		card.pressed.connect(_on_weapon_pressed.bind(id))
		_weapon_row.add_child(card)
		_weapon_buttons[id] = card


func _on_weapon_pressed(id: StringName) -> void:
	_preview_weapon = id
	AudioManager.play_sfx("ui_click")
	_refresh_weapons()
	_refresh_weapon_preview()


func _step_weapon(step: int) -> void:
	var ids: Array[StringName] = Weapons.ids()
	var index: int = ids.find(_preview_weapon)
	if index < 0:
		index = 0
	_preview_weapon = ids[posmod(index + step, ids.size())]
	(_weapon_buttons[_preview_weapon] as Button).grab_focus()
	_refresh_weapons()
	_refresh_weapon_preview()


func _weapon_stats() -> Dictionary:
	return Upgrades.stats_for(SaveData.upgrade_levels)


func _on_buy_pressed() -> void:
	if SaveData.buy_weapon(_preview_weapon):
		AudioManager.play_sfx("upgrade_buy")
		changed.emit()
		refresh()
		return
	AudioManager.play_sfx("upgrade_denied")
	if not Weapons.is_unlocked(_preview_weapon):
		_show_feedback(
			"LOCKED: %d PLANETS" % Weapons.unlock_planets(_preview_weapon), UITheme.COLOR_WARN
		)
	elif Weapons.owned(_preview_weapon):
		_show_feedback("ALREADY OWNED", UITheme.COLOR_MUTED)
	else:
		_show_feedback(
			"NOT ENOUGH ENERGY: NEED %d" % Weapons.cost(_preview_weapon), UITheme.COLOR_WARN
		)


func _on_equip_weapon_pressed(slot: int) -> void:
	if SaveData.equip_weapon(_preview_weapon, slot):
		AudioManager.play_sfx("upgrade_buy")
		changed.emit()
		refresh()
		return
	AudioManager.play_sfx("upgrade_denied")
	_show_feedback("CANNOT EQUIP THAT PAIR", UITheme.COLOR_WARN)


## One short line under the tabs, faded out after two seconds, so a refused
## purchase says why instead of doing nothing. The row is always present and
## always 14 px tall: showing it never re-flows the tabs, which is what used to
## push the buttons out of the panel.
func _show_feedback(message: String, tint: Color) -> void:
	if message.is_empty():
		return
	_feedback.text = message
	_feedback.add_theme_color_override("font_color", tint)
	_feedback.modulate.a = 1.0
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(FEEDBACK_SECONDS)
	_feedback_tween.tween_property(_feedback, "modulate:a", 0.0, 0.35)


## HULL & SHIP swaps the 2x2 upgrade grid and the skin row for the weapon rack.
func _select_tab(tab: int) -> void:
	if _tab == tab:
		return
	_tab = tab
	AudioManager.play_sfx("ui_click")
	_apply_tab_visibility()
	refresh()
	if tab == Tab.WEAPONS:
		(_weapon_buttons[_preview_weapon] as Button).grab_focus()
	else:
		(get_node(CARD_ROOT[&"hull"]) as Button).grab_focus()


func _apply_tab_visibility() -> void:
	var hull: bool = _tab == Tab.HULL
	_grid.visible = hull
	_skins.visible = hull
	_weapon_box.visible = not hull
	_equip_button.visible = hull
	# The whole preview box goes, not only its sprites: an empty preview control
	# was what opened the big gap above the weapon icon.
	_preview_box.visible = hull
	_preview_ship.visible = hull
	_preview_thruster.visible = hull
	_weapon_icon.visible = not hull
	_buy_button.visible = not hull
	_equip_primary_button.visible = not hull
	_equip_secondary_button.visible = not hull
	_hull_tab.modulate = Color.WHITE if hull else Color(0.65, 0.7, 0.85)
	_weapon_tab.modulate = Color(0.65, 0.7, 0.85) if hull else Color.WHITE
	# Hull tab: preview column, then the 2x2 grid. Weapons tab: the rack on the
	# left, the preview column (projectile, stats, buttons) on the right.
	if hull:
		_body.move_child(_stats_column, 0)
		_body.move_child(_grid, 1)
		_stats_column.custom_minimum_size.x = STATS_WIDTH_HULL
	else:
		_body.move_child(_weapon_box, 0)
		_body.move_child(_stats_column, 1)
		_stats_column.custom_minimum_size.x = STATS_WIDTH_WEAPONS
	_scroll.scroll_vertical = 0


func _refresh_weapons() -> void:
	var stats: Dictionary = _weapon_stats()
	for id: StringName in Weapons.ids():
		var card: Button = _weapon_buttons[id]
		var data: Dictionary = Weapons.entry(id)
		var name_label: Label = card.get_node("Box/Name") as Label
		var numbers: Label = card.get_node("Box/Stats") as Label
		var status: Label = card.get_node("Box/Status") as Label
		var owned: bool = Weapons.owned(id)
		var unlocked: bool = Weapons.is_unlocked(id)
		name_label.text = Weapons.title(id)
		name_label.add_theme_color_override(
			"font_color", Weapons.color(id) if unlocked else UITheme.COLOR_MUTED
		)
		numbers.text = "DMG %d   RATE %.1f/s   SPD %d   DPS %.0f" % [
			Weapons.damage(id, stats),
			float(data["count"]) / Weapons.interval(id, stats),
			int(data["speed"]),
			Weapons.dps(id, stats),
		]
		if not unlocked:
			status.text = "UNLOCKS AT %d PLANETS" % Weapons.unlock_planets(id)
			status.add_theme_color_override("font_color", UITheme.COLOR_WARN)
		elif not owned:
			status.text = "COST %d ENERGY" % Weapons.cost(id)
			status.add_theme_color_override("font_color", UITheme.COLOR_GOLD)
		elif SaveData.weapon_primary == id:
			status.text = "PRIMARY"
			status.add_theme_color_override("font_color", UITheme.COLOR_ACCENT)
		elif SaveData.weapon_secondary == id:
			status.text = "SECONDARY"
			status.add_theme_color_override("font_color", UITheme.COLOR_ACCENT)
		else:
			status.text = "OWNED"
			status.add_theme_color_override("font_color", UITheme.COLOR_TEXT)
		var equipped: bool = SaveData.weapon_primary == id or SaveData.weapon_secondary == id
		var style: StyleBoxFlat = _style_normal
		if equipped:
			style = _style_equipped
		elif id == _preview_weapon:
			style = _style_preview
		card.add_theme_stylebox_override("normal", style)
		card.add_theme_stylebox_override("hover", style)
		card.add_theme_stylebox_override("pressed", style)
		card.modulate.a = 1.0 if unlocked else 0.5
	var secondary_text: String = "EMPTY"
	if SaveData.weapon_secondary != &"":
		secondary_text = Weapons.title(SaveData.weapon_secondary)
	_weapon_hint.text = "PRIMARY %s   |   SECONDARY %s" % [
		Weapons.title(SaveData.weapon_primary), secondary_text,
	]


## Projectile preview: the art large and in its own colour, then exactly what it
## takes to own and equip it.
func _refresh_weapon_preview() -> void:
	var id: StringName = _preview_weapon
	var data: Dictionary = Weapons.entry(id)
	if data.is_empty():
		return
	var owned: bool = Weapons.owned(id)
	var unlocked: bool = Weapons.is_unlocked(id)
	var price: int = Weapons.cost(id)
	var tint: Color = Weapons.color(id)
	_weapon_icon.texture = Weapons.texture(id)
	_weapon_icon.modulate = tint if unlocked else Color(0.55, 0.58, 0.7)
	_preview_name.text = Weapons.title(id)
	_preview_name.add_theme_color_override(
		"font_color", tint if unlocked else UITheme.COLOR_MUTED
	)
	_laser_label.text = Weapons.description(id)
	_laser_label.add_theme_color_override("font_color", UITheme.COLOR_MUTED)
	if not unlocked:
		_preview_status.text = "UNLOCKS AT %d PLANETS" % Weapons.unlock_planets(id)
		_preview_status.add_theme_color_override("font_color", UITheme.COLOR_WARN)
	elif owned:
		_preview_status.text = "OWNED"
		_preview_status.add_theme_color_override("font_color", UITheme.COLOR_ACCENT)
	else:
		_preview_status.text = "COST %d ENERGY" % price
		_preview_status.add_theme_color_override("font_color", UITheme.COLOR_GOLD)
	_buy_button.text = "OWNED" if owned else "BUY %d" % price
	_buy_button.disabled = owned or not unlocked or SaveData.energy < price
	_equip_primary_button.disabled = not owned or not unlocked or SaveData.weapon_primary == id
	_equip_primary_button.text = "PRIMARY" if SaveData.weapon_primary == id else "EQUIP PRIMARY"
	_equip_secondary_button.disabled = not owned or not unlocked \
		or SaveData.weapon_primary == id or SaveData.weapon_secondary == id
	_equip_secondary_button.text = "SECONDARY" if SaveData.weapon_secondary == id else "EQUIP SECONDARY"


func _skin_style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.corner_radius_top_left = 3
	box.corner_radius_top_right = 3
	box.corner_radius_bottom_left = 3
	box.corner_radius_bottom_right = 3
	box.content_margin_left = 2.0
	box.content_margin_right = 2.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	return box
