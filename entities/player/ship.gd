class_name Ship
extends Node2D
## The player ship. Free flight with a little inertia, a hull that swings onto
## the aim, HP plus shield charges, and a thruster that follows the speed.
##
## It only broadcasts: `shot_fired` when the muzzle opens, `hurt` and HP changes
## when damage lands. The battle decides what a shot spawns and what a hit
## costs. Everything it reads comes from the InputMap actions, so keyboard,
## gamepad and the on-screen stick all drive the same code.

signal shot_fired(origin: Vector2, direction: Vector2)
signal hurt(amount: int)
signal hp_changed(hp: int, max_hp: int)
signal shields_changed(charges: int)
signal died

@export var max_hp: int = Tuning.SHIP_MAX_HP
@export var move_speed: float = Tuning.SHIP_MAX_SPEED
@export var fire_interval: float = Tuning.SHIP_FIRE_INTERVAL
@export var bullet_damage: int = Tuning.SHIP_BULLET_DAMAGE
@export var acceleration: float = Tuning.SHIP_ACCELERATION
@export var drag: float = Tuning.SHIP_DRAG

@onready var _sprite: Sprite2D = $ShipSprite
@onready var _flash: Sprite2D = $FlashSprite
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _thruster: Thruster = $Thruster

var hp: int = Tuning.SHIP_MAX_HP
var shields: int = 0
var alive: bool = true
## Unit vector the nose is following.
var aim: Vector2 = Vector2.UP

var _velocity: Vector2 = Vector2.ZERO
var _thrust: float = 0.0
var _shoot_cooldown: float = 0.0
var _invulnerable_left: float = 0.0
var _blink_timer: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
## Touch sets this while a finger holds the right zone; zero means "no override".
var _aim_override: Vector2 = Vector2.ZERO
var _mouse_active: bool = false


func _ready() -> void:
	_base_scale = _sprite.scale
	_flash.scale = _base_scale
	_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	shields_changed.emit(shields)


func _process(delta: float) -> void:
	if not alive:
		return
	_update_movement(delta)
	_update_aim(delta)
	_update_shooting(delta)
	_update_invulnerability(delta)


# --- Run setup --------------------------------------------------------------

## Totals from the upgrade shop, applied at the start of a battle.
func apply_run_stats(stats: Dictionary) -> void:
	max_hp = int(stats["max_hp"])
	move_speed = float(stats["move_speed"])
	bullet_damage = int(stats["bullet_damage"])
	fire_interval = float(stats["fire_interval"])
	revive()
	set_shields(int(stats["shield_charges"]))


## Resets the hull for a new battle (or after a restart).
func revive() -> void:
	alive = true
	visible = true
	hp = max_hp
	_velocity = Vector2.ZERO
	_thrust = 0.0
	_shoot_cooldown = 0.0
	_invulnerable_left = 0.0
	_blink_timer = 0.0
	_sprite.modulate.a = 1.0
	_flash.modulate.a = 0.0
	hp_changed.emit(hp, max_hp)


func set_shields(charges: int) -> void:
	shields = clampi(charges, 0, Tuning.MAX_SHIELD_CHARGES)
	shields_changed.emit(shields)
	queue_redraw()


## On-screen aim for touch devices: a direction, or zero to give control back
## to the mouse / right stick.
func set_aim_override(direction: Vector2) -> void:
	_aim_override = direction


# --- Damage -----------------------------------------------------------------

func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## A shield charge eats the whole hit; otherwise the hull takes it.
func take_damage(amount: int) -> void:
	if not alive or is_invulnerable():
		return
	if shields > 0:
		set_shields(shields - 1)
		_start_invulnerability(Tuning.SHIP_SHIELD_GRACE)
		_play_hit_feedback(Color(0.5, 0.95, 1.0))
		return
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	hurt.emit(amount)
	_start_invulnerability(Tuning.SHIP_INVULNERABILITY)
	_play_hit_feedback(Color.WHITE)
	if hp <= 0:
		alive = false
		_velocity = Vector2.ZERO
		_thruster.set_thrust(0.0)
		died.emit()


func heal(amount: int) -> void:
	if not alive:
		return
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)


# --- Movement and input -----------------------------------------------------

