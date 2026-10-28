class_name HUD
extends CanvasLayer
## Presentation only. Shows the run readouts plus the menu, pause and
## game-over panels, and turns button presses into requests that the
## GameManager acts on. It never changes game state by itself.
##
## The CanvasLayer is process_mode Always so panels stay interactive while the
## tree is paused; UI tweens therefore keep running during pause, which is what
## menus need.

signal play_requested
signal resume_requested
signal restart_requested
signal menu_requested

const PANEL_FADE_SECONDS: float = 0.18
const PANEL_SLIDE_PIXELS: float = 16.0
const SCORE_COUNT_SECONDS: float = 0.25
const LIVES_PULSE_SCALE: float = 1.35
const LIVES_PULSE_SECONDS: float = 0.25
const BANNER_SCALE_FROM: float = 0.6
const BANNER_POP_SECONDS: float = 0.22
const BANNER_FADE_SECONDS: float = 0.3

@onready var _score_label: Label = $Root/ScoreLabel
@onready var _best_label: Label = $Root/BestLabel
@onready var _lives_label: Label = $Root/LivesLabel
@onready var _powerup_label: Label = $Root/PowerupLabel
@onready var _debug_label: Label = $Root/DebugLabel
@onready var _banner_label: Label = $Root/BannerLabel

@onready var _menu_panel: Control = $Root/MenuPanel
@onready var _pause_panel: Control = $Root/PausePanel
@onready var _game_over_panel: Control = $Root/GameOverPanel

@onready var _menu_best_label: Label = $Root/MenuPanel/Box/BestValueLabel
@onready var _final_score_label: Label = $Root/GameOverPanel/Box/FinalScoreLabel
@onready var _game_over_best_label: Label = $Root/GameOverPanel/Box/GameOverBestLabel
@onready var _new_best_label: Label = $Root/GameOverPanel/Box/NewBestLabel
@onready var _banner_timer: Timer = $BannerTimer

var _panel_tweens: Dictionary = {}
var _score_tween: Tween
var _banner_tween: Tween
var _displayed_score: int = 0
var _displayed_lives: int = 0


func _ready() -> void:
	$Root/MenuPanel/Box/PlayButton.pressed.connect(play_requested.emit)
	$Root/PausePanel/Box/ResumeButton.pressed.connect(resume_requested.emit)
	$Root/PausePanel/Box/RestartButton.pressed.connect(restart_requested.emit)
	$Root/PausePanel/Box/MenuButton.pressed.connect(menu_requested.emit)
	$Root/GameOverPanel/Box/RetryButton.pressed.connect(restart_requested.emit)
	$Root/GameOverPanel/Box/MenuButton.pressed.connect(menu_requested.emit)
	_banner_timer.timeout.connect(_on_banner_timeout)
	_show_only(_menu_panel)


func set_score(value: int) -> void:
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	_score_tween = create_tween()
	_score_tween.tween_method(_set_score_text, float(_displayed_score), float(value), SCORE_COUNT_SECONDS)


func set_lives(value: int, maximum: int) -> void:
	var dropped: bool = value < _displayed_lives
	_displayed_lives = value
	_lives_label.text = "LIVES %d/%d" % [value, maximum]
	if dropped:
		_pulse(_lives_label)


func set_high_score(value: int) -> void:
	_best_label.text = "BEST %d" % value


## Debug builds only: live-node readout used to judge whether pooling pays.
func set_debug_text(text: String) -> void:
	_debug_label.text = text


func set_debug_visible(is_visible: bool) -> void:
	_debug_label.visible = is_visible


## One line describing the active power-ups, e.g. "RAPID 6s   SHIELD".
func set_powerups(text: String) -> void:
	_powerup_label.text = text


func show_menu(high_score: int) -> void:
	_menu_best_label.text = "BEST %d" % high_score
	_show_only(_menu_panel)
	_snap_score()


func show_playing() -> void:
	_show_only(null)


func show_paused() -> void:
	_show_only(_pause_panel)


func show_game_over(final_score: int, high_score: int, is_new_best: bool) -> void:
	_final_score_label.text = "SCORE %d" % final_score
	_game_over_best_label.text = "BEST %d" % high_score
	_new_best_label.visible = is_new_best
	_show_only(_game_over_panel)


## Short "WAVE 3" / "BOSS WAVE" flash between waves.
func show_wave_banner(text: String) -> void:
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
	_banner_timer.start()


func _set_score_text(value: float) -> void:
	_displayed_score = int(round(value))
	_score_label.text = "SCORE %d" % _displayed_score


## Jumps the readout (without counting) when a run ends or the menu opens.
func _snap_score() -> void:
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	_displayed_score = 0
	_score_label.text = "SCORE 0"


func _pulse(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(LIVES_PULSE_SCALE, LIVES_PULSE_SCALE)
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2.ONE, LIVES_PULSE_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_banner_timeout() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_label, "modulate:a", 0.0, BANNER_FADE_SECONDS)
	_banner_tween.tween_callback(_banner_label.hide)


func _show_only(panel: Control) -> void:
	for candidate: Control in [_menu_panel, _pause_panel, _game_over_panel]:
		if candidate == panel:
			_fade_in(candidate)
		elif candidate.visible:
			_fade_out(candidate)


func _fade_in(panel: Control) -> void:
	_kill_panel_tween(panel)
	if panel.visible and panel.modulate.a >= 0.99:
		return
	panel.visible = true
	panel.modulate.a = 0.0
	panel.position.y = PANEL_SLIDE_PIXELS
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, PANEL_FADE_SECONDS)
	tween.tween_property(panel, "position:y", 0.0, PANEL_FADE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_panel_tweens[panel] = tween


func _fade_out(panel: Control) -> void:
	_kill_panel_tween(panel)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, PANEL_FADE_SECONDS)
	tween.tween_callback(panel.hide)
	_panel_tweens[panel] = tween


func _kill_panel_tween(panel: Control) -> void:
	var existing: Tween = _panel_tweens.get(panel)
	if existing != null and existing.is_valid():
		existing.kill()
