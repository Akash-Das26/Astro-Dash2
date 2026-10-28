class_name Pickup
extends Area2D
## Falling power-up. It only reports what it is; GameManager decides what the
## effect does. Layer 6 / mask 1: it notices the player hurtbox on its own.
## The icon is drawn with primitives, so it needs no art and no texture.

signal collected(kind: Kind)

enum Kind { RAPID_FIRE, SPREAD_SHOT, SHIELD, BOMB }

const PLAYER_LAYER_BIT: int = 1 << 0
const DESPAWN_Y: float = 620.0
const BODY_RADIUS: float = 13.0
const BODY_COLOR: Color = Color(0.04, 0.05, 0.12, 0.85)

const TINTS: Dictionary = {
	Kind.RAPID_FIRE: Color(1.0, 0.82, 0.25),
	Kind.SPREAD_SHOT: Color(0.45, 0.8, 1.0),
	Kind.SHIELD: Color(0.45, 1.0, 0.6),
	Kind.BOMB: Color(1.0, 0.45, 0.45),
}

@export var kind: Kind = Kind.RAPID_FIRE
@export var fall_speed: float = 55.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	position.y += fall_speed * delta
	if position.y > DESPAWN_Y:
		queue_free()


func _draw() -> void:
	var tint: Color = TINTS[kind]
	draw_circle(Vector2.ZERO, BODY_RADIUS, BODY_COLOR)
	draw_arc(Vector2.ZERO, BODY_RADIUS, 0.0, TAU, 20, tint, 2.0, true)
	match kind:
		Kind.RAPID_FIRE:
			_draw_rapid_icon(tint)
		Kind.SPREAD_SHOT:
			_draw_spread_icon(tint)
		Kind.SHIELD:
			_draw_shield_icon(tint)
		Kind.BOMB:
			_draw_bomb_icon(tint)


## Zig-zag bolt.
func _draw_rapid_icon(tint: Color) -> void:
	var bolt := PackedVector2Array([
		Vector2(2.0, -7.0),
		Vector2(-3.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(-2.0, 7.0),
	])
	draw_polyline(bolt, tint, 2.0)


## Three diverging shots.
func _draw_spread_icon(tint: Color) -> void:
	for offset_x: float in [-6.0, 0.0, 6.0]:
		draw_line(Vector2(0.0, -5.0), Vector2(offset_x, 6.0), tint, 2.0)


## Ring with a core.
func _draw_shield_icon(tint: Color) -> void:
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 16, tint, 2.0, true)
	draw_circle(Vector2.ZERO, 2.5, tint)


## Ball with a fuse.
func _draw_bomb_icon(tint: Color) -> void:
	draw_circle(Vector2(0.0, 1.0), 6.0, tint)
	draw_line(Vector2(2.0, -5.0), Vector2(5.0, -8.0), tint, 2.0)


func _on_area_entered(area: Area2D) -> void:
	if (area.collision_layer & PLAYER_LAYER_BIT) == 0:
		return
	collected.emit(kind)
	queue_free()
