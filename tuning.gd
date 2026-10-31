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

# --- Difficulty -------------------------------------------------------------
## One row per mode. Everything the mode changes is here: the between-planet
## heal, what a defeat does, and the battle multipliers. They stack with the
## galaxy bands and the body traits, so a distant FORTRESS on SINGULARITY is
## the hardest fight the tables can produce.
##
## `heal_per_planet` is a fraction of MAX HP added on every conquest.
## `milestones` maps "planets conquered" -> fraction; the largest reached
## milestone REPLACES the per-planet heal (an empty table means none).
## `on_defeat` is "keep" (progress stays), "reset" (new galaxy, meta kept) or
## "wipe" (new galaxy and every meta progression reset).
const DIFFICULTY_CADET: StringName = &"cadet"
const DIFFICULTY_VECTOR: StringName = &"vector"
const DIFFICULTY_SUPERNOVA: StringName = &"supernova"
const DIFFICULTY_EVENT_HORIZON: StringName = &"event_horizon"
const DIFFICULTY_SINGULARITY: StringName = &"singularity"
const DIFFICULTY_ORDER: Array[StringName] = [
	DIFFICULTY_CADET, DIFFICULTY_VECTOR, DIFFICULTY_SUPERNOVA,
	DIFFICULTY_EVENT_HORIZON, DIFFICULTY_SINGULARITY,
]
## Old saves without a stored mode load as CADET.
const DIFFICULTY_DEFAULT: StringName = DIFFICULTY_CADET
const DIFFICULTIES: Dictionary = {
	DIFFICULTY_CADET: {
		"title": "CADET", "level": 1, "color": Color(0.55, 1.0, 0.65),
		"heal_per_planet": 1.0, "milestones": {}, "on_defeat": "keep",
		"defeat_hp": 1.0,
		"enemy_hp": 0.8, "enemy_damage": 0.8, "enemies": 0.9,
		"energy": 1.0, "score": 1.0, "shield_drop": 1.5,
	},
	DIFFICULTY_VECTOR: {
		"title": "VECTOR", "level": 2, "color": Color(0.6, 0.85, 1.0),
		"heal_per_planet": 0.25,
		"milestones": {5: 0.5, 10: 1.0},
		"on_defeat": "keep", "defeat_hp": 0.5,
		"enemy_hp": 1.0, "enemy_damage": 1.0, "enemies": 1.0,
		"energy": 1.0, "score": 1.0, "shield_drop": 1.0,
	},
	DIFFICULTY_SUPERNOVA: {
		"title": "SUPERNOVA", "level": 3, "color": Color(1.0, 0.8, 0.4),
		"heal_per_planet": 0.1,
		"milestones": {5: 0.25, 10: 0.5},
		"on_defeat": "reset", "defeat_hp": 0.0,
		"enemy_hp": 1.25, "enemy_damage": 1.2, "enemies": 1.1,
		"energy": 1.1, "score": 1.25, "shield_drop": 0.8,
	},
	DIFFICULTY_EVENT_HORIZON: {
		"title": "EVENT HORIZON", "level": 4, "color": Color(1.0, 0.55, 0.35),
		"heal_per_planet": 0.0,
		"milestones": {5: 0.1, 10: 0.25},
		"on_defeat": "reset", "defeat_hp": 0.0,
		"enemy_hp": 1.5, "enemy_damage": 1.4, "enemies": 1.25,
		"energy": 1.25, "score": 1.5, "shield_drop": 0.6,
	},
	DIFFICULTY_SINGULARITY: {
		"title": "SINGULARITY", "level": 5, "color": Color(1.0, 0.35, 0.45),
		"heal_per_planet": 0.0,
		"milestones": {10: 0.05},
		"on_defeat": "wipe", "defeat_hp": 0.0,
		"enemy_hp": 1.8, "enemy_damage": 1.7, "enemies": 1.4,
		"energy": 1.5, "score": 2.0, "shield_drop": 0.5,
	},
}
## What a SINGULARITY defeat resets, listed on its card.
const DIFFICULTY_WIPE_LIST: Array[String] = [
	"CAMPAIGN", "BANKED ENERGY", "UPGRADE LEVELS", "OWNED WEAPONS",
]
## Fixed while a campaign runs; the picker is the only way to change it.
const DIFFICULTY_PICKER_BG: Color = Color(0.04, 0.06, 0.12, 0.97)

