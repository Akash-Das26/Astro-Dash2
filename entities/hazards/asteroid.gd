class_name Asteroid
extends Area2D
## A drifting rock. Large ones take a few hits and break into tiny debris; tiny
## ones pop. Layer 4 (the hazard bit), mask 0: the ship hurtbox and the player
## bullets detect it, so it needs no references.
##
## It never scores or spawns anything itself: `shattered` tells the battle where
## and how big, and the battle decides whether debris appears.

signal shattered(at: Vector2, was_large: bool)
signal damaged(at: Vector2)

const LARGE_TEXTURE: Texture2D = preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/asteroid_grey.png")
const TINY_TEXTURES: Array[Texture2D] = [
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/asteroid_tiny.png"),
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/asteroid_grey_tiny.png"),
]

@export var large: bool = true

var velocity: Vector2 = Vector2.ZERO

var _hp: int = 1
var _spin: float = 0.0
var _radius: float = Tuning.ASTEROID_LARGE_RADIUS
var _age: float = 0.0
var _active: bool = true

@onready var _sprite: Sprite2D = $Sprite
@onready var _body: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_apply_size()
	_spin = randf_range(Tuning.ASTEROID_SPIN_MIN, Tuning.ASTEROID_SPIN_MAX)
	rotation = randf() * TAU


## Size, art and collider. Called before the rock enters the tree.
func setup(is_large: bool, start_velocity: Vector2, start_position: Vector2) -> void:
	large = is_large
	velocity = start_velocity
	position = start_position


func _apply_size() -> void:
	_hp = Tuning.ASTEROID_LARGE_HP if large else 1
	_radius = Tuning.ASTEROID_LARGE_RADIUS if large else Tuning.ASTEROID_TINY_RADIUS
	var art_scale: float = Tuning.ASTEROID_LARGE_SCALE if large else Tuning.ASTEROID_TINY_SCALE
	_sprite.texture = LARGE_TEXTURE if large else TINY_TEXTURES[randi() % TINY_TEXTURES.size()]
	_sprite.scale = Vector2.ONE * art_scale
	var shape := CircleShape2D.new()
	shape.radius = _radius
	_body.shape = shape


func _process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	position += velocity * delta
	rotation += _spin * delta
	if _is_outside():
		queue_free()


func _is_outside() -> bool:
	const EDGE: float = 140.0
	return position.x < -EDGE or position.x > Tuning.VIEW_SIZE.x + EDGE \
		or position.y < Tuning.ARENA_TOP - EDGE or position.y > Tuning.ARENA_BOTTOM + EDGE


func take_damage(amount: int) -> void:
	if not _active:
		return
	_hp -= amount
	damaged.emit(global_position)
	_flash()
	if _hp > 0:
		return
	_active = false
	shattered.emit(global_position, large)
	queue_free()


## The ship bumped into this rock: nudge it away instead of removing it.
func bump() -> void:
	if not _active:
		return
	velocity = -velocity.rotated(randf_range(-0.5, 0.5)) * 0.8
	_flash()
	_active = false
	_shattered_without_debris()
	queue_free()


func _shattered_without_debris() -> void:
	# A ram does not drop debris: it already cost the player hull.
	shattered.emit(global_position, false)


func _flash() -> void:
	_sprite.modulate = Color(2.0, 2.0, 2.0)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)
