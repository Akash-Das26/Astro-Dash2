class_name BattleHUD
extends CanvasLayer
## Landscape readout. Top bar: ENERGY and SCORE on the right, COMBO in the
## centre. Bottom bar: WAVE on the left, ENEMIES on the right, and the HP and
## shield bars in the centre. The pause card and the end-of-battle card live
## here too.
##
## Presentation only: every button emits a signal and the battle decides what
## happens. The layer runs while the tree is paused, so the pause card and the
## end card stay interactive.

signal resume_requested
signal restart_requested
signal pause_requested
signal aim_changed(direction: Vector2)
signal end_continue_requested
signal end_retry_requested
signal end_quit_requested
signal menu_requested

const BAR_GREY: Texture2D = preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/horizontal_bar_grey.png")
const BAR_GREEN: Texture2D = preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/horizontal_bar_green.png")
const BAR_YELLOW: Texture2D = preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/horizontal_bar_yellow.png")
const BAR_RED: Texture2D = preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/horizontal_bar_red.png")
const BAR_BLUE: Texture2D = preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/horizontal_bar_blue.png")

const BANNER_SECONDS: float = 1.4
const BANNER_SCALE_FROM: float = 0.7
const BANNER_POP_SECONDS: float = 0.18
const HP_GREEN_ABOVE: float = 0.55
const HP_YELLOW_ABOVE: float = 0.25
## Below this multiplier the combo readout stays hidden; a single kill is not
## a combo yet.
const COMBO_MIN_SHOWN: float = 1.25
const WEAPON_SLOT_PATHS: Array[String] = [
	"Root/BottomBar/PrimarySlot", "Root/BottomBar/SecondarySlot",
]

var _weapon_icons: Array[TextureRect] = []
var _weapon_names: Array[Label] = []
var _weapon_cooldowns: Array[TextureProgressBar] = []

@onready var _score_label: Label = $Root/TopBar/ScoreLabel
@onready var _energy_label: Label = $Root/TopBar/EnergyLabel
@onready var _combo_label: Label = $Root/TopBar/ComboLabel
@onready var _wave_label: Label = $Root/BottomBar/WaveLabel
@onready var _enemies_label: Label = $Root/BottomBar/EnemiesLabel
@onready var _hp_bar: TextureProgressBar = $Root/BottomBar/HpBar
@onready var _shield_bar: TextureProgressBar = $Root/BottomBar/ShieldBar
@onready var _shield_label: Label = $Root/BottomBar/ShieldLabel
@onready var _banner_label: Label = $Root/BannerLabel
@onready var _end_card: Control = $Root/EndCard
@onready var _end_title: Label = $Root/EndCard/Panel/Margin/Box/Title
@onready var _end_subtitle: Label = $Root/EndCard/Panel/Margin/Box/Subtitle
@onready var _end_detail: Label = $Root/EndCard/Panel/Margin/Box/Detail
@onready var _end_hint: Label = $Root/EndCard/Panel/Margin/Box/Hint
@onready var _end_button: Button = $Root/EndCard/Panel/Margin/Box/Buttons/EndButton
@onready var _quit_button: Button = $Root/EndCard/Panel/Margin/Box/Buttons/QuitButton
@onready var _pause_button: Button = $Root/TouchControls/PauseButton
@onready var _pause_panel: Control = $Root/PausePanel
@onready var _resume_button: Button = $Root/PausePanel/Box/ResumeButton
@onready var _menu_button: Button = $Root/PausePanel/Box/MenuButton
@onready var _controls_button: Button = $Root/PausePanel/Box/ControlsButton
@onready var _controls_card: ControlsCard = $Root/ControlsCard
@onready var _pause_confirm_label: Label = $Root/PausePanel/Box/ConfirmLabel
@onready var _pause_confirm_row: HBoxContainer = $Root/PausePanel/Box/ConfirmRow
@onready var _pause_confirm_yes: Button = $Root/PausePanel/Box/ConfirmRow/ConfirmMenuButton
@onready var _pause_confirm_no: Button = $Root/PausePanel/Box/ConfirmRow/CancelMenuButton
@onready var _banner_timer: Timer = $BannerTimer
@onready var _touch_controls: TouchControls = $Root/TouchControls
@onready var _boss_panel: Control = $Root/BossPanel
@onready var _boss_name: Label = $Root/BossPanel/Name
@onready var _boss_bar: TextureProgressBar = $Root/BossPanel/Bar