# --- Ship -------------------------------------------------------------------
const SHIP_MAX_HP: int = 100
const SHIP_ACCELERATION: float = 1500.0
const SHIP_MAX_SPEED: float = 400.0
## Higher coasts less: the ship keeps a little inertia but stops in ~0.4s.
const SHIP_DRAG: float = 3.4
## How fast the hull swings onto the aim direction, as an exponential rate per
## second (1 - exp(-rate * delta)), so the turn feels the same at any fps.
const SHIP_TURN_RATE: float = 12.0
## The nose ignores a mouse pointer this close to the hull, which stops the
## aim from jittering while the mouse is at rest.
const SHIP_AIM_DEADZONE: float = 18.0
const SHIP_FIRE_INTERVAL: float = 0.14
const SHIP_BULLET_SPEED: float = 720.0
const SHIP_BULLET_DAMAGE: int = 1
const SHIP_BULLET_LIFE: float = 1.4
const SHIP_SPAWN_POSITION: Vector2 = Vector2(480.0, 480.0)
const SHIP_RADIUS: float = 14.0
## Distance from the hull centre where a shot leaves the muzzle.
const SHIP_MUZZLE_OFFSET: float = 24.0
## The ship wraps around the arena once its hull is fully past an edge; this
## extra gap is how far outside the opposite edge it re-enters.
const SHIP_WRAP_MARGIN: float = 8.0
const SHIP_INVULNERABILITY: float = 0.9
const SHIP_SHIELD_GRACE: float = 0.4
const SHIP_BLINK_INTERVAL: float = 0.08
const SHIP_BLINK_ALPHA: float = 0.3
const MAX_SHIELD_CHARGES: int = 3
## Shield drops: a blue bubble that drifts down, always worth one charge.
const SHIELD_DROP_CHANCE: float = 0.08
const SHIELD_DROP_FALL_SPEED: float = 46.0
const SHIELD_DROP_DRIFT: float = 22.0
const SHIELD_DROP_LIFE: float = 12.0
const SHIELD_DROP_RADIUS: float = 20.0
const SHIELD_DROP_VISUAL_RADIUS: float = 11.0
## The SHIELDS track also recharges one charge after a quiet stretch: this is
## the wait at level 1, it shortens per level down to the floor, and any damage
## restarts the quiet timer. Level 0 means no recharge, but drops still work.
const SHIELD_RECHARGE_BASE: float = 25.0
const SHIELD_RECHARGE_STEP: float = 1.8
const SHIELD_RECHARGE_MIN: float = 8.0
const SHIELD_RECHARGE_DAMAGE_DELAY: float = 3.0
const SHIELD_BUBBLE_RADIUS: float = 24.0

# --- Music ------------------------------------------------------------------
## Playlist rotation. SHUFFLE uses a bag: every track plays once per pass and
## the track that just ended never starts the next pass.
const MUSIC_ORDER_SHUFFLE: StringName = &"shuffle"
const MUSIC_ORDER_IN_ORDER: StringName = &"in_order"
## Crossfade between tracks, in seconds, and how quiet a fading-out player
## drops before it stops. The pause dip multiplies the Music bus (0.45 = about
## -7 dB) and eases in at MUSIC_PAUSE_FADE per second.
const MUSIC_CROSSFADE: float = 1.5
## Track file base name (no extension) -> context. A context track replaces the
## rotation while that context lasts and is kept out of the normal shuffle and
## in-order loop, so it only ever plays for its own fight. If the file is
## missing the context is silently ignored.
const MUSIC_CONTEXTS: Dictionary = {
	"Orbital Colossus": "boss",
}
const MUSIC_SILENT_DB: float = -40.0
const MUSIC_PAUSE_GAIN: float = 0.45
const MUSIC_PAUSE_FADE: float = 2.0

