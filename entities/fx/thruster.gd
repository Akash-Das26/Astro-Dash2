class_name Thruster
extends AnimatedSprite2D
## Five-frame exhaust flame, shared by the player ship and every fighter. The
## sprite sits behind the hull and points the other way, so a parent that turns
## onto its heading turns the flame with it.
##
## The owner only reports how hard it is thrusting (0..1): the flame then grows,
## brightens and animates faster, and disappears below the idle threshold.

const FRAMES: Array[Texture2D] = [
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/thruster-1.png"),
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/thruster-2.png"),
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/thruster-3.png"),
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/thruster-4.png"),
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/thruster-5.png"),
]

var _thrust: float = 0.0
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_base_scale = scale
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"burn")
	frames.set_animation_speed(&"burn", Tuning.THRUSTER_FRAME_FPS)
	frames.set_animation_loop(&"burn", true)
	for texture: Texture2D in FRAMES:
		frames.add_frame(&"burn", texture)
	sprite_frames = frames
	animation = &"burn"
	play(&"burn")
	_apply()


## Per-fighter flame size. Kept separate from `scale` so the thrust lerp can
## own that property without losing the size a big hull wants.
func set_base_scale(value: Vector2) -> void:
	_base_scale = value
	if is_inside_tree():
		_apply()


## 0 = idle, 1 = full speed.
func set_thrust(value: float) -> void:
	_thrust = clampf(value, 0.0, 1.0)
	if is_inside_tree():
		_apply()


func thrust() -> float:
	return _thrust


func _apply() -> void:
	visible = _thrust > Tuning.THRUSTER_MIN_VISIBLE
	if not visible:
		return
	var amount: float = lerpf(Tuning.THRUSTER_IDLE_SCALE, Tuning.THRUSTER_FULL_SCALE, _thrust)
	scale = _base_scale * amount
	modulate.a = 0.55 + 0.45 * _thrust
	speed_scale = 0.7 + 0.7 * _thrust
