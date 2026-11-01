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
		"texture": preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship_blue_small.png"),
		"scale": 0.62,
	},
	&"gunner": {
		"texture": preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship_red_small_2.png"),
		"scale": 0.68,
	},
	&"heavy": {
		"texture": preload("res://assets/sprites/spacepixels_ships_stroked/space_pixels_ships_stroked/ship_red_stroked.png"),
		"scale": 0.6,
	},
	# Elite family: the pack's alternate fighter art, unused until now.
	&"elite_red": {
		"texture": preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship3_red.png"),
		"scale": 0.9,
	},
	&"elite_green": {
		"texture": preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship3_green.png"),
		"scale": 0.85,
	},
	&"elite_yellow": {
		"texture": preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship3_yellow.png"),
		"scale": 0.95,
	},
	&"drone": {
		"texture": preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_shape3_blue.png"),
		"scale": 0.55,
	},
}

const WARP_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/warpgate_1.png"),
	preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/warpgate_2.png"),
	preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/warpgate_3.png"),
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
## Damage of this kind's own shots; the battle reads it per fighter.
@export var bullet_damage: int = Tuning.ENEMY_DEFAULT_BULLET_DAMAGE
## Shield-carrier aura: while this fighter lives, other fighters inside the
## radius take their damage multiplied by `aura_multiplier`.
@export var aura_radius: float = 0.0
@export var aura_multiplier: float = 1.0
@export var thruster_scale: float = Tuning.ENEMY_DEFAULT_THRUSTER_SCALE
@export var swarm: bool = false
@export var hit_flash_time: float = 0.12
@export var effect_color: Color = Color(0.45, 0.8, 1.0)

## Opaque bounds per texture, cached: `get_image()` decompresses, and fighters
## spawn by the dozen. The alternate fighter art ships inside a mostly empty
## 128px square, so the drawn pixels -- not the file size -- decide the hull.
static var _used_cache: Dictionary = {}

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
var _glow: Sprite2D
var _glow_tween: Tween


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
	contact_damage = int(row.get("contact_damage", Tuning.ENEMY_CONTACT_DAMAGE))
	bullet_damage = int(row.get("bullet_damage", Tuning.ENEMY_DEFAULT_BULLET_DAMAGE))
	aura_radius = float(row.get("aura_radius", 0.0))
	aura_multiplier = float(row.get("aura_multiplier", 1.0))
	thruster_scale = float(row.get("thruster_scale", Tuning.ENEMY_DEFAULT_THRUSTER_SCALE))
	swarm = bool(row.get("swarm", false))
	effect_color = row["effect_color"]
	# The aura ring is static, so one redraw is all it needs.
	queue_redraw()
	max_hp = maxi(roundi(float(max_hp) * _hp_scale), 1)
	hp = max_hp
	if fire_interval > 0.0:
		fire_interval *= _fire_scale
	var art: Dictionary = SPRITES.get(kind, SPRITES[&"scout"])
	var texture: Texture2D = art["texture"]
	var art_scale: float = float(art["scale"])
	var used: Rect2 = _used_rect(texture)
	# A row may ask for a drawn height instead of a scale, so art with a lot of
	# transparent margin still comes out the size the arena expects.
	if row.has("target_height"):
		art_scale = float(row["target_height"]) / maxf(used.size.y, 1.0)
	# The elite family is drawn larger, and its hit radius grows with the art so
	# the silhouette and the collider stay in step.
	var size_scale: float = float(row.get("size_scale", 1.0))
	art_scale *= size_scale
	body_radius *= size_scale
	_apply_body()
	_sprite.texture = texture
	_flash.texture = texture
	_sprite.scale = Vector2.ONE * art_scale
	_flash.scale = Vector2.ONE * art_scale
	# Centre the opaque pixels on the node origin: padded art otherwise draws
	# off-centre, away from its collider and from its exhaust anchor.
	_sprite.offset = used.position + used.size * 0.5 - texture.get_size() * 0.5
	_flash.offset = _sprite.offset
	# Elite art is near-black; a brightness multiply keeps its stripes legible
	# on every band. Every other fighter stays exactly as it was.
	var brightness: float = Tuning.ELITE_SPRITE_BRIGHTNESS \
		if Tuning.ELITE_GLOW.has(kind) else 1.0
	_sprite.modulate = Color(brightness, brightness, brightness)
	_build_glow(texture, used, art_scale)
	# Anchor the exhaust at the art's real rear edge, not at the file's edge.
	var hull_half: float = used.size.y * 0.5 * art_scale
	var hull_width: float = used.size.x * art_scale
	_thruster.position = Vector2(0.0, hull_half + Tuning.THRUSTER_TAIL_GAP * size_scale)
	# Sized from the hull (see ENEMY_THRUSTER_WIDTH_RATIO): the body radius would
	# blow the 32 px art up past the hull on a heavy and shrink it to a sliver on
	# a drone.
	# Divided by THRUSTER_FULL_SCALE because the ratio is what the flame measures
	# at FULL thrust, where `_apply()` has already grown it by that factor.
	var flame: float = clampf(
		hull_width * Tuning.ENEMY_THRUSTER_WIDTH_RATIO
			/ Tuning.THRUSTER_ART_SIZE / Tuning.THRUSTER_FULL_SCALE,
		Tuning.ENEMY_THRUSTER_MIN_SCALE,
		Tuning.ENEMY_THRUSTER_MAX_SCALE
	)
	_thruster.set_base_scale(Vector2.ONE * flame * thruster_scale)


