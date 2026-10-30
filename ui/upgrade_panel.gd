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

@onready var _energy_label: Label = $Panel/Margin/Box/Header/EnergyLabel
@onready var _close_button: Button = $Panel/Margin/Box/Header/CloseButton
@onready var _stats_label: Label = $Panel/Margin/Box/Body/Stats/Value
@onready var _skin_row: HBoxContainer = $Panel/Margin/Box/Skins/Row
@onready var _skin_hint: Label = $Panel/Margin/Box/Skins/Hint

var _skin_buttons: Dictionary = {}


func _ready() -> void:
	_close_button.pressed.connect(close)
	for kind: StringName in Tuning.UPGRADE_ORDER:
		var card := get_node(CARD_ROOT[kind]) as Button
		card.pressed.connect(_on_card_pressed.bind(kind))
	_build_skins()
	refresh()


func open() -> void:
	visible = true
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


func _on_skin_pressed(id: StringName) -> void:
	if not Skins.is_unlocked(id):
		refresh()
		return
	if Skins.select(id):
		AudioManager.play_sfx("ui_click")
		changed.emit()
	refresh()


func _refresh_skins() -> void:
	var worn: StringName = Skins.selected()
	for skin: Dictionary in Skins.all():
		var id: StringName = skin["id"]
		var button: Button = _skin_buttons[id]
		var unlocked: bool = Skins.is_unlocked(id)
		button.disabled = not unlocked
		button.button_pressed = id == worn
		if unlocked:
			button.tooltip_text = "%s   (WEARING)" % Skins.title(id) if id == worn \
				else Skins.title(id)
		else:
			button.tooltip_text = "%s - UNLOCKS AT %d PLANETS" % [
				Skins.title(id), int(skin["unlock"]),
			]
	var next: Dictionary = Skins.next_unlock()
	var next_text: String = "ALL SKINS UNLOCKED"
	if not next.is_empty():
		next_text = "NEXT SKIN AT %d PLANETS" % int(next["unlock"])
	_skin_hint.text = "WEARING %s   |   %s" % [Skins.title(worn), next_text]
