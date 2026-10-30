class_name MenuBackdrop
extends Node2D
## The animated main-menu background: ships with live thrusters crossing the
## screen, rocks tumbling past, one large asteroid on the left and the warpgate
## frames breathing behind the title. All of it is existing sprite art, moved
## with simple sine drift so the front end costs nothing.

const SHIP_TEXTURES: Array[Texture2D] = [
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship_blue.png"),
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship_green_small_2.png"),
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship_yellow.png"),
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship_red.png"),
]
const ROCK_TEXTURES: Array[Texture2D] = [
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/asteroid_grey.png"),
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_asteroid.png"),
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/asteroid_tiny.png"),
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/asteroid_grey_tiny.png"),
]
const WARP_FRAMES: Array[Texture2D] = [
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/warpgate_1.png"),
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/warpgate_2.png"),
	preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/warpgate_3.png"),
]
const THRUSTER_SCENE: PackedScene = preload("res://entities/fx/thruster.tscn")
const WARP_FPS: float = 9.0
const SHIP_COUNT: int = 4
const ROCK_COUNT: int = 5
const BIG_ROCK_POSITION: Vector2 = Vector2(64.0, 438.0)
const BIG_ROCK_SCALE: float = 5.4
const GATE_POSITION: Vector2 = Vector2(742.0, 292.0)
const GATE_SCALE: float = 1.5
## How far off screen a drifting sprite starts before it wraps.
const WRAP_MARGIN: float = 180.0

var _ships: Array[Dictionary] = []
var _rocks: Array[Dictionary] = []
var _big_rock: Sprite2D
var _gate: AnimatedSprite2D
var _age: float = 0.0


func _ready() -> void:
	_build_gate()
	_build_big_rock()
	_build_ships()
	_build_rocks()


func _process(delta: float) -> void:
	_age += delta
	var width: float = Tuning.VIEW_SIZE.x
	for ship: Dictionary in _ships:
		var node: Sprite2D = ship["node"]
		node.position.x += float(ship["speed"]) * float(ship["direction"]) * delta
		node.position.y = float(ship["base_y"]) + sin(_age * 0.8 + float(ship["phase"])) * 14.0
		if float(ship["direction"]) > 0.0 and node.position.x > width + WRAP_MARGIN:
			node.position.x = -WRAP_MARGIN
		elif float(ship["direction"]) < 0.0 and node.position.x < -WRAP_MARGIN:
			node.position.x = width + WRAP_MARGIN
	for rock: Dictionary in _rocks:
		var node: Sprite2D = rock["node"]
		node.position.x += float(rock["speed"]) * float(rock["direction"]) * delta
		node.rotation += float(rock["spin"]) * delta
		if float(rock["direction"]) > 0.0 and node.position.x > width + WRAP_MARGIN:
			node.position.x = -WRAP_MARGIN
		elif float(rock["direction"]) < 0.0 and node.position.x < -WRAP_MARGIN:
			node.position.x = width + WRAP_MARGIN
	_big_rock.rotation += 0.035 * delta
	_gate.modulate.a = 0.22 + 0.12 * (0.5 + 0.5 * sin(_age * 0.9))


func _build_gate() -> void:
	_gate = AnimatedSprite2D.new()
	_gate.name = "Warpgate"
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"warp")
	frames.set_animation_speed(&"warp", WARP_FPS)
	frames.set_animation_loop(&"warp", true)
	for texture: Texture2D in WARP_FRAMES:
		frames.add_frame(&"warp", texture)
	_gate.sprite_frames = frames
	_gate.animation = &"warp"
	_gate.scale = Vector2.ONE * GATE_SCALE
	_gate.position = GATE_POSITION
	_gate.modulate = Color(0.7, 0.9, 1.0, 0.3)
	_gate.play()
	add_child(_gate)


func _build_big_rock() -> void:
	_big_rock = Sprite2D.new()
	_big_rock.name = "BigAsteroid"
	_big_rock.texture = ROCK_TEXTURES[1]
	_big_rock.scale = Vector2.ONE * BIG_ROCK_SCALE
	_big_rock.position = BIG_ROCK_POSITION
	_big_rock.modulate = Color(0.7, 0.74, 0.86, 0.55)
	add_child(_big_rock)


func _build_ships() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5EED
	for index: int in SHIP_COUNT:
		var ship := Sprite2D.new()
		ship.name = "DriftingShip%d" % index
		ship.texture = SHIP_TEXTURES[index % SHIP_TEXTURES.size()]
		ship.scale = Vector2.ONE * 0.42
		var direction: float = 1.0 if index % 2 == 0 else -1.0
		ship.position = Vector2(
			rng.randf_range(120.0, Tuning.VIEW_SIZE.x - 80.0),
			rng.randf_range(96.0, Tuning.VIEW_SIZE.y - 90.0)
		)
		# The art points up; turn the hull onto its travel direction.
		ship.rotation = PI * 0.5 * direction
		ship.modulate = Color(1.0, 1.0, 1.0, 0.7)
		add_child(ship)
		var thruster := THRUSTER_SCENE.instantiate() as Thruster
		thruster.position = Vector2(0.0, 16.0)
		thruster.set_base_scale(Vector2(0.85, 0.85))
		ship.add_child(thruster)
		thruster.set_thrust(0.85)
		_ships.append({
			"node": ship,
			"speed": rng.randf_range(34.0, 78.0),
			"direction": direction,
			"base_y": ship.position.y,
			"phase": rng.randf_range(0.0, TAU),
		})


func _build_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xA57E
	for index: int in ROCK_COUNT:
		var rock := Sprite2D.new()
		rock.name = "DriftingRock%d" % index
		rock.texture = ROCK_TEXTURES[index % ROCK_TEXTURES.size()]
		rock.scale = Vector2.ONE * rng.randf_range(0.7, 1.8)
		var direction: float = 1.0 if index % 2 == 0 else -1.0
		rock.position = Vector2(
			rng.randf_range(80.0, Tuning.VIEW_SIZE.x - 80.0),
			rng.randf_range(70.0, Tuning.VIEW_SIZE.y - 60.0)
		)
		rock.rotation = rng.randf_range(0.0, TAU)
		rock.modulate = Color(1.0, 1.0, 1.0, 0.42)
		add_child(rock)
		_rocks.append({
			"node": rock,
			"speed": rng.randf_range(14.0, 40.0),
			"direction": direction,
			"spin": rng.randf_range(-0.5, 0.5),
		})
