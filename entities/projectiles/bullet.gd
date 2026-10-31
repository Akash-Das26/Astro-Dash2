class_name Bullet
extends Node2D
## Player projectile, driven entirely by the weapon table. It flies along the
## direction the muzzle was aiming at, which is what lets the ship fire anywhere
## on screen. Layer 2, mask 12: it reacts to fighters, stations and asteroids,
## and to nothing else.
##
## Every visual and behaviour flag comes from Weapons.entry(): a pulse bolt, a
## fat cannon slug, a short scatter pellet, a piercing rail lance or a homing
## missile that bursts. With no override the sprite follows the fire-power tier
## (blue, green, yellow), which is what the PULSE LASER wants.

const LASERS: Array[Texture2D] = [
	preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_laser_blue.png"),
	preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_laser_green.png"),
	preload("res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_laser_yellow.png"),
]

## A splash weapon landed: the battle spreads the damage around `at`.
signal area_hit(at: Vector2, radius: float, damage: int)

@export var speed: float = Tuning.SHIP_BULLET_SPEED
@export var damage: int = Tuning.SHIP_BULLET_DAMAGE
@export var life_time: float = Tuning.SHIP_BULLET_LIFE
## 0 blue, 1 green, 2 yellow; only the pulse laser still uses it.
@export var tier: int = 0
@export var pierce: int = 0
@export var homing: float = 0.0
@export var area_radius: float = 0.0
@export var knockback: float = 0.0
@export var scale_factor: float = 0.36
@export var tint: Color = Color.WHITE

var direction: Vector2 = Vector2.UP
var texture_override: Texture2D
## Weakly typed on purpose: the battle may free the target before the shot lands.
var homing_target: Node2D

var _age: float = 0.0
## Instance ids already hit, so a piercing shot damages each target once.
var _hits: Array[int] = []

@onready var _sprite: Sprite2D = $BulletSprite
@onready var _hitbox: Area2D = $BulletArea


func _ready() -> void:
	# The laser art points up, so rotate it onto the travel direction.
	rotation = direction.angle() + PI * 0.5
	var texture: Texture2D = texture_override
	if texture == null:
		texture = LASERS[clampi(tier, 0, LASERS.size() - 1)]
	_sprite.texture = texture
	_sprite.modulate = tint
	_sprite.scale = Vector2.ONE * scale_factor
	_hitbox.area_entered.connect(_on_hitbox_area_entered)
	# The hitbox is a fair size for every weapon: slightly smaller than the art.
	var shape := CircleShape2D.new()
	shape.radius = maxf(4.0, 7.0 * scale_factor / 0.36)
	(_hitbox.get_node("CollisionShape2D") as CollisionShape2D).shape = shape


func _physics_process(delta: float) -> void:
	if homing > 0.0 and homing_target != null and is_instance_valid(homing_target):
		var to_target: Vector2 = homing_target.global_position - global_position
		if to_target.length() > 1.0:
			direction = direction.lerp(to_target.normalized(), clampf(homing * delta, 0.0, 1.0)).normalized()
			rotation = direction.angle() + PI * 0.5
	position += direction * speed * delta
	_age += delta
	if _age >= life_time or not _on_screen():
		queue_free()


func _on_screen() -> bool:
	const EDGE: float = 48.0
	return position.x > -EDGE and position.x < Tuning.VIEW_SIZE.x + EDGE \
		and position.y > Tuning.ARENA_TOP - EDGE and position.y < Tuning.ARENA_BOTTOM + EDGE


func _on_hitbox_area_entered(area: Area2D) -> void:
	if not is_instance_valid(area):
		return
	if not (area is EnemyBase or area is BossStation or area is Asteroid):
		return
	var id: int = area.get_instance_id()
	if _hits.has(id):
		return
	_hits.append(id)
	area.call("take_damage", damage)
	if knockback > 0.0 and area.has_method("apply_knockback"):
		area.call("apply_knockback", direction, knockback)
	if area_radius > 0.0:
		area_hit.emit(global_position, area_radius, damage)
	if pierce > 0:
		pierce -= 1
		return
	queue_free()
