class_name TouchControls
extends Control
## Landscape touch controls. A virtual stick on the left half drives the
## move_up/down/left/right actions; a finger on the right half aims from the
## ship towards itself and holds `shoot`. Both only ever press the InputMap
## actions, so the ship never learns that touch exists.
##
## The stick is drawn with primitives and appears under the finger that owns it,
## which is why the left half can be used anywhere instead of one fixed spot.

signal pause_requested
signal aim_changed(direction: Vector2)

const STICK_RADIUS: float = 76.0
const KNOB_RADIUS: float = 30.0
const MIN_TOUCH_TARGET: float = 48.0
## Below this drag length the stick counts as centred.
const STICK_DEADZONE: float = 0.16
## A right-zone tap closer than this to the ship keeps the last aim.
const AIM_DEADZONE: float = 14.0

## The ship the right zone aims from; the HUD passes it in.
var aim_origin: Node2D

@onready var _pause_button: Button = $PauseButton
@onready var _alt_fire_button: Button = $AltFireButton

var _touch_seen: bool = false
var _move_index: int = -1
var _aim_index: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_vector: Vector2 = Vector2.ZERO
var _aim_point: Vector2 = Vector2.ZERO
var _aim_vector: Vector2 = Vector2.ZERO


func _ready() -> void:
	_pause_button.custom_minimum_size = Vector2(MIN_TOUCH_TARGET, MIN_TOUCH_TARGET)
	_pause_button.pressed.connect(_on_pause_pressed)
	# Second hardpoint: hold to fire the secondary weapon, exactly like the
	# right mouse button or the left trigger on a gamepad.
	_alt_fire_button.custom_minimum_size = Vector2(MIN_TOUCH_TARGET, MIN_TOUCH_TARGET)
	_alt_fire_button.button_down.connect(_on_alt_fire_down)
	_alt_fire_button.button_up.connect(_on_alt_fire_up)
	GameState.state_changed.connect(_on_state_changed)
	_touch_seen = DisplayServer.is_touchscreen_available()
	_refresh_visibility()


func _process(_delta: float) -> void:
	if _move_index >= 0 or _aim_index >= 0:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_note_touch()
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_touch(touch)
		else:
			_end_touch(touch)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _move_index:
			_update_stick(drag.position)
		elif drag.index == _aim_index:
			_update_aim(drag.position)


func _begin_touch(touch: InputEventScreenTouch) -> void:
	if not GameState.is_playing():
		return
	if _pause_button.visible and _pause_button.get_global_rect().has_point(touch.position):
		return
	if _alt_fire_button.visible and _alt_fire_button.get_global_rect().has_point(touch.position):
		return
	if touch.position.x < size.x * 0.5:
		if _move_index >= 0:
			return
		_move_index = touch.index
		_stick_origin = touch.position
		_update_stick(touch.position)
		return
	if _aim_index >= 0:
		return
	_aim_index = touch.index
	_update_aim(touch.position)
	Input.action_press("shoot")


func _end_touch(touch: InputEventScreenTouch) -> void:
	if touch.index == _move_index:
		_move_index = -1
		_stick_vector = Vector2.ZERO
		_stick_origin = Vector2.ZERO
		_apply_stick(Vector2.ZERO)
		queue_redraw()
	elif touch.index == _aim_index:
		_aim_index = -1
		_aim_vector = Vector2.ZERO
		aim_changed.emit(Vector2.ZERO)
		Input.action_release("shoot")
		queue_redraw()


func _update_stick(at: Vector2) -> void:
	var offset: Vector2 = at - _stick_origin
	_stick_vector = (offset / STICK_RADIUS).limit_length(1.0)
	_apply_stick(_stick_vector)
	queue_redraw()


## The right zone aims from the ship towards the finger, so a tap anywhere on
## that half points the nose there.
func _update_aim(at: Vector2) -> void:
	_aim_point = at
	if aim_origin == null or not is_instance_valid(aim_origin):
		return
	var origin: Vector2 = aim_origin.get_global_transform_with_canvas().origin
	var to_finger: Vector2 = at - origin
	if to_finger.length() < AIM_DEADZONE:
		_aim_vector = Vector2.ZERO
	else:
		_aim_vector = to_finger.normalized()
	aim_changed.emit(_aim_vector)
	queue_redraw()


## FREE AIM maps the stick to strafing; CLASSIC maps X to turn and Y to
## thrust/brake, exactly like the keyboard scheme.
func _apply_stick(vector: Vector2) -> void:
	if SaveData.control_scheme == Tuning.CONTROL_SCHEME_CLASSIC:
		_press_axis("turn_left", "turn_right", vector.x)
		Input.action_release("thrust")
		Input.action_release("brake")
		if vector.y < -STICK_DEADZONE:
			Input.action_press("thrust", absf(vector.y))
		elif vector.y > STICK_DEADZONE:
			Input.action_press("brake", vector.y)
		return
	_press_axis("move_left", "move_right", vector.x)
	_press_axis("move_up", "move_down", vector.y)


func _press_axis(negative: StringName, positive: StringName, value: float) -> void:
	var amount: float = absf(value)
	if amount <= STICK_DEADZONE:
		Input.action_release(negative)
		Input.action_release(positive)
		return
	if value < 0.0:
		Input.action_release(positive)
		Input.action_press(negative, amount)
	else:
		Input.action_release(negative)
		Input.action_press(positive, amount)


func _on_pause_pressed() -> void:
	pause_requested.emit()


func _on_alt_fire_down() -> void:
	Input.action_press("shoot_alt")


func _on_alt_fire_up() -> void:
	Input.action_release("shoot_alt")


func _on_state_changed(_new_state: int) -> void:
	_release_all()
	_refresh_visibility()


## Never leave an action stuck down when the battle pauses or restarts.
func _release_all() -> void:
	_move_index = -1
	_aim_index = -1
	_stick_vector = Vector2.ZERO
	_stick_origin = Vector2.ZERO
	_aim_vector = Vector2.ZERO
	_apply_stick(Vector2.ZERO)
	aim_changed.emit(Vector2.ZERO)
	Input.action_release("shoot")
	Input.action_release("shoot_alt")
	Input.action_release("turn_left")
	Input.action_release("turn_right")
	Input.action_release("thrust")
	Input.action_release("brake")
	queue_redraw()


func _note_touch() -> void:
	if _touch_seen:
		return
	_touch_seen = true
	_refresh_visibility()


func _refresh_visibility() -> void:
	var playing: bool = _touch_seen and GameState.is_playing()
	_pause_button.visible = playing
	_alt_fire_button.visible = playing


func _draw() -> void:
	if _move_index >= 0:
		var knob: Vector2 = _stick_origin + _stick_vector * STICK_RADIUS
		draw_circle(_stick_origin, STICK_RADIUS, Color(0.6, 0.8, 1.0, 0.10))
		draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 32, Color(0.7, 0.9, 1.0, 0.5), 2.0, true)
		draw_circle(knob, KNOB_RADIUS, Color(0.75, 0.9, 1.0, 0.30))
		draw_arc(knob, KNOB_RADIUS, 0.0, TAU, 24, Color(0.85, 0.95, 1.0, 0.75), 2.0, true)
	if _aim_index >= 0:
		draw_arc(_aim_point, 26.0, 0.0, TAU, 24, Color(1.0, 0.55, 0.45, 0.8), 2.0, true)
		draw_circle(_aim_point, 4.0, Color(1.0, 0.7, 0.5, 0.9))
