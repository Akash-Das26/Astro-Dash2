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

const CARD_ROOT: Dictionary = {
	&"hull": "Panel/Margin/Box/Body/Grid/HullCard",
	&"speed": "Panel/Margin/Box/Body/Grid/SpeedCard",
	&"shield": "Panel/Margin/Box/Body/Grid/ShieldCard",
	&"fire": "Panel/Margin/Box/Body/Grid/FireCard",
}
const SKIN_ICON_SIZE: Vector2 = Vector2(58.0, 48.0)
## The preview draws a hull at about four times its in-battle size. Normalising
## against the base 0.4 keeps the small green interceptor equally big.
const BASE_SKIN_SCALE: float = 0.4
const PREVIEW_ZOOM: float = 1.4
const PREVIEW_CENTER: Vector2 = Vector2(105.0, 62.0)
const LASER_NAMES: Array[String] = ["BLUE", "GREEN", "YELLOW"]
const LASER_COLORS: Array[Color] = [
	Color(0.55, 0.78, 1.0),
	Color(0.6, 1.0, 0.7),
	Color(1.0, 0.88, 0.35),
]

@onready var _energy_label: Label = $Panel/Margin/Box/Header/EnergyLabel
@onready var _close_button: Button = $Panel/Margin/Box/Header/CloseButton
@onready var _stats_label: Label = $Panel/Margin/Box/Body/Stats/Value
@onready var _preview_ship: Sprite2D = $Panel/Margin/Box/Body/Stats/Preview/ShipSprite
@onready var _preview_thruster: Thruster = $Panel/Margin/Box/Body/Stats/Preview/Thruster
@onready var _preview_name: Label = $Panel/Margin/Box/Body/Stats/PreviewName
@onready var _preview_status: Label = $Panel/Margin/Box/Body/Stats/PreviewStatus
@onready var _laser_label: Label = $Panel/Margin/Box/Body/Stats/LaserLabel
@onready var _equip_button: Button = $Panel/Margin/Box/Body/Stats/EquipButton
@onready var _skin_row: HBoxContainer = $Panel/Margin/Box/Skins/Row
@onready var _skin_hint: Label = $Panel/Margin/Box/Skins/Hint

## Hull shown in the preview. Picking a skin only previews it; EQUIP commits.
var _preview_id: StringName = Skins.DEFAULT_ID
var _skin_buttons: Dictionary = {}
var _style_normal: StyleBoxFlat
var _style_preview: StyleBoxFlat
var _style_equipped: StyleBoxFlat


func _ready() -> void:
	_preview_id = Skins.selected()
	_close_button.pressed.connect(close)
	_equip_button.pressed.connect(_on_equip_pressed)
	for kind: StringName in Tuning.UPGRADE_ORDER:
		var card := get_node(CARD_ROOT[kind]) as Button
		card.pressed.connect(_on_card_pressed.bind(kind))
	_build_skins()
	refresh()


func open() -> void:
	visible = true
	_preview_id = Skins.selected()
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
	_refresh_preview()


func _render_stats() -> void:
	var stats: Dictionary = Upgrades.stats_for(SaveData.upgrade_levels)
	var max_hp: int = int(stats["max_hp"])
	var hp: int = max_hp
	var shields: int = int(stats["shield_charges"])
	if SaveData.campaign_active:
		if SaveData.campaign_hp > 0:
			hp = clampi(SaveData.campaign_hp, 1, max_hp)
		shields = SaveData.campaign_shields
	_stats_label.text = "HEALTH    %d/%d\nSPEED      %d\nSHIELDS   %d/%d\nFIRE       %dx" % [
		hp,
		max_hp,
		roundi(float(stats["move_speed"])),
		shields,
		Tuning.MAX_SHIELD_CHARGES,
		int(stats["bullet_damage"]),
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
		AudioManager.play_sfx("ui_click")
		changed.emit()
		refresh()


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
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or not _skin_buttons.values().has(focused):
		return
	if event.is_action_pressed("ui_left"):
		_step_skin(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_step_skin(1)
		get_viewport().set_input_as_handled()


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
		return
	AudioManager.play_sfx("ui_click")
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


## The preview under CURRENT STATS: hull large, thruster lit, and exactly what
## it takes to wear it. Locked hulls are dimmed rather than hidden.
func _refresh_preview() -> void:
	var id: StringName = _preview_id
	var unlocked: bool = Skins.is_unlocked(id)
	var equipped: bool = id == Skins.selected()
	var texture: Texture2D = Skins.texture(id)
	var zoom: float = PREVIEW_ZOOM * (Skins.scale_of(id) / BASE_SKIN_SCALE)
	var alpha: float = 1.0 if unlocked else 0.4
	_preview_ship.texture = texture
	_preview_ship.scale = Vector2.ONE * zoom
	_preview_ship.position = PREVIEW_CENTER
	_preview_ship.modulate = Color(1.0, 1.0, 1.0, alpha)
	var height: float = 0.0
	if texture != null:
		height = float(texture.get_height()) * zoom
	_preview_thruster.position = PREVIEW_CENTER + Vector2(0.0, height * 0.36)
	_preview_thruster.set_base_scale(Vector2.ONE * (zoom * 0.9))
	_preview_thruster.set_thrust(0.9)
	_preview_thruster.modulate = Color(1.0, 1.0, 1.0, alpha)
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
