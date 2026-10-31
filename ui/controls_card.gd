class_name ControlsCard
extends Control
## The CONTROLS screen: one row per action, a KEYBOARD/MOUSE cell, a GAMEPAD
## cell and a per-action reset. Selecting a cell waits for the next input and
## writes it through Controls, which owns the InputMap and the save.
##
## It runs while the tree is paused (the pause card opens it), and Esc both
## cancels a capture and closes the card. Every row is a focusable Button, so
## the whole screen works with keyboard and gamepad navigation.

signal closed

const CELL_HEIGHT: float = 36.0
const NAME_WIDTH: float = 180.0
const RESET_WIDTH: float = 40.0
## How far a stick or trigger has to move before it counts as a binding.
const AXIS_CAPTURE_THRESHOLD: float = 0.6

@onready var _close_button: Button = $Panel/Margin/Box/Header/CloseButton
@onready var _rows: VBoxContainer = $Panel/Margin/Box/Scroll/Rows
@onready var _reset_all: Button = $Panel/Margin/Box/Footer/ResetAll
@onready var _status: Label = $Panel/Margin/Box/Footer/Status

var _key_buttons: Dictionary = {}
var _pad_buttons: Dictionary = {}
var _reset_buttons: Dictionary = {}
## Action being rebound, and which column, while a capture is running.
var _capture_action: StringName = &""
var _capture_gamepad: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close_button.pressed.connect(close)
	_reset_all.pressed.connect(_on_reset_all)
	_build_rows()
	_refresh()


func open() -> void:
	visible = true
	_capture_action = &""
	_status.text = ""
	# The scheme may have changed since the card was built, and each scheme
	# lists a different set of actions.
	_build_rows()
	_refresh()
	AudioManager.play_sfx("ui_click")
	var first: Button = _key_buttons.get(Controls.actions()[0]) as Button
	if first != null:
		first.grab_focus()


func close() -> void:
	if not visible:
		return
	_capture_action = &""
	visible = false
	AudioManager.play_sfx("ui_click")
	closed.emit()


func _build_rows() -> void:
	_key_buttons.clear()
	_pad_buttons.clear()
	_reset_buttons.clear()
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for action: StringName in Controls.actions():
		var row := HBoxContainer.new()
		row.name = "Row_%s" % String(action)
		row.add_theme_constant_override("separation", 8)
		_rows.add_child(row)
		var name_label := Label.new()
		name_label.text = Controls.label(action)
		name_label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		row.add_child(name_label)
		var key_button := _make_cell("KEYBOARD / MOUSE")
		row.add_child(key_button)
		key_button.pressed.connect(_on_cell_pressed.bind(action, false))
		var pad_button := _make_cell("GAMEPAD")
		row.add_child(pad_button)
		pad_button.pressed.connect(_on_cell_pressed.bind(action, true))
		var reset_button := Button.new()
		reset_button.name = "Reset_%s" % String(action)
		reset_button.text = "R"
		reset_button.custom_minimum_size = Vector2(RESET_WIDTH, CELL_HEIGHT)
		reset_button.add_theme_font_size_override("font_size", 12)
		reset_button.tooltip_text = "RESET %s" % Controls.label(action)
		reset_button.pressed.connect(_on_reset_pressed.bind(action))
		row.add_child(reset_button)
		_key_buttons[action] = key_button
		_pad_buttons[action] = pad_button
		_reset_buttons[action] = reset_button


func _make_cell(column_name: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, CELL_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	button.clip_text = true
	button.tooltip_text = "%s BINDING" % column_name
	return button


func _refresh() -> void:
	for action: StringName in Controls.actions():
		var key_button: Button = _key_buttons[action]
		var pad_button: Button = _pad_buttons[action]
		var reset_button: Button = _reset_buttons[action]
		var fixed: bool = Controls.is_fixed(action)
		reset_button.disabled = fixed
		if fixed:
			key_button.text = "ESC (FIXED)"
			pad_button.text = "START (FIXED)"
			key_button.disabled = true
			pad_button.disabled = true
			continue
		key_button.disabled = false
		pad_button.disabled = false
		if _capture_action == action and not _capture_gamepad:
			key_button.text = "PRESS A KEY..."
		else:
			key_button.text = Controls.binding_text(action, false)
		if _capture_action == action and _capture_gamepad:
			pad_button.text = "PRESS A BUTTON..."
		else:
			pad_button.text = Controls.binding_text(action, true)


func _on_cell_pressed(action: StringName, gamepad: bool) -> void:
	if Controls.is_fixed(action):
		return
	_capture_action = action
	_capture_gamepad = gamepad
	_status.text = "PRESS THE NEW %s FOR %s. ESC CANCELS." % [
		"GAMEPAD INPUT" if gamepad else "KEY", Controls.label(action),
	]
	AudioManager.play_sfx("ui_click")
	_refresh()


func _on_reset_pressed(action: StringName) -> void:
	if Controls.is_fixed(action):
		return
	Controls.reset_action(action)
	_refresh()
	_status.text = "%s RESET TO DEFAULT" % Controls.label(action)
	AudioManager.play_sfx("ui_click")


func _on_reset_all() -> void:
	Controls.reset_all()
	_refresh()
	_status.text = "ALL BINDINGS RESET TO DEFAULT"
	AudioManager.play_sfx("ui_click")


## Capture runs in `_input` so it sees the raw event before any button or the
## game state machine consumes it.
func _input(event: InputEvent) -> void:
	if not visible or _capture_action == &"":
		return
	var is_gamepad_event: bool = event is InputEventJoypadButton \
		or event is InputEventJoypadMotion
	if is_gamepad_event != _capture_gamepad:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.physical_keycode == KEY_ESCAPE:
			_cancel_capture()
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseButton:
		if not (event as InputEventMouseButton).pressed:
			return
	elif event is InputEventJoypadButton:
		if not (event as InputEventJoypadButton).pressed:
			return
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) < AXIS_CAPTURE_THRESHOLD:
			return
	else:
		return
	var clean := Controls.sanitize(event)
	if clean == null:
		return
	var action: StringName = _capture_action
	var note: String = Controls.bind(action, _capture_gamepad, clean)
	_capture_action = &""
	_refresh()
	if note.is_empty():
		_status.text = "%s SET TO %s" % [Controls.label(action), Controls.describe(clean)]
	else:
		_status.text = note
	AudioManager.play_sfx("ui_click")
	get_viewport().set_input_as_handled()


func _cancel_capture() -> void:
	_capture_action = &""
	_refresh()
	_status.text = "CAPTURE CANCELLED"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