var _banner_tween: Tween
## The end card's primary button continues after a win and retries after a loss.
var _end_is_victory: bool = false


func _ready() -> void:
	_resume_button.pressed.connect(resume_requested.emit)
	$Root/PausePanel/Box/RestartButton.pressed.connect(restart_requested.emit)
	_menu_button.pressed.connect(_show_menu_confirm)
	_controls_button.pressed.connect(_controls_card.open)
	_controls_card.closed.connect(_on_controls_closed)
	_pause_confirm_yes.pressed.connect(menu_requested.emit)
	_pause_confirm_no.pressed.connect(_hide_menu_confirm)
	_touch_controls.pause_requested.connect(pause_requested.emit)
	_touch_controls.aim_changed.connect(aim_changed.emit)
	_end_button.pressed.connect(_on_end_button_pressed)
	_quit_button.pressed.connect(end_quit_requested.emit)
	_banner_timer.timeout.connect(_on_banner_timeout)
	_hp_bar.texture_under = BAR_GREY
	_hp_bar.texture_progress = BAR_GREEN
	_shield_bar.texture_under = BAR_GREY
	_shield_bar.texture_progress = BAR_BLUE
	_pause_panel.visible = false
	_end_card.visible = false
	_combo_label.visible = false
	_banner_label.visible = false
	_boss_panel.visible = false
	for path: String in WEAPON_SLOT_PATHS:
		var slot: Control = get_node(path) as Control
		_weapon_icons.append(slot.get_node("Icon") as TextureRect)
		_weapon_names.append(slot.get_node("Name") as Label)
		_weapon_cooldowns.append(slot.get_node("Cooldown") as TextureProgressBar)


## The ship the touch zone aims from; the battle sets it once at boot.
func set_aim_origin(ship: Node2D) -> void:
	_touch_controls.aim_origin = ship


## Clears the screen for a new battle.
func reset(battle: Battle) -> void:
	set_score(0)
	set_energy(0)
	set_combo(0, 1.0)
	set_wave(1, battle.waves)
	set_enemies(0, battle.enemy_total())
	hide_boss()
	hide_end()
	set_weapon_cooldowns(0.0, 0.0)
	show_playing()
	_banner_label.visible = false


func set_score(value: int) -> void:
	_score_label.text = "SCORE %d" % value


func set_energy(value: int) -> void:
	_energy_label.text = "ENERGY %d" % value


## chain is the raw kill count; the multiplier is 1 + chain / COMBO_SCORE_STEP.
func set_combo(chain: int, multiplier: float) -> void:
	if chain <= 0 or multiplier < COMBO_MIN_SHOWN:
		_combo_label.visible = false
		return
	_combo_label.visible = true
	_combo_label.text = "COMBO x%.1f" % multiplier


func set_wave(index: int, total: int) -> void:
	_wave_label.text = "WAVE %d/%d" % [index, maxi(total, 1)]


func set_enemies(killed: int, total: int) -> void:
	_enemies_label.text = "ENEMIES %d/%d" % [killed, total]


func set_hp(hp: int, max_hp: int) -> void:
	var maximum: int = maxi(max_hp, 1)
	var ratio: float = float(hp) / float(maximum)
	_hp_bar.max_value = maximum
	_hp_bar.value = clampi(hp, 0, maximum)
	if ratio > HP_GREEN_ABOVE:
		_hp_bar.texture_progress = BAR_GREEN
	elif ratio > HP_YELLOW_ABOVE:
		_hp_bar.texture_progress = BAR_YELLOW
	else:
		_hp_bar.texture_progress = BAR_RED


