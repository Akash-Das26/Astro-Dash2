class_name Explosion
extends CPUParticles2D
## One-shot square-pixel burst, freed when it finishes. CPUParticles2D (not GPU)
## because the Web export runs without threads and on the Compatibility
## renderer. A particle is a plain square, which is exactly the pixel look we
## want; the ramp starts white and cools into the caller's tint.
##
## GameManager keeps a cap on how many of these can exist at once.

@export var tint: Color = Color(1.0, 0.45, 0.3)
@export var particle_count: int = Tuning.EXPLOSION_PARTICLES
@export var size_scale: float = 1.0
@export var life_time: float = Tuning.EXPLOSION_LIFE


func _ready() -> void:
	modulate = Color.WHITE
	amount = maxi(particle_count, 1)
	lifetime = life_time
	explosiveness = 0.92
	spread = 180.0
	gravity = Vector2.ZERO
	initial_velocity_min = 30.0 * size_scale
	initial_velocity_max = 150.0 * size_scale
	scale_amount_min = 2.0 * size_scale
	scale_amount_max = 4.0 * size_scale
	color_initial_ramp = _ramp([Color(1.0, 1.0, 1.0, 1.0), tint])
	color_ramp = _ramp([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0)])
	finished.connect(queue_free)
	emitting = true


func _ramp(colors: Array) -> Gradient:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var ramp := PackedColorArray()
	for index: int in colors.size():
		offsets.append(float(index) / float(maxi(colors.size() - 1, 1)))
		ramp.append(colors[index])
	gradient.offsets = offsets
	gradient.colors = ramp
	return gradient
