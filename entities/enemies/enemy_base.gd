class_name EnemyBase
extends Area2D
## Shared behaviour for every enemy: hp, score value, hit flash, contact
## reporting and boundary detection. Subclasses override _move() (and any
## attack pattern); nothing else needs to be duplicated per enemy type.

signal died(points: int)
signal reached_boundary(enemy: EnemyBase)
signal damaged(at: Vector2)

## Collision layer 4 (the Boundary bar) as a bit mask.
const BOUNDARY_LAYER_BIT: int = 1 << 3
const PLAY_AREA_WIDTH: float = 400.0

@export var max_hp: int = 1
@export var speed: float = 80.0
@export var points: int = 10
@export var spawn_margin: float = 16.0
@export var spawn_y: float = -20.0
## Bosses leave the screen without costing the player a life.
@export var costs_life_on_boundary: bool = true
@export var is_boss: bool = false
@export var hit_flash_time: float = 0.12
## Tints this type's hit sparks and death burst.
@export var effect_color: Color = Color(1.0, 0.45, 0.3)

@onready var _sprite: Sprite2D = $Sprite
@onready var _flash: Sprite2D = $FlashSprite

var hp: int
var spawn_center_x: float
var _active: bool = true
var _flash_tween: Tween


func _ready() -> void:
	hp = max_hp
	spawn_center_x = randf_range(spawn_margin, PLAY_AREA_WIDTH - spawn_margin)
	position = Vector2(spawn_center_x, spawn_y)
	_sync_flash_sprite()
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if not _active:
		return
	_move(delta)


## Virtual: how this enemy travels. Overridden by zigzag / diver / boss.
func _move(delta: float) -> void:
	position.y += speed * delta


func take_damage(amount: int) -> void:
	if not _active:
		return
	hp -= amount
	damaged.emit(global_position)
	if hp <= 0:
		die()
	else:
		_flash_hit()


## Killed by bullets or a bomb: awards points.
func die() -> void:
	if not _active:
		return
	_active = false
	died.emit(points)
	queue_free()


## Removed without awarding points (rammed the player ship, cleared pickup).
func destroy() -> void:
	if not _active:
		return
	_active = false
	queue_free()


## Contact with the player ship. Base enemies are destroyed on impact;
## the boss overrides this to stay alive.
func on_player_contact() -> void:
	destroy()


func _sync_flash_sprite() -> void:
	# The flash overlay mirrors the sprite so subclasses only override Sprite.
	_flash.texture = _sprite.texture
	_flash.position = _sprite.position
	_flash.rotation = _sprite.rotation
	_flash.scale = _sprite.scale
	_flash.modulate.a = 0.0


func _flash_hit() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.modulate.a = 0.9
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, hit_flash_time)


func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if (area.collision_layer & BOUNDARY_LAYER_BIT) == 0:
		return
	_active = false
	reached_boundary.emit(self)
	queue_free()
