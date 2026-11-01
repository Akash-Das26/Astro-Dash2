class_name Ship
extends Node2D
## The player ship. Free flight with a little inertia, a hull that swings onto
## the aim, HP plus shield charges, and a thruster that follows the speed.
##
## It only broadcasts: `weapon_fired` when a muzzle opens, `hurt` and HP changes
## when damage lands. The battle decides what a shot spawns and what a hit
## costs. Everything it reads comes from the InputMap actions, so keyboard,
## gamepad and the on-screen stick all drive the same code.

## slot 0 is the primary hardpoint, slot 1 the secondary. The battle decides
## what a shot spawns; the ship only knows when each gun is ready.
signal weapon_fired(slot: int, origin: Vector2, direction: Vector2)
signal hurt(amount: int)
## A shot was eaten by a shield charge, and the last one just went.
signal shield_spent
signal shield_broken
## MANUAL mode: a charge raised the timed bubble.
signal shield_raised
## Seconds left on the manual bubble; 0 when it is down.
signal shield_timer_changed(remaining: float)
signal hp_changed(hp: int, max_hp: int)
signal shields_changed(charges: int, capacity: int)
signal died

const SHOOT_ACTIONS: Array[StringName] = [&"shoot", &"shoot_alt"]

@export var max_hp: int = Tuning.SHIP_MAX_HP
@export var move_speed: float = Tuning.SHIP_MAX_SPEED
@export var fire_interval: float = Tuning.SHIP_FIRE_INTERVAL
@export var bullet_damage: int = Tuning.SHIP_BULLET_DAMAGE
## 0 blue, 1 green, 2 yellow laser; follows the fire-power level.
@export var bullet_tier: int = 0
@export var acceleration: float = Tuning.SHIP_ACCELERATION
@export var drag: float = Tuning.SHIP_DRAG

@onready var _sprite: Sprite2D = $ShipSprite
@onready var _flash: Sprite2D = $FlashSprite
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _thruster: Thruster = $Thruster

var hp: int = Tuning.SHIP_MAX_HP
var shields: int = 0
## How many charges the shield holds. The SHIELDS track raises it; a battle
## always starts full, so this is also the count shown on the HUD.
var shield_capacity: int = Tuning.SHIELD_BASE_CAPACITY
## Seconds for the SHIELDS track to recharge one charge; 0 disables it.
var shield_recharge_time: float = 0.0
var alive: bool = true
## Unit vector the nose is following.
var aim: Vector2 = Vector2.UP
## FREE AIM (today's twin-stick) or CLASSIC (turn + thrust along the nose).
var control_scheme: StringName = Tuning.CONTROL_SCHEME_DEFAULT
## AUTO spends a charge per hit; MANUAL spends one on a timed bubble.
var shield_mode: StringName = Tuning.SHIELD_MODE_DEFAULT
## Difficulty's enemy-damage multiplier, applied to every hull hit.
var damage_scale: float = 1.0

## The upgrade totals for this battle, so a weapon can read its multipliers.
var run_stats: Dictionary = {}
## Two equipped weapons; an empty id is an empty hardpoint.
var weapon_ids: Array[StringName] = [Weapons.DEFAULT_ID, &""]

var _weapon_intervals: Array[float] = [0.0, 0.0]
var _weapon_cooldowns: Array[float] = [0.0, 0.0]
var _velocity: Vector2 = Vector2.ZERO
var _thrust: float = 0.0
var _invulnerable_left: float = 0.0
## 0..1 bubble flash after a charge is spent or picked up.
var _shield_flash: float = 0.0
var _recharge_left: float = 0.0
var _since_damage: float = 0.0
## Manual bubble countdown and its post-raise cooldown.
var _shield_active_left: float = 0.0
var _shield_cooldown_left: float = 0.0
var _blink_timer: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
## Touch sets this while a finger holds the right zone; zero means "no override".
var _aim_override: Vector2 = Vector2.ZERO
var _mouse_active: bool = false


func _ready() -> void:
	_apply_skin()
	_base_scale = _sprite.scale
	_flash.scale = _base_scale
	_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	shields_changed.emit(shields, shield_limit())


## Movement, aim, fire and damage all tick in `_physics_process`: the hull flies
## on the same fixed step as the areas that can hit it, so a fast ship cannot
## tunnel through a rock between two frames of a variable frame rate.
func _physics_process(delta: float) -> void:
	if not alive:
		return
	_update_movement(delta)
	_update_aim(delta)
	_update_shooting(delta)
	_update_invulnerability(delta)
	_update_shields(delta)
	if Tuning.thruster_debug:
		queue_redraw()