func _update_movement(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Light inertia: the ship keeps drifting for a moment after the key is let
	# go, and the drag is what stops it, not a hard reset.
	_velocity = _velocity.lerp(Vector2.ZERO, clampf(drag * delta, 0.0, 1.0))
	if input.length() > 0.05:
		_velocity += input * acceleration * delta
	_velocity = _velocity.limit_length(move_speed)
	position += _velocity * delta
	position.x = clampf(position.x, Tuning.ARENA_LEFT + Tuning.ARENA_MARGIN, Tuning.ARENA_RIGHT - Tuning.ARENA_MARGIN)
	position.y = clampf(position.y, Tuning.ARENA_TOP + Tuning.ARENA_MARGIN, Tuning.ARENA_BOTTOM - Tuning.ARENA_MARGIN)
	_thrust = lerpf(_thrust, clampf(_velocity.length() / maxf(move_speed, 1.0), 0.0, 1.0), 10.0 * delta)
	_thruster.set_thrust(_thrust)


## Three aim sources in priority order: the touch zone, the right stick, the
## mouse. With none of them active the nose keeps its last heading, so a
## keyboard-only player flies and shoots forward.
func _update_aim(delta: float) -> void:
	if _aim_override.length() > 0.1:
		aim = _aim_override.normalized()
	elif Input.is_action_pressed("aim"):
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if stick.length() > 0.3:
			aim = stick.normalized()
	elif _mouse_active:
		var to_mouse: Vector2 = get_global_mouse_position() - global_position
		if to_mouse.length() > 8.0:
			aim = to_mouse.normalized()
	rotation = lerp_angle(rotation, aim.angle() + PI * 0.5, clampf(Tuning.SHIP_TURN_LERP * delta, 0.0, 1.0))


func _update_shooting(delta: float) -> void:
	_shoot_cooldown = maxf(_shoot_cooldown - delta, 0.0)
	if _shoot_cooldown > 0.0 or not Input.is_action_pressed("shoot"):
		return
	_shoot_cooldown = fire_interval
	shot_fired.emit(global_position + aim * Tuning.SHIP_MUZZLE_OFFSET, aim)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_active = true


# --- Feedback ---------------------------------------------------------------

func _play_hit_feedback(tint: Color) -> void:
	_flash.modulate = Color(tint.r, tint.g, tint.b, 0.85)
	var flash_tween := create_tween()
	flash_tween.tween_property(_flash, "modulate:a", 0.0, 0.16)
	_sprite.scale = _base_scale * 1.25
	var pop_tween := create_tween()
	pop_tween.tween_property(_sprite, "scale", _base_scale, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _start_invulnerability(duration: float) -> void:
	_invulnerable_left = duration
	_blink_timer = 0.0


func _update_invulnerability(delta: float) -> void:
	if _invulnerable_left <= 0.0:
		return
	_invulnerable_left -= delta
	_blink_timer += delta
	if _blink_timer >= Tuning.SHIP_BLINK_INTERVAL:
		_blink_timer = 0.0
		_sprite.modulate.a = 1.0 if _sprite.modulate.a <= Tuning.SHIP_BLINK_ALPHA else Tuning.SHIP_BLINK_ALPHA
	if _invulnerable_left <= 0.0:
		_invulnerable_left = 0.0
		_sprite.modulate.a = 1.0


## Shield bubble with one pip per charge, drawn behind the hull.
func _draw() -> void:
	if shields <= 0:
		return
	draw_circle(Vector2.ZERO, 24.0, Color(0.4, 0.9, 1.0, 0.12))
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, Color(0.5, 0.95, 1.0, 0.8), 2.0, true)
	for index: int in shields:
		var angle: float = -PI * 0.5 + float(index) * (TAU / float(Tuning.MAX_SHIELD_CHARGES))
		draw_circle(Vector2(cos(angle), sin(angle)) * 24.0, 2.5, Color(0.75, 1.0, 1.0, 0.9))


# --- Collisions -------------------------------------------------------------

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not alive or is_invulnerable():
		return
	# Fighters are duck-typed on purpose: Ship and EnemyBase would otherwise
	# reference each other's class, which GDScript does not like.
	if area is EnemyBullet:
		var bullet := area as EnemyBullet
		var amount: int = bullet.damage
		bullet.destroy()
		take_damage(amount)
	elif area is Asteroid:
		var rock := area as Asteroid
		rock.bump()
		take_damage(Tuning.ASTEROID_CONTACT_DAMAGE)
	elif area.has_method("on_player_contact"):
		area.call("on_player_contact")
		take_damage(Tuning.ENEMY_CONTACT_DAMAGE)
