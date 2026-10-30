# Astro Dash 2

A landscape twin-stick space shooter built with **Godot 4.7** (GL Compatibility)
for desktop, the web and Android. Fly free in a 960x600 arena, shoot fighters and
asteroids, chain kills for combo score and pick up the energy they drop.

This build is **stage 7A: the landscape conversion and the new battle core**. The
portrait game is retired (kept in git history and on the `portrait-final` tag) and
the front end, campaign map and shop come back on top of the arena in the next
stages. See *What is not in this build yet* below.

## What is in this build

- **Free-flight ship.** WASD / arrows / left stick / on-screen stick, with light
  inertia. The nose follows the mouse, the right stick or a touch on the right
  half; `Space` / left click / `A` / right trigger fires along the nose. HP is 100
  plus up to three shield charges, both scaled by the upgrade shop.
- **Thruster.** One shared `thruster.tscn` (five-frame `thruster-1..5` loop)
  behind the hull, on the ship and on every fighter: it grows, brightens and
  animates faster with speed, and disappears at rest.
- **Three fighters** on the shared `EnemyBase` (hp, score, hit flash, contact
  damage, warp-in):
  - *scout* — fast and fragile, dives straight at the ship;
  - *gunner* — keeps its distance, strafes and fires red dots with aim error;
  - *heavy* — slow, stroked hull, twelve hits, heavy shots.
  Stats live in `Tuning.ENEMY_TYPES`.
- **Asteroids.** Rocks drift in from off screen, spin, damage the ship on
  contact, and a large one shot down splits into 2-3 tiny ones.
- **Waves from a Battle resource.** `{waves, enemies_per_wave, enemy_mix,
  asteroid_density, background}` with staggered spawns and warpgate openings. All
  waves cleared = victory; HP at zero = defeat.
- **Combo.** Kills inside a 3s window raise the multiplier (1 + chain/8, no cap),
  the score per kill follows it, `+N COMBO!` floats up at the kill, `COMBO xN`
  sits yellow at the top centre, and taking a hit resets the chain.
- **Energy.** Kills drop cyan `pixel_laser_small_blue` orbs with a soft glow
  pulse; they drift, then home in inside the magnet radius and add to ENERGY.