# --- Run setup --------------------------------------------------------------

## The hull chosen in the upgrade screen. The flash sprite mirrors it, so a hit
## flashes the silhouette the player is actually flying.
func _apply_skin() -> void:
	var id: StringName = Skins.selected()
	var texture: Texture2D = Skins.texture(id)
	var art_scale: float = Skins.scale_of(id)
	if texture != null:
		_sprite.texture = texture
		_flash.texture = texture
		_sprite.scale = Vector2.ONE * art_scale
		_flash.scale = Vector2.ONE * art_scale
	# The exhaust starts at the hull's rear edge, whatever the skin's size.
	_thruster.position = Vector2(0.0, _hull_half_length() + Tuning.THRUSTER_TAIL_GAP)


## Half of the drawn hull's long axis, from the sprite itself rather than a
## constant, so every skin and size puts the flame in the right place.
func _hull_half_length() -> float:
	return _sprite.get_rect().size.y * 0.5 * _sprite.scale.y

## Totals from the upgrade shop, applied at the start of a battle.
func apply_run_stats(stats: Dictionary) -> void:
	run_stats = stats.duplicate()
	max_hp = int(stats["max_hp"])
	move_speed = float(stats["move_speed"])
	bullet_damage = int(stats["bullet_damage"])
	bullet_tier = int(stats.get("bullet_tier", 0))
	fire_interval = float(stats["fire_interval"])
	shield_recharge_time = float(stats.get("shield_recharge", 0.0))
	# The floor is 0, not SHIELD_BASE_CAPACITY: SUPERNOVA and above start at
	# capacity 0, where a drop is the only shield until the track reaches level 3.
	shield_capacity = clampi(
		int(stats.get("shield_charges", Tuning.SHIELD_BASE_CAPACITY)),
		0,
		Tuning.MAX_SHIELD_CHARGES
	)
	apply_controls()
	revive()
	set_shields(shield_capacity)


## Reads the schemes from the save. Called at the start of every battle, so a
## change in Settings applies without a restart.
func apply_controls() -> void:
	control_scheme = SaveData.control_scheme
	shield_mode = SaveData.shield_mode


## The two equipped weapons, from SaveData. An empty or unknown id leaves that
## hardpoint silent, which is how the secondary starts before the first buy.
func apply_loadout(primary: StringName, secondary: StringName) -> void:
	weapon_ids[0] = primary
	weapon_ids[1] = secondary
	for slot: int in 2:
		_weapon_intervals[slot] = 0.0
		_weapon_cooldowns[slot] = 0.0
		if Weapons.exists(weapon_ids[slot]):
			_weapon_intervals[slot] = Weapons.interval(weapon_ids[slot], run_stats)


func weapon_id(slot: int) -> StringName:
	if slot < 0 or slot >= weapon_ids.size():
		return &""
	return weapon_ids[slot]


## 1 right after firing, 0 when ready; the HUD bars read this.
func weapon_cooldown_ratio(slot: int) -> float:
	if slot < 0 or slot >= _weapon_intervals.size():
		return 0.0
	var total: float = _weapon_intervals[slot]
	if total <= 0.0:
		return 0.0
	return clampf(_weapon_cooldowns[slot] / total, 0.0, 1.0)


## Hull left over from the previous campaign battle. Applied after
## apply_run_stats(), which already filled the shield: every battle starts with
## the shield full, so the stored count is kept in the save but never starts the
## next fight with spent charges.
func carry_over(stored_hp: int, _stored_shields: int) -> void:
	if stored_hp > 0:
		hp = clampi(stored_hp, 1, max_hp)
		hp_changed.emit(hp, max_hp)
	set_shields(shield_capacity)


## Resets the hull for a new battle (or after a restart).
func revive() -> void:
	alive = true
	visible = true
	hp = max_hp
	_velocity = Vector2.ZERO
	_thrust = 0.0
	_weapon_cooldowns[0] = 0.0
	_weapon_cooldowns[1] = 0.0
	_invulnerable_left = 0.0
	_blink_timer = 0.0
	_shield_flash = 0.0
	_recharge_left = shield_recharge_time
	_since_damage = 0.0
	_shield_active_left = 0.0
	_shield_cooldown_left = 0.0
	shield_timer_changed.emit(0.0)
	_sprite.modulate.a = 1.0
	_flash.modulate.a = 0.0
	hp_changed.emit(hp, max_hp)