## The bar is the visual, the label is the exact count, and both stay readable
## at zero so the player knows a drop is worth grabbing.
func set_shields(charges: int) -> void:
	var capped: int = clampi(charges, 0, Tuning.MAX_SHIELD_CHARGES)
	_shield_bar.max_value = Tuning.MAX_SHIELD_CHARGES
	_shield_bar.value = capped
	_shield_bar.visible = capped > 0
	if capped > 0:
		_shield_label.text = "SHIELD x%d" % capped
		_shield_label.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	else:
		_shield_label.text = "NO SHIELD"
		_shield_label.add_theme_color_override("font_color", UITheme.COLOR_MUTED)


## Two weapon readouts: icon, name in the weapon's own colour, and a cooldown
## bar that drains back to empty as the gun cools.
func set_weapons(primary: StringName, secondary: StringName) -> void:
	_render_weapon_slot(0, primary)
	_render_weapon_slot(1, secondary)


func set_weapon_cooldowns(primary: float, secondary: float) -> void:
	if _weapon_cooldowns.size() < 2:
		return
	_weapon_cooldowns[0].value = clampf(primary, 0.0, 1.0)
	_weapon_cooldowns[1].value = clampf(secondary, 0.0, 1.0)


func _render_weapon_slot(slot: int, id: StringName) -> void:
	var data: Dictionary = Weapons.entry(id)
	var icon: TextureRect = _weapon_icons[slot]
	var name_label: Label = _weapon_names[slot]
	if data.is_empty():
		icon.texture = null
		name_label.text = "EMPTY"
		name_label.add_theme_color_override("font_color", UITheme.COLOR_MUTED)
		_weapon_cooldowns[slot].modulate.a = 0.35
		return
	icon.texture = Weapons.texture(id)
	name_label.text = Weapons.title(id)
	name_label.add_theme_color_override("font_color", Weapons.color(id))
	_weapon_cooldowns[slot].texture_progress = BAR_BLUE if slot == 0 else BAR_GREEN
	_weapon_cooldowns[slot].modulate.a = 1.0


## Citadel bar: the station name and the red HP bar under the top readout.
func show_boss(title: String, hp: int, max_hp: int) -> void:
	_boss_name.text = title.to_upper()
	_boss_panel.visible = true
	set_boss_hp(hp, max_hp)


func set_boss_hp(hp: int, max_hp: int) -> void:
	var maximum: int = maxi(max_hp, 1)
	_boss_bar.max_value = maximum
	_boss_bar.value = clampi(hp, 0, maximum)


func hide_boss() -> void:
	_boss_panel.visible = false


## Short "WAVE 2/3" flash in the middle of the arena.
func show_banner(text: String) -> void:
	_banner_label.text = text
	_banner_label.visible = true
	_banner_label.modulate.a = 1.0
	_banner_label.pivot_offset = _banner_label.size * 0.5
	_banner_label.scale = Vector2(BANNER_SCALE_FROM, BANNER_SCALE_FROM)
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_label, "scale", Vector2.ONE, BANNER_POP_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_timer.start(BANNER_SECONDS)


func _on_banner_timeout() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_label, "modulate:a", 0.0, 0.3)
	_banner_tween.tween_callback(_banner_label.hide)


