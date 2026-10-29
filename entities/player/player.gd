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

## Damage every bullet gets. Raised by the fire-power upgrade, read by the
## manager when it spawns a bullet.
var bullet_damage: int = Tuning.BASE_BULLET_DAMAGE

@onready var _sprite: Sprite2D = $ShipSprite
@onready var _flash: Sprite2D = $FlashSprite
@onready var _hurtbox: Area2D = $Hurtbox

var _shoot_cooldown: float = 0.0
var _invulnerable_time_left: float = 0.0
var _blink_timer: float = 0.0
var _rapid_fire: bool = false
var _spread_shot: bool = false
var _shield_charges: int = 0
## Charges a fresh run starts with, from the shield upgrade.
var _starting_shield_charges: int = 0
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_base_scale = _sprite.scale
	_flash.scale = _base_scale
	_hurtbox.area_entered.connect(_on_hurtbox_area_entered)


func _process(delta: float) -> void:
	_move(delta)
	_update_shooting(delta)
	_update_invulnerability(delta)


## Applies one hit: a shield charge eats it, otherwise it costs a life and
## starts the invulnerability window.
func take_hit() -> void:
	if is_invulnerable():
		return
	if _shield_charges > 0:
		_set_shield_charges(_shield_charges - 1)
		_start_invulnerability(shield_grace_time)
		_play_hit_feedback(Color(0.5, 0.95, 1.0))
		return
	_start_invulnerability(invulnerability_time)
	_play_hit_feedback(Color.WHITE)
	hurt.emit()


func is_invulnerable() -> bool:
	return _invulnerable_time_left > 0.0


func has_shield() -> bool:
	return _shield_charges > 0


func shield_charges() -> int:
	return _shield_charges


## A shield pickup is one extra charge, up to the cap.
func grant_shield() -> void:
	_set_shield_charges(_shield_charges + 1)


## Run-start totals from the upgrade shop. Lives stay the manager's business.
func apply_run_stats(stats: Dictionary) -> void:
	move_speed = float(stats["move_speed"])
	bullet_damage = int(stats["bullet_damage"])
	fire_interval = float(stats["fire_interval"])
	rapid_fire_interval = float(stats["rapid_interval"])
	_starting_shield_charges = int(stats["shield_charges"])
	_set_shield_charges(_starting_shield_charges)


## Rapid fire and spread shot last as long as the manager keeps them active;
## the shield survives until it absorbs a hit.
func set_rapid_fire(active: bool) -> void:
	_rapid_fire = active


func set_spread_shot(active: bool) -> void:
	_spread_shot = active


func clear_powerups() -> void:
	_rapid_fire = false
	_spread_shot = false
	_set_shield_charges(_starting_shield_charges)


## Shield bubble with one pip per charge, drawn behind the hull. No texture,
## no shader.
func _draw() -> void:
	if _shield_charges <= 0:
		return
	draw_circle(Vector2.ZERO, 26.0, Color(0.4, 0.9, 1.0, 0.12))
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 32, Color(0.5, 0.95, 1.0, 0.8), 2.0, true)
	for index: int in _shield_charges:
		var angle: float = -PI * 0.5 + float(index) * (TAU / float(Tuning.MAX_SHIELD_CHARGES))
		draw_circle(Vector2(cos(angle), sin(angle)) * 26.0, 2.5, Color(0.75, 1.0, 1.0, 0.9))


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


## White flash on the hull plus a small scale pop when a hit lands.
func _play_hit_feedback(tint: Color) -> void:
	_flash.modulate = Color(tint.r, tint.g, tint.b, 0.85)
	var flash_tween := create_tween()
	flash_tween.tween_property(_flash, "modulate:a", 0.0, 0.16)
	_sprite.scale = _base_scale * 1.3
	var pop_tween := create_tween()
	pop_tween.tween_property(_sprite, "scale", _base_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_shield_charges(count: int) -> void:
	var clamped: int = clampi(count, 0, Tuning.MAX_SHIELD_CHARGES)
	if clamped == _shield_charges:
		return
	_shield_charges = clamped
	queue_redraw()
	shield_changed.emit(has_shield())


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
