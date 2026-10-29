class_name Tuning
extends RefCounted
## One place for the numbers that decide pacing, the economy and the combo.
## Nothing in the game logic depends on the exact values, so this file is meant
## to be edited while balancing; see the "Balancing" section of the README.

# --- Run rules --------------------------------------------------------------
const BASE_LIVES: int = 3
const PICKUP_DROP_CHANCE: float = 0.1
const POWERUP_DURATION: float = 8.0
## Hard cap on particle emitters so a bomb chain cannot flood a phone.
const MAX_LIVE_EXPLOSIONS: int = 12
const BOSS_EXPLOSION_COUNT: int = 30

# --- Waves ------------------------------------------------------------------
## Wave number -> { enemy key: how many }. Past the last entry the last mix is
## reused; the spawn interval keeps shrinking to its floor. Keys are
## "straight", "zigzag" and "tank".
const WAVE_TABLE: Dictionary = {
	1: {"straight": 4},
	2: {"straight": 5, "zigzag": 3},
	3: {"zigzag": 5, "tank": 1},
	4: {"straight": 4, "zigzag": 4, "tank": 2},
}
## Every Nth wave is a single boss instead of a mix.
const BOSS_EVERY: int = 5
## Seconds between spawns on wave 1, shrunk per wave down to the floor.
const FIRST_WAVE_INTERVAL: float = 1.4
const MIN_SPAWN_INTERVAL: float = 0.45
const INTERVAL_STEP: float = 0.08
## Beat between "wave cleared" and the next wave.
const WAVE_GAP: float = 2.0

# --- Energy -----------------------------------------------------------------
## Energy per kill = score points / this (integer division, floored at the
## minimum): straight 10 -> 1, zigzag 20 -> 2, tank 50 -> 5, boss 500 -> 50.
const SCORE_POINTS_PER_ENERGY: int = 10
const MIN_ENERGY_PER_KILL: int = 1
## A kill's energy is split between at most this many motes.
const MAX_MOTES_PER_KILL: int = 3
## The ship pulls a mote in from this distance.
const MOTE_MAGNET_RADIUS: float = 90.0
## How fast a mote drifts down before it is pulled in.
const MOTE_DRIFT_SPEED: float = 34.0
## How fast a pulled mote travels.
const MOTE_HOME_SPEED: float = 320.0
## A mote that is never collected disappears after this long.
const MOTE_LIFE_SECONDS: float = 8.0
## Distance at which a homing mote counts as collected.
const MOTE_PICKUP_DISTANCE: float = 18.0

# --- Campaign ---------------------------------------------------------------
## The sector graph for campaign mode. Each entry is a planet drawn on the
## vertical 400x600 map: `tier` picks a row of CAMPAIGN_TIER_DIFFICULTY,
## `waves` is 1-3 battles of `mix`, `boss` adds a boss to the last wave, `pos`
## is the node centre on the map, and `links` are the sectors this one unlocks
## when conquered. Sectors with no links are the final one.
const CAMPAIGN_SECTORS: Dictionary = {
	&"drift": {
		"name": "DRIFT BELT", "tier": 1, "waves": 1, "boss": false,
		"mix": {"straight": 4}, "pos": Vector2(200, 528),
		"links": [&"cinder", &"vesper"],
	},
	&"cinder": {
		"name": "CINDER RUN", "tier": 1, "waves": 2, "boss": false,
		"mix": {"straight": 4, "zigzag": 2}, "pos": Vector2(110, 452),
		"links": [&"hollow", &"ember"],
	},
	&"vesper": {
		"name": "VESPER FIELD", "tier": 1, "waves": 2, "boss": false,
		"mix": {"zigzag": 4, "tank": 1}, "pos": Vector2(290, 452),
		"links": [&"ember", &"quill"],
	},
	&"hollow": {
		"name": "HOLLOW MOON", "tier": 2, "waves": 2, "boss": false,
		"mix": {"straight": 5, "tank": 2}, "pos": Vector2(88, 368),
		"links": [&"warden"],
	},
	&"ember": {
		"name": "EMBER GATE", "tier": 2, "waves": 2, "boss": false,
		"mix": {"zigzag": 6, "tank": 2}, "pos": Vector2(200, 368),
		"links": [&"warden", &"sable"],
	},
	&"quill": {
		"name": "QUILL NEBULA", "tier": 2, "waves": 3, "boss": false,
		"mix": {"straight": 5, "zigzag": 4, "tank": 2}, "pos": Vector2(312, 368),
		"links": [&"sable"],
	},
	&"warden": {
		"name": "WARDEN REEF", "tier": 3, "waves": 3, "boss": true,
		"mix": {"zigzag": 5, "tank": 3}, "pos": Vector2(140, 286),
		"links": [&"nexus"],
	},
	&"sable": {
		"name": "SABLE EXPANSE", "tier": 3, "waves": 3, "boss": false,
		"mix": {"straight": 6, "zigzag": 5, "tank": 2}, "pos": Vector2(262, 286),
		"links": [&"nexus"],
	},
	&"nexus": {
		"name": "THE NEXUS", "tier": 3, "waves": 3, "boss": true,
		"mix": {"tank": 4, "zigzag": 6}, "pos": Vector2(200, 204),
		"links": [],
	},
}
## Display order (and the order the map uses for keyboard cycling).
const CAMPAIGN_ORDER: Array[StringName] = [
	&"drift", &"cinder", &"vesper", &"hollow", &"ember", &"quill", &"warden", &"sable", &"nexus",
]
## Sectors the player may attack before conquering anything.
const CAMPAIGN_START: Array[StringName] = [&"drift"]

