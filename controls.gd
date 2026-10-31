class_name Controls
extends RefCounted
## Key and gamepad remapping, applied to the engine's InputMap.
##
## Every screen keeps reading the same actions (`move_up`, `shoot`, ...); this
## helper only swaps which physical inputs they are wired to. Bindings persist
## in SaveData as serialized events, and the project's own bindings are captured
## once at startup so RESET can always put them back.
##
## `pause` is deliberately fixed: Esc is the menu key, and a remap that could
## take it away would be able to lock the player out of every screen.

## Captured from the InputMap before any override, so a reset is always possible.
static var _defaults: Dictionary = {}
static var _defaults_ready: bool = false


static func actions() -> Array[StringName]:
	return Tuning.CONTROL_ACTIONS.duplicate()


static func is_fixed(action: StringName) -> bool:
	return Tuning.CONTROL_FIXED.has(action)


static func label(action: StringName) -> String:
	return String(Tuning.CONTROL_LABELS.get(action, String(action).to_upper()))


## Must run once, before any saved binding is applied.
static func ensure_defaults() -> void:
	if _defaults_ready:
		return
	_defaults_ready = true
	for action: StringName in Tuning.CONTROL_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var events: Array[InputEvent] = []
		for event: InputEvent in InputMap.action_get_events(action):
			events.append(event)
		_defaults[action] = events


## Rebuilds every rebindable action from the save. Called once at startup.
static func apply_saved() -> void:
	ensure_defaults()
	for action: StringName in Tuning.CONTROL_ACTIONS:
		if is_fixed(action):
			continue
		_rebuild(action)


## The text shown in a binding cell. Falls back to the project's own first
## binding of that kind, and to UNBOUND when the action has none.
static func binding_text(action: StringName, gamepad: bool) -> String:
	ensure_defaults()
	var column: Dictionary = SaveData.gamepad_bindings if gamepad else SaveData.keyboard_bindings
	var stored: String = String(column.get(action, ""))
	if not stored.is_empty():
		var event := str_to_var(stored) as InputEvent
		if event != null:
			return describe(event)
	for event: InputEvent in _defaults.get(action, []):
		if _is_gamepad(event) == gamepad:
			return describe(event)
	return "UNBOUND"


## Binds one captured event to one column of an action. Any other action that
## was using the same input loses it (a swap), and the note says whose it was.
static func bind(action: StringName, gamepad: bool, event: InputEvent) -> String:
	ensure_defaults()
	if is_fixed(action) or event == null:
		return ""
	var stored: Dictionary = SaveData.gamepad_bindings if gamepad else SaveData.keyboard_bindings
	stored[action] = var_to_str(event)
	var note: String = ""
	for other: StringName in Tuning.CONTROL_ACTIONS:
		if other == action:
			continue
		var other_stored: Dictionary = (
			SaveData.gamepad_bindings if gamepad else SaveData.keyboard_bindings
		)
		if not String(other_stored.get(other, "")).is_empty():
			var other_event := str_to_var(String(other_stored[other])) as InputEvent
			if other_event != null and _same_binding(other_event, event) and not is_fixed(other):
				other_stored.erase(other)
				note = "%s MOVED FROM %s" % [describe(event), label(other)]
		if is_fixed(other):
			continue
		if _strip_event(other, event):
			note = "%s MOVED FROM %s" % [describe(event), label(other)]
	_rebuild(action)
	SaveData.save_data()
	return note


static func reset_action(action: StringName) -> void:
	SaveData.keyboard_bindings.erase(action)
	SaveData.gamepad_bindings.erase(action)
	_rebuild(action)
	SaveData.save_data()


static func reset_all() -> void:
	SaveData.keyboard_bindings.clear()
	SaveData.gamepad_bindings.clear()
	for action: StringName in Tuning.CONTROL_ACTIONS:
		_rebuild(action)
	SaveData.save_data()


## Strips one binding from an action's live events. Returns true if it was there.
static func _strip_event(action: StringName, event: InputEvent) -> bool:
	if not InputMap.has_action(action):
		return false
	var kept: Array[InputEvent] = []
	var found: bool = false
	for existing: InputEvent in InputMap.action_get_events(action):
		if _same_binding(existing, event):
			found = true
			continue
		kept.append(existing)
	if not found:
		return false
	InputMap.action_erase_events(action)
	for existing: InputEvent in kept:
		InputMap.action_add_event(action, existing)
	return true


