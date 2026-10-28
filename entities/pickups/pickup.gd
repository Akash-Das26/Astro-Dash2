class_name Pickup
extends Area2D
## Falling power-up. It only reports what it is; GameManager decides what the
## effect does. Layer 6 / mask 1: it notices the player hurtbox on its own.

signal collected(kind: Kind)

enum Kind { RAPID_FIRE, SPREAD_SHOT, SHIELD, BOMB }

const PLAYER_LAYER_BIT: int = 1 << 0
const DESPAWN_Y: float = 620.0

const TINTS: Dictionary = {
	Kind.RAPID_FIRE: Color(1.0, 0.82, 0.25),
	Kind.SPREAD_SHOT: Color(0.45, 0.8, 1.0),
	Kind.SHIELD: Color(0.45, 1.0, 0.6),
	Kind.BOMB: Color(1.0, 0.45, 0.45),
}
const LETTERS: Dictionary = {
	Kind.RAPID_FIRE: "R",
	Kind.SPREAD_SHOT: "S",
	Kind.SHIELD: "H",
	Kind.BOMB: "B",
}

@export var kind: Kind = Kind.RAPID_FIRE
@export var fall_speed: float = 55.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _letter: Label = $Letter


func _ready() -> void:
	_sprite.modulate = TINTS[kind]
	_letter.text = LETTERS[kind]
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	position.y += fall_speed * delta
	if position.y > DESPAWN_Y:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if (area.collision_layer & PLAYER_LAYER_BIT) == 0:
		return
	collected.emit(kind)
	queue_free()
