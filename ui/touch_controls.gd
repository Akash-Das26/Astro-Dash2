class_name TouchControls
extends Control
## On-screen controls for touch devices. It only presses and releases the
## InputMap actions the keyboard and gamepad already use, so Player never
## learns that touch exists and gameplay stays in one place.
##
## Steering is relative: horizontal drag is banked and then spent at the ship's
## own speed, so the hull never jumps under the finger and the thumb can stay
## on the empty lower half instead of covering the ship. The whole layer only
## appears once a touchscreen (or a first touch event) is detected.

signal pause_requested

const MIN_TOUCH_TARGET: float = 48.0
## Drag pixels banked at most, so a fast flick cannot keep the ship moving for
## seconds after the finger lifted.
const MAX_PENDING_DRAG: float = 96.0

## Should match Player.move_speed: how fast banked drag is spent.
@export var follow_speed: float = 300.0
## Fraction of the screen height where the steering area begins.
@export var steer_zone_top: float = 0.5

@onready var _pause_button: Button = $PauseButton

var _touch_seen: bool = false
var _finger_index: int = -1
var _pending_drag: float = 0.0
var _applied_axis: float = 0.0
var _shooting: bool = false


func _ready() -> void:
	_pause_button.custom_minimum_size = Vector2(MIN_TOUCH_TARGET, MIN_TOUCH_TARGET)
	_pause_button.pressed.connect(_on_pause_pressed)
	GameState.state_changed.connect(_on_state_changed)
	_touch_seen = DisplayServer.is_touchscreen_available()
	_refresh_pause_button()


func _process(delta: float) -> void:
	if _finger_index < 0:
		return
	if _shooting and not SaveData.auto_fire:
		_stop_auto_fire()
	var max_step: float = follow_speed * delta
	if max_step <= 0.0 or is_zero_approx(_pending_drag):
		_apply_axis(0.0)
		return
	var step: float = clampf(_pending_drag, -max_step, max_step)
	_pending_drag -= step
	if absf(_pending_drag) < 0.001:
		_pending_drag = 0.0
	# Strength is the fraction of a full speed step, so a slow drag crawls.
	_apply_axis(step / max_step)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		_note_touch_device()
		if touch.pressed:
			_begin_steer(touch)
		else:
			_end_steer(touch)
	elif event is InputEventScreenDrag:
		_bank_drag(event as InputEventScreenDrag)


## Pauses only while a run is live; the pause panel owns the rest.
func _on_pause_pressed() -> void:
	pause_requested.emit()


func _on_state_changed(_new_state: int) -> void:
	_release_all()
	_refresh_pause_button()


func _note_touch_device() -> void:
	if _touch_seen:
		return
	_touch_seen = true
	_refresh_pause_button()


func _begin_steer(touch: InputEventScreenTouch) -> void:
	if _finger_index != -1 or not GameState.is_playing():
		return
	if not _is_in_steer_zone(touch.position) or _is_on_pause_button(touch.position):
		return
	_finger_index = touch.index
	_pending_drag = 0.0
	_start_auto_fire()


func _end_steer(touch: InputEventScreenTouch) -> void:
	if touch.index != _finger_index:
		return
	_finger_index = -1
	_pending_drag = 0.0
	_apply_axis(0.0)
	_stop_auto_fire()


func _bank_drag(drag: InputEventScreenDrag) -> void:
	if drag.index != _finger_index:
		return
	_pending_drag = clampf(_pending_drag + drag.relative.x, -MAX_PENDING_DRAG, MAX_PENDING_DRAG)


## Relative drag -> the move_left / move_right actions the ship already reads.
func _apply_axis(axis: float) -> void:
	if is_equal_approx(axis, _applied_axis):
		return
	_applied_axis = axis
	if axis > 0.0:
		Input.action_release("move_left")
		Input.action_press("move_right", axis)
	elif axis < 0.0:
		Input.action_release("move_right")
		Input.action_press("move_left", -axis)
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")


func _start_auto_fire() -> void:
	if _shooting or not SaveData.auto_fire:
		return
	_shooting = true
	Input.action_press("shoot")


func _stop_auto_fire() -> void:
	if not _shooting:
		return
	_shooting = false
	Input.action_release("shoot")


## Never leave an action stuck down when the run stops or the app is paused.
func _release_all() -> void:
	_finger_index = -1
	_pending_drag = 0.0
	_apply_axis(0.0)
	_stop_auto_fire()


func _refresh_pause_button() -> void:
	_pause_button.visible = _touch_seen and GameState.is_playing()


func _is_in_steer_zone(at: Vector2) -> bool:
	return at.y >= size.y * steer_zone_top


func _is_on_pause_button(at: Vector2) -> bool:
	return _pause_button.visible and _pause_button.get_global_rect().has_point(at)