## Writes one action's InputMap events: untouched defaults for a column with no
## custom binding, the custom event where one was stored.
static func _rebuild(action: StringName) -> void:
	if not InputMap.has_action(action) or is_fixed(action):
		return
	var key_text: String = String(SaveData.keyboard_bindings.get(action, ""))
	var pad_text: String = String(SaveData.gamepad_bindings.get(action, ""))
	InputMap.action_erase_events(action)
	for event: InputEvent in _defaults.get(action, []):
		var custom: String = pad_text if _is_gamepad(event) else key_text
		if custom.is_empty():
			InputMap.action_add_event(action, event)
	if not key_text.is_empty():
		var key_event := str_to_var(key_text) as InputEvent
		if key_event != null:
			InputMap.action_add_event(action, key_event)
	if not pad_text.is_empty():
		var pad_event := str_to_var(pad_text) as InputEvent
		if pad_event != null:
			InputMap.action_add_event(action, pad_event)


## A short line for the settings card, showing the keys actually in use.
static func help_text() -> String:
	return "MOVE %s   |   FIRE %s   |   SECONDARY %s\nPAUSE %s (FIXED)   |   BACK %s   |   REMAP IN CONTROLS" % [
		binding_text(&"move_up", false),
		binding_text(&"shoot", false),
		binding_text(&"shoot_alt", false),
		binding_text(&"pause", false),
		"ESC / B",
	]


# --- Event helpers ----------------------------------------------------------

static func _is_gamepad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


## A clean copy holding only the binding itself: no modifiers, no click
## position, no half-pushed trigger value.
static func sanitize(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key := event as InputEventKey
		var fresh := InputEventKey.new()
		fresh.physical_keycode = key.physical_keycode
		if fresh.physical_keycode == 0:
			fresh.physical_keycode = key.keycode
		return fresh if fresh.physical_keycode != 0 else null
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		var fresh_mouse := InputEventMouseButton.new()
		fresh_mouse.button_index = mouse.button_index
		return fresh_mouse
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		var fresh_button := InputEventJoypadButton.new()
		fresh_button.button_index = button.button_index
		return fresh_button
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var fresh_motion := InputEventJoypadMotion.new()
		fresh_motion.axis = motion.axis
		fresh_motion.axis_value = signf(motion.axis_value)
		return fresh_motion
	return null


static func _same_binding(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return (a as InputEventKey).physical_keycode == (b as InputEventKey).physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index \
			== (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return (a as InputEventJoypadMotion).axis == (b as InputEventJoypadMotion).axis \
			and signf((a as InputEventJoypadMotion).axis_value) \
			== signf((b as InputEventJoypadMotion).axis_value)
	return false


static func describe(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: int = (event as InputEventKey).physical_keycode
		if code == 0:
			code = (event as InputEventKey).keycode
		return OS.get_keycode_string(code).to_upper()
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "MOUSE LEFT"
			MOUSE_BUTTON_RIGHT:
				return "MOUSE RIGHT"
			MOUSE_BUTTON_MIDDLE:
				return "MOUSE MIDDLE"
			_:
				return "MOUSE %d" % int((event as InputEventMouseButton).button_index)
	if event is InputEventJoypadButton:
		return String(PAD_BUTTONS.get((event as InputEventJoypadButton).button_index, "PAD BTN"))
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var axis_name: String = String(PAD_AXES.get(motion.axis, "PAD AXIS"))
		return "%s %s" % [axis_name, "+" if motion.axis_value > 0.0 else "-"]
	return "UNKNOWN"


const PAD_BUTTONS: Dictionary = {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "BACK",
	JOY_BUTTON_START: "START",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-UP",
	JOY_BUTTON_DPAD_DOWN: "D-DOWN",
	JOY_BUTTON_DPAD_LEFT: "D-LEFT",
	JOY_BUTTON_DPAD_RIGHT: "D-RIGHT",
}

const PAD_AXES: Dictionary = {
	JOY_AXIS_LEFT_X: "L-STICK X",
	JOY_AXIS_LEFT_Y: "L-STICK Y",
	JOY_AXIS_RIGHT_X: "R-STICK X",
	JOY_AXIS_RIGHT_Y: "R-STICK Y",
	JOY_AXIS_TRIGGER_LEFT: "LT",
	JOY_AXIS_TRIGGER_RIGHT: "RT",
}