# --- Controls ---------------------------------------------------------------
## Two ways to fly. FREE AIM is the twin-stick scheme (mouse or right stick
## aims, WASD strafes); CLASSIC turns and thrusts like the reference.
const CONTROL_SCHEME_FREE: StringName = &"free_aim"
const CONTROL_SCHEME_CLASSIC: StringName = &"classic"
## Default scheme, so the whole build can be flipped in one place.
const CONTROL_SCHEME_DEFAULT: StringName = CONTROL_SCHEME_FREE
## Every bindable action, for persistence and the remap card's storage. The
## card itself only lists the actions of the active scheme.
const CONTROL_ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
	&"turn_left", &"turn_right", &"thrust", &"brake",
	&"shoot", &"shoot_alt", &"shield", &"controls", &"pause",
]
const CONTROL_ACTIONS_FREE: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
	&"shoot", &"shoot_alt", &"shield", &"controls", &"pause",
]
const CONTROL_ACTIONS_CLASSIC: Array[StringName] = [
	&"turn_left", &"turn_right", &"thrust", &"brake",
	&"shoot", &"shoot_alt", &"shield", &"controls", &"pause",
]
## `pause` is listed but fixed: Esc is the menu key, so no remap may take it away.
const CONTROL_FIXED: Array[StringName] = [&"pause"]
const CONTROL_LABELS: Dictionary = {
	&"move_up": "MOVE UP",
	&"move_down": "MOVE DOWN",
	&"move_left": "MOVE LEFT",
	&"move_right": "MOVE RIGHT",
	&"turn_left": "TURN LEFT",
	&"turn_right": "TURN RIGHT",
	&"thrust": "THRUST",
	&"brake": "BRAKE",
	&"shoot": "PRIMARY FIRE",
	&"shoot_alt": "SECONDARY FIRE",
	&"shield": "SHIELD",
	&"controls": "CONTROLS CARD",
	&"pause": "PAUSE / MENU",
}
## Classic flight: how fast the hull turns, in radians per second.
const SHIP_CLASSIC_TURN_RATE: float = 3.0
## Shield behaviour. AUTO spends a charge on every hit (the original rule);
## MANUAL spends one charge to raise a timed bubble that absorbs everything.
const SHIELD_MODE_AUTO: StringName = &"auto"
const SHIELD_MODE_MANUAL: StringName = &"manual"
## Default shield mode, used when there is no save yet.
const SHIELD_MODE_DEFAULT: StringName = SHIELD_MODE_AUTO
## Capacity at SHIELDS level 0. Every battle starts with the shield full, so a
## fresh save already has one charge to spend (AUTO) or raise (MANUAL). The
## upgrade adds one more per SHIELD_LEVELS_PER_CHARGE levels, up to the cap.
const SHIELD_BASE_CAPACITY: int = 1
## A drop taken while the shield is already full is not wasted: it pays out this
## much energy instead, with a floating readout.
const SHIELD_PICKUP_FULL_ENERGY: int = 5
## MANUAL: one charge raises the bubble for this long, with a short cooldown
## before another charge can be spent. It flashes during its last second.
const SHIELD_ACTIVE_SECONDS: float = 4.0
const SHIELD_COOLDOWN_SECONDS: float = 1.0
const SHIELD_LAST_SECOND: float = 1.0

