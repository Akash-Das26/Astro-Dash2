class_name Player
extends Node2D
## The player ship. Owns movement, fire rate, power-up effects and damage
## handling, but never touches other systems: it broadcasts `shot_fired` /
## `hurt` / `shield_changed` and a manager reacts. Enemy ships and enemy
## bullets reach it through the Hurtbox (collision layer 1).

signal shot_fired(spawn_position: Vector2, direction: Vector2)
signal hurt
signal shield_changed(active: bool)

@export var move_speed: float = 300.0
@export var fire_interval: float = 0.5
@export var rapid_fire_interval: float = 0.16
@export var spread_angle_degrees: float = 12.0
@export var muzzle_offset: Vector2 = Vector2(0.0, -20.0)
@export var play_area_width: float = 400.0
@export var half_width: float = 16.0
## Grace period after a hit, during which the ship blinks and cannot be hit.
@export var invulnerability_time: float = 1.0
@export var blink_interval: float = 0.1
@export var blink_alpha: float = 0.35
## Short mercy window after the shield absorbs a hit.
@export var shield_grace_time: float = 0.4

@onready var _sprite: Sprite2D = $ShipSprite
@onready var _hurtbox: Area2D = $Hurtbox

var _shoot_cooldown: float = 0.0
var _invulnerable_time_left: float = 0.0
var _blink_timer: float = 0.0
var _rapid_fire: bool = false
var _spread_shot: bool = false
var _shield: bool = false


func _ready() -> void:
	_hurtbox.area_entered.connect(_on_hurtbox_area_entered)


func _process(delta: float) -> void:
	_move(delta)
	_update_shooting(delta)
	_update_invulnerability(delta)


## Applies one hit: the shield eats it, otherwise it costs a life and starts
## the invulnerability window.
func take_hit() -> void:
	if is_invulnerable():
		return
	if _shield:
		_shield = false
		_start_invulnerability(shield_grace_time)
		shield_changed.emit(false)
		return
	_start_invulnerability(invulnerability_time)
	hurt.emit()


func is_invulnerable() -> bool:
	return _invulnerable_time_left > 0.0


func has_shield() -> bool:
	return _shield


func grant_shield() -> void:
	if _shield:
		return
	_shield = true
	shield_changed.emit(true)


## Rapid fire and spread shot last as long as the manager keeps them active;
## the shield survives until it absorbs a hit.
func set_rapid_fire(active: bool) -> void:
	_rapid_fire = active


func set_spread_shot(active: bool) -> void:
	_spread_shot = active


func clear_powerups() -> void:
	_rapid_fire = false
	_spread_shot = false
	if _shield:
		_shield = false
		shield_changed.emit(false)


func _move(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	var target_x: float = position.x + direction * move_speed * delta
	position.x = clampf(target_x, half_width, play_area_width - half_width)


func _update_shooting(delta: float) -> void:
	_shoot_cooldown += delta
	var interval: float = rapid_fire_interval if _rapid_fire else fire_interval
	if not Input.is_action_pressed("shoot") or _shoot_cooldown < interval:
		return
	_shoot_cooldown = 0.0
	_fire()


func _fire() -> void:
	var origin: Vector2 = position + muzzle_offset
	if not _spread_shot:
		shot_fired.emit(origin, Vector2.UP)
		return
	var step: float = deg_to_rad(spread_angle_degrees)
	for offset: float in [-step, 0.0, step]:
		shot_fired.emit(origin, Vector2.UP.rotated(offset))


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
	if is_invulnerable():
		return
	if area is EnemyBase:
		(area as EnemyBase).on_player_contact()
		take_hit()
	elif area is EnemyBullet:
		(area as EnemyBullet).destroy()
		take_hit()