- **Feel.** Square-pixel bursts (white cooling into the fighter's tint), ring
  shockwaves, hit flashes, capped trauma camera shake, and a three-layer
  parallax starfield over the tiled `background-black.png`.
- **HUD** (24px translucent bars, top and bottom): ENERGY and SCORE on the right,
  COMBO centred, WAVE left, ENEMIES right, HP bar (green/yellow/red by health) and
  the shield bar in the bottom centre. Pause card and end card included.
- **Touch controls:** stick anywhere on the left half, aim-and-fire anywhere on
  the right half, plus a 48px pause button.
- **Debug harness:** a debug build boots straight into a one-wave, ten-enemy
  battle (no map needed), and `F9` starts it again at any time.

## What is not in this build yet

Retired and returning in later stages: the menu, the campaign map, the shop card,
the settings card, the how-to card, power-up pickups and the boss.

The systems behind them are kept and ported, not deleted: `GameState` (state
machine and pause ownership), `SaveData` (ConfigFile persistence), `AudioManager`
(buses and pooled SFX), `Tuning`, `Upgrades` (hull now adds max HP), `ShakeCamera`,
`Explosion`, `SettingsPanel`, `ShopPanel`, `Campaign` and the sector graph.

## Controls

**Keyboard**

| Action | Input |
| --- | --- |
| Move | `W` `A` `S` `D` or the arrow keys |
| Aim | Mouse (the nose follows the pointer once it moves) |
| Fire | `Space` or hold left click |
| Pause | `P` or `Esc` |
| Debug (debug builds) | `F9` one-wave harness, `R` restart from the end card |

**Gamepad** (twin-stick)

| Action | Input |
| --- | --- |
| Move | Left stick |
| Aim | Right stick |
| Fire | Right trigger or `A` / Cross |
| Pause | `Start` |

**Touch** (only active once a touchscreen or a touch event is seen)

| Action | Input |
| --- | --- |
| Move | Virtual stick anywhere on the left half (it appears under your thumb) |
| Aim + fire | Finger anywhere on the right half: the ship turns towards it and fires while held |
| Pause | The **II** button, top right |

Everything reaches the game through InputMap actions (`move_up`, `move_down`,
`move_left`, `move_right`, `aim`, `aim_left/right/up/down`, `shoot`, `pause`), so
the ship never asks where an input came from.

## How a battle runs

1. `BattleGame` builds a `Battle` from `Tuning.BATTLES` (the debug preset in a
   debug build, `DEFAULT_BATTLE` otherwise) and starts a wave director and a
   hazard field.
2. Each wave spawns `enemies_per_wave` fighters from the battle's weighted mix,
   each through a warpgate and at least 220px away from the ship.
3. Killing a fighter scores `points * combo multiplier`, drops energy orbs and
   raises the combo. Being hit costs a shield charge or HP and breaks the combo.
4. Clearing the last wave shows VICTORY; losing the hull shows DEFEATED. Both
   freeze the arena through `GameState` and leave the card and `R` (or the pause
   card's restart) available.

## Project structure

```
project.godot            960x600 canvas, landscape, nearest filtering, input actions
battle_game.gd/.tscn     arena root: score, combo, energy, waves, debug harness
battle.gd                Battle resource (waves, mix, density, background)
tuning.gd                every balance number, in one file (see Balancing)
upgrades.gd              upgrade table -> prices and ship stats
campaign.gd              sector graph queries (kept for the next stage)

autoload/
  game_state.gd          MENU / PLAYING / PAUSED / GAME_OVER / MAP / BATTLE_WON,
                         owns tree pause, focus loss and the back button
  save_data.gd           ConfigFile persistence in user://save.cfg
  audio_manager.gd       bus volumes, pooled SFX players, music, pitch jitter

entities/
  player/ship.gd/.tscn   flight, aim, HP, shields, fire
  fx/                    thruster.tscn (shared five-frame flame)
  enemies/               enemy_base (AI + stats), enemy_bullet (red dot)
  hazards/               asteroid, hazard_field (drift-in + debris)
  spawner/               wave_director (Battle -> waves)
  bullet/                player projectile
  effects/               explosion, shockwave, float_text, energy_mote, starfield,
                         shake_camera

ui/
  hud.gd/.tscn           landscape bars, pause card, end card
  touch_controls.gd      virtual stick, aim zone, pause button
  shop_panel.gd/.tscn    kept for the next stage
  settings_panel.gd/.tscn  kept for the next stage

assests/                 sprite packs, backgrounds and the (still empty) audio drop
                         folder; the name is misspelled on purpose, paths depend on it
```

## Collision layers

| # | Value | Layer | Used by | Mask | Reacts to |
| --- | --- | --- | --- | --- | --- |
| 1 | 1 | player | `Ship/Hurtbox` | 28 | enemies (4), rocks (8), enemy bullets (16) |
| 2 | 2 | player bullets | `Bullet/BulletArea` | 12 | enemies (4), rocks (8) |
| 3 | 4 | enemies | every `EnemyBase` | 0 | nothing (only detected) |
| 4 | 8 | hazards | `Asteroid` | 0 | nothing (only detected) |
| 5 | 16 | enemy bullets | `EnemyBullet` | 0 | nothing (only detected) |

Detection is one-way everywhere: a fighter or a rock never needs a reference to
the ship, and the ship never needs one to them.

## Running the project

1. Install **Godot 4.7** (standard build; the project uses the GL Compatibility
   renderer so it runs on older GPUs, the web and mobile).
2. Open `project.godot` and press `F5`, or from a terminal:
   ```bash
   godot --path .
   ```
3. Export templates are only needed for exporting (*Editor > Manage Export
   Templates*).

## Balancing

Every number worth tweaking lives in **`tuning.gd`**. Nothing in the logic depends
on the exact values.

| What | Constant(s) |
| --- | --- |
| Canvas and arena | `VIEW_SIZE` (960x600), `HUD_BAR_HEIGHT` (24), `ARENA_TOP/BOTTOM/LEFT/RIGHT`, `ARENA_MARGIN` |
| Ship flight | `SHIP_MAX_HP`, `SHIP_ACCELERATION`, `SHIP_MAX_SPEED`, `SHIP_DRAG` (inertia), `SHIP_TURN_LERP` |
| Ship weapons | `SHIP_FIRE_INTERVAL`, `SHIP_BULLET_SPEED`, `SHIP_BULLET_DAMAGE`, `SHIP_BULLET_LIFE`, `SHIP_MUZZLE_OFFSET` |
| Ship damage | `SHIP_INVULNERABILITY`, `SHIP_SHIELD_GRACE`, `MAX_SHIELD_CHARGES`, `SHIP_BLINK_*` |
| Thruster | `THRUSTER_FRAME_FPS`, `THRUSTER_IDLE_SCALE`, `THRUSTER_FULL_SCALE`, `THRUSTER_MIN_VISIBLE` |
| Fighters | `ENEMY_TYPES`: per kind `hp`, `speed`, `points`, `radius`, `orbit_radius` (0 = dive), `fire_interval`, `bullet_speed`, `aim_error`, `effect_color` |
| Fighter behaviour | `ENEMY_APPROACH_SLACK`, `ENEMY_ORBIT_SPEED_RATIO`, `ENEMY_WARP_TIME`, `WARP_SCALE`, `WARP_FRAME_FPS`, `ENEMY_CONTACT_DAMAGE`, `ENEMY_BULLET_*` |
| Asteroids | `ASTEROID_LARGE_HP`, `ASTEROID_LARGE/TINY_SCALE`, `ASTEROID_*_RADIUS`, `ASTEROID_CONTACT_DAMAGE`, `ASTEROID_SPEED_MIN/MAX`, `ASTEROID_SPIN_MIN/MAX`, `ASTEROID_SPLIT_MIN/MAX`, `ASTEROID_MAX_LIVE`, `ASTEROID_SPAWN_INTERVAL`, `ASTEROID_SPAWN_OFFSET` |
| Waves | `WAVE_GAP`, `SPAWN_STAGGER`, `ENEMY_THINK_INTERVAL` |
| Battle presets | `BATTLES` (`debug`, `tier1`, `tier2`, `tier3`): `waves`, `enemies_per_wave`, `mix`, `asteroid_density`, `background`; `DEFAULT_BATTLE`, `DEBUG_BATTLE` |
| Combo | `COMBO_WINDOW`, `COMBO_SCORE_STEP` (multiplier is 1 + chain/step, no cap), `COMBO_FLOAT_LIFE`, `COMBO_FLOAT_RISE`, `COMBO_FLOAT_COLOR` |
| Energy | `SCORE_POINTS_PER_ENERGY`, `MIN_ENERGY_PER_KILL`, `MAX_ORBS_PER_KILL`, `ORB_MAGNET_RADIUS`, `ORB_DRIFT_SPEED`, `ORB_HOME_SPEED`, `ORB_LIFE_SECONDS`, `ORB_PICKUP_RADIUS`, `ORB_PULSE_SPEED` |
| Effects | `MAX_LIVE_EXPLOSIONS`, `MAX_LIVE_FLOAT_TEXTS`, `EXPLOSION_PARTICLES`, `EXPLOSION_LIFE`, `SHOCKWAVE_LIFE`, `SHOCKWAVE_RADIUS`, `STARFIELD_*` |
| Upgrades | `UPGRADES` (price is `base_cost + cost_step * level`), `UPGRADE_MAX_LEVEL`, `HULL_LEVELS_PER_STEP` + `HP_PER_HULL_STEP` (+20 HP per 3 levels), `SPEED_PER_LEVEL`, `SHIELD_LEVELS_PER_CHARGE`, `FIRE_LEVELS_PER_DAMAGE`, `FIRE_INTERVAL_PER_LEVEL`, `MIN_FIRE_INTERVAL` |
| Campaign (next stage) | `CAMPAIGN_SECTORS`, `CAMPAIGN_ORDER`, `CAMPAIGN_START`, `CAMPAIGN_TIER_DIFFICULTY` |

## Exporting

All three presets live in `export_presets.cfg`. The Windows and Web builds use
`icon.svg`; Android uses the pre-rendered `icon-192.png`.

The canvas is **960x600 landscape**: the Android preset listens in landscape
(`window/handheld/orientation=0`), and the web canvas uses *Adaptive* resize with
`canvas_items` + `keep`, so any window or iframe letterboxes the same 16:10 view.
For an itch.io embed use **960x600** and enable the fullscreen button.

- **Windows:** *Project > Export... > Windows Desktop > Export Project*. Built
  `*.exe` files are git-ignored.
- **Web:** export into `export/` and serve it over HTTP (`python -m http.server
  8000` inside `export/`); opening `index.html` from disk will not load the WASM
  build.
- **Android:** arm64-v8a, package `com.astrodash.spaceshooter`, version 1.0.0.
  Create a debug keystore outside the repo once and point
  *Editor Settings > Export > Android > Debug Keystore* at it; keystore paths and
  passwords are deliberately not stored in this repo.

## Credits

- **SpacePixels** sprite packs: `assests/spacepixels-0.2.0` (ships, lasers,
  asteroids, thrusters, warpgates, bars, planets), `assests/spacepixels-0.1.0`
  (an older, smaller copy of the same art, kept because it is not byte-identical
  and is no longer referenced) and `spacepixels_ships_stroked` (the heavy hull).
- **Kenney** (<https://kenney.nl>) space backgrounds (`assests/background-*.png`).
- **Audio**: TODO — the project ships no sound files yet;
  `assests/audio/README.md` lists the names `AudioManager` expects.
- Everything else (HUD, hud bars layout, stick, particles, starfield, icon) is
  drawn in code or in `icon.svg` and was written for this project.
