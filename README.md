# Astro Dash 2

A landscape twin-stick space shooter built with **Godot 4.7** (GL Compatibility)
for desktop, the web and Android. Fly free in a 960x600 arena, shoot fighters and
asteroids, chain kills for combo score, and take a galaxy one world at a time.

This build is **stage 7B: the galaxy map campaign**. The old node-graph campaign
screen from the portrait era is gone; the map is now a seeded field of 50-60
bodies you pan around, and the arena from stage 7A is how a body is taken. The
front end, shop, settings and how-to cards return in the next stages, so the map
starts a campaign by itself for now. See *What is not in this build yet*.

## What is in this build

### Galaxy map (the campaign hub)

- **A stable galaxy per campaign.** ~50-60 bodies are scattered with a seeded
  Poisson-disk layout over a 2300x1500 map, then linked to their nearest
  neighbours (plus a few short bridges so no island is unreachable). The seed is
  stored in the save, so quitting and relaunching brings back the same worlds,
  names, links and conquests. The map is panned, never zoomed.
- **Home and gate.** The home system sits nearest the left of the map and starts
  conquered; it is drawn as the animated `warpgate_1..3` loop. The gate is the
  body farthest from home by graph distance, drawn with the same gate art and
  tinted pink. It stays sealed until three of the five citadels have fallen.
- **Body types**, all with their own sprite and a `modulate` tint (the art is
  never recoloured): minor planets (`asteroid_grey`, `pixel_asteroid`,
  `asteroid_tiny`), rocky/lava (`planet5`/`planet6`, orange and red),
  ocean/earth (`planet4`/`planet3`), gas giants (`planet1`/`planet2`) and
  citadels (`pixel_station_blue/green/red/yellow`, every colour used). All six
  planet sprites and all four stations appear in every galaxy.
- **Procedural names and traits.** Names come from a prefix + suffix list in
  `galaxy.gd` and are unique per galaxy. Each body also has a trait shown in its
  tooltip — `MINOR PLANET`, `RESOURCE RICH`, `FERTILE`, `FORTRESS`, `CITADEL`,
  `HOME SYSTEM`, `THE FINAL GATE` — which changes the payout and the battle
  (energy multiplier, asteroid density, enemies per wave, fighter HP and mix).
- **Interaction.** Hover or tap for a tooltip (name, trait, band, wave count,
  enemies per wave, boss, conquered/attackable/locked). Bodies next to the
  conquered network glow green with a bouncing arrow; conquered bodies are
  green-tinted with a check badge; locked ones are dim. Selecting an attackable
  body opens a confirm card — *CONQUER &lt;NAME&gt;?* with a green **BATTLE** and a red
  **CANCEL** (both 48px tall) — and keyboard/gamepad can cycle the attackable
  frontier with the arrow keys / d-pad.
- **Top bar:** planets conquered, campaign score and spendable energy. The
  bottom line lists the map controls.

### Battles from a body

- **Difficulty from distance.** The number of graph hops from home picks a band:
  enemies per wave 6 to 14, 1 to 3 waves, a heavier fighter mix, more rocks and
  a different backdrop (`background-black`, `-blue`, `-purple`, `-red`). The
  trait then bends it again. Citadels are always at least two waves, the gate
  three.
- **Carried hull.** HP and shield charges carry from one campaign battle to the
  next and are saved with every conquest. The shop's hull/fire/speed/shield
  upgrades still apply on top.
- **Citadel boss.** A citadel's last wave is followed by its station: 140 HP plus
  9 per hop from home, hovering over the arena and firing a fan of five red dots
  every 2.1s. Its name and a `horizontal_bar_red` health bar sit under the top
  readout. Beating it pays a large energy bonus.
- **Conquest.** Victory marks the body conquered, adds the battle score to the
  run, banks the flat energy bonus (trait-scaled, +120 for a citadel, +250 for the
  gate) and returns to the map after a short summary. Defeat ends the campaign
  and shows the summary card — planets, citadels, score, best — with **RETRY**.
  Taking the gate shows **GALAXY CONQUERED** with **NEW CAMPAIGN**. Both start a
  fresh galaxy with reset conquests and hull; energy and upgrades are kept.
- **Everything from 7A stays:** free-flight ship with thruster, HP and shields,
  three fighter types, splitting asteroids, waves, combo, energy orbs, particles,
  shockwaves, camera shake, parallax starfield, touch stick and aim zone.

## What is not in this build yet

The front end (menu with NEW / CONTINUE CAMPAIGN, campaign summaries from the map
entry point), the shop card, the settings card, the how-to card, power-up pickups
and audio. Because there is no front end yet, the map begins a new campaign on
first launch instead of asking; Android Back on the bare map is absorbed (it
closes the confirm card when one is open) until the menu exists.