# --- Thrusters --------------------------------------------------------------
const THRUSTER_FRAME_FPS: float = 18.0
## Exhaust size and brightness at idle and at full speed.
const THRUSTER_IDLE_SCALE: float = 0.7
const THRUSTER_FULL_SCALE: float = 1.35
const THRUSTER_MIN_VISIBLE: float = 0.06
## Exhaust geometry: the thruster textures are 32x32 stacks of HORIZONTAL bars,
## longest on the top row and shorter going down, so a ship whose nose points up
## needs no rotation at all -- the bars are already perpendicular to the heading.
## The sprite offset pins the art's top edge to the anchor so the stack grows
## away from the hull.
const THRUSTER_TAIL_GAP: float = 3.0
const THRUSTER_ART_SIZE: float = 32.0
## Rows of pixels used by thruster-1..5, measured from the art (2, 6, 10, 14,
## 18). The last entry is the longest frame: how far the flame reaches behind
## the tail, and what the preview and the F3 overlay budget for.
const THRUSTER_BAR_ROWS: Array[int] = [2, 6, 10, 14, 18]
## F3 debug overlay: hull circle and thruster anchor on every ship.
const THRUSTER_DEBUG_COLOR: Color = Color(0.3, 1.0, 0.5, 0.85)
static var thruster_debug: bool = false

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
## Enemy shots are drawn shapes, not sprites: a hot diamond with a white core, a
## pulsing halo and a short trail, so they never read as a player laser. The
## hitbox stays a little smaller than the art so near misses feel fair.
const ENEMY_BULLET_HITBOX_RADIUS: float = 8.0
const ENEMY_BULLET_VISUAL_RADIUS: float = 10.0
const ENEMY_BULLET_CORE_RADIUS: float = 3.4
const ENEMY_BULLET_TRAIL_SEGMENTS: int = 4
const ENEMY_BULLET_TRAIL_SPACING: float = 6.0
const ENEMY_BULLET_GLOW_PULSE: float = 6.0
const ENEMY_BULLET_BODY: Color = Color(0.96, 0.22, 0.18)
const ENEMY_BULLET_CORE: Color = Color(1.0, 0.97, 0.9)
const ENEMY_BULLET_OUTLINE: Color = Color(1.0, 0.42, 0.28)
## On the red band the outline turns yellow-white so the shot keeps its edge.
const ENEMY_BULLET_OUTLINE_HOT: Color = Color(1.0, 0.95, 0.5)
const ENEMY_BULLET_OUTLINE_WIDTH: float = 2.0
const ENEMY_BULLET_OUTLINE_WIDTH_HIGH: float = 3.5
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
## Large rocks are drawn at roughly three times the old size; tiny debris is
## unchanged, so a split visibly scatters small pieces.
const ASTEROID_LARGE_SCALE: float = 1.9
const ASTEROID_TINY_SCALE: float = 0.6
const ASTEROID_LARGE_RADIUS: float = 46.0
## A fresh large rock is pushed this far away if it would appear on the ship.
const ASTEROID_SHIP_CLEARANCE: float = 130.0
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
## The campaign builds its battles from the galaxy tables further down; these
## rows only feed the debug harness and the no-selection fallback.
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
## The fallback battle when no galaxy body was selected.
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
## base_cost + cost_step * current level, so the first point is the cheapest.
const UPGRADES: Dictionary = {
	&"hull": {"title": "HEALTH", "base_cost": 20, "cost_step": 15},
	&"speed": {"title": "SPEED", "base_cost": 15, "cost_step": 12},
	&"shield": {"title": "SHIELDS", "base_cost": 15, "cost_step": 8},
	&"fire": {"title": "FIRE POWER", "base_cost": 25, "cost_step": 18},
}
const UPGRADE_ORDER: Array[StringName] = [&"hull", &"speed", &"shield", &"fire"]

# --- Galaxy map -------------------------------------------------------------
## The campaign map is generated from one integer seed (kept in SaveData), so a
## campaign always comes back with the same worlds. The map is larger than the
## 960x600 view and is panned, never zoomed.
const GALAXY_MAP_SIZE: Vector2 = Vector2(2300.0, 1500.0)
const GALAXY_BODY_COUNT_MIN: int = 50
const GALAXY_BODY_COUNT_MAX: int = 60
## Blue-noise spacing of the bodies (Poisson disk), in map pixels.
const GALAXY_MIN_SPACING: float = 152.0
const GALAXY_EDGE_MARGIN: float = 130.0
## Nearest neighbours every body is linked to, and the longest link drawn.
const GALAXY_LINKS_PER_BODY: int = 2
const GALAXY_MAX_LINK_LENGTH: float = 560.0
## Station-coloured bodies; each one ends with a boss fight.
const GALAXY_CITADEL_COUNT: int = 5
## Citadels that must fall before the final gate can be attacked.
const GALAXY_CITADELS_FOR_GATE: int = 3
## Tap / click radius of a body, in map pixels.
const GALAXY_TAP_RADIUS: float = 40.0
## Space between a body and its tooltip, on top of the tap radius.
const GALAXY_TOOLTIP_GAP: float = 16.0
## The home system is placed nearest this map point, so the map opens rightward.
const GALAXY_HOME_ANCHOR: Vector2 = Vector2(240.0, 760.0)
## Panning the map with WASD / the left stick, in pixels per second.
const GALAXY_PAN_SPEED: float = 700.0
## Zoom: wheel / pinch / +- around the cursor. The level lasts for the session
## only and never touches the save.
const GALAXY_ZOOM_MIN: float = 0.55
const GALAXY_ZOOM_MAX: float = 1.7
const GALAXY_ZOOM_STEP: float = 0.12
const GALAXY_ZOOM_SMOOTH: float = 12.0
## Seconds inside which a second tap on the same body counts as a double-tap
## and opens the CONQUER card. A single tap only selects the body.
const MAP_DOUBLE_CLICK_TIME: float = 0.35

