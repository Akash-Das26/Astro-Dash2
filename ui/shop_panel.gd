class_name ShopPanel
extends VBoxContainer
## The upgrade card. It reads levels and energy from SaveData and never writes:
## a tap emits `buy_requested` and the manager answers by telling the HUD to
## refresh. Rows are plain buttons, so the whole row is the touch target and
## the disabled state is the engine's own.

signal buy_requested(kind: StringName)
signal close_requested

@onready var _energy_label: Label = $EnergyLabel
@onready var _close_button: Button = $CloseButton
@onready var _rows: Dictionary = {
	&"hull": $HullRow,
	&"speed": $SpeedRow,
	&"shield": $ShieldRow,
	&"fire": $FireRow,
}


func _ready() -> void:
	for kind: StringName in Tuning.UPGRADE_ORDER:
		(_rows[kind] as Button).pressed.connect(_on_row_pressed.bind(kind))
	_close_button.pressed.connect(close_requested.emit)
	refresh()


## Called on open and after every purchase attempt.
func refresh() -> void:
	_energy_label.text = "ENERGY %d" % SaveData.energy
	for kind: StringName in Tuning.UPGRADE_ORDER:
		_render_row(kind)


## "FIRE POWER  4/10  DMG 2  3.6/s   97 ENERGY", or MAXED when the track is full.
func _render_row(kind: StringName) -> void:
	var row: Button = _rows[kind]
	var level: int = SaveData.level_of(kind)
	var effect: String = Upgrades.effect_text(kind, level)
	var head: String = "%s  %d/%d  %s" % [Upgrades.title(kind), level, Upgrades.MAX_LEVEL, effect]
	if level >= Upgrades.MAX_LEVEL:
		row.text = "%s   MAXED" % head
		row.disabled = true
		return
	var price: int = Upgrades.cost(kind, level)
	row.text = "%s   %d ENERGY" % [head, price]
	row.disabled = SaveData.energy < price


func _on_row_pressed(kind: StringName) -> void:
	buy_requested.emit(kind)