The systems behind those screens are kept and ported: `GameState` (state machine
and pause ownership), `SaveData` (ConfigFile persistence), `AudioManager` (buses
and pooled SFX), `Tuning`, `Upgrades`, `ShakeCamera`, `Explosion`, `SettingsPanel`
and `ShopPanel`.

## Controls

### Galaxy map

| Action | Input |
| --- | --- |
| Pan | Drag with the mouse or a finger, `W` `A` `S` `D`, or the left stick |
| Inspect | Hover a body (mouse), or tap it (touch) |
| Attack | Click / tap a glowing body, or select it and press `Enter` / `A` |
| Cycle the frontier | `Left` / `Right` / `Up` / `Down` or the d-pad |
| Close the card | `CANCEL`, `Esc` / `B`, or Android Back |
| Debug battle (debug builds) | `F9` starts the one-wave harness instead |

### Battle

**Keyboard**

| Action | Input |
| --- | --- |
| Move | `W` `A` `S` `D` or the arrow keys |
| Aim | Mouse (the nose follows the pointer once it moves) |
| Fire | `Space` or hold left click |
| Pause | `P` or `Esc` |
| Debug (debug builds) | `R` restarts the end card, `F9` starts the harness |

**Gamepad** (twin-stick): left stick moves, right stick aims, right trigger or
`A` / Cross fires, `Start` pauses.

**Touch** (once a touchscreen is seen): virtual stick anywhere on the left half,
aim-and-fire anywhere on the right half, 48px **II** pause button. On the map,
drag pans and a tap selects.

