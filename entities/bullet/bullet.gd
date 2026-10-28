class_name Bullet
extends Node2D
## Player projectile. Collides with the enemy layer only (see the collision
## layers table in game_manager.gd) and damages whatever enemy it touches.

@export var bullet_speed: float = 300.0
@export var damage: int = 1
@export var despawn_y: float = -20.0

@onready var _hitbox: Area2D = $BulletArea


func _ready() -> void:
	_hitbox.area_entered.connect(_on_hitbox_area_entered)


func _process(delta: float) -> void:
	position.y -= bullet_speed * delta
	if position.y < despawn_y:
		queue_free()


func _on_hitbox_area_entered(area: Area2D) -> void:
	if not is_instance_valid(area) or not area is Enemy:
		return
	(area as Enemy).take_damage(damage)
	queue_free()
