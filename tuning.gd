class_name Tuning
extends RefCounted
## One place for the numbers that decide pacing, the economy and the combo.
## Nothing in the game logic depends on the exact values, so this file is meant
## to be edited while balancing; see the "Balancing" section of the README.

# --- Run rules --------------------------------------------------------------
const BASE_LIVES: int = 3
const PICKUP_DROP_CHANCE: float = 0.1
const POWERUP_DURATION: float = 8.0
const MAX_LIVE_EXPLOSIONS: int = 12

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