## How many charges the shield can hold right now. A mode may start a battle at
## capacity 0, but a drop must still be usable there, so the reachable limit is
## never below SHIELD_PICKUP_MIN_CAPACITY.
func shield_limit() -> int:
	return maxi(shield_capacity, Tuning.SHIELD_PICKUP_MIN_CAPACITY)


func set_shields(charges: int) -> void:
	shields = clampi(charges, 0, shield_limit())
	shields_changed.emit(shields, shield_limit())
	queue_redraw()


## A shield drop: one charge, never above the limit. Works at capacity 0, where
## the first drop gives a real shield. Returns false when the shield is already
## at the limit, so the battle can pay the drop out as energy instead.
func add_shield(amount: int = 1) -> bool:
	if not alive or shields >= shield_limit():
		return false
	set_shields(shields + amount)
	_shield_flash = 0.7
	queue_redraw()
	return true


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
	# MANUAL: the timed bubble eats everything while it is up, and no charge is
	# spent by the hit itself.
	if shield_mode == Tuning.SHIELD_MODE_MANUAL and _shield_active_left > 0.0:
		_shield_flash = 1.0
		_start_invulnerability(Tuning.SHIP_SHIELD_GRACE)
		_play_hit_feedback(Color(0.5, 0.95, 1.0))
		shield_spent.emit()
		return
	if shields > 0:
		set_shields(shields - 1)
		_shield_flash = 1.0
		_recharge_left = shield_recharge_time
		_since_damage = 0.0
		_start_invulnerability(Tuning.SHIP_SHIELD_GRACE)
		_play_hit_feedback(Color(0.5, 0.95, 1.0))
		shield_spent.emit()
		if shields == 0:
			shield_broken.emit()
		return
	_since_damage = 0.0
	# A hit always costs at least one point, whatever the mode's multiplier.
	var dealt: int = maxi(roundi(float(amount) * maxf(damage_scale, 0.0)), 1)
	hp = maxi(hp - dealt, 0)
	hp_changed.emit(hp, max_hp)
	hurt.emit(dealt)
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
	if control_scheme == Tuning.CONTROL_SCHEME_CLASSIC:
		_update_classic_movement(delta)
		return
	# get_vector normalises the result and applies the actions' own deadzones,
	# so a diagonal is exactly as fast as a straight line and a resting stick
	# reads as zero instead of drifting on noise.
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Light inertia: thrust adds speed, exponential drag bleeds it off, and the
	# result is clamped to the hull's top speed. exp(-drag * delta) is
	# frame-rate independent, unlike a per-frame lerp weight.
	_velocity += input * acceleration * delta
	_velocity *= exp(-drag * delta)
	_velocity = _velocity.limit_length(move_speed)
	position += _velocity * delta
	_wrap_position()
	_thrust = lerpf(_thrust, clampf(_velocity.length() / maxf(move_speed, 1.0), 0.0, 1.0), 10.0 * delta)
	_thruster.set_thrust(_thrust)


## Classic flight: left/right turn the hull, thrust pushes along the nose,
## brake bleeds speed toward zero (it never reverses). Same exp() drag, top
## speed and wrap as free aim, and the same thruster, driven by thrust input
## rather than by the current speed.
func _update_classic_movement(delta: float) -> void:
	var turn: float = Input.get_axis("turn_left", "turn_right")
	rotation += turn * Tuning.SHIP_CLASSIC_TURN_RATE * delta
	var forward: Vector2 = Vector2.UP.rotated(rotation)
	var thrust_input: float = Input.get_action_strength("thrust")
	if thrust_input > 0.01 and not Input.is_action_pressed("brake"):
		_velocity += forward * acceleration * thrust_input * delta
	if Input.is_action_pressed("brake"):
		_velocity = _velocity.move_toward(Vector2.ZERO, acceleration * delta)
	_velocity *= exp(-drag * delta)
	_velocity = _velocity.limit_length(move_speed)
	position += _velocity * delta
	_wrap_position()
	_thrust = lerpf(_thrust, clampf(thrust_input, 0.0, 1.0), 10.0 * delta)
	_thruster.set_thrust(_thrust)


