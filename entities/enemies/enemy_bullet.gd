class_name EnemyBullet
extends Area2D
## Boss projectile. It sits on layer 5 with an empty mask on purpose: the
## player's hurtbox detects it, so it never needs a reference to the player.

@export var speed: float = 170.0

var direction: Vector2 = Vector2.DOWN


func _ready() -> void:
	rotation = direction.angle() + PI * 0.5


func _process(delta: float) -> void:
	position += direction * speed * delta
	if position.y > 660.0 or position.y < -60.0 or position.x < -60.0 or position.x > 460.0:
		queue_free()


func destroy() -> void:
	queue_free()
