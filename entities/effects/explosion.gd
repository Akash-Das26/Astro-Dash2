class_name Explosion
extends CPUParticles2D
## One-shot pixel burst, freed when it finishes. CPUParticles2D (not GPU)
## because the Web export runs without threads and the Compatibility renderer.
## GameManager caps how many of these can exist at once.

@export var tint: Color = Color(1.0, 0.65, 0.35)
@export var particle_count: int = 14
@export var size_scale: float = 1.0
@export var life_time: float = 0.5


func _ready() -> void:
	modulate = tint
	amount = maxi(particle_count, 1)
	lifetime = life_time
	scale_amount_min = 2.0 * size_scale
	scale_amount_max = 3.5 * size_scale
	finished.connect(queue_free)
	emitting = true
