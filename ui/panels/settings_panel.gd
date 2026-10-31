class_name SettingsPanel
extends VBoxContainer
## Audio and motion settings block, instanced on both the main menu and the
## pause panel. It writes straight through to AudioManager and SaveData
## (global services) and holds no game state.
##
## Two instances exist at once, so they resync from AudioManager's
## `settings_changed` signal instead of reading each other. Slider changes are
## saved on a short debounce so dragging does not hit the disk every frame.

signal controls_requested

const SAVE_DEBOUNCE_SECONDS: float = 0.4

@onready var _master_slider: HSlider = $MasterRow/MasterSlider
@onready var _music_slider: HSlider = $MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $SfxRow/SfxSlider
@onready var _mute_check: CheckButton = $MuteCheck
@onready var _motion_check: CheckButton = $MotionCheck
@onready var _auto_fire_check: CheckButton = $AutoFireCheck
@onready var _contrast_check: CheckButton = $ContrastCheck
@onready var _scheme_button: Button = $SchemeButton
@onready var _shield_mode_button: Button = $ShieldModeButton
@onready var _now_playing: Label = $NowPlaying
@onready var _prev_button: Button = $TrackRow/PrevButton
@onready var _next_button: Button = $TrackRow/NextButton
@onready var _order_button: Button = $TrackRow/OrderButton
@onready var _controls_button: Button = $ControlsButton
@onready var _controls_note: Label = $ControlsNote
@onready var _save_timer: Timer = $SaveTimer

## True while the controls are being filled in, so echoed values neither
## re-apply the setting nor start a save.
var _syncing: bool = false


