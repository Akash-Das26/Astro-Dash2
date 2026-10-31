class_name MapBody
extends Node2D
## One body on the galaxy map: its sprite, the green glow and arrow when it can
## be attacked, a check badge once it is conquered, and a focus ring for the
## keyboard / gamepad cursor.
##
## The marker only draws and animates. The map decides what is conquered and
## what is attackable and pushes that in through set_state().

const WARP_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/warpgate_1.png"),
	preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/warpgate_2.png"),
	preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/warpgate_3.png"),
]
const WARP_SCALES: Dictionary = {&"home": 0.52, &"gate": 0.44}
const WARP_FPS: float = 9.0
const CHECK_OFFSET: Vector2 = Vector2(26.0, -26.0)
const CHECK_RADIUS: float = 10.0

var id: StringName = &""
var data: Dictionary = {}
var conquered: bool = false
var attackable: bool = false
var focused: bool = false

var _art: Node2D
var _tint: Color = Color.WHITE
var _radius: float = 32.0
var _phase: float = 0.0


## Called before the marker enters the tree.
func setup(body_id: StringName, body_data: Dictionary) -> void:
	id = body_id
	data = body_data
	position = body_data.get("pos", Vector2.ZERO)


func _ready() -> void:
	_tint = data.get("tint", Color.WHITE)
	_build_art()
	_apply_state_colors()


func _build_art() -> void:
	var kind: StringName = data.get("type", &"minor")
	if kind == &"home" or kind == &"gate":
		var warp := AnimatedSprite2D.new()
		warp.name = "Warp"
		warp.sprite_frames = _warp_frames()
		warp.animation = &"warp"
		warp.play()
		warp.scale = Vector2.ONE * float(WARP_SCALES.get(kind, 0.44))
		add_child(warp)
		_art = warp
		_radius = 200.0 * warp.scale.x * 0.46
		return
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	var art: Array = Tuning.GALAXY_BODY_ART.get(kind, Tuning.GALAXY_BODY_ART[&"minor"])
	var index: int = clampi(int(data.get("art", 0)), 0, art.size() - 1)
	var row: Dictionary = art[index]
	sprite.texture = row["texture"]
	var draw_scale: float = float(row["scale"])
	sprite.scale = Vector2.ONE * draw_scale
	add_child(sprite)
	_art = sprite
	var art_size: Vector2 = (row["texture"] as Texture2D).get_size()
	_radius = maxf(art_size.x, art_size.y) * draw_scale * 0.46


## Greener once conquered, dimmer while locked, unchanged while attackable.
func set_state(conquered_now: bool, attackable_now: bool, focused_now: bool) -> void:
	conquered = conquered_now
	attackable = attackable_now
	focused = focused_now
	_apply_state_colors()
	queue_redraw()


func _apply_state_colors() -> void:
	if _art == null:
		return
	var color: Color = _tint
	if conquered:
		color = _tint.lerp(Tuning.MAP_CONQUERED_TINT, 0.45)
	elif not attackable:
		color = _tint.darkened(Tuning.MAP_LOCKED_DARKEN)
	if _art is AnimatedSprite2D:
		(_art as AnimatedSprite2D).modulate = color
	else:
		(_art as Sprite2D).modulate = color


func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()


func _draw() -> void:
	if conquered:
		draw_circle(Vector2.ZERO, _radius + 5.0, Color(0.3, 1.0, 0.55, 0.10))
	if attackable:
		var pulse: float = 0.5 + 0.5 * sin(_phase * Tuning.MAP_GLOW_PULSE)
		var ring: float = _radius + 8.0 + 3.0 * pulse
		draw_circle(
			Vector2.ZERO,
			ring,
			Color(0.35, 1.0, 0.5, 0.06 + 0.06 * pulse)
		)
		draw_arc(
			Vector2.ZERO,
			ring,
			0.0,
			TAU,
			40,
			Color(0.42, 1.0, 0.58, 0.45 + 0.35 * pulse),
			2.0,
			true
		)
		_draw_arrow()
	if focused:
		draw_arc(
			Vector2.ZERO,
			_radius + 15.0,
			0.0,
			TAU,
			44,
			Tuning.MAP_FOCUS_COLOR,
			2.0,
			true
		)
	if conquered:
		_draw_check()


func _draw_arrow() -> void:
	var lift: float = _radius + 20.0 + sin(_phase * Tuning.MAP_ARROW_SPEED) * 6.0
	var tip := Vector2(0.0, -lift)
	draw_colored_polygon(
		PackedVector2Array([
			tip,
			tip + Vector2(-9.0, -13.0),
			tip + Vector2(9.0, -13.0),
		]),
		Color(0.5, 1.0, 0.6, 0.95)
	)


func _draw_check() -> void:
	draw_circle(CHECK_OFFSET, CHECK_RADIUS, Color(0.07, 0.28, 0.16, 0.95))
	draw_arc(
		CHECK_OFFSET,
		CHECK_RADIUS,
		0.0,
		TAU,
		18,
		Color(0.45, 1.0, 0.65, 0.9),
		1.5,
		true
	)
	var tick := PackedVector2Array([
		CHECK_OFFSET + Vector2(-4.0, 0.0),
		CHECK_OFFSET + Vector2(-1.0, 4.0),
		CHECK_OFFSET + Vector2(5.0, -4.0),
	])
	draw_polyline(tick, Color(0.7, 1.0, 0.8), 2.0)


func _warp_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"warp")
	frames.set_animation_speed(&"warp", WARP_FPS)
	frames.set_animation_loop(&"warp", true)
	for texture: Texture2D in WARP_FRAMES:
		frames.add_frame(&"warp", texture)
	return frames