## Sprite and draw scale per body type. Planets are 64px art, stations 130x180
## and the warpgate 200x200; only `modulate` changes between two bodies.
const GALAXY_BODY_ART: Dictionary = {
	&"minor": [
		{
			"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/asteroid_grey.png"),
			"scale": 0.74,
		},
		{
			"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_asteroid.png"),
			"scale": 0.74,
		},
		{
			"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/asteroid_tiny.png"),
			"scale": 1.7,
		},
	],
	&"rocky": [
		{
			"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/planets/planet5.png"),
			"scale": 1.35,
		},
		{
			"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/planets/planet6.png"),
			"scale": 1.35,
		},
	],
	&"ocean": [
		{
			"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/planets/planet4.png"),
			"scale": 1.35,
		},
		{
			"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/planets/planet3.png"),
			"scale": 1.35,
		},
	],
	&"gas": [
		{
			"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/planets/planet1.png"),
			"scale": 1.35,
		},
		{
			"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/planets/planet2.png"),
			"scale": 1.35,
		},
	],
	&"citadel": [
		{
			"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_station_blue.png"),
			"scale": 0.44,
		},
		{
			"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_station_green.png"),
			"scale": 0.44,
		},
		{
			"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_station_red.png"),
			"scale": 0.44,
		},
		{
			"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_station_yellow.png"),
			"scale": 0.44,
		},
	],
}
## Station art order, so `art` doubles as the boss colour.
const GALAXY_STATION_COLORS: Array[StringName] = [&"blue", &"green", &"red", &"yellow"]

## Modulate per art variant. The art itself is never recoloured.
const GALAXY_TINTS: Dictionary = {
	&"minor": [Color(0.82, 0.84, 0.9), Color(0.72, 0.68, 0.62), Color(0.9, 0.86, 0.72)],
	&"rocky": [Color(1.0, 0.74, 0.5), Color(1.0, 0.56, 0.44)],
	&"ocean": [Color(0.74, 1.0, 0.94), Color(0.68, 0.88, 1.0)],
	&"gas": [Color(1.0, 0.92, 0.74), Color(0.9, 0.82, 1.0)],
	&"citadel": [
		Color(0.85, 0.9, 1.0), Color(0.82, 1.0, 0.86),
		Color(1.0, 0.86, 0.84), Color(1.0, 0.95, 0.78),
	],
}
## Home and gate markers keep their warpgate art and are only tinted.
const GALAXY_MARKER_TINTS: Dictionary = {
	&"home": Color(0.7, 0.88, 1.0),
	&"gate": Color(1.0, 0.66, 0.82),
}
const MAP_LINK_COLOR: Color = Color(0.32, 0.4, 0.62, 0.35)
const MAP_LINK_OPEN_COLOR: Color = Color(0.45, 0.95, 0.6, 0.6)
const MAP_LINK_CONQUERED_COLOR: Color = Color(0.4, 1.0, 0.65, 0.55)
const MAP_GLOW_COLOR: Color = Color(0.4, 1.0, 0.55)
const MAP_FOCUS_COLOR: Color = Color(1.0, 0.95, 0.45)
const MAP_CONQUERED_TINT: Color = Color(0.55, 1.0, 0.72)
## How far a locked body's art is darkened (0 = untouched, 1 = black).
const MAP_LOCKED_DARKEN: float = 0.42
const MAP_GLOW_PULSE: float = 2.6
const MAP_ARROW_SPEED: float = 3.4