Everything reaches the game through InputMap actions (`move_up`, `move_down`,
`move_left`, `move_right`, `aim`, `aim_left/right/up/down`, `shoot`, `pause`, plus
Godot's built-in `ui_*` actions for the map), so no screen asks where an input
came from.

## How a campaign runs

1. The map loads the galaxy from `SaveData.campaign_seed` (a fresh seed is drawn
   when no campaign is active). Home is conquered without being stored, so the
   neighbourhood of home is attackable from the first frame.
2. Picking an attackable body builds a `Battle` from its distance band and
   trait, hands the body id to `Campaign`, and changes scene. HP/shields from the
   previous victory are applied after the shop stats.
3. The battle runs exactly like 7A: waves warp in, combo and energy accrue, and a
   citadel adds its station after the last wave.
4. Victory records the conquest, run score, carried hull and energy, then returns
   to the map so the glows and links update. Defeat records the best result and
   ends the run.

## Project structure

```
project.godot            960x600 canvas, landscape, nearest filtering, input actions
ui/galaxy_map.gd/.tscn   campaign hub: pan, tooltip, confirm card, summaries
galaxy.gd                seeded layout, graph, types, traits, names, battle_for()
campaign.gd              run state: galaxy cache, pending body, victories/defeats
battle_game.gd/.tscn     arena root: score, combo, energy, waves, boss, return trip
battle.gd                Battle resource (waves, mix, density, difficulty, boss)
tuning.gd                every balance number, in one file (see Balancing)
upgrades.gd              upgrade table -> prices and ship stats

autoload/
  game_state.gd          MENU / PLAYING / PAUSED / GAME_OVER / MAP / BATTLE_WON,
                         owns tree pause, focus loss and the back button
  save_data.gd           ConfigFile persistence in user://save.cfg
  audio_manager.gd       bus volumes, pooled SFX players, music, pitch jitter

entities/
  player/ship.gd/.tscn   flight, aim, HP, shields, fire, carried hull
  fx/                    thruster.tscn (shared five-frame flame)
  enemies/               enemy_base (AI + stats), enemy_bullet, boss_station
  hazards/               asteroid, hazard_field (drift-in + debris)
  spawner/               wave_director (Battle -> waves)
  map/                   body_marker (planet/glow/arrow/check), galaxy_links
  bullet/                player projectile
  effects/               explosion, shockwave, float_text, energy_mote, starfield,
                         shake_camera

ui/
  hud.gd/.tscn           landscape bars, boss bar, pause card, end card
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
| 3 | 4 | enemies | every `EnemyBase`, `BossStation` | 0 | nothing (only detected) |
| 4 | 8 | hazards | `Asteroid` | 0 | nothing (only detected) |
| 5 | 16 | enemy bullets | `EnemyBullet` | 0 | nothing (only detected) |

Detection is one-way everywhere: a fighter, station or rock never needs a
reference to the ship, and the ship never needs one to them.

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
| Battle presets (debug / fallback only) | `BATTLES` (`debug`, `tier1`, `tier2`, `tier3`), `DEFAULT_BATTLE`, `DEBUG_BATTLE` |
| Combo | `COMBO_WINDOW`, `COMBO_SCORE_STEP` (multiplier is 1 + chain/step, no cap), `COMBO_FLOAT_LIFE`, `COMBO_FLOAT_RISE`, `COMBO_FLOAT_COLOR` |
| Energy | `SCORE_POINTS_PER_ENERGY`, `MIN_ENERGY_PER_KILL`, `MAX_ORBS_PER_KILL`, `ORB_MAGNET_RADIUS`, `ORB_DRIFT_SPEED`, `ORB_HOME_SPEED`, `ORB_LIFE_SECONDS`, `ORB_PICKUP_RADIUS`, `ORB_PULSE_SPEED` |
| Effects | `MAX_LIVE_EXPLOSIONS`, `MAX_LIVE_FLOAT_TEXTS`, `EXPLOSION_PARTICLES`, `EXPLOSION_LIFE`, `SHOCKWAVE_LIFE`, `SHOCKWAVE_RADIUS`, `STARFIELD_*` |
| Upgrades | `UPGRADES` (price is `base_cost + cost_step * level`), `UPGRADE_MAX_LEVEL`, `HULL_LEVELS_PER_STEP` + `HP_PER_HULL_STEP`, `SPEED_PER_LEVEL`, `SHIELD_LEVELS_PER_CHARGE`, `FIRE_LEVELS_PER_DAMAGE`, `FIRE_INTERVAL_PER_LEVEL`, `MIN_FIRE_INTERVAL` |
| Galaxy layout | `GALAXY_MAP_SIZE`, `GALAXY_BODY_COUNT_MIN/MAX`, `GALAXY_MIN_SPACING`, `GALAXY_EDGE_MARGIN`, `GALAXY_LINKS_PER_BODY`, `GALAXY_MAX_LINK_LENGTH`, `GALAXY_HOME_ANCHOR`, `GALAXY_TAP_RADIUS`, `GALAXY_PAN_SPEED` |
| Body art and tint | `GALAXY_BODY_ART`, `GALAXY_STATION_COLORS`, `GALAXY_TINTS`, `GALAXY_MARKER_TINTS`, `MAP_*` |
| Map rules | `GALAXY_CITADEL_COUNT`, `GALAXY_CITADELS_FOR_GATE` |
| Distance bands | `GALAXY_BANDS`: per band `max_distance`, `label`, `enemies`, `waves`, `mix`, `density`, `hp_scale`, `interval_scale`, `background` |
| Body traits | `GALAXY_TRAITS`: per trait `title`, `energy_scale`, `density_scale`, `enemies_delta`, `hp_scale`, `mix_bonus` |
| Conquest payouts | `GALAXY_CONQUEST_ENERGY`, `GALAXY_CITADEL_ENERGY`, `GALAXY_GATE_ENERGY` |
| Citadel boss | `BOSS_HP`, `BOSS_HP_PER_DISTANCE`, `BOSS_POINTS`, `BOSS_RADIUS`, `BOSS_SCALE`, `BOSS_FIRE_INTERVAL`, `BOSS_BULLETS_PER_VOLLEY`, `BOSS_SPREAD`, `BOSS_BULLET_DAMAGE`, `BOSS_CONTACT_DAMAGE`, `BOSS_HOVER_*` |

### Difficulty bands

`GALAXY_BANDS` is keyed on the number of links between a body and home. The first
row whose `max_distance` is at least that hop count wins; the last row is the
fallback.

| Band | Hops | Enemies/wave | Waves | Backdrop | Rock density | Fighter HP |
| --- | --- | --- | --- | --- | --- | --- |
| NEAR SPACE | 1-2 | 6 | 1 | `background-black` | 0.55 | x1.0 |
| BLUE VEIL | 3-5 | 9 | 2 | `background-blue` | 0.85 | x1.15 |
| PURPLE DEEP | 6-8 | 12 | 2 | `background-purple` | 1.1 | x1.3 |
| RED EXPANSE | 9+ | 14 | 3 | `background-red` | 1.4 | x1.5 |

The trait then adds `enemies_delta`, multiplies density and HP, and scales the
conquest bonus: MINOR PLANET x0.7 energy, RESOURCE RICH x1.8, FERTILE x1.2,
FORTRESS x1.0, CITADEL x1.4, THE FINAL GATE x2.0. Citadels add 120 energy, the
gate 250.

## Save file

`user://save.cfg` keeps the meta-progression and the run:

| Section | Keys |
| --- | --- |
| `progress` | `high_score`, `energy` |
| `upgrades` | `<kind>_level` for hull, speed, shield, fire |
| `audio` | `music_volume`, `sfx_volume`, `muted` |
| `gameplay` | `reduce_motion`, `auto_fire` |
| `campaign` | `active`, `seed`, `score`, `hp`, `shields`, `conquered`, `best_score`, `best_planets` |

The galaxy is rebuilt from `seed`; `conquered` stores the body ids that fell (home
is implicit). `hp`/`shields` are written on every conquest, so a relaunch resumes
with the same map and the hull the last victory ended with. Quitting in the
middle of a battle loses that battle but not the run or the energy collected.

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
- Everything else (HUD, map markers and links, tooltips, cards, stick, particles,
  starfield, icon) is drawn in code or in `icon.svg` and was written for this
  project.