## Victory card: planet, waves, kills, the score this battle and the campaign
## total, plus the no-damage bonus line when it was earned.
func show_victory(data: Dictionary) -> void:
	_end_is_victory = true
	_end_title.text = "SECTOR SECURED!"
	_end_title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7))
	_end_subtitle.text = "%s CONQUERED!" % String(data.get("name", "SECTOR")).to_upper()
	_end_subtitle.add_theme_color_override("font_color", UITheme.COLOR_ACCENT)
	var lines: PackedStringArray = []
	lines.append("WAVES %d/%d   |   ENEMIES %d/%d" % [
		int(data.get("wave", 1)), int(data.get("waves", 1)),
		int(data.get("kills", 0)), int(data.get("total", 0)),
	])
	lines.append("SCORE +%d   |   CAMPAIGN TOTAL %d" % [
		int(data.get("score", 0)), int(data.get("total_score", 0)),
	])
	if bool(data.get("perfect", false)):
		lines.append("PERFECT VICTORY   +%d SCORE   +%d ENERGY" % [
			Tuning.PERFECT_BONUS_SCORE, Tuning.PERFECT_BONUS_ENERGY,
		])
	else:
		lines.append("ENERGY +%d" % int(data.get("energy", 0)))
	_end_detail.text = "\n".join(lines)
	_end_hint.text = "ENTER CONTINUES"
	_end_button.text = "CONTINUE"
	_quit_button.visible = false
	_present_end()


## Game-over card: the run's final score against the record, the worlds taken
## and the deepest band reached.
func show_game_over(data: Dictionary) -> void:
	_end_is_victory = false
	_end_title.text = "GAME OVER"
	_end_title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	var new_high: bool = bool(data.get("new_high", false))
	_end_subtitle.text = "NEW HIGH SCORE!" if new_high else "CAMPAIGN OVER"
	_end_subtitle.add_theme_color_override(
		"font_color", UITheme.COLOR_GOLD if new_high else UITheme.COLOR_WARN
	)
	var lines: PackedStringArray = []
	lines.append("FINAL SCORE %d" % int(data.get("score", 0)))
	lines.append("HIGH SCORE %d" % int(data.get("high", 0)))
	var planets: int = int(data.get("planets", 0))
	var bodies: int = int(data.get("bodies", 0))
	if bodies > 0:
		lines.append("PLANETS %d/%d   |   DEEPEST %s" % [
			planets, bodies, String(data.get("band", "")),
		])
	else:
		lines.append("PLANETS %d   |   WAVE %d" % [planets, int(data.get("wave", 1))])
	_end_detail.text = "\n".join(lines)
	_end_hint.text = "TRY AGAIN STARTS A FRESH CAMPAIGN"
	_end_button.text = "TRY AGAIN"
	_quit_button.visible = true
	_present_end()


func _present_end() -> void:
	_end_card.visible = true
	# The end card owns the screen; a stray pause tap behind it would fight it.
	_pause_button.visible = false
	_end_button.grab_focus()


func _on_end_button_pressed() -> void:
	if _end_is_victory:
		end_continue_requested.emit()
	else:
		end_retry_requested.emit()


func hide_end() -> void:
	_end_card.visible = false
	_pause_button.visible = true


func show_paused() -> void:
	_hide_menu_confirm()
	_pause_panel.visible = true
	_resume_button.grab_focus()


func show_playing() -> void:
	_pause_panel.visible = false
	_controls_card.close()
	_hide_menu_confirm()


## MAIN MENU abandons the battle, so it asks once: one line, two buttons, and
## CANCEL puts the pause card back.
func _show_menu_confirm() -> void:
	_menu_button.visible = false
	_pause_confirm_label.visible = true
	_pause_confirm_row.visible = true
	_pause_confirm_yes.grab_focus()


func _hide_menu_confirm() -> void:
	_pause_confirm_label.visible = false
	_pause_confirm_row.visible = false
	_menu_button.visible = true
	if _pause_panel.visible:
		_menu_button.grab_focus()


## The controls card is the top-most layer while it is open: Back and B close
## it before they touch the pause card underneath.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _controls_card.visible:
		_controls_card.close()
		get_viewport().set_input_as_handled()
		return
	if _pause_panel.visible:
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _on_controls_closed() -> void:
	if _pause_panel.visible:
		_controls_button.grab_focus()


## Android Back while paused: close the controls card if it is open, else
## resume. Re-armed on every request, because GameState consumes it.
func handle_pause_back() -> void:
	GameState.back_handler = handle_pause_back
	if _controls_card.visible:
		_controls_card.close()
		return
	resume_requested.emit()