## Difficulty by graph distance from home. Each row applies to every body whose
## hop count is <= `max_distance`; the last row is the fallback.
const GALAXY_BANDS: Array[Dictionary] = [
	{
		"max_distance": 2, "label": "NEAR SPACE",
		"enemies": 6, "waves": 1,
		"mix": {&"scout": 5, &"gunner": 1},
		"density": 0.55, "hp_scale": 1.0, "interval_scale": 1.1,
		"background": preload("res://assests/background-black.png"),
	},
	{
		"max_distance": 5, "label": "BLUE VEIL",
		"enemies": 9, "waves": 2,
		"mix": {&"scout": 4, &"gunner": 3, &"heavy": 1},
		"density": 0.85, "hp_scale": 1.15, "interval_scale": 1.0,
		"background": preload("res://assests/background-blue.png"),
	},
	{
		"max_distance": 8, "label": "PURPLE DEEP",
		"enemies": 12, "waves": 2,
		"mix": {&"scout": 3, &"gunner": 4, &"heavy": 2},
		"density": 1.1, "hp_scale": 1.3, "interval_scale": 0.9,
		"background": preload("res://assests/background-purple.png"),
	},
	{
		"max_distance": 99, "label": "RED EXPANSE",
		"enemies": 14, "waves": 3,
		"mix": {&"scout": 3, &"gunner": 5, &"heavy": 3},
		"density": 1.4, "hp_scale": 1.5, "interval_scale": 0.8,
		"background": preload("res://assests/background-red.png"),
	},
]

## A body's trait changes both the battle and the payout. `enemies_delta` is
## added to the band's enemies per wave, `density_scale` multiplies the rock
## rate, `hp_scale` multiplies fighter HP and `mix_bonus` adds weight to a kind.
const GALAXY_TRAITS: Dictionary = {
	&"minor": {
		"title": "MINOR PLANET", "energy_scale": 0.7, "density_scale": 1.35,
		"enemies_delta": -1, "hp_scale": 0.9, "mix_bonus": {&"scout": 1},
	},
	&"resource": {
		"title": "RESOURCE RICH", "energy_scale": 1.8, "density_scale": 1.0,
		"enemies_delta": 1, "hp_scale": 1.0, "mix_bonus": {&"gunner": 1},
	},
	&"fertile": {
		"title": "FERTILE", "energy_scale": 1.2, "density_scale": 0.55,
		"enemies_delta": -1, "hp_scale": 0.9, "mix_bonus": {&"scout": 2},
	},
	&"fortress": {
		"title": "FORTRESS", "energy_scale": 1.0, "density_scale": 1.35,
		"enemies_delta": 1, "hp_scale": 1.2, "mix_bonus": {&"heavy": 1, &"gunner": 1},
	},
	&"citadel": {
		"title": "CITADEL", "energy_scale": 1.4, "density_scale": 1.1,
		"enemies_delta": 0, "hp_scale": 1.15, "mix_bonus": {&"gunner": 1, &"heavy": 1},
	},
	&"home": {
		"title": "HOME SYSTEM", "energy_scale": 1.0, "density_scale": 1.0,
		"enemies_delta": 0, "hp_scale": 1.0, "mix_bonus": {},
	},
	&"gate": {
		"title": "THE FINAL GATE", "energy_scale": 2.0, "density_scale": 1.0,
		"enemies_delta": 2, "hp_scale": 1.35, "mix_bonus": {&"heavy": 2},
	},
}
## Flat energy banked when a body falls, before the trait multiplier.
const GALAXY_CONQUEST_ENERGY: int = 20
const GALAXY_CITADEL_ENERGY: int = 120
const GALAXY_GATE_ENERGY: int = 250
## Perfect Victory: a battle won without losing a single hull point.
const PERFECT_BONUS_SCORE: int = 500
const PERFECT_BONUS_ENERGY: int = 25

