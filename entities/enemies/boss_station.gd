class_name BossStation
extends Area2D
## A citadel's station boss. It hovers over a fixed anchor, fires a fan of red
## dots at the ship and reports its HP for the HUD bar. Like EnemyBase it never
## spawns bullets itself: `shot_requested` goes up to the battle.
##
## Layer 3 (the enemy bit), empty mask: player bullets and the ship's hurtbox
## detect it, so it needs no reference back to them.

signal hp_changed(hp: int, max_hp: int)
signal damaged(at: Vector2)
signal died(points: int)
## `damage_scale` is the station's own phase multiplier, applied by the battle.
signal shot_requested(origin: Vector2, direction: Vector2, damage_scale: float)

const STATION_ART: Dictionary = {
	&"blue": preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_station_blue.png"),
	&"green": preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_station_green.png"),
	&"red": preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_station_red.png"),
	&"yellow": preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_station_yellow.png"),
}

@export var max_hp: int = Tuning.BOSS_HP
@export var points: int = Tuning.BOSS_POINTS
@export var body_radius: float = Tuning.BOSS_RADIUS
@export var contact_damage: int = Tuning.BOSS_CONTACT_DAMAGE
@export var effect_color: Color = Color(1.0, 0.6, 0.45)

var hp: int = 1
var target: Ship

var _station_color: StringName = &"red"
var _anchor: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _fire_cooldown: float = 0.0
## Seconds left in the warning window before the fan fires; 0 when idle.
var _charge_left: float = 0.0
var _charging: bool = false
var _active: bool = true
var _flash_tween: Tween

@onready var _sprite: Sprite2D = $Sprite
@onready var _body: CollisionShape2D = $CollisionShape2D


## Called before the station enters the tree.
func configure(
	station_color: StringName,
	boss_hp: int,
	spawn_position: Vector2,
	ship: Ship
) -> void:
	_station_color = station_color
	max_hp = maxi(boss_hp, 1)
	position = spawn_position
	_anchor = spawn_position
	target = ship


func _ready() -> void:
	_sprite.texture = STATION_ART.get(_station_color, STATION_ART[&"red"])
	_sprite.scale = Vector2.ONE * Tuning.BOSS_SCALE
	var shape := CircleShape2D.new()
	shape.radius = body_radius
	_body.shape = shape
	hp = max_hp
	_fire_cooldown = 1.4
	hp_changed.emit(hp, max_hp)
	# A short fade rather than a warp: the station is already in the sky.
	_sprite.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(_sprite, "modulate:a", 1.0, 0.5)


func _process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	position = _anchor + Vector2(
		cos(_age * Tuning.BOSS_HOVER_SPEED) * Tuning.BOSS_HOVER_AMPLITUDE,
		sin(_age * Tuning.BOSS_HOVER_SPEED * 0.7) * Tuning.BOSS_HOVER_RISE
	)
	rotation = sin(_age * 0.5) * 0.06
	_tick_fire(delta)
	# Brighten while charging, so the warning reads even without the ring.
	if _charging:
		_sprite.modulate = Color(1.0, 0.84, 0.7, _sprite.modulate.a)
	else:
		_sprite.modulate = Color(1.0, 1.0, 1.0, _sprite.modulate.a)
	queue_redraw()


func _tick_fire(delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.alive:
		return
	if _charging:
		_charge_left -= delta
		if _charge_left <= 0.0:
			_charging = false
			_charge_left = 0.0
			_fire_volley()
			queue_redraw()
		return
	_fire_cooldown -= delta
	if _fire_cooldown > 0.0:
		return
	_begin_telegraph()


## True while the fan is being warned: the charge ring fills and the aim line
## shows, so there is a window to move out of the arc.
func is_telegraphing() -> bool:
	return _charging


## The station's damage multiplier right now: softer above
## Tuning.BOSS_EARLY_PHASE_FRACTION, full strength once it is hurt.
func damage_scale() -> float:
	if _in_early_phase():
		return Tuning.BOSS_EARLY_DAMAGE_SCALE
	return 1.0


func _in_early_phase() -> bool:
	return float(hp) > float(max_hp) * Tuning.BOSS_EARLY_PHASE_FRACTION


func _begin_telegraph() -> void:
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length() < body_radius + 30.0:
		# The ship is hugging the hull: hold the volley until it backs off, so a
		# point-blank fan cannot delete the whole hull in one frame.
		_fire_cooldown = 0.25
		return
	_charging = true
	_charge_left = Tuning.BOSS_TELEGRAPH
	queue_redraw()


func _fire_volley() -> void:
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length() < body_radius + 30.0:
		_fire_cooldown = 0.25
		return
	var aim: Vector2 = to_target.normalized()
	var scale: float = damage_scale()
	var count: int = Tuning.BOSS_BULLETS_PER_VOLLEY
	var middle: float = (float(count) - 1.0) * 0.5
	for index: int in count:
		var shot: Vector2 = aim.rotated((float(index) - middle) * Tuning.BOSS_SPREAD)
		shot_requested.emit(global_position + shot * (body_radius + 10.0), shot, scale)
	# The opening phase also waits longer between fans.
	_fire_cooldown = Tuning.BOSS_FIRE_INTERVAL * (
		Tuning.BOSS_EARLY_INTERVAL_SCALE if _in_early_phase() else 1.0
	)


# --- Damage -----------------------------------------------------------------

func take_damage(amount: int) -> void:
	if not _active:
		return
	hp -= amount
	damaged.emit(global_position)
	hp_changed.emit(maxi(hp, 0), max_hp)
	if hp <= 0:
		_die()
	else:
		_flash_hit()


func _die() -> void:
	if not _active:
		return
	_active = false
	died.emit(points)
	queue_free()


## The ship's hurtbox found the station. It does not shatter when rammed, but it
## does flash so the hit reads as a hit.
func on_player_contact() -> void:
	_flash_hit()


func _flash_hit() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.modulate = Color(2.0, 2.0, 2.0, _sprite.modulate.a)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.14)


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_age * 2.2)
	draw_arc(
		Vector2.ZERO,
		body_radius + 5.0,
		0.0,
		TAU,
		48,
		Color(effect_color.r, effect_color.g, effect_color.b, 0.2 + 0.25 * pulse),
		2.0,
		true
	)
	if not _charging or target == null or not is_instance_valid(target):
		return
	# The warning: a thin aim line at the ship and a ring that fills over
	# Tuning.BOSS_TELEGRAPH seconds, so the volley can be read and dodged.
	var progress: float = 1.0 - clampf(_charge_left / Tuning.BOSS_TELEGRAPH, 0.0, 1.0)
	var to_ship: Vector2 = target.global_position - global_position
	draw_line(
		Vector2.ZERO,
		to_ship,
		Color(1.0, 0.85, 0.55, 0.16 + 0.3 * progress),
		1.5
	)
	draw_arc(
		Vector2.ZERO,
		body_radius + 12.0,
		-PI * 0.5,
		-PI * 0.5 + TAU * progress,
		40,
		Color(1.0, 0.92, 0.68, 0.5 + 0.4 * progress),
		3.0,
		true
	)
