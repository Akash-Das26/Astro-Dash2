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

@onready var _score_label: Label = $Root/TopBar/ScoreLabel
@onready var _energy_label: Label = $Root/TopBar/EnergyLabel
@onready var _combo_label: Label = $Root/TopBar/ComboLabel
@onready var _wave_label: Label = $Root/BottomBar/WaveLabel
@onready var _enemies_label: Label = $Root/BottomBar/EnemiesLabel
@onready var _hp_bar: TextureProgressBar = $Root/BottomBar/HpBar
@onready var _shield_bar: TextureProgressBar = $Root/BottomBar/ShieldBar
@onready var _banner_label: Label = $Root/BannerLabel
@onready var _end_card: Control = $Root/EndCard
@onready var _end_title: Label = $Root/EndCard/Title
@onready var _end_detail: Label = $Root/EndCard/Detail
@onready var _end_hint: Label = $Root/EndCard/Hint
@onready var _pause_panel: Control = $Root/PausePanel
@onready var _banner_timer: Timer = $BannerTimer
@onready var _touch_controls: TouchControls = $Root/TouchControls
@onready var _boss_panel: Control = $Root/BossPanel
@onready var _boss_name: Label = $Root/BossPanel/Name
@onready var _boss_bar: TextureProgressBar = $Root/BossPanel/Bar

var _banner_tween: Tween


func _ready() -> void:
	$Root/PausePanel/Box/ResumeButton.pressed.connect(resume_requested.emit)
	$Root/PausePanel/Box/RestartButton.pressed.connect(restart_requested.emit)
	_touch_controls.pause_requested.connect(pause_requested.emit)
	_touch_controls.aim_changed.connect(aim_changed.emit)
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


func set_shields(charges: int) -> void:
	_shield_bar.max_value = Tuning.MAX_SHIELD_CHARGES
	_shield_bar.value = clampi(charges, 0, Tuning.MAX_SHIELD_CHARGES)
	_shield_bar.visible = charges > 0


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


## End of a battle: victory or defeat card over the frozen arena.
func show_end(title: String, detail: String, hint: String) -> void:
	_end_title.text = title
	_end_detail.text = detail
	_end_hint.text = hint
	_end_title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7) if title == "VICTORY" else Color(1.0, 0.45, 0.4))
	_end_card.visible = true


func hide_end() -> void:
	_end_card.visible = false


func show_paused() -> void:
	_pause_panel.visible = true


func show_playing() -> void:
	_pause_panel.visible = false
