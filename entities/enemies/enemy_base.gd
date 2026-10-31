class_name EnemyBase
extends Area2D
## Every fighter shares this: hp, score value, the hit flash, contact damage and
## the three-state AI (warp in, approach, orbit). `configure()` fills the stats
## from Tuning.ENEMY_TYPES, so a new type is a row in config/config/tuning.gd, not a new
## script.
##
## It never spawns bullets itself: it emits `shot_requested` and the battle
## decides what a shot is. It also never touches score or the HUD.

signal died(points: int)
signal damaged(at: Vector2)
signal shot_requested(origin: Vector2, direction: Vector2)

enum State { WARP_IN, APPROACH, ORBIT }

## Where each kind gets its art and how big it is drawn. 100x90 art at 0.4 is
## the same 40px ship the portrait build used.
const SPRITES: Dictionary = {
	&"scout": {
		"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship_blue_small.png"),
		"scale": 0.62,
	},
	&"gunner": {
		"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship_red_small_2.png"),
		"scale": 0.68,
	},
	&"heavy": {
		"texture": preload("res://assests/spacepixels_ships_stroked/space_pixels_ships_stroked/ship_red_stroked.png"),
		"scale": 0.6,
	},
}

const WARP_FRAMES: Array[Texture2D] = [
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/warpgate_1.png"),
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/warpgate_2.png"),
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/warpgate_3.png"),
]
const TURN_LERP: float = 7.0
const STEER_LERP: float = 3.5
## A fighter stops firing when the ship is further away than this.
const MAX_FIRE_RANGE: float = 640.0

@export var kind: StringName = &"scout"
@export var max_hp: int = 2
@export var speed: float = 200.0
@export var points: int = 20
@export var body_radius: float = 11.0
@export var orbit_radius: float = 0.0
@export var fire_interval: float = 0.0
@export var bullet_speed: float = 0.0
@export var aim_error: float = 0.0
@export var contact_damage: int = Tuning.ENEMY_CONTACT_DAMAGE
@export var hit_flash_time: float = 0.12
@export var effect_color: Color = Color(0.45, 0.8, 1.0)

@onready var _sprite: Sprite2D = $Sprite
@onready var _flash: Sprite2D = $FlashSprite
@onready var _body: CollisionShape2D = $CollisionShape2D
@onready var _thruster: Thruster = $Thruster
@onready var _warp: AnimatedSprite2D = $Warp

var hp: int = 1
var state: State = State.WARP_IN
var target: Ship

var _velocity: Vector2 = Vector2.ZERO
var _heading: Vector2 = Vector2.DOWN
## Battle scale from the body's distance band and trait; set by configure().
var _hp_scale: float = 1.0
var _fire_scale: float = 1.0
var _warp_left: float = 0.0
var _fire_cooldown: float = 0.0
var _orbit_sign: float = 1.0
var _active: bool = true
var _flash_tween: Tween


func _ready() -> void:
	# configure() runs before the fighter enters the tree, so the node lookups
	# only happen here, once the @onready references are valid.
	_apply_kind()
	_apply_body()
	hp = max_hp
	_orbit_sign = 1.0 if randf() < 0.5 else -1.0
	_fire_cooldown = randf_range(0.4, 1.2)
	_build_warp_frames()
	_warp.visible = true
	_warp.play(&"warp")
	_sprite.visible = false
	_flash.visible = false
	_thruster.set_thrust(0.0)
	_warp_left = Tuning.ENEMY_WARP_TIME


## Called before the fighter enters the tree: kind, arena position, target and
## the battle's difficulty scales. Everything that needs child nodes waits for
## _ready().
func configure(
	fighter_kind: StringName,
	spawn_position: Vector2,
	ship: Ship,
	hp_scale: float = 1.0,
	fire_scale: float = 1.0
) -> void:
	kind = fighter_kind
	target = ship
	position = spawn_position
	_hp_scale = maxf(hp_scale, 0.1)
	_fire_scale = maxf(fire_scale, 0.2)


func _apply_kind() -> void:
	var row: Dictionary = Tuning.ENEMY_TYPES.get(kind, Tuning.ENEMY_TYPES[&"scout"])
	max_hp = int(row["hp"])
	speed = float(row["speed"])
	points = int(row["points"])
	body_radius = float(row["radius"])
	orbit_radius = float(row["orbit_radius"])
	fire_interval = float(row["fire_interval"])
	bullet_speed = float(row["bullet_speed"])
	aim_error = float(row["aim_error"])
	effect_color = row["effect_color"]
	max_hp = maxi(roundi(float(max_hp) * _hp_scale), 1)
	hp = max_hp
	if fire_interval > 0.0:
		fire_interval *= _fire_scale
	var art: Dictionary = SPRITES.get(kind, SPRITES[&"scout"])
	var texture: Texture2D = art["texture"]
	var art_scale: float = float(art["scale"])
	_sprite.texture = texture
	_flash.texture = texture
	_sprite.scale = Vector2.ONE * art_scale
	_flash.scale = Vector2.ONE * art_scale
	_sprite.modulate = Color.WHITE
	# Anchor the exhaust at this art's rear edge, not at a fixed pixel count.
	var hull_half: float = _sprite.get_rect().size.y * 0.5 * _sprite.scale.y
	_thruster.position = Vector2(0.0, hull_half + Tuning.THRUSTER_TAIL_GAP)
	_thruster.set_base_scale(Vector2.ONE * clampf(body_radius / 11.0, 0.8, 1.8))