# --- Weapons ----------------------------------------------------------------
## Two hardpoints on the hull, left and right of the nose, so the primary and
## the secondary visibly fire from different places.
const WEAPON_MUZZLE_SIDE: float = 13.0
## FIRE POWER multiplies every weapon's damage and shortens every cooldown;
## these two constants are the whole upgrade curve.
const FIRE_DAMAGE_PER_LEVEL: float = 0.12
const FIRE_COOLDOWN_PER_LEVEL: float = 0.03
const MIN_FIRE_COOLDOWN_MULT: float = 0.55
## Weapons are bought with energy and also gated behind planets conquered.
const WEAPON_ORDER: Array[StringName] = [&"pulse", &"cannon", &"scatter", &"rail", &"missile"]
const WEAPONS: Dictionary = {
	&"pulse": {
		"title": "PULSE LASER",
		"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_laser_blue.png"),
		"color": Color(0.55, 0.78, 1.0),
		"damage": 3.0, "interval": 0.14, "speed": 780.0, "count": 1,
		"spread": 0.0, "pierce": 0, "life": 1.3, "scale": 0.36,
		"homing": 0.0, "area": 0.0, "knockback": 0.0,
		"cost": 0, "unlock": 0,
		"desc": "Fast, accurate, unlimited. The laser colour follows FIRE POWER.",
	},
	&"cannon": {
		"title": "HEAVY CANNON",
		"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_laser_small_blue.png"),
		"color": Color(0.85, 0.92, 1.0),
		"damage": 9.0, "interval": 0.8, "speed": 620.0, "count": 1,
		"spread": 0.0, "pierce": 0, "life": 1.2, "scale": 0.62,
		"homing": 0.0, "area": 0.0, "knockback": 240.0,
		"cost": 45, "unlock": 3,
		"desc": "Slow slug, heavy damage and a shove that pushes fighters back.",
	},
	&"scatter": {
		"title": "SCATTER SHOT",
		"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_laser_green.png"),
		"color": Color(0.65, 1.0, 0.6),
		"damage": 2.0, "interval": 0.6, "speed": 640.0, "count": 4,
		"spread": 0.2, "pierce": 0, "life": 0.5, "scale": 0.26,
		"homing": 0.0, "area": 0.0, "knockback": 0.0,
		"cost": 80, "unlock": 6,
		"desc": "Four pellets in a fan. Ruinous up close, useless at range.",
	},
	&"rail": {
		"title": "RAIL LASER",
		"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_laser_yellow.png"),
		"color": Color(1.0, 0.9, 0.4),
		"damage": 12.0, "interval": 1.4, "speed": 1500.0, "count": 1,
		"spread": 0.0, "pierce": 4, "life": 0.9, "scale": 0.44,
		"homing": 0.0, "area": 0.0, "knockback": 0.0,
		"cost": 130, "unlock": 12,
		"desc": "A piercing lance. Lines of fighters fall to one shot.",
	},
	&"missile": {
		"title": "HOMING MISSILE",
		"texture": preload("res://assests/spacepixels-0.2.0/spacepixels-0.2.0/pixel_laser_red.png"),
		"color": Color(1.0, 0.62, 0.3),
		"damage": 7.0, "interval": 1.1, "speed": 320.0, "count": 1,
		"spread": 0.0, "pierce": 0, "life": 2.4, "scale": 0.34,
		"homing": 3.4, "area": 74.0, "knockback": 60.0,
		"cost": 200, "unlock": 18,
		"desc": "Steers onto the nearest fighter and bursts on impact.",
	},
}
## Explosion tint for an area burst, shared by the battle.
const WEAPON_BURST_COLOR: Color = Color(1.0, 0.7, 0.35)
const WEAPON_BURST_PARTICLES: int = 10

# --- Citadel boss -----------------------------------------------------------
const BOSS_HP: int = 140
const BOSS_HP_PER_DISTANCE: int = 9
const BOSS_POINTS: int = 400
const BOSS_RADIUS: float = 54.0
## The 130x180 station art is drawn at this scale.
const BOSS_SCALE: float = 0.46
const BOSS_FIRE_INTERVAL: float = 2.1
const BOSS_BULLETS_PER_VOLLEY: int = 5
## Angle between two bullets of the same fan, in radians.
const BOSS_SPREAD: float = 0.16
const BOSS_BULLET_DAMAGE: int = 10
const BOSS_CONTACT_DAMAGE: int = 25
const BOSS_HOVER_AMPLITUDE: float = 70.0
const BOSS_HOVER_RISE: float = 26.0
const BOSS_HOVER_SPEED: float = 0.55
