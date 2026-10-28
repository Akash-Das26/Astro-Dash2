class_name HUD
extends CanvasLayer
## Presentation only. Shows the run readouts plus the menu, pause and
## game-over panels, and turns button presses into requests that the
## GameManager acts on. It never changes game state by itself.

signal play_requested
signal resume_requested
signal restart_requested
signal menu_requested

@onready var _score_label: Label = $Root/ScoreLabel
@onready var _best_label: Label = $Root/BestLabel
@onready var _lives_label: Label = $Root/LivesLabel

@onready var _menu_panel: Control = $Root/MenuPanel
@onready var _pause_panel: Control = $Root/PausePanel
@onready var _game_over_panel: Control = $Root/GameOverPanel

@onready var _powerup_label: Label = $Root/PowerupLabel
@onready var _banner_label: Label = $Root/BannerLabel
@onready var _banner_timer: Timer = $BannerTimer

@onready var _menu_best_label: Label = $Root/MenuPanel/Box/BestValueLabel
@onready var _final_score_label: Label = $Root/GameOverPanel/Box/FinalScoreLabel
@onready var _game_over_best_label: Label = $Root/GameOverPanel/Box/GameOverBestLabel
@onready var _new_best_label: Label = $Root/GameOverPanel/Box/NewBestLabel


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
	_score_label.text = "SCORE %d" % value


func set_lives(value: int, maximum: int) -> void:
	_lives_label.text = "LIVES %d/%d" % [value, maximum]


func set_high_score(value: int) -> void:
	_best_label.text = "BEST %d" % value


## One line describing the active power-ups, e.g. "RAPID 6s   SHIELD".
func set_powerups(text: String) -> void:
	_powerup_label.text = text


func show_menu(high_score: int) -> void:
	_menu_best_label.text = "BEST %d" % high_score
	_show_only(_menu_panel)


func show_playing() -> void:
	_show_only(null)


## Short "WAVE 3" / "BOSS WAVE" flash between waves.
func show_wave_banner(text: String) -> void:
	_banner_label.text = text
	_banner_label.visible = true
	_banner_timer.start()


func show_paused() -> void:
	_show_only(_pause_panel)


func show_game_over(final_score: int, high_score: int, is_new_best: bool) -> void:
	_final_score_label.text = "SCORE %d" % final_score
	_game_over_best_label.text = "BEST %d" % high_score
	_new_best_label.visible = is_new_best
	_show_only(_game_over_panel)


func _on_banner_timeout() -> void:
	_banner_label.visible = false


func _show_only(panel: Control) -> void:
	for candidate: Control in [_menu_panel, _pause_panel, _game_over_panel]:
		candidate.visible = candidate == panel
