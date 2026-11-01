class_name EnemyBullet
extends Area2D
## Fighter projectile: a drawn red/orange diamond with a white core, a pulsing
## halo and a short fading trail. Deliberately unlike the player's long laser
## bolts. Layer 5 with an empty mask on purpose, because the ship's hurtbox
## detects it and it never needs a reference back to the ship.
##
## Two flags come from the battle: `high_contrast` is the settings toggle, and
## `hot_backdrop` marks the red band, where the outline turns yellow-white so
## the shot stays readable against the background.

@export var speed: float = Tuning.ENEMY_BULLET_SPEED
@export var damage: int = Tuning.ENEMY_BULLET_DAMAGE
@export var life_time: float = Tuning.ENEMY_BULLET_LIFE
@export var high_contrast: bool = true
@export var hot_backdrop: bool = false
## Which fighter fired this. Only used for the damage report and for the bot's
## balance run; nothing in the game reads it.
@export var source_kind: StringName = &""

var direction: Vector2 = Vector2.DOWN

var _age: float = 0.0

@onready var _body_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	rotation = direction.angle() + PI * 0.5
	# Per-instance shape, sized from Tuning, and a touch smaller than the art.
	var shape := CircleShape2D.new()
	shape.radius = Tuning.ENEMY_BULLET_HITBOX_RADIUS
	_body_shape.shape = shape
	queue_redraw()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_age += delta
	if _age >= life_time or not _on_screen():
		queue_free()
		return
	queue_redraw()


func _on_screen() -> bool:
	const EDGE: float = 60.0
	return position.x > -EDGE and position.x < Tuning.VIEW_SIZE.x + EDGE \
		and position.y > Tuning.ARENA_TOP - EDGE and position.y < Tuning.ARENA_BOTTOM + EDGE


func destroy() -> void:
	queue_free()


## The halo, the trail, the diamond body and its outline, then the white core.
## Local -Y is the travel direction after _ready() rotates the node.
func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_age * Tuning.ENEMY_BULLET_GLOW_PULSE)
	var radius: float = Tuning.ENEMY_BULLET_VISUAL_RADIUS
	var outline: Color = Tuning.ENEMY_BULLET_OUTLINE_HOT if hot_backdrop \
		else Tuning.ENEMY_BULLET_OUTLINE
	var width: float = Tuning.ENEMY_BULLET_OUTLINE_WIDTH_HIGH if high_contrast \
		else Tuning.ENEMY_BULLET_OUTLINE_WIDTH
	var glow_alpha: float = (0.16 if high_contrast else 0.10) + 0.06 * pulse
	draw_circle(Vector2.ZERO, radius * (1.9 + 0.15 * pulse), Color(1.0, 0.3, 0.2, glow_alpha))
	var trail_count: int = Tuning.ENEMY_BULLET_TRAIL_SEGMENTS
	for index: int in trail_count:
		var falloff: float = 1.0 - float(index) / float(maxi(trail_count, 1))
		var at := Vector2(0.0, Tuning.ENEMY_BULLET_TRAIL_SPACING * float(index + 1))
		draw_circle(at, radius * 0.55 * falloff, Color(1.0, 0.35, 0.25, 0.22 * falloff))
	var diamond: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -radius),
		Vector2(radius, 0.0),
		Vector2(0.0, radius),
		Vector2(-radius, 0.0),
	])
	draw_colored_polygon(diamond, Tuning.ENEMY_BULLET_BODY)
	var closed: PackedVector2Array = PackedVector2Array([
		diamond[0], diamond[1], diamond[2], diamond[3], diamond[0],
	])
	draw_polyline(closed, outline, width, true)
	if high_contrast:
		draw_arc(
			Vector2.ZERO, radius + width, 0.0, TAU, 24,
			Color(outline.r, outline.g, outline.b, 0.55), width, true
		)
	draw_circle(
		Vector2.ZERO,
		Tuning.ENEMY_BULLET_CORE_RADIUS * (1.0 + 0.2 * pulse),
		Tuning.ENEMY_BULLET_CORE
	)
