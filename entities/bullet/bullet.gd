class_name Bullet
extends Node2D
## Player projectile. It flies along the direction the muzzle was aiming at,
## which is what lets the ship fire anywhere on screen. Layer 2, mask 12: it
## reacts to fighters and to asteroids and to nothing else.

@export var speed: float = Tuning.SHIP_BULLET_SPEED
@export var damage: int = Tuning.SHIP_BULLET_DAMAGE
@export var life_time: float = Tuning.SHIP_BULLET_LIFE

var direction: Vector2 = Vector2.UP

var _age: float = 0.0

@onready var _hitbox: Area2D = $BulletArea


func _ready() -> void:
	# The laser art points up, so rotate it onto the travel direction.
	rotation = direction.angle() + PI * 0.5
	_hitbox.area_entered.connect(_on_hitbox_area_entered)


func _physics_process(delta: float) -> void:
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
	if area is EnemyBase:
		(area as EnemyBase).take_damage(damage)
	elif area is Asteroid:
		(area as Asteroid).take_damage(damage)
	else:
		return
	queue_free()
