class_name Player
extends Node2D
## The player ship. Owns movement, fire rate and damage handling, but never
## touches other systems: it broadcasts `shot_fired` / `hurt` and a manager
## reacts. Enemy ships and enemy bullets reach it through the Hurtbox
## (collision layer 1), which calls take_hit().

signal shot_fired(spawn_position: Vector2)
signal hurt

@export var move_speed: float = 300.0
@export var fire_interval: float = 0.5
@export var muzzle_offset: Vector2 = Vector2(0.0, -20.0)
@export var play_area_width: float = 400.0
@export var half_width: float = 16.0
## Grace period after a hit, during which the ship blinks and cannot be hit.
@export var invulnerability_time: float = 1.0
@export var blink_interval: float = 0.1
@export var blink_alpha: float = 0.35

@onready var _sprite: Sprite2D = $ShipSprite
@onready var _hurtbox: Area2D = $Hurtbox

var _shoot_cooldown: float = 0.0
var _invulnerable_time_left: float = 0.0
var _blink_timer: float = 0.0


func _ready() -> void:
	_hurtbox.area_entered.connect(_on_hurtbox_area_entered)


func _process(delta: float) -> void:
	_move(delta)
	_update_shooting(delta)
	_update_invulnerability(delta)


## Applies one hit unless the ship is still blinking from the previous one.
func take_hit() -> void:
	if is_invulnerable():
		return
	_start_invulnerability(invulnerability_time)
	hurt.emit()


func is_invulnerable() -> bool:
	return _invulnerable_time_left > 0.0


func _move(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	var target_x: float = position.x + direction * move_speed * delta
	position.x = clampf(target_x, half_width, play_area_width - half_width)


func _update_shooting(delta: float) -> void:
	_shoot_cooldown += delta
	if not Input.is_action_pressed("shoot") or _shoot_cooldown < fire_interval:
		return
	_shoot_cooldown = 0.0
	shot_fired.emit(position + muzzle_offset)


func _start_invulnerability(duration: float) -> void:
	_invulnerable_time_left = duration
	_blink_timer = 0.0


func _update_invulnerability(delta: float) -> void:
	if _invulnerable_time_left <= 0.0:
		return
	_invulnerable_time_left -= delta
	_blink_timer += delta
	if _blink_timer >= blink_interval:
		_blink_timer = 0.0
		_sprite.modulate.a = 1.0 if _sprite.modulate.a <= blink_alpha else blink_alpha
	if _invulnerable_time_left <= 0.0:
		_invulnerable_time_left = 0.0
		_sprite.modulate.a = 1.0


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not area is Enemy or is_invulnerable():
		return
	(area as Enemy).destroy()
	take_hit()
