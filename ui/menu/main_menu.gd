class_name MainMenu
extends Control
## The front end. It owns no run state: NEW GAME asks Campaign for a fresh
## galaxy, CONTINUE only appears when a run is saved, and the settings card is
## the same panel the pause menu uses.
##
## GameState pauses the tree on MENU, so this root runs with PROCESS_MODE_ALWAYS
## and the backdrop keeps moving behind the buttons.

const GALAXY_SCENE: String = "res://ui/map/galaxy_map.tscn"

@onready var _new_game: Button = $Buttons/NewGame
@onready var _continue_button: Button = $Buttons/Continue
@onready var _settings_button: Button = $Buttons/Settings
@onready var _quit_button: Button = $Buttons/Quit
@onready var _footer: Label = $Footer
@onready var _settings_card: Control = $SettingsCard
@onready var _settings_close: Button = $SettingsCard/Panel/Margin/Box/Header/CloseButton
@onready var _settings_panel: SettingsPanel = $SettingsCard/Panel/Margin/Box/SettingsPanel
@onready var _controls_card: ControlsCard = $ControlsCard
@onready var _confirm_card: Control = $ConfirmCard
@onready var _confirm_start: Button = $ConfirmCard/Panel/Margin/Box/Buttons/StartButton
@onready var _confirm_cancel: Button = $ConfirmCard/Panel/Margin/Box/Buttons/CancelButton
@onready var _difficulty_picker: DifficultyPicker = $DifficultyPicker
@onready var _credits_button: Button = $Buttons/Credits
@onready var _credits_card: CreditsCard = $CreditsCard


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.apply(self)
	GameState.change_state(GameState.State.MENU)
	GameState.back_handler = _handle_back
	_settings_card.visible = false
	_confirm_card.visible = false
	_new_game.pressed.connect(_on_new_game)
	_continue_button.pressed.connect(_on_continue)
	_settings_button.pressed.connect(_open_settings)
	_quit_button.pressed.connect(_quit)
	_settings_close.pressed.connect(_close_settings)
	_confirm_start.pressed.connect(_on_confirm_new_run)
	_confirm_cancel.pressed.connect(_close_confirm)
	_difficulty_picker.chosen.connect(_on_difficulty_chosen)
	_difficulty_picker.closed.connect(_on_difficulty_closed)
	_credits_button.pressed.connect(_open_credits)
	_credits_card.closed.connect(_on_credits_closed)
	_settings_panel.controls_requested.connect(_open_controls)
	_controls_card.closed.connect(_on_controls_closed)
	_continue_button.disabled = not SaveData.campaign_active
	# The footer follows the mode of the campaign just played (or the next one).
	var mode: StringName = Difficulty.normalise(SaveData.campaign_difficulty)
	_footer.text = "ENERGY %d      BEST %d PLANETS      %s HIGH %d" % [
		SaveData.energy, SaveData.campaign_best_planets,
		Difficulty.title(mode), SaveData.high_score_for(mode),
	]
	_show_version()
	_new_game.grab_focus()


## The build number in the corner, small and out of the way. Built in code so
## the scene stays the same shape whatever the version is.
func _show_version() -> void:
	var label := Label.new()
	label.name = "Version"
	label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.78, 0.9))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	label.offset_left = -150.0
	label.offset_top = -26.0
	label.offset_right = -14.0
	label.offset_bottom = -8.0


func _on_new_game() -> void:
	# Starting over throws a run away, so an active campaign asks first.
	if SaveData.campaign_active:
		_confirm_card.visible = true
		_confirm_start.grab_focus()
		return
	_open_difficulty()


func _on_confirm_new_run() -> void:
	_confirm_card.visible = false
	_open_difficulty()


func _open_difficulty() -> void:
	_new_game.release_focus()
	_difficulty_picker.open()


func _on_difficulty_chosen(difficulty: StringName) -> void:
	_start_new_run(difficulty)


func _on_difficulty_closed() -> void:
	_new_game.grab_focus()


func _start_new_run(difficulty: StringName) -> void:
	Campaign.begin_run(difficulty)
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file(GALAXY_SCENE)


func _on_continue() -> void:
	if not SaveData.campaign_active:
		return
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file(GALAXY_SCENE)


func _open_settings() -> void:
	_settings_card.visible = true
	_settings_close.grab_focus()


func _close_settings() -> void:
	_settings_card.visible = false
	_settings_button.grab_focus()


func _close_confirm() -> void:
	_confirm_card.visible = false
	_new_game.grab_focus()


func _open_controls() -> void:
	_controls_card.open()


func _on_controls_closed() -> void:
	_settings_close.grab_focus()


func _open_credits() -> void:
	AudioManager.play_sfx("ui_click")
	_credits_card.open()


func _on_credits_closed() -> void:
	_credits_button.grab_focus()


func _quit() -> void:
	get_tree().quit()


## Back closes whatever overlay is open. On the bare menu it does nothing:
## quitting is the QUIT button's job, so a stray Back/Esc cannot drop the player
## out of the game.
func _handle_back() -> void:
	GameState.back_handler = _handle_back
	if _credits_card.visible:
		_credits_card.close()
		return
	if _difficulty_picker.picker_open():
		_difficulty_picker.close()
		return
	if _controls_card.visible:
		_controls_card.close()
		return
	if _settings_card.visible:
		_close_settings()
		return
	if _confirm_card.visible:
		_close_confirm()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	# Marked first: a NEW GAME confirmation can hand over to another scene.
	vp.set_input_as_handled()
	_handle_back()
