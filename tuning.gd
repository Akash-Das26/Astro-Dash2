class_name Tuning
extends RefCounted
## One place for the numbers that decide the arena, the pacing, the economy
## and the combo. Nothing in the game logic depends on the exact values, so
## this file is meant to be edited while balancing; see the "Balancing"
## section of the README.

# --- Screen and arena -------------------------------------------------------
## Design resolution of the landscape canvas. Everything is authored at this
## size and stretched with canvas_items + keep.
const VIEW_SIZE: Vector2 = Vector2(960.0, 600.0)
## Translucent readout bars at the very top and bottom of the screen.
const HUD_BAR_HEIGHT: float = 24.0
const ARENA_LEFT: float = 0.0
const ARENA_RIGHT: float = VIEW_SIZE.x
const ARENA_TOP: float = HUD_BAR_HEIGHT
const ARENA_BOTTOM: float = VIEW_SIZE.y - HUD_BAR_HEIGHT
## Keep-out band inside the arena, so nothing spawns half off screen.
const ARENA_MARGIN: float = 36.0

# --- Ship -------------------------------------------------------------------
const SHIP_MAX_HP: int = 100
const SHIP_ACCELERATION: float = 1500.0
const SHIP_MAX_SPEED: float = 400.0
## Higher coasts less: the ship keeps a little inertia but stops in ~0.4s.
const SHIP_DRAG: float = 3.4
## How fast the hull swings onto the aim direction (per second, 0..1 lerp).
const SHIP_TURN_LERP: float = 12.0
const SHIP_FIRE_INTERVAL: float = 0.14
const SHIP_BULLET_SPEED: float = 720.0
const SHIP_BULLET_DAMAGE: int = 1
const SHIP_BULLET_LIFE: float = 1.4
const SHIP_SPAWN_POSITION: Vector2 = Vector2(480.0, 480.0)
const SHIP_RADIUS: float = 14.0
## Distance from the hull centre where a shot leaves the muzzle.
const SHIP_MUZZLE_OFFSET: float = 24.0
const SHIP_INVULNERABILITY: float = 0.9
const SHIP_SHIELD_GRACE: float = 0.4
const SHIP_BLINK_INTERVAL: float = 0.08
const SHIP_BLINK_ALPHA: float = 0.3
const MAX_SHIELD_CHARGES: int = 3

# --- Thrusters --------------------------------------------------------------
const THRUSTER_FRAME_FPS: float = 18.0
## Exhaust size and brightness at idle and at full speed.
const THRUSTER_IDLE_SCALE: float = 0.7
const THRUSTER_FULL_SCALE: float = 1.35
const THRUSTER_MIN_VISIBLE: float = 0.06

# --- Enemies ----------------------------------------------------------------
## One row per fighter type. `orbit_radius` is how far it tries to sit from the
## ship, `fire_interval` 0 means it never shoots, and `aim_error` is the random
## spread (radians) added to each shot so a gunner is not a sniper.
const ENEMY_TYPES: Dictionary = {
	&"scout": {
		"hp": 2, "speed": 200.0, "points": 20, "radius": 11.0,
		"orbit_radius": 0.0, "fire_interval": 0.0, "bullet_speed": 0.0,
		"aim_error": 0.0, "effect_color": Color(0.45, 0.8, 1.0),
	},
	&"gunner": {
		"hp": 4, "speed": 130.0, "points": 35, "radius": 14.0,
		"orbit_radius": 230.0, "fire_interval": 1.7, "bullet_speed": 260.0,
		"aim_error": 0.12, "effect_color": Color(1.0, 0.5, 0.35),
	},
	&"heavy": {
		"hp": 12, "speed": 85.0, "points": 80, "radius": 20.0,
		"orbit_radius": 280.0, "fire_interval": 2.3, "bullet_speed": 220.0,
		"aim_error": 0.2, "effect_color": Color(0.85, 0.55, 1.0),
	},
}
const ENEMY_CONTACT_DAMAGE: int = 20
const ENEMY_BULLET_DAMAGE: int = 12
const ENEMY_BULLET_SPEED: float = 260.0
const ENEMY_BULLET_LIFE: float = 4.0
const ENEMY_BULLET_RADIUS: float = 5.0
## How far past the ship a fighter starts to swing onto its orbit.
const ENEMY_APPROACH_SLACK: float = 40.0
## Sideways speed relative to `speed` while orbiting.
const ENEMY_ORBIT_SPEED_RATIO: float = 0.75
## Time the warpgate plays before a fighter is solid and can act.
const ENEMY_WARP_TIME: float = 0.45
## The 200px warpgate sprite is drawn at this scale (~48px).
const WARP_SCALE: float = 0.24
const WARP_FRAME_FPS: float = 12.0