## Rim copy behind the hull, in the kind's own colour, pulsing gently. Only the
## elite family has a colour in Tuning, so every other fighter is unchanged.
func _build_glow(texture: Texture2D, used: Rect2, art_scale: float) -> void:
	if not Tuning.ELITE_GLOW.has(kind):
		if _glow != null:
			_glow.queue_free()
			_glow = null
		return
	var tint: Color = Tuning.ELITE_GLOW[kind]
	if _glow == null:
		_glow = Sprite2D.new()
		_glow.name = "RimGlow"
		# Behind the hull, and never in front of a sibling fighter.
		_glow.z_index = -2
		_glow.show_behind_parent = true
		add_child(_glow)
	_glow.texture = texture
	_glow.offset = used.position + used.size * 0.5 - texture.get_size() * 0.5
	_glow.scale = Vector2.ONE * art_scale * Tuning.ELITE_GLOW_SCALE
	_glow.modulate = Color(tint.r, tint.g, tint.b, Tuning.ELITE_GLOW_ALPHA)
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(
		_glow, "modulate:a", Tuning.ELITE_GLOW_ALPHA_MIN, Tuning.ELITE_GLOW_PULSE_SECONDS
	)
	_glow_tween.tween_property(
		_glow, "modulate:a", Tuning.ELITE_GLOW_ALPHA, Tuning.ELITE_GLOW_PULSE_SECONDS
	)


## Size of the pixels actually drawn, in arena units. The thruster anchor, the
## frame check and the tests all use this instead of the texture size.
func drawn_size() -> Vector2:
	if _sprite.texture == null:
		return Vector2.ZERO
	return _used_rect(_sprite.texture).size * _sprite.scale


## Opaque bounds of a texture, in its own pixels. Falls back to the full rect
## when the image cannot be read (an exported build may not decode it).
func _used_rect(texture: Texture2D) -> Rect2:
	var key: String = texture.resource_path
	if not key.is_empty() and _used_cache.has(key):
		return _used_cache[key]
	var full := Rect2(Vector2.ZERO, texture.get_size())
	var rect: Rect2 = full
	var image: Image = texture.get_image()
	if image != null:
		var used: Rect2 = image.get_used_rect()
		if used.size.x >= 1.0 and used.size.y >= 1.0:
			rect = used
	if not key.is_empty():
		_used_cache[key] = rect
	return rect


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
	hp -= mitigated(amount)
	damaged.emit(global_position)
	if hp <= 0:
		die()
	else:
		_flash_hit()


## Damage after any shield-carrier aura in range. A carrier protects the
## fighters around it while it lives, never itself.
func mitigated(amount: int) -> int:
	var carrier := _carrier_in_range()
	if carrier == null:
		return amount
	return maxi(roundi(float(amount) * carrier.aura_multiplier), 1)


func _carrier_in_range() -> EnemyBase:
	var parent: Node = get_parent()
	if parent == null:
		return null
	for sibling: Node in parent.get_children():
		var other := sibling as EnemyBase
		if other == null or other == self or not other.is_active():
			continue
		if other.aura_radius <= 0.0:
			continue
		if other.global_position.distance_to(global_position) > other.aura_radius:
			continue
		return other
	return null


## Still alive and in the fight (used by the aura scan).
func is_active() -> bool:
	return _active


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
	# The elite art is thin coloured lines on black, so a rim copy only makes it
	# a bigger set of thin lines. A soft filled disc behind the hull (this runs
	# before the child sprites draw) gives the silhouette something to sit on.
	if Tuning.ELITE_GLOW.has(kind):
		var elite_tint: Color = Tuning.ELITE_GLOW[kind]
		var hull: Vector2 = drawn_size()
		var hull_radius: float = maxf(hull.x, hull.y) * 0.5
		if hull_radius > 0.0:
			draw_circle(
				Vector2.ZERO, hull_radius * 1.15,
				Color(elite_tint.r, elite_tint.g, elite_tint.b, 0.16)
			)
			draw_circle(
				Vector2.ZERO, hull_radius * 0.85,
				Color(elite_tint.r, elite_tint.g, elite_tint.b, 0.2)
			)
	# A shield carrier shows its protection: a faint ring at the aura radius.
	if aura_radius > 0.0:
		draw_arc(
			Vector2.ZERO, aura_radius, 0.0, TAU, 40,
			Color(
				Tuning.AURA_RING_COLOR.r, Tuning.AURA_RING_COLOR.g,
				Tuning.AURA_RING_COLOR.b, Tuning.AURA_RING_ALPHA
			),
			Tuning.AURA_RING_WIDTH, true
		)
	if not Tuning.thruster_debug:
		return
	var tint: Color = Tuning.THRUSTER_DEBUG_COLOR
	draw_circle(Vector2.ZERO, body_radius, Color(tint.r, tint.g, tint.b, 0.18))
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 28, tint, 1.0, true)
	draw_line(Vector2.ZERO, _thruster.position, tint, 1.0)
	draw_circle(_thruster.position, 2.0, tint)