## Per-tier difficulty. `hp_scale` multiplies enemy health, `interval_scale`
## multiplies the seconds between spawns (below 1 = faster), and `bullet_scale`
## multiplies the boss spread interval (below 1 = more frequent).
const CAMPAIGN_TIER_DIFFICULTY: Dictionary = {
	1: {"hp_scale": 1.0, "interval_scale": 1.0, "bullet_scale": 1.0},
	2: {"hp_scale": 1.3, "interval_scale": 0.9, "bullet_scale": 0.85},
	3: {"hp_scale": 1.6, "interval_scale": 0.8, "bullet_scale": 0.7},
}
## Cleared without losing a life.
const CAMPAIGN_PERFECT_SCORE_BONUS: int = 250
const CAMPAIGN_PERFECT_ENERGY_BONUS: int = 10
## Clearing a sector that ends with a boss grants one extra life.
const CAMPAIGN_BOSS_LIFE_BONUS: int = 1

# --- Combo ------------------------------------------------------------------
## Seconds a kill keeps the chain alive; every kill resets the clock.
const COMBO_WINDOW: float = 2.5
## Kills needed for one step of the multiplier: x2 at 4 kills, x3 at 8, ...
const COMBO_KILLS_PER_STEP: int = 4
const COMBO_MAX_MULTIPLIER: int = 5

# --- Upgrades ---------------------------------------------------------------
const UPGRADE_MAX_LEVEL: int = 10
## Ship stats before any upgrade level.
const BASE_MOVE_SPEED: float = 300.0
const BASE_FIRE_INTERVAL: float = 0.5
const BASE_RAPID_INTERVAL: float = 0.16
const BASE_BULLET_DAMAGE: int = 1
const MAX_SHIELD_CHARGES: int = 3
## Hull: +1 life every N levels, so levels 3 / 6 / 9 give 4 / 5 / 6 lives.
const HULL_LEVELS_PER_LIFE: int = 3
## Shields: one starting charge every N levels, capped at MAX_SHIELD_CHARGES.
const SHIELD_LEVELS_PER_CHARGE: int = 3
## Fire power: +1 bullet damage every N levels.
const FIRE_LEVELS_PER_DAMAGE: int = 3
const SPEED_PER_LEVEL: float = 15.0
## Fire intervals shrink per level, down to their floors.
const FIRE_INTERVAL_PER_LEVEL: float = 0.02
const RAPID_INTERVAL_PER_LEVEL: float = 0.008
const MIN_FIRE_INTERVAL: float = 0.12
const MIN_RAPID_INTERVAL: float = 0.05

## Shop rows in display order. Price of a level is
## base_cost + cost_step * current_level, so the first point is the cheapest.
const UPGRADES: Dictionary = {
	&"hull": {"title": "HULL", "base_cost": 20, "cost_step": 15},
	&"speed": {"title": "SPEED", "base_cost": 15, "cost_step": 12},
	&"shield": {"title": "SHIELDS", "base_cost": 30, "cost_step": 20},
	&"fire": {"title": "FIRE POWER", "base_cost": 25, "cost_step": 18},
}
const UPGRADE_ORDER: Array[StringName] = [&"hull", &"speed", &"shield", &"fire"]
