class_name Bullet
extends Node2D
## Player projectile. Collides with the enemy layer only (see the collision
## layers table in game_manager.gd) and damages whatever enemy it touches.
## Travelling along `direction` is what makes spread shot possible.

@export var bullet_speed: float = 300.0
@export var damage: int = 1
@export var despawn_y: float = -20.0
@export var despawn_x: float = 20.0

var direction: Vector2 = Vector2.UP

@onready var _hitbox: Area2D = $BulletArea


func _ready() -> void:
	# The laser sprite points up, so rotate it onto the travel direction.
	rotation = direction.angle() + PI * 0.5
	_hitbox.area_entered.connect(_on_hitbox_area_entered)


func _process(delta: float) -> void:
	position += direction * bullet_speed * delta
	if position.y < despawn_y or position.x < -despawn_x or position.x > 400.0 + despawn_x:
		queue_free()


func _on_hitbox_area_entered(area: Area2D) -> void:
	if not is_instance_valid(area) or not area is EnemyBase:
		return
	(area as EnemyBase).take_damage(damage)
	queue_free()
