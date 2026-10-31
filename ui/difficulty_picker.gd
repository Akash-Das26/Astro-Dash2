class_name DifficultyPicker
extends CanvasLayer
## The five-mode picker, shown before a campaign starts. It lives on its own
## layer with PROCESS_MODE_ALWAYS so it works on the menu, over the map and on
## top of a paused battle. SINGULARITY asks once more before it is chosen.
##
## It only emits the choice; the screen that opened it decides what a new
## campaign means there.

signal chosen(difficulty: StringName)
signal closed

const OPTION_IDS: Array[StringName] = Tuning.DIFFICULTY_ORDER
const OPTION_PATHS: Array[String] = [
	"Root/Panel/Margin/Box/Options/Cadet",
	"Root/Panel/Margin/Box/Options/Vector",
	"Root/Panel/Margin/Box/Options/Supernova",
	"Root/Panel/Margin/Box/Options/EventHorizon",
	"Root/Panel/Margin/Box/Options/Singularity",
]

@onready var _root: Control = $Root
@onready var _confirm_card: Control = $Root/ConfirmCard
@onready var _confirm_title: Label = $Root/ConfirmCard/Panel/Margin/Box/Title
@onready var _confirm_detail: Label = $Root/ConfirmCard/Panel/Margin/Box/Detail
@onready var _confirm_yes: Button = $Root/ConfirmCard/Panel/Margin/Box/Buttons/ConfirmButton
@onready var _confirm_no: Button = $Root/ConfirmCard/Panel/Margin/Box/Buttons/CancelButton

var _buttons: Array[Button] = []
var _pending: StringName = &""
var _open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.apply(_root)
	_confirm_card.visible = false
	_root.visible = false
	for index: int in OPTION_PATHS.size():
		var button := get_node(OPTION_PATHS[index]) as Button
		var id: StringName = OPTION_IDS[index]
		# Names only: the rules live in the README and the help card.
		button.text = Difficulty.title(id)
		button.add_theme_color_override("font_color", Difficulty.color(id))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_focus_color", Color.WHITE)
		button.pressed.connect(_on_option.bind(id))
		_buttons.append(button)
	_confirm_yes.pressed.connect(_on_confirm)
	_confirm_no.pressed.connect(_on_cancel_confirm)


func picker_open() -> bool:
	return _open


func open() -> void:
	_open = true
	_pending = &""
	_confirm_card.visible = false
	_root.visible = true
	_buttons[0].grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	_confirm_card.visible = false
	_pending = &""
	closed.emit()


func _on_option(id: StringName) -> void:
	if id == Tuning.DIFFICULTY_SINGULARITY:
		_pending = id
		_confirm_title.text = "DEATH WIPES EVERYTHING"
		_confirm_detail.text = (
			"A defeat resets the campaign, banked energy, upgrade levels and\n"
			+ "every owned weapon. Settings, keys, high scores and skins stay.\n"
			+ "The run itself also heals almost nothing."
		)
		_confirm_card.visible = true
		_confirm_yes.grab_focus()
		return
	_choose(id)


func _on_confirm() -> void:
	if _pending == &"":
		return
	_choose(_pending)


func _on_cancel_confirm() -> void:
	_pending = &""
	_confirm_card.visible = false
	_buttons[Tuning.DIFFICULTY_ORDER.find(Tuning.DIFFICULTY_SINGULARITY)].grab_focus()


func _choose(id: StringName) -> void:
	_open = false
	_root.visible = false
	_confirm_card.visible = false
	_pending = &""
	chosen.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		return
	if _confirm_card.visible:
		_on_cancel_confirm()
	else:
		close()
	get_viewport().set_input_as_handled()
