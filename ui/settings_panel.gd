class_name SettingsPanel
extends VBoxContainer
## Audio and motion settings block, instanced on both the main menu and the
## pause panel. It writes straight through to AudioManager and SaveData
## (global services) and holds no game state.
##
## Two instances exist at once, so they resync from AudioManager's
## `settings_changed` signal instead of reading each other. Slider changes are
## saved on a short debounce so dragging does not hit the disk every frame.

const SAVE_DEBOUNCE_SECONDS: float = 0.4

@onready var _music_slider: HSlider = $MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $SfxRow/SfxSlider
@onready var _mute_check: CheckButton = $MuteCheck
@onready var _motion_check: CheckButton = $MotionCheck
@onready var _save_timer: Timer = $SaveTimer

## True while the controls are being filled in, so echoed values neither
## re-apply the setting nor start a save.
var _syncing: bool = false


func _ready() -> void:
	_save_timer.wait_time = SAVE_DEBOUNCE_SECONDS
	_save_timer.one_shot = true
	_save_timer.timeout.connect(_flush_settings)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_sfx_slider.drag_ended.connect(_on_sfx_drag_ended)
	_mute_check.toggled.connect(_on_mute_toggled)
	_motion_check.toggled.connect(_on_motion_toggled)
	AudioManager.settings_changed.connect(_sync_from_settings)
	_sync_from_settings()


func _sync_from_settings() -> void:
	_syncing = true
	_music_slider.value = SaveData.music_volume
	_sfx_slider.value = SaveData.sfx_volume
	_mute_check.button_pressed = SaveData.muted
	_motion_check.button_pressed = SaveData.reduce_motion
	_syncing = false


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


func _flush_settings() -> void:
	SaveData.save_data()