## Asteroids-style wrap: the hull only wraps once it has completely left the
## arena, and it re-enters just outside the opposite edge, so nothing pops in
## the middle of the screen. Velocity is untouched, which keeps the drift
## continuous, and the exhaust is restarted so no flame streaks across.
## Bullets and enemy shots keep their own rule (they are freed off screen);
## rocks and fighters also keep their current off-screen behaviour.
func _wrap_position() -> void:
	var half: Vector2 = _sprite.get_rect().size * 0.5 * _sprite.scale
	var gap: float = Tuning.SHIP_WRAP_MARGIN
	var left: float = Tuning.ARENA_LEFT - half.x - gap
	var right: float = Tuning.ARENA_RIGHT + half.x + gap
	var top: float = Tuning.ARENA_TOP - half.y - gap
	var bottom: float = Tuning.ARENA_BOTTOM + half.y + gap
	var wrapped: bool = false
	if position.x < left:
		position.x = right
		wrapped = true
	elif position.x > right:
		position.x = left
		wrapped = true
	if position.y < top:
		position.y = bottom
		wrapped = true
	elif position.y > bottom:
		position.y = top
		wrapped = true
	if wrapped:
		_thruster.snap()

## Three aim sources in priority order: the touch zone, the right stick, the
## mouse. With none of them active the nose keeps its last heading, so a
## keyboard-only player flies and shoots forward.
func _update_aim(delta: float) -> void:
	# Classic has no aim stick and no mouse aim: the nose is the aim, and the
	# next shot goes wherever the hull points.
	if control_scheme == Tuning.CONTROL_SCHEME_CLASSIC:
		aim = Vector2.UP.rotated(rotation)
		return
	if _aim_override.length() > 0.1:
		aim = _aim_override.normalized()
	elif Input.is_action_pressed("aim"):
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if stick.length() > 0.3:
			aim = stick.normalized()
	elif _mouse_active:
		var to_mouse: Vector2 = get_global_mouse_position() - global_position
		# The nose only re-aims once the pointer is a few pixels away from the
		# hull, so a mouse sitting still does not jitter the ship.
		if to_mouse.length() > Tuning.SHIP_AIM_DEADZONE:
			aim = to_mouse.normalized()
	# Framerate-independent smoothing: the hull closes the same fraction of the
	# remaining angle per second at 30, 60 or 144 fps.
	rotation = lerp_angle(
		rotation, aim.angle() + PI * 0.5, 1.0 - exp(-Tuning.SHIP_TURN_RATE * delta)
	)


## Both hardpoints fire along the same aim, each on its own cooldown. A slot
## with no weapon has a zero interval and simply never fires.
func _update_shooting(delta: float) -> void:
	for slot: int in 2:
		_weapon_cooldowns[slot] = maxf(_weapon_cooldowns[slot] - delta, 0.0)
		if _weapon_intervals[slot] <= 0.0 or _weapon_cooldowns[slot] > 0.0:
			continue
		if not Input.is_action_pressed(SHOOT_ACTIONS[slot]):
			continue
		_weapon_cooldowns[slot] = _weapon_intervals[slot]
		weapon_fired.emit(slot, _muzzle(slot), aim)


## The hardpoints sit on either side of the nose, so two simultaneous shots
## visibly come from two different guns.
func _muzzle(slot: int) -> Vector2:
	var side: float = -1.0 if slot == 0 else 1.0
	var lateral: Vector2 = aim.rotated(PI * 0.5) * side * Tuning.WEAPON_MUZZLE_SIDE
	return global_position + aim * Tuning.SHIP_MUZZLE_OFFSET + lateral


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


## Shield bubble with one pip per charge, drawn behind the hull. The bubble
## flashes when a charge is spent or picked up, and the recharge lights the
## ring a little brighter while a new charge is building.
func _draw() -> void:
	# The debug overlay must not depend on a shield being up.
	if Tuning.thruster_debug:
		_draw_thruster_debug()
	var manual_active: bool = _shield_active_left > 0.0
	if shields <= 0 and not manual_active:
		return
	var radius: float = Tuning.SHIELD_BUBBLE_RADIUS
	var charging: bool = shield_recharge_time > 0.0 and shields < shield_limit()
	var glow: float = 0.10 + 0.24 * _shield_flash + (0.04 if charging else 0.0)
	var width: float = 2.0 + 1.5 * _shield_flash
	if manual_active:
		# Last second: the bubble pulses and its rim fades, so the drop is
		# readable without watching the HUD.
		glow += 0.16
		radius += 1.5 * sin(_shield_active_left * 9.0)
		if _shield_active_left < Tuning.SHIELD_LAST_SECOND:
			width = 2.0 + 2.0 * absf(sin(_shield_active_left * 12.0))
	draw_circle(Vector2.ZERO, radius, Color(0.4, 0.9, 1.0, glow))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.5, 0.95, 1.0, 0.8), width, true)
	for index: int in shields:
		var angle: float = -PI * 0.5 + float(index) * (TAU / float(shield_limit()))
		draw_circle(Vector2(cos(angle), sin(angle)) * radius, 2.5, Color(0.75, 1.0, 1.0, 0.9))


