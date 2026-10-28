class_name Enemy
extends Area2D
## Base enemy: drifts straight down, survives `max_hp` bullet hits and tells
## the rest of the game about its fate through signals. Movement variants
## (zigzag, diver, boss) are meant to override the movement step only.

signal died(points: int)
signal reached_boundary

## Collision layer 4 (the Boundary bar) as a bit mask.
const BOUNDARY_LAYER_BIT: int = 1 << 3
const PLAY_AREA_WIDTH: float = 400.0

@export var speed: float = 80.0
@export var max_hp: int = 1
@export var score_value: int = 10
@export var spawn_margin: float = 16.0
@export var spawn_y: float = -20.0

var hp: int


func _ready() -> void:
	hp = max_hp
	position = Vector2(randf_range(spawn_margin, PLAY_AREA_WIDTH - spawn_margin), spawn_y)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	move_step(delta)


## Override in subclasses for zigzag / homing / diver movement.
func move_step(delta: float) -> void:
	position.y += speed * delta


func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp -= amount
	if hp <= 0:
		die()


func die() -> void:
	died.emit(score_value)
	queue_free()


## Removed without awarding points (rammed the player ship).
func destroy() -> void:
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if (area.collision_layer & BOUNDARY_LAYER_BIT) == 0:
		return
	reached_boundary.emit()
	queue_free()
