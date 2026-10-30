class_name ShieldPickup
extends Area2D
## A shield charge drop: a drawn blue bubble that drifts down and bobs. Layer 6
## (bit 32), mask 1: the ship's hurtbox is what detects it, so the pickup never
## needs a reference back to the ship. BattleGame owns spawning and collection
## and only hears the `collected` signal.
##
## It is an Area2D, so it is always added deferred when it comes out of a
## damage callback.

signal collected

var _age: float = 0.0
var _drift: float = 0.0
var _bob: float = 0.0

@onready var _body: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = Tuning.SHIELD_DROP_RADIUS
	_body.shape = shape
	_drift = randf_range(-Tuning.SHIELD_DROP_DRIFT, Tuning.SHIELD_DROP_DRIFT)
	_bob = randf_range(0.0, TAU)
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_age += delta
	position.y += Tuning.SHIELD_DROP_FALL_SPEED * delta
	position.x += _drift * delta
	if _age >= Tuning.SHIELD_DROP_LIFE or position.y > Tuning.ARENA_BOTTOM + 40.0:
		queue_free()
		return
	queue_redraw()


## A soft halo, the bubble, a highlight stroke and a bright centre, so it reads
## as the same art as the shield around the hull.
func _draw() -> void:
	var radius: float = Tuning.SHIELD_DROP_VISUAL_RADIUS
	var pulse: float = 0.5 + 0.5 * sin(_age * 4.0 + _bob)
	draw_circle(Vector2.ZERO, radius * (1.5 + 0.12 * pulse), Color(0.35, 0.8, 1.0, 0.12 + 0.08 * pulse))
	draw_circle(Vector2.ZERO, radius, Color(0.25, 0.55, 0.85, 0.45))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(0.65, 0.95, 1.0, 0.95), 2.0, true)
	draw_arc(
		Vector2(-2.0, -2.0), radius * 0.45, PI * 1.1, PI * 1.75, 12,
		Color(0.85, 1.0, 1.0, 0.8), 2.0, true
	)
	draw_circle(Vector2.ZERO, 2.4, Color(0.9, 1.0, 1.0, 0.95))


func _on_area_entered(area: Area2D) -> void:
	if not area is Ship:
		return
	collected.emit()
	queue_free()