## F3 overlay: the hurtbox circle and where the exhaust is anchored. The anchor
## is drawn in the hull's own frame, so a wrong offset is obvious at a glance.
func _draw_thruster_debug() -> void:
	var tint: Color = Tuning.THRUSTER_DEBUG_COLOR
	draw_circle(Vector2.ZERO, Tuning.SHIP_RADIUS, Color(tint.r, tint.g, tint.b, 0.18))
	draw_arc(Vector2.ZERO, Tuning.SHIP_RADIUS, 0.0, TAU, 32, tint, 1.5, true)
	draw_line(Vector2.ZERO, _thruster.position, tint, 1.5)
	draw_circle(_thruster.position, 3.0, tint)
	# The flame's footprint: the row stack hangs behind the tail, and the bars
	# are as wide as the art. Both follow the exhaust's current scale.
	var faint := Color(tint.r, tint.g, tint.b, 0.5)
	var flame_scale: float = _thruster.scale.y
	var reach: float = Tuning.THRUSTER_BAR_ROWS.back() * flame_scale
	var half_width: float = Tuning.THRUSTER_ART_SIZE * 0.5 * flame_scale
	draw_line(_thruster.position, _thruster.position + Vector2(0.0, reach), faint, 1.0)
	draw_line(
		_thruster.position + Vector2(-half_width, 0.0),
		_thruster.position + Vector2(half_width, 0.0),
		faint,
		1.0
	)


## Shield charges: the SHIELDS track recharges one charge after a quiet
## stretch, and any damage restarts the wait. Drop pickups bypass this.
func _update_shields(delta: float) -> void:
	if _shield_flash > 0.0:
		_shield_flash = maxf(_shield_flash - delta * 2.5, 0.0)
		queue_redraw()
	if _shield_cooldown_left > 0.0:
		_shield_cooldown_left = maxf(_shield_cooldown_left - delta, 0.0)
	if _shield_active_left > 0.0:
		_shield_active_left = maxf(_shield_active_left - delta, 0.0)
		shield_timer_changed.emit(_shield_active_left)
		queue_redraw()
		if _shield_active_left <= 0.0:
			_shield_flash = 0.6
			queue_redraw()
	if shield_mode == Tuning.SHIELD_MODE_MANUAL and alive \
			and _shield_active_left <= 0.0 and _shield_cooldown_left <= 0.0 \
			and shields > 0 and Input.is_action_just_pressed("shield"):
		set_shields(shields - 1)
		_shield_active_left = Tuning.SHIELD_ACTIVE_SECONDS
		_shield_cooldown_left = Tuning.SHIELD_COOLDOWN_SECONDS
		_shield_flash = 0.8
		shield_raised.emit()
		shield_timer_changed.emit(_shield_active_left)
		queue_redraw()
	if shield_recharge_time <= 0.0:
		return
	_since_damage += delta
	if shields >= shield_limit() or _since_damage < Tuning.SHIELD_RECHARGE_DAMAGE_DELAY:
		_recharge_left = shield_recharge_time
		return
	_recharge_left -= delta
	if _recharge_left > 0.0:
		return
	_recharge_left = shield_recharge_time
	set_shields(shields + 1)
	_shield_flash = 0.5


# --- Collisions -------------------------------------------------------------

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not alive or is_invulnerable():
		return
	# Fighters are duck-typed on purpose: Ship and EnemyBase would otherwise
	# reference each other's class, which GDScript does not like.
	if area is EnemyBullet:
		var bullet := area as EnemyBullet
		var amount: int = bullet.damage
		# Metadata, not a member: only the debug damage report reads it.
		set_meta("last_damage_source", bullet.source_kind)
		bullet.destroy()
		take_damage(amount)
	elif area is Asteroid:
		var rock := area as Asteroid
		rock.bump()
		set_meta("last_damage_source", &"asteroid")
		take_damage(Tuning.ASTEROID_CONTACT_DAMAGE)
	elif area.has_method("on_player_contact"):
		# Fighters and stations report their own contact damage; anything else
		# falls back to the fighter default.
		var contact: int = Tuning.ENEMY_CONTACT_DAMAGE
		var reported: Variant = area.get("contact_damage")
		if reported is int:
			contact = int(reported)
		var shooter: Variant = area.get("kind")
		set_meta("last_damage_source", StringName(shooter) if shooter is StringName else &"contact")
		area.call("on_player_contact")
		take_damage(contact)