func _ready() -> void:
	_save_timer.wait_time = SAVE_DEBOUNCE_SECONDS
	_save_timer.one_shot = true
	_save_timer.timeout.connect(_flush_settings)
	_master_slider.value_changed.connect(_on_master_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_sfx_slider.drag_ended.connect(_on_sfx_drag_ended)
	_mute_check.toggled.connect(_on_mute_toggled)
	_motion_check.toggled.connect(_on_motion_toggled)
	_auto_fire_check.toggled.connect(_on_auto_fire_toggled)
	_contrast_check.toggled.connect(_on_contrast_toggled)
	_scheme_button.pressed.connect(_on_scheme_pressed)
	_shield_mode_button.pressed.connect(_on_shield_mode_pressed)
	_controls_button.pressed.connect(controls_requested.emit)
	_prev_button.pressed.connect(_on_prev_track)
	_next_button.pressed.connect(_on_next_track)
	_order_button.pressed.connect(_on_order_pressed)
	AudioManager.track_changed.connect(_on_track_changed)
	AudioManager.music_order_changed.connect(_on_order_changed)
	AudioManager.settings_changed.connect(_sync_from_settings)
	_sync_from_settings()


func _sync_from_settings() -> void:
	_syncing = true
	_master_slider.value = SaveData.master_volume
	_music_slider.value = SaveData.music_volume
	_sfx_slider.value = SaveData.sfx_volume
	_mute_check.button_pressed = SaveData.muted
	_motion_check.button_pressed = SaveData.reduce_motion
	_auto_fire_check.button_pressed = SaveData.auto_fire
	_contrast_check.button_pressed = SaveData.high_contrast_bullets
	# The help line always shows the scheme and the keys bound right now.
	_refresh_controls_note()
	_refresh_music()
	_syncing = false


func _refresh_controls_note() -> void:
	_scheme_button.text = "SCHEME: %s" % Controls.scheme_label()
	_shield_mode_button.text = "SHIELD: %s" % String(SaveData.shield_mode).to_upper()
	_controls_note.text = Controls.help_text()


func _on_shield_mode_pressed() -> void:
	SaveData.shield_mode = (
		Tuning.SHIELD_MODE_AUTO if SaveData.shield_mode == Tuning.SHIELD_MODE_MANUAL \
			else Tuning.SHIELD_MODE_MANUAL
	)
	SaveData.save_data()
	AudioManager.play_sfx("ui_click")
	_refresh_controls_note()


## Switching to CLASSIC also turns the manual bubble on, since that scheme has
## no mouse aim to dodge with; the player can still change it back.
func _on_scheme_pressed() -> void:
	var classic: bool = SaveData.control_scheme != Tuning.CONTROL_SCHEME_CLASSIC
	SaveData.control_scheme = (
		Tuning.CONTROL_SCHEME_CLASSIC if classic else Tuning.CONTROL_SCHEME_FREE
	)
	SaveData.shield_mode = (
		Tuning.SHIELD_MODE_MANUAL if classic else Tuning.SHIELD_MODE_AUTO
	)
	SaveData.save_data()
	AudioManager.play_sfx("ui_click")
	_refresh_controls_note()


## NOW PLAYING, the skip buttons and the shuffle/order toggle. The track name
## is the file name AudioManager reports, without its extension.
func _refresh_music() -> void:
	var track: String = AudioManager.current_track_name()
	_now_playing.text = "NOW PLAYING: %s" % (track if not track.is_empty() else "NONE")
	_now_playing.add_theme_color_override(
		"font_color", UITheme.COLOR_TEXT if not track.is_empty() else UITheme.COLOR_MUTED
	)
	var has_tracks: bool = AudioManager.track_count() > 0
	_prev_button.disabled = not has_tracks
	_next_button.disabled = not has_tracks
	_order_button.disabled = not has_tracks
	_order_button.text = (
		"SHUFFLE" if SaveData.music_order == Tuning.MUSIC_ORDER_SHUFFLE else "IN ORDER"
	)


func _on_track_changed(_track: String) -> void:
	_refresh_music()


func _on_order_changed(_order: StringName) -> void:
	_refresh_music()


func _on_prev_track() -> void:
	AudioManager.previous_track()
	AudioManager.play_sfx("ui_click")


func _on_next_track() -> void:
	AudioManager.next_track()
	AudioManager.play_sfx("ui_click")


func _on_order_pressed() -> void:
	AudioManager.toggle_music_order()
	SaveData.music_order = AudioManager.music_order()
	AudioManager.play_sfx("ui_click")
	_save_timer.start()


func _on_master_changed(value: float) -> void:
	if _syncing:
		return
	SaveData.master_volume = value
	AudioManager.set_bus_volume(AudioManager.MASTER_BUS, value)
	_save_timer.start()


func _on_music_changed(value: float) -> void:
	if _syncing:
		return
	SaveData.music_volume = value
	AudioManager.set_bus_volume(AudioManager.MUSIC_BUS, value)
	_save_timer.start()


func _on_sfx_changed(value: float) -> void:
	if _syncing:
		return
	SaveData.sfx_volume = value
	AudioManager.set_bus_volume(AudioManager.SFX_BUS, value)
	_save_timer.start()


## The sample plays on release, at the level the slider was just set to, so the
## change is audible without waiting for a battle sound.
func _on_sfx_drag_ended(value_changed: bool) -> void:
	if value_changed:
		AudioManager.play_sfx("ui_click")


func _on_mute_toggled(enabled: bool) -> void:
	if _syncing:
		return
	SaveData.muted = enabled
	AudioManager.set_mute(enabled)
	_save_timer.start()


func _on_motion_toggled(enabled: bool) -> void:
	if _syncing:
		return
	SaveData.reduce_motion = enabled
	_save_timer.start()


func _on_auto_fire_toggled(enabled: bool) -> void:
	if _syncing:
		return
	SaveData.auto_fire = enabled
	_save_timer.start()


func _on_contrast_toggled(enabled: bool) -> void:
	if _syncing:
		return
	SaveData.high_contrast_bullets = enabled
	_save_timer.start()


func _flush_settings() -> void:
	SaveData.save_data()
