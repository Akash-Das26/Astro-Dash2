class_name EnemyBullet
extends Area2D
## Fighter projectile: a small red dot that flies on a fixed heading. It sits on
## layer 5 with an empty mask on purpose, because the ship's hurtbox detects it
## and it never needs a reference back to the ship.

@export var speed: float = Tuning.ENEMY_BULLET_SPEED
@export var damage: int = Tuning.ENEMY_BULLET_DAMAGE
@export var life_time: float = Tuning.ENEMY_BULLET_LIFE

var direction: Vector2 = Vector2.DOWN

var _age: float = 0.0


func _ready() -> void:
	rotation = direction.angle() + PI * 0.5


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_age += delta
	if _age >= life_time or not _on_screen():
		queue_free()


func _on_screen() -> bool:
	const EDGE: float = 60.0
	return position.x > -EDGE and position.x < Tuning.VIEW_SIZE.x + EDGE \
		and position.y > Tuning.ARENA_TOP - EDGE and position.y < Tuning.ARENA_BOTTOM + EDGE


func destroy() -> void:
	queue_free()