# --- Asteroids --------------------------------------------------------------
const ASTEROID_LARGE_SCALE: float = 0.72
const ASTEROID_TINY_SCALE: float = 0.6
const ASTEROID_LARGE_RADIUS: float = 32.0
const ASTEROID_TINY_RADIUS: float = 9.0
const ASTEROID_LARGE_HP: int = 3
const ASTEROID_CONTACT_DAMAGE: int = 15
const ASTEROID_SPEED_MIN: float = 34.0
const ASTEROID_SPEED_MAX: float = 96.0
const ASTEROID_SPIN_MIN: float = -1.1
const ASTEROID_SPIN_MAX: float = 1.1
## A large rock breaks into this many tiny ones when shot down.
const ASTEROID_SPLIT_MIN: int = 2
const ASTEROID_SPLIT_MAX: int = 3
const ASTEROID_MAX_LIVE: int = 16
## Seconds between drift-in rocks at density 1.0; higher density = shorter.
const ASTEROID_SPAWN_INTERVAL: float = 2.4
## Rocks start this far outside the screen edge.
const ASTEROID_SPAWN_OFFSET: float = 70.0

# --- Waves ------------------------------------------------------------------
const WAVE_GAP: float = 2.2
## Gap between two fighters of the same wave.
const SPAWN_STAGGER: float = 0.4
## A fighter spends this long between its own decision updates.
const ENEMY_THINK_INTERVAL: float = 0.25

# --- Battle presets ---------------------------------------------------------
## A Battle resource is built from one of these rows (see battle.gd). `mix` is
## { fighter kind: how many of the wave's enemies are that kind } and
## `asteroid_density` scales the drift-in rate (0 turns rocks off).
const BATTLES: Dictionary = {
	&"debug": {
		"title": "DEBUG 1 WAVE",
		"waves": 1,
		"enemies_per_wave": 10,
		"mix": {&"scout": 6, &"gunner": 3, &"heavy": 1},
		"asteroid_density": 0.6,
		"background": preload("res://assests/background-black.png"),
	},
	&"tier1": {
		"title": "DRIFT BELT",
		"waves": 2,
		"enemies_per_wave": 8,
		"mix": {&"scout": 5, &"gunner": 3},
		"asteroid_density": 0.7,
		"background": preload("res://assests/background-black.png"),
	},
	&"tier2": {
		"title": "CINDER RUN",
		"waves": 3,
		"enemies_per_wave": 10,
		"mix": {&"scout": 4, &"gunner": 4, &"heavy": 2},
		"asteroid_density": 1.0,
		"background": preload("res://assests/background-black.png"),
	},
	&"tier3": {
		"title": "THE NEXUS",
		"waves": 3,
		"enemies_per_wave": 12,
		"mix": {&"scout": 4, &"gunner": 5, &"heavy": 3},
		"asteroid_density": 1.4,
		"background": preload("res://assests/background-black.png"),
	},
}
## The battle the main scene starts (campaign selection arrives with the map).
const DEFAULT_BATTLE: StringName = &"tier1"
## Debug harness: a single wave of ten enemies.
const DEBUG_BATTLE: StringName = &"debug"

# --- Combo ------------------------------------------------------------------
## Seconds a kill keeps the chain alive; every kill resets the clock.
const COMBO_WINDOW: float = 3.0
## Score multiplier is 1 + chain / COMBO_SCORE_STEP, with no cap.
const COMBO_SCORE_STEP: int = 8
## Floating "+150 COMBO!" text: how long it lives and how far it rises.
const COMBO_FLOAT_LIFE: float = 0.9
const COMBO_FLOAT_RISE: float = 34.0
const COMBO_FLOAT_COLOR: Color = Color(1.0, 0.32, 0.28)
const COMBO_LABEL_COLOR: Color = Color(1.0, 0.85, 0.2)

# --- Energy -----------------------------------------------------------------
## Energy per kill = score points / this, floored at the minimum: a 20 point
## scout gives 2, an 80 point heavy gives 8.
const SCORE_POINTS_PER_ENERGY: int = 10
const MIN_ENERGY_PER_KILL: int = 1
## Kills split their energy between at most this many orbs.
const MAX_ORBS_PER_KILL: int = 3
const ORB_MAGNET_RADIUS: float = 150.0
const ORB_DRIFT_SPEED: float = 48.0
const ORB_HOME_SPEED: float = 540.0
const ORB_LIFE_SECONDS: float = 9.0
const ORB_PICKUP_RADIUS: float = 22.0
## Speed of the soft glow pulse on an orb, in radians per second.
const ORB_PULSE_SPEED: float = 7.0

# --- Effects ----------------------------------------------------------------
## Hard cap on particle emitters so a chain of kills cannot flood a phone.
const MAX_LIVE_EXPLOSIONS: int = 16
const MAX_LIVE_FLOAT_TEXTS: int = 12
const EXPLOSION_PARTICLES: int = 18
const EXPLOSION_LIFE: float = 0.45
const SHOCKWAVE_LIFE: float = 0.35
const SHOCKWAVE_RADIUS: float = 46.0
const STARFIELD_SPEEDS: Array[float] = [14.0, 38.0, 72.0]
const STARFIELD_COUNTS: Array[int] = [46, 30, 18]
const STARFIELD_SIZES: Array[float] = [1.0, 2.0, 3.0]
const STARFIELD_COLORS: Array[Color] = [
	Color(0.55, 0.6, 0.9, 0.55),
	Color(0.8, 0.85, 1.0, 0.8),
	Color(1.0, 1.0, 1.0, 0.95),
]