func _apply_body() -> void:
	# Per-instance shape, so a heavy cannot resize a scout's collider.
	var shape := CircleShape2D.new()
	shape.radius = body_radius
	_body.shape = shape


func _build_warp_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"warp")
	frames.set_animation_speed(&"warp", Tuning.WARP_FRAME_FPS)
	frames.set_animation_loop(&"warp", false)
	for texture: Texture2D in WARP_FRAMES:
		frames.add_frame(&"warp", texture)
	_warp.sprite_frames = frames
	_warp.scale = Vector2.ONE * Tuning.WARP_SCALE


func _process(delta: float) -> void:
	if not _active:
		return
	if Tuning.thruster_debug:
		queue_redraw()
	if state == State.WARP_IN:
		_tick_warp(delta)
		return
	if target == null or not is_instance_valid(target) or not target.alive:
		_drift(delta)
		return
	_tick_ai(delta)


func _tick_warp(delta: float) -> void:
	_warp.global_position = global_position
	_warp_left -= delta
	if _warp_left > 0.0:
		return
	_warp.visible = false
	_sprite.visible = true
	_flash.visible = true
	_flash.modulate.a = 0.0
	state = State.APPROACH


func _drift(delta: float) -> void:
	global_position += _heading * speed * 0.35 * delta
	_clamp_to_arena()


func _tick_ai(delta: float) -> void:
	var to_target: Vector2 = target.global_position - global_position
	var distance: float = to_target.length()
	var direction: Vector2 = to_target.normalized()
	if orbit_radius <= 0.0:
		# Scouts have no stand-off distance: they dive straight at the ship.
		_steer(direction, delta, 1.0)
	elif state == State.APPROACH:
		_steer(direction, delta, 1.0)
		if distance <= orbit_radius + Tuning.ENEMY_APPROACH_SLACK:
			state = State.ORBIT
	else:
		var tangent: Vector2 = direction.orthogonal() * _orbit_sign
		var radial: Vector2 = Vector2.ZERO
		if distance > orbit_radius + Tuning.ENEMY_APPROACH_SLACK:
			radial = direction
		elif distance < orbit_radius - Tuning.ENEMY_APPROACH_SLACK:
			radial = -direction
		var mix: Vector2 = (tangent * Tuning.ENEMY_ORBIT_SPEED_RATIO + radial).normalized()
		_steer(mix, delta, 1.0)
		if distance < orbit_radius * 0.55:
			# The ship closed the gap: back out and swing around again.
			state = State.APPROACH
	_update_fire(delta, to_target)


func _steer(direction: Vector2, delta: float, strength: float) -> void:
	var wanted: Vector2 = direction * speed * strength
	_velocity = _velocity.lerp(wanted, clampf(STEER_LERP * delta, 0.0, 1.0))
	global_position += _velocity * delta
	_clamp_to_arena()
	if _velocity.length() > 6.0:
		_heading = _velocity.normalized()
	rotation = lerp_angle(rotation, _heading.angle() + PI * 0.5, clampf(TURN_LERP * delta, 0.0, 1.0))
	_thruster.set_thrust(clampf(_velocity.length() / maxf(speed, 1.0), 0.0, 1.0))


func _clamp_to_arena() -> void:
	position.x = clampf(position.x, Tuning.ARENA_LEFT + body_radius, Tuning.ARENA_RIGHT - body_radius)
	position.y = clampf(position.y, Tuning.ARENA_TOP + body_radius, Tuning.ARENA_BOTTOM - body_radius)


func _update_fire(delta: float, to_target: Vector2) -> void:
	if fire_interval <= 0.0:
		return
	_fire_cooldown -= delta
	if _fire_cooldown > 0.0:
		return
	if to_target.length() > MAX_FIRE_RANGE or to_target.length() < body_radius + 20.0:
		return
	_fire_cooldown = fire_interval * randf_range(0.8, 1.2)
	var stray: float = randf_range(-aim_error, aim_error)
	var shot: Vector2 = to_target.normalized().rotated(stray)
	shot_requested.emit(global_position + shot * (body_radius + 6.0), shot)


# --- Damage -----------------------------------------------------------------

## A shove from a heavy slug. It nudges the current velocity only, so the AI
## keeps flying and nothing can push a fighter through the arena bounds.
func apply_knockback(direction: Vector2, strength: float) -> void:
	if direction.length() < 0.01:
		return
	_velocity += direction.normalized() * strength


func take_damage(amount: int) -> void:
	if not _active:
		return
	hp -= amount
	damaged.emit(global_position)
	if hp <= 0:
		die()
	else:
		_flash_hit()


## Killed by a bullet: awards points.
func die() -> void:
	if not _active:
		return
	_active = false
	died.emit(points)
	queue_free()


## Removed without points (rammed the ship, cleared with a bomb).
func destroy() -> void:
	if not _active:
		return
	_active = false
	queue_free()


## The ship hurtbox found this fighter. The battle reads contact_damage from the
## ship side, so the fighter itself only reports what it is worth.
func on_player_contact() -> void:
	destroy()


func _flash_hit() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.modulate.a = 0.9
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, hit_flash_time)


## F3 overlay: the body circle and the exhaust anchor in the fighter's frame.
func _draw() -> void:
	if not Tuning.thruster_debug:
		return
	var tint: Color = Tuning.THRUSTER_DEBUG_COLOR
	draw_circle(Vector2.ZERO, body_radius, Color(tint.r, tint.g, tint.b, 0.18))
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 28, tint, 1.0, true)
	draw_line(Vector2.ZERO, _thruster.position, tint, 1.0)
	draw_circle(_thruster.position, 2.0, tint)
