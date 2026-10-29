class_name CampaignMap
extends CanvasLayer
## The campaign hub screen. It reads the conquered sectors from SaveData, tells
## the view what to draw, and turns a tap (or the arrow keys plus accept) into a
## confirmation card and then a `battle_requested` for the manager. It changes
## no game data itself.
##
## CanvasLayer + process_mode Always so it keeps working while the tree is
## paused in the MAP state.

signal battle_requested(sector_id: StringName)

@onready var _view: CampaignMapView = $Root/MapView
@onready var _energy_label: Label = $Root/TopBar/EnergyLabel
@onready var _planets_label: Label = $Root/TopBar/PlanetsLabel
@onready var _lives_label: Label = $Root/TopBar/LivesLabel
@onready var _confirm: Control = $Root/ConfirmCard
@onready var _confirm_title: Label = $Root/ConfirmCard/Box/Title
@onready var _confirm_detail: Label = $Root/ConfirmCard/Box/Detail
@onready var _confirm_note: Label = $Root/ConfirmCard/Box/Note
@onready var _battle_button: Button = $Root/ConfirmCard/Box/BattleButton
@onready var _cancel_button: Button = $Root/ConfirmCard/Box/CancelButton

var _available: Array[StringName] = []
var _selected: StringName = &""


func _ready() -> void:
	visible = false
	_view.sector_tapped.connect(_on_sector_tapped)
	_battle_button.pressed.connect(_on_battle_pressed)
	_cancel_button.pressed.connect(_close_confirm)
	_confirm.visible = false


func show_map() -> void:
	_close_confirm()
	visible = true
	_refresh()
	_select(_available[0] if not _available.is_empty() else &"")


func hide_map() -> void:
	_close_confirm()
	visible = false


func is_confirm_open() -> bool:
	return _confirm.visible


func _refresh() -> void:
	_available = Campaign.available_ids(SaveData.campaign_conquered)
	_energy_label.text = "ENERGY %d" % SaveData.energy
	_lives_label.text = "LIVES %d" % SaveData.campaign_lives
	_planets_label.text = "PLANETS %d/%d" % [SaveData.campaign_conquered.size(), Campaign.total_sectors()]
	_view.set_sectors(_available, SaveData.campaign_conquered, _selected)


func _select(sector_id: StringName) -> void:
	_selected = sector_id
	_view.set_selection(sector_id)


func _on_sector_tapped(sector_id: StringName) -> void:
	if not _available.has(sector_id):
		return
	_select(sector_id)
	AudioManager.play_sfx("ui_click")
	_open_confirm(sector_id)


## Arrow keys / d-pad cycle the sectors that can be attacked right now.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or GameState.state != GameState.State.MAP:
		return
	if _confirm.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_confirm()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_cycle(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_cycle(1)
	elif event.is_action_pressed("ui_accept") and _selected != &"":
		_open_confirm(_selected)
	else:
		return
	get_viewport().set_input_as_handled()


func _cycle(step: int) -> void:
	if _available.is_empty():
		return
	var index: int = maxi(_available.find(_selected), 0)
	index = wrapi(index + step, 0, _available.size())
	_select(_available[index])
	AudioManager.play_sfx("ui_click")


func _open_confirm(sector_id: StringName) -> void:
	var waves: int = Campaign.wave_count(sector_id)
	var boss_text: String = "BOSS" if Campaign.has_boss(sector_id) else "NO BOSS"
	_confirm_title.text = Campaign.title(sector_id)
	_confirm_detail.text = "TIER %d    %d WAVE%s    %s" % [
		Campaign.tier_of(sector_id), waves, "" if waves == 1 else "S", boss_text
	]
	_confirm_note.text = "+1 LIFE ON CLEAR" if Campaign.has_boss(sector_id) else "LIVES CARRY OVER"
	_confirm.visible = true
	_battle_button.grab_focus()
	GameState.back_handler = _close_confirm


func _close_confirm() -> void:
	GameState.back_handler = Callable()
	if not _confirm.visible:
		return
	_confirm.visible = false
	_battle_button.release_focus()


func _on_battle_pressed() -> void:
	if _selected == &"":
		return
	var sector_id: StringName = _selected
	_close_confirm()
	battle_requested.emit(sector_id)
