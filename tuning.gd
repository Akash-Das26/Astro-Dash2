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