# --- Upgrades ---------------------------------------------------------------
const UPGRADE_MAX_LEVEL: int = 10
## Ship hull before any upgrade level.
const BASE_MAX_HP: int = SHIP_MAX_HP
const BASE_MOVE_SPEED: float = SHIP_MAX_SPEED
const BASE_FIRE_INTERVAL: float = SHIP_FIRE_INTERVAL
const BASE_BULLET_DAMAGE: int = SHIP_BULLET_DAMAGE
## Hull: +HP_PER_HULL_STEP max HP every HULL_LEVELS_PER_STEP levels.
const HULL_LEVELS_PER_STEP: int = 3
const HP_PER_HULL_STEP: int = 20
const SPEED_PER_LEVEL: float = 12.0
## Shields: one starting charge every N levels, capped at the maximum.
const SHIELD_LEVELS_PER_CHARGE: int = 3
## Fire power: +1 bullet damage every N levels.
const FIRE_LEVELS_PER_DAMAGE: int = 3
const FIRE_INTERVAL_PER_LEVEL: float = 0.008
const MIN_FIRE_INTERVAL: float = 0.06

## Shop rows in display order. Price of a level is
## base_cost + cost_step * current_level, so the first point is the cheapest.
const UPGRADES: Dictionary = {
	&"hull": {"title": "HULL", "base_cost": 20, "cost_step": 15},
	&"speed": {"title": "SPEED", "base_cost": 15, "cost_step": 12},
	&"shield": {"title": "SHIELDS", "base_cost": 30, "cost_step": 20},
	&"fire": {"title": "FIRE POWER", "base_cost": 25, "cost_step": 18},
}
const UPGRADE_ORDER: Array[StringName] = [&"hull", &"speed", &"shield", &"fire"]

# --- Campaign ---------------------------------------------------------------
## The sector graph is kept from the portrait build and is ported onto the
## landscape map in the next stage. `pos` are portrait map coordinates and are
## not read by the battle.
const CAMPAIGN_SECTORS: Dictionary = {
	&"drift": {
		"name": "DRIFT BELT", "tier": 1, "waves": 1, "boss": false,
		"mix": {"scout": 4}, "pos": Vector2(200, 528),
		"links": [&"cinder", &"vesper"],
	},
	&"cinder": {
		"name": "CINDER RUN", "tier": 1, "waves": 2, "boss": false,
		"mix": {"scout": 4, "gunner": 2}, "pos": Vector2(110, 452),
		"links": [&"hollow", &"ember"],
	},
	&"vesper": {
		"name": "VESPER FIELD", "tier": 1, "waves": 2, "boss": false,
		"mix": {"gunner": 4, "heavy": 1}, "pos": Vector2(290, 452),
		"links": [&"ember", &"quill"],
	},
	&"hollow": {
		"name": "HOLLOW MOON", "tier": 2, "waves": 2, "boss": false,
		"mix": {"scout": 5, "heavy": 2}, "pos": Vector2(88, 368),
		"links": [&"warden"],
	},
	&"ember": {
		"name": "EMBER GATE", "tier": 2, "waves": 2, "boss": false,
		"mix": {"gunner": 6, "heavy": 2}, "pos": Vector2(200, 368),
		"links": [&"warden", &"sable"],
	},
	&"quill": {
		"name": "QUILL NEBULA", "tier": 2, "waves": 3, "boss": false,
		"mix": {"scout": 5, "gunner": 4, "heavy": 2}, "pos": Vector2(312, 368),
		"links": [&"sable"],
	},
	&"warden": {
		"name": "WARDEN REEF", "tier": 3, "waves": 3, "boss": true,
		"mix": {"gunner": 5, "heavy": 3}, "pos": Vector2(140, 286),
		"links": [&"nexus"],
	},
	&"sable": {
		"name": "SABLE EXPANSE", "tier": 3, "waves": 3, "boss": false,
		"mix": {"scout": 6, "gunner": 5, "heavy": 2}, "pos": Vector2(262, 286),
		"links": [&"nexus"],
	},
	&"nexus": {
		"name": "THE NEXUS", "tier": 3, "waves": 3, "boss": true,
		"mix": {"heavy": 4, "gunner": 6}, "pos": Vector2(200, 204),
		"links": [],
	},
}
const CAMPAIGN_ORDER: Array[StringName] = [
	&"drift", &"cinder", &"vesper", &"hollow", &"ember", &"quill", &"warden", &"sable", &"nexus",
]
## Sectors the player may attack before conquering anything.
const CAMPAIGN_START: Array[StringName] = [&"drift"]
const CAMPAIGN_TIER_DIFFICULTY: Dictionary = {
	1: {"hp_scale": 1.0, "interval_scale": 1.0, "bullet_scale": 1.0},
	2: {"hp_scale": 1.3, "interval_scale": 0.9, "bullet_scale": 0.85},
	3: {"hp_scale": 1.6, "interval_scale": 0.8, "bullet_scale": 0.7},
}
