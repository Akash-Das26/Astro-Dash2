# Astro Dash 2

A landscape twin-stick space shooter built with **Godot 4.7** (GL Compatibility)
for desktop, the web and Android. Fly free in a 960x600 arena, shoot fighters and
asteroids, chain kills for combo score, and take a galaxy one world at a time.

This build is **stage 11: difficulty modes, between-planet healing, thruster
alignment and wired sound effects**. NEW GAME opens a five-mode difficulty
picker, the hull heals between planets by mode, a defeat follows the mode's own
rule (keep the planets, start a new galaxy, or wipe everything), the exhaust is
anchored at every hull's tail, and the real SFX packs are mapped by keyword.
The campaign is still the seeded galaxy from 7B; the arena is the 7A/8 battle.

## Screenshots

> TODO: capture the menu, a mid-battle frame, the galaxy map, the upgrade screen
> and the victory card at 960x600 and drop them in `docs/screenshots/`. Until
> then this section is a placeholder; the game is playable with `F5`.

## What is in this build

### Main menu

- **A drawn title** (`ASTRO DASH 2`, red with a yellow outline) over an animated
  backdrop: ships with thrusters and asteroids drifting across, a large rock on
  the left, a parallax starfield and a slowly turning warpgate.
- **NEW GAME / CONTINUE / SETTINGS / QUIT**, left-aligned, with hover and focus
  highlight from the shared theme. CONTINUE is disabled when no campaign is
  saved. NEW GAME asks first when a run is in progress.
- The footer shows banked energy, the best planets-conquered run and the high
  score.

### Galaxy map (the campaign hub)

- **A stable galaxy per campaign.** ~50-60 bodies are scattered with a seeded
  Poisson-disk layout over a 2300x1500 map, then linked to their nearest
  neighbours (plus bridges so no island is unreachable). The seed is stored in
  the save, so relaunching brings back the same worlds, names, links and
  conquests. The map is panned, never zoomed.
- **Home and gate.** The home system sits nearest the left of the map and starts
  conquered; it is drawn as the animated `warpgate_1..3` loop. The gate is the
  body farthest from home by graph distance, drawn with the same art and tinted
  pink. It stays sealed until three of the five citadels have fallen.
- **Body types**, all with their own sprite and a `modulate` tint (the art is
  never recoloured): minor planets (`asteroid_grey`, `pixel_asteroid`,
  `asteroid_tiny`), rocky/lava (`planet5`/`planet6`), ocean/earth
  (`planet4`/`planet3`), gas giants (`planet1`/`planet2`) and citadels
  (`pixel_station_blue/green/red/yellow`, every colour used). All six planets and
  all four stations appear in every galaxy.
- **Procedural names and traits** from `galaxy.gd`, unique per galaxy. Each body
  has a trait — `MINOR PLANET`, `RESOURCE RICH`, `FERTILE`, `FORTRESS`,
  `CITADEL`, `HOME SYSTEM`, `THE FINAL GATE` — which changes payout and battle.
- **Interaction.** Hover or tap for a tooltip (name, trait, band, waves, enemies,
  boss, status). Attackable neighbours glow green with a bouncing arrow;
  conquered bodies are green-tinted with a check badge; locked ones are dim.
  Selecting one opens *CONQUER &lt;NAME&gt;?* with 48px green **BATTLE** and red
  **CANCEL**. Arrows / d-pad cycle the frontier, `Enter` / `A` attacks.
- **Top bar:** planets conquered, campaign score, spendable energy. **UPGRADE**
  (top left) opens the ship screen; Back returns to the menu.

### Ship upgrades and skins

- **A 2x2 grid of cards** — HEALTH +20, SPEED +1, SHIELDS +1, FIRE POWER +1 —
  each showing its level 0/10, its price and its precise effect on hover
  (`Upgrades.tooltip`). A card is disabled when it is unaffordable or maxed.
- **Current stats** on the left: HEALTH, SPEED, SHIELDS, FIRE. When a campaign is
  running, HEALTH and SHIELDS show the carried hull instead of a fresh one.
- **Energy** in red at the top; **X** closes (48px). Arrow keys / d-pad move
  between cards, `Enter` / `A` buys, `Esc` / `B` / Android Back closes.
- **Fire power is now shared by both hardpoints**: every level adds +12% damage
  and -3% cooldown (cooldown floors at -45%) to whatever is equipped. Only the
  PULSE LASER still changes its art with the track — blue at level 0, green from
  level 3, yellow from level 6 — because its art is the laser itself.
- **A WEAPONS tab** beside HULL & SHIP: one card per weapon showing DAMAGE,
  RATE, projectile SPEED and DPS, plus its state (OWNED, PRIMARY, SECONDARY,
  COST n ENERGY, UNLOCKS AT n PLANETS). Selecting a card previews its projectile
  large and in its own colour on the left; **BUY** spends energy, **EQUIP
  PRIMARY** / **EQUIP SECONDARY** fill the two hardpoints. A weapon may only sit
  in one slot, and the secondary starts empty.
- **Ten hull skins** in the picker: `pixel_ship_red/blue/yellow` plus the green
  interceptor, then the six stroked hulls. They unlock at 0, 5, 10, 15, 20, 25,
  30, 35, 40 and 45 planets conquered (best run counts, so a skin can unlock
  mid-run). The picker is saved as `skin` and the ship wears it in battle.

### Battles from a body

- **Difficulty from distance.** Graph hops from home pick a band: 6 to 14 enemies
  per wave, 1 to 3 waves, a heavier mix, more rocks and a different backdrop
  (`background-black`, `-blue`, `-purple`, `-red`). The trait bends it again.
- **Carried hull.** HP and shield charges carry from one campaign battle to the
  next and are saved with every conquest. Upgrade levels apply on top.
- **Citadel boss.** A citadel's last wave is followed by its station: 140 HP plus
  9 per hop, hovering and firing a fan of five red dots. Its name and a red
  health bar sit under the top readout. Beating it pays a large energy bonus.
- **Victory card:** planet name, waves completed, enemies destroyed, score
  earned, campaign total, and a **PERFECT VICTORY** line (+500 score, +25 energy)
  when the hull never dropped below the HP it entered with. **CONTINUE** returns
  to the map.
- **Game-over card:** **NEW HIGH SCORE!** when the run beat the record, final
  score, high score, planets conquered and the deepest band reached. **TRY
  AGAIN** starts a fresh campaign (energy and upgrades kept), **QUIT** returns to
  the menu.
- **Readable enemy fire.** Enemy shots are drawn hot diamonds with a white
  core, a pulsing halo and a short fading trail — never a reused player colour.
  The hitbox is deliberately smaller than the art. **HIGH-CONTRAST BULLETS**
  (Settings, on by default) thickens the outline and brightens the halo; on the
  red band the outline switches to yellow-white.
- **Shield drops.** About 8% of kills and always a citadel drop a blue bubble
  pickup worth one charge, up to 3. The ship wears a bubble with one pip per
  charge that flashes when a charge is spent, and the HUD reads `SHIELD x N`
  next to the HP bar. The SHIELDS track also adds starting charges every three
  levels and recharges one charge after a quiet stretch (25 s at level 1 down to
  8 s at max, reset by any hit). At level 0 the drop still works, so a shield is
  always reachable.
- **Two hardpoints.** The primary fires on `shoot`, the secondary on `shoot_alt`
  (right mouse / `Shift` / left shoulder or trigger / a second touch button),
  with independent cooldowns and left/right muzzle positions.
- **Everything from 7A stays:** free-flight ship with thruster, HP and shields,
  three fighter types, splitting asteroids, waves, combo, energy orbs, particles,
  shockwaves, camera shake, parallax starfield, touch stick and aim zone.

### Pause, focus and Back

`GameState` owns the tree pause. Losing window focus during a battle pauses it.
Android Back pauses a battle, resumes a paused one, closes the confirm card, the
upgrade screen and the settings card, returns the map to the menu, and quits from
the bare menu. The victory card's Back continues; the game-over card's Back goes
to the menu.

### Settings

Music and SFX sliders, mute, reduce motion, touch auto-fire,
**HIGH-CONTRAST BULLETS** (thicker outline, brighter halo; saved in
`user://save.cfg`) and **REMAP CONTROLS**, which opens the binding card. The note
under the sliders always shows the keys that are bound right now.

Music is a playlist of every `.ogg` / `.mp3` / `.wav` in
`assests/audio/music/`. Settings shows **NOW PLAYING**, **PREV**, **NEXT** and a
**SHUFFLE / IN ORDER** toggle. Shuffle uses a bag, so a full pass plays every
track once and the track that just ended never starts the next pass; tracks
cross-fade over 1.5 s. Sound effects are still postponed: `AudioManager` warns
once per missing file and those events stay silent.

## What is not in this build yet

A how-to-play card and real screenshots. Sound effects are now wired from the
two packs already in `assests/audio/` (see `assests/audio/README.md`); music is
a playlist from `assests/audio/music/`. The only open audio item is filling in
the per-pack credit TODO lines.

## Controls

Every action except the menu key can be rebound in **Settings > REMAP CONTROLS**:
one keyboard/mouse column, one gamepad column, a per-action reset and RESET TO
DEFAULTS. A key already in use is taken from the other action (the card says
which). Bindings are stored under `[controls]` in `user://save.cfg` and applied
at startup; Esc and Back stay fixed so a remap can never lock the player out.

### Menu

| Action | Input |
| --- | --- |
| Move focus | `Up` / `Down`, left stick / d-pad |
| Choose | `Enter` / `Space` / `A` |
| Close settings or confirm | `Esc` / `B` / Android Back |

### Galaxy map

| Action | Input |
| --- | --- |
| Pan | Drag with the mouse or a finger, `W` `A` `S` `D`, or the left stick |
| Inspect | Hover a body (mouse), or tap it (touch) |
| Attack | Click / tap a glowing body, or select it and press `Enter` / `A` |
| Cycle the frontier | `Left` / `Right` / `Up` / `Down` or the d-pad |
| Upgrades | Click / tap **UPGRADE**, or focus it with the d-pad |
| Close a card | `CANCEL`, `Esc` / `B`, or Android Back |
| Back to the menu | `Esc` / `B` / Android Back on the bare map |
| Zoom | Mouse wheel (around the cursor), pinch, or `+` / `-` |
| Controls card | `C` anywhere |
| Debug battle (debug builds) | `F9` starts the one-wave harness instead |

### Battle

**Keyboard**

| Action | Input |
| --- | --- |
| Move | `W` `A` `S` `D` or the arrow keys |
| Aim | Mouse (the nose follows the pointer once it moves) |
| Fire primary | `Space` or hold left click |
| Fire secondary | `Shift`, hold right click, or the touch **FIRE II** button |
| Raise the manual shield | `Z` (MANUAL shield mode), or the touch **SHIELD** button |
| Pause | `P` or `Esc` |
| Controls card | `C` (pauses while open) |
| Thruster overlay (debug builds) | `F3` draws every hull circle and exhaust anchor |
| End card | `Enter` continues / retries, `Esc` / `B` Back |
| Debug (debug builds) | `R` restarts the harness, `F9` starts it |

**CLASSIC scheme** (Settings > CONTROL SCHEME): `Left` / `Right` or `A` / `D`
turn, `Up` / `W` thrusts, `Down` / `S` brakes (it never reverses), and the nose
is the aim. Both schemes' bindings persist.

**Gamepad** (twin-stick): left stick moves, right stick aims, right trigger or
`A` / Cross fires the primary, left shoulder or left trigger fires the
secondary, `X` / Square raises the manual shield, `Start` pauses, d-pad and `A`
navigate cards.

**Touch:** virtual stick on the left half, aim-and-fire on the right half, a
second 48px+ **FIRE II** button for the secondary, 48px pause button. On the map,
drag pans and a tap selects.

Everything reaches the game through InputMap actions (`move_up`, `move_down`,
`move_left`, `move_right`, `aim`, `aim_left/right/up/down`, `shoot`, `shoot_alt`,
`pause`, plus Godot's built-in `ui_*` actions for every screen), so no screen
asks where an input came from.

## How a campaign runs

1. NEW GAME (or CONTINUE) loads the galaxy from `SaveData.campaign_seed`. Home is
   conquered without being stored, so its neighbours are attackable at once.
2. Picking an attackable body builds a `Battle` from its band and trait, hands
   the id to `Campaign` and changes scene. The carried hull is applied after the
   upgrade stats.
3. Waves warp in, combo and energy accrue, and a citadel adds its station after
   the last wave.
4. Victory banks the conquest, run score, carried hull and energy, then
   **CONTINUE** returns to the map so glows and links update.
5. A victory heals the hull by the mode's fraction of MAX HP (clamped), shown on
   the victory card as `HULL +25%  (96/120)` or `HULL REPAIRED TO FULL`.
6. Defeat ends the battle on the game-over card, which shows the mode and its
   rule. CADET/VECTOR keep the galaxy and planets and restore the hull
   (100% / 50%); SUPERNOVA/EVENT HORIZON draw a new galaxy while keeping energy,
   upgrades and weapons; SINGULARITY also wipes the campaign's meta progression.
   The button follows that rule: RETURN TO MAP, NEW GALAXY or START OVER.

## Project structure

```
project.godot            960x600 canvas, landscape, nearest filtering, input actions
ui/main_menu.gd/.tscn    front end: title, buttons, settings card, confirm card
ui/menu_backdrop.gd      drifting ships, rocks and warpgate behind the menu
ui/galaxy_map.gd/.tscn   campaign hub: pan, tooltip, confirm card, summaries
ui/upgrade_panel.gd/.tscn  upgrade cards, current stats, skin picker
ui/ui_theme.gd           the one theme: pixel font (if present), sizes, colours
skins.gd                 hull table, unlock thresholds, selected-skin validation
galaxy.gd                seeded layout, graph, types, traits, names, battle_for()
campaign.gd              run state: galaxy cache, pending body, victories/defeats
battle_game.gd/.tscn     arena root: score, combo, energy, waves, boss, end cards
battle.gd                Battle resource (waves, mix, density, difficulty, boss)
weapons.gd               the weapon table readers and formatting helpers
tuning.gd                every balance number, in one file (see Balancing)
upgrades.gd              upgrade table -> prices, ship stats, card labels

autoload/
  game_state.gd          MENU / PLAYING / PAUSED / GAME_OVER / MAP / BATTLE_WON,
                         owns tree pause, focus loss and the back button
  save_data.gd           ConfigFile persistence in user://save.cfg
  audio_manager.gd       bus volumes, pooled SFX players, music, pitch jitter

entities/
  player/ship.gd/.tscn   flight, aim, HP, shields, fire, carried hull, skin
  fx/                    thruster.tscn (shared five-frame flame)
  enemies/               enemy_base (AI + stats), enemy_bullet, boss_station
  hazards/               asteroid, hazard_field (drift-in + debris)
  spawner/               wave_director (Battle -> waves)
  map/                   body_marker (planet/glow/arrow/check), galaxy_links
  bullet/                player projectile with three laser tiers
  effects/               explosion, shockwave, float_text, energy_mote, starfield,
                         shake_camera

ui/
  hud.gd/.tscn           landscape bars, boss bar, pause card, victory/game-over cards
  touch_controls.gd      virtual stick, aim zone, pause button
  settings_panel.gd/.tscn  sliders, mute, reduce motion, auto-fire, control notes

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

Every number worth tweaking lives in **`tuning.gd`**, plus UI sizes in
`ui/ui_theme.gd` and skin unlock thresholds in `skins.gd`. Nothing in the logic
depends on the exact values.

| What | Constant(s) |
| --- | --- |
| Canvas and arena | `VIEW_SIZE` (960x600), `HUD_BAR_HEIGHT` (24), `ARENA_TOP/BOTTOM/LEFT/RIGHT`, `ARENA_MARGIN` |
| Ship flight | `SHIP_MAX_HP`, `SHIP_ACCELERATION`, `SHIP_MAX_SPEED`, `SHIP_DRAG` (exponential inertia), `SHIP_TURN_RATE` (exponential turn), `SHIP_AIM_DEADZONE`, `SHIP_WRAP_MARGIN` |
| Weapons | `WEAPONS` (one row per weapon: `damage`, `interval`, `speed`, `count`, `spread`, `pierce`, `life`, `scale`, `homing`, `area`, `knockback`, `cost`, `unlock`), `WEAPON_ORDER`, `WEAPON_MUZZLE_SIDE`, `FIRE_DAMAGE_PER_LEVEL`, `FIRE_COOLDOWN_PER_LEVEL`, `MIN_FIRE_COOLDOWN_MULT`, `WEAPON_BURST_COLOR`, `WEAPON_BURST_PARTICLES` |
| Shield drops and recharge | `SHIELD_DROP_CHANCE`, `SHIELD_DROP_FALL_SPEED`, `SHIELD_DROP_DRIFT`, `SHIELD_DROP_LIFE`, `SHIELD_DROP_RADIUS`, `SHIELD_DROP_VISUAL_RADIUS`, `SHIELD_RECHARGE_BASE`, `SHIELD_RECHARGE_STEP`, `SHIELD_RECHARGE_MIN`, `SHIELD_RECHARGE_DAMAGE_DELAY`, `SHIELD_BUBBLE_RADIUS` |
| Enemy bullet art | `ENEMY_BULLET_VISUAL_RADIUS`, `ENEMY_BULLET_CORE_RADIUS`, `ENEMY_BULLET_HITBOX_RADIUS`, `ENEMY_BULLET_TRAIL_SEGMENTS`, `ENEMY_BULLET_TRAIL_SPACING`, `ENEMY_BULLET_GLOW_PULSE`, `ENEMY_BULLET_BODY`, `ENEMY_BULLET_CORE`, `ENEMY_BULLET_OUTLINE*`, `ENEMY_BULLET_OUTLINE_WIDTH*` |
| Ship damage | `SHIP_INVULNERABILITY`, `SHIP_SHIELD_GRACE`, `MAX_SHIELD_CHARGES`, `SHIP_BLINK_*` |
| Thruster | `THRUSTER_FRAME_FPS`, `THRUSTER_IDLE_SCALE`, `THRUSTER_FULL_SCALE`, `THRUSTER_MIN_VISIBLE`, `THRUSTER_TAIL_GAP`, `THRUSTER_ART_SIZE`, `THRUSTER_BAR_ROWS` |
| Difficulty modes | `DIFFICULTIES` (heal, milestones, on_defeat, all battle multipliers), `DIFFICULTY_ORDER`, `DIFFICULTY_DEFAULT` (CADET), `DIFFICULTY_WIPE_LIST` |
| Fighters | `ENEMY_TYPES`: per kind `hp`, `speed`, `points`, `radius`, `orbit_radius` (0 = dive), `fire_interval`, `bullet_speed`, `aim_error`, `effect_color` |
| Fighter behaviour | `ENEMY_APPROACH_SLACK`, `ENEMY_ORBIT_SPEED_RATIO`, `ENEMY_WARP_TIME`, `WARP_SCALE`, `WARP_FRAME_FPS`, `ENEMY_CONTACT_DAMAGE`, `ENEMY_BULLET_*` |
| Asteroids | `ASTEROID_LARGE_HP`, `ASTEROID_LARGE/TINY_SCALE` (large art is ~2.6x the old size), `ASTEROID_*_RADIUS`, `ASTEROID_SHIP_CLEARANCE`, `ASTEROID_CONTACT_DAMAGE`, `ASTEROID_SPEED_MIN/MAX`, `ASTEROID_SPIN_MIN/MAX`, `ASTEROID_SPLIT_MIN/MAX`, `ASTEROID_MAX_LIVE`, `ASTEROID_SPAWN_INTERVAL`, `ASTEROID_SPAWN_OFFSET` |
| Waves | `WAVE_GAP`, `SPAWN_STAGGER`, `ENEMY_THINK_INTERVAL` |
| Battle presets (debug / fallback only) | `BATTLES` (`debug`, `tier1`, `tier2`, `tier3`), `DEFAULT_BATTLE`, `DEBUG_BATTLE` |
| Combo | `COMBO_WINDOW`, `COMBO_SCORE_STEP` (multiplier is 1 + chain/step, no cap), `COMBO_FLOAT_LIFE`, `COMBO_FLOAT_RISE`, `COMBO_FLOAT_COLOR` |
| Energy | `SCORE_POINTS_PER_ENERGY`, `MIN_ENERGY_PER_KILL`, `MAX_ORBS_PER_KILL`, `ORB_MAGNET_RADIUS`, `ORB_DRIFT_SPEED`, `ORB_HOME_SPEED`, `ORB_LIFE_SECONDS`, `ORB_PICKUP_RADIUS`, `ORB_PULSE_SPEED` |
| Effects | `MAX_LIVE_EXPLOSIONS`, `MAX_LIVE_FLOAT_TEXTS`, `EXPLOSION_PARTICLES`, `EXPLOSION_LIFE`, `SHOCKWAVE_LIFE`, `SHOCKWAVE_RADIUS`, `STARFIELD_*` |
| Upgrades | `UPGRADES` (price is `base_cost + cost_step * level`), `UPGRADE_MAX_LEVEL`, `HULL_LEVELS_PER_STEP` + `HP_PER_HULL_STEP`, `SPEED_PER_LEVEL`, `SHIELD_LEVELS_PER_CHARGE`, `FIRE_LEVELS_PER_DAMAGE`, `FIRE_INTERVAL_PER_LEVEL`, `MIN_FIRE_INTERVAL` |
| Perfect victory | `PERFECT_BONUS_SCORE` (500), `PERFECT_BONUS_ENERGY` (25) |
| Skins | `Skins.PLANETS_PER_UNLOCK` and each row's `unlock` in `skins.gd` |
| Legacy single-laser values | `SHIP_FIRE_INTERVAL`, `SHIP_BULLET_*`, `SHIP_MUZZLE_OFFSET`, `FIRE_INTERVAL_PER_LEVEL`, `MIN_FIRE_INTERVAL` (kept for the fallback bullet, superseded by `WEAPONS`) |
| UI scale and fonts | `UITheme.SIZE_*` (including `SIZE_DISPLAY`), `UITheme.COLOR_*`, the font-name hints in `ui/ui_theme.gd` and the button/card styleboxes |
| Galaxy layout | `GALAXY_MAP_SIZE`, `GALAXY_BODY_COUNT_MIN/MAX`, `GALAXY_MIN_SPACING`, `GALAXY_EDGE_MARGIN`, `GALAXY_LINKS_PER_BODY`, `GALAXY_MAX_LINK_LENGTH`, `GALAXY_HOME_ANCHOR`, `GALAXY_TAP_RADIUS`, `GALAXY_PAN_SPEED` |
| Map zoom | `GALAXY_ZOOM_MIN` (0.55), `GALAXY_ZOOM_MAX` (1.7), `GALAXY_ZOOM_STEP`, `GALAXY_ZOOM_SMOOTH` |
| Music playlist | `MUSIC_ORDER_SHUFFLE` / `MUSIC_ORDER_IN_ORDER`, `MUSIC_CROSSFADE` (1.5 s), `MUSIC_SILENT_DB` (-40), `MUSIC_PAUSE_GAIN` (0.45), `MUSIC_PAUSE_FADE`; the folder and formats in `autoload/audio_manager.gd` (`MUSIC_DIR`, `MUSIC_EXTENSIONS`, `MUSIC_FORMAT_PRIORITY`) |
| Controls | `CONTROL_ACTIONS`, `CONTROL_FIXED` (pause only), `CONTROL_LABELS` |
| Body art and tint | `GALAXY_BODY_ART`, `GALAXY_STATION_COLORS`, `GALAXY_TINTS`, `GALAXY_MARKER_TINTS`, `MAP_*` |
| Map rules | `GALAXY_CITADEL_COUNT`, `GALAXY_CITADELS_FOR_GATE` |
| Distance bands | `GALAXY_BANDS`: per band `max_distance`, `label`, `enemies`, `waves`, `mix`, `density`, `hp_scale`, `interval_scale`, `background` |
| Body traits | `GALAXY_TRAITS`: per trait `title`, `energy_scale`, `density_scale`, `enemies_delta`, `hp_scale`, `mix_bonus` |
| Conquest payouts | `GALAXY_CONQUEST_ENERGY`, `GALAXY_CITADEL_ENERGY`, `GALAXY_GATE_ENERGY` |
| Citadel boss | `BOSS_HP`, `BOSS_HP_PER_DISTANCE`, `BOSS_POINTS`, `BOSS_RADIUS`, `BOSS_SCALE`, `BOSS_FIRE_INTERVAL`, `BOSS_BULLETS_PER_VOLLEY`, `BOSS_SPREAD`, `BOSS_BULLET_DAMAGE`, `BOSS_CONTACT_DAMAGE`, `BOSS_HOVER_*` |

### Weapons

Every row lives in `Tuning.WEAPONS`; `weapons.gd` only reads and formats them.
FIRE POWER multiplies damage by `1 + 0.12 * level` and cooldowns by
`1 - 0.03 * level`, floored at 0.55, for **both** equipped slots.

| Weapon | Unlock | Cost | Projectile | Damage | Interval | Speed | Pattern | Extra |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PULSE LASER | start | — | `pixel_laser_blue` (tier-tinted) | 3 | 0.14 s | 780 | 1 bolt | default, unlimited |
| HEAVY CANNON | 3 planets | 45 | `pixel_laser_small_blue` | 9 | 0.8 s | 620 | 1 slug | 240 knockback |
| SCATTER SHOT | 6 planets | 80 | `pixel_laser_green` | 2 | 0.6 s | 640 | 4 pellets, 0.2 rad fan | short range (0.5 s life) |
| RAIL LASER | 12 planets | 130 | `pixel_laser_yellow` | 12 | 1.4 s | 1500 | 1 lance | pierces 4 |
| HOMING MISSILE | 18 planets | 200 | `pixel_laser_red` tinted orange | 7 | 1.1 s | 320 | 1, steers | 74 px burst, splash half damage |

### Shields and enemy fire

| What | Value |
| --- | --- |
| Shield drop chance | 8% per kill; a citadel boss always drops one |
| Shield drop | one charge, max 3, drifts down for 12 s |
| Shield recharge | 25 s at level 1, -1.8 s per level, floor 8 s; 3 s of no damage required; level 0 = no recharge |
| Shield upgrade | 15 energy + 8 per level; +1 starting charge every 3 levels |
| Enemy bullet | 10 px visual radius, 3.4 px core, 4 trail puffs, 8 px hitbox, 2 px outline (3.5 px high contrast) |

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

## Difficulty

Five modes live in `Tuning.DIFFICULTIES`, chosen on NEW GAME / NEW CAMPAIGN and
fixed for the campaign. Healing is a fraction of **MAX HP**, added to the hull
and clamped; the largest reached milestone **replaces** the per-planet heal.
`Campaign.planets_conquered()` counts the home system, so the counter on the map
is also the number used by the milestones. Every mode stacks its battle
multipliers on top of the distance band and the body trait.

| Mode | Heal per planet | Milestones | Defeat rule | Enemy HP | Enemy damage | Enemies/wave | Energy | Score | Shield drops |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CADET | 100% | — | keep planets, hull 100% | x0.8 | x0.8 | x0.9 | x1.0 | x1.0 | x1.5 |
| VECTOR | 25% | 50% at 5, 100% at 10 | keep planets, hull 50% | x1.0 | x1.0 | x1.0 | x1.0 | x1.0 | x1.0 |
| SUPERNOVA | 10% | 25% at 5, 50% at 10 | new galaxy, meta kept | x1.25 | x1.2 | x1.1 | x1.1 | x1.25 | x0.8 |
| EVENT HORIZON | 0% | 10% at 5, 25% at 10 | new galaxy, meta kept | x1.5 | x1.4 | x1.25 | x1.25 | x1.5 | x0.6 |
| SINGULARITY | 0% | 5% at 10 | wipes campaign, energy, upgrades and weapons | x1.8 | x1.7 | x1.4 | x1.5 | x2.0 | x0.5 |

High scores are stored per mode under `[high_scores]`; the game-over card and the
menu footer show the record for the mode being played. A save from before this
system loads as CADET, with its old `high_score` seeding CADET's record.

## Save file

`user://save.cfg` keeps the meta-progression and the run:

| Section | Keys |
| --- | --- |
| `progress` | `high_score` (legacy = CADET), `energy`, `skin` |
| `high_scores` | one key per mode (`cadet`, `vector`, `supernova`, `event_horizon`, `singularity`) |
| `upgrades` | `<kind>_level` for hull, speed, shield, fire |
| `gameplay` | `reduce_motion`, `auto_fire`, `high_contrast_bullets` |
| `weapons` | `owned` (list), `primary`, `secondary` — missing keys fall back to the pulse laser and an empty second slot, so older saves load |
| `audio` | `music_volume`, `sfx_volume`, `muted` |
| `gameplay` | `reduce_motion`, `auto_fire` |
| `campaign` | `active`, `seed`, `difficulty`, `score`, `hp`, `shields`, `conquered`, `best_score`, `best_planets` |

The galaxy is rebuilt from `seed`; `conquered` stores the body ids that fell (home
is implicit). `hp`/`shields` are written on every conquest, so a relaunch resumes
with the same map and the hull the last victory ended with. Quitting in the
middle of a battle loses that battle but not the run or the energy collected.

## Asset audit

Every PNG under `assests/`, where it is used, and why anything is unused.
Paths are relative to `assests/`.

| PNG | Used by |
| --- | --- |
| `background-black.png` | `battle_game.tscn` backdrop, near-space band |
| `background-blue.png` | blue-veil band (`tuning.gd`) |
| `background-purple.png` | purple-deep band (`tuning.gd`) |
| `background-red.png` | red-expanse band (`tuning.gd`) |
| `spacepixels-0.2.0/.../asteroid_grey.png` | map minor planets, large rocks, menu drift |
| `spacepixels-0.2.0/.../asteroid_grey_tiny.png` | split debris, menu drift |
| `spacepixels-0.2.0/.../asteroid_tiny.png` | map minor planets, small rocks, menu drift |
| `spacepixels-0.2.0/.../pixel_asteroid.png` | map minor planets, menu prop |
| `spacepixels-0.2.0/.../horizontal_bar_grey.png` | HP/shield/boss bar underlays |
| `spacepixels-0.2.0/.../horizontal_bar_green.png` | HP bar (healthy) |
| `spacepixels-0.2.0/.../horizontal_bar_yellow.png` | HP bar (hurt) |
| `spacepixels-0.2.0/.../horizontal_bar_red.png` | HP bar (critical), citadel bar |
| `spacepixels-0.2.0/.../horizontal_bar_blue.png` | shield bar |
| `spacepixels-0.2.0/.../pixel_laser_blue.png` | player shot, fire power tier 0 |
| `spacepixels-0.2.0/.../pixel_laser_green.png` | player shot, tier 1 |
| `spacepixels-0.2.0/.../pixel_laser_yellow.png` | player shot, tier 2 (and the scene default) |
| `spacepixels-0.2.0/.../pixel_laser_red.png` | enemy bullets |
| `spacepixels-0.2.0/.../pixel_laser_small_blue.png` | energy orbs |
| `spacepixels-0.2.0/.../pixel_ship_red.png` | default hull, skin, menu drift |
| `spacepixels-0.2.0/.../pixel_ship_blue.png` | COBALT skin, menu drift |
| `spacepixels-0.2.0/.../pixel_ship_yellow.png` | AMBER skin, menu drift |
| `spacepixels-0.2.0/.../pixel_ship_green_small_2.png` | JADE skin (the pack's only green hull), menu drift |
| `spacepixels-0.2.0/.../pixel_ship_blue_small.png` | scout/gunner fighters |
| `spacepixels-0.2.0/.../pixel_ship_red_small_2.png` | heavy fighter |
| `spacepixels-0.2.0/.../pixel_station_blue.png` | citadel body, map citadel |
| `spacepixels-0.2.0/.../pixel_station_green.png` | citadel body, map citadel |
| `spacepixels-0.2.0/.../pixel_station_red.png` | citadel body (scene default), map citadel |
| `spacepixels-0.2.0/.../pixel_station_yellow.png` | citadel body, map citadel |
| `spacepixels-0.2.0/.../planets/planet1.png` | gas giants (map) |
| `spacepixels-0.2.0/.../planets/planet2.png` | gas giants (map) |
| `spacepixels-0.2.0/.../planets/planet3.png` | ocean/earth worlds (map) |
| `spacepixels-0.2.0/.../planets/planet4.png` | ocean/earth worlds (map) |
| `spacepixels-0.2.0/.../planets/planet5.png` | rocky/lava worlds (map) |
| `spacepixels-0.2.0/.../planets/planet6.png` | rocky/lava worlds (map) |
| `spacepixels-0.2.0/.../thruster-1..5.png` | shared five-frame thruster on every ship |
| `spacepixels-0.2.0/.../warpgate_1..3.png` | warp-in effect, home and gate markers, menu |
| `spacepixels_ships_stroked/.../ship_red_stroked.png` | heavy fighter, STROKED RED skin |
| `spacepixels_ships_stroked/.../ship_blue_stroked.png` | STROKED BLUE skin |
| `spacepixels_ships_stroked/.../ship_green_stroked.png` | STROKED GREEN skin |
| `spacepixels_ships_stroked/.../ship_orange_stroked.png` | STROKED ORANGE skin |
| `spacepixels_ships_stroked/.../ship_purple_stroked.png` | STROKED PURPLE skin |
| `spacepixels_ships_stroked/.../ship_yellow_stroked.png` | STROKED YELLOW skin |

Unused, deliberately:

| PNG | Why it is unused |
| --- | --- |
| `spacepixels-0.2.0/.../pixel_ship.png` | the white base hull; the skins only use the coloured variants |
| `spacepixels-0.2.0/.../pixel_shape3_blue.png` | an abstract blue shape, not a ship, rock or station |
| `spacepixels-0.2.0/.../pixel_ship3_red.png` | alternate 32px fighter art, superseded by the small hulls |
| `spacepixels-0.2.0/.../pixel_ship3_green.png` | same alternate art |
| `spacepixels-0.2.0/.../pixel_ship3_yellow.png` | same alternate art |

`spacepixels-0.1.0` was deleted: every PNG in it was byte-identical to its
`0.2.0` copy. No file under `res://assests/` is referenced by a missing path.

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
  asteroids, thrusters, warpgates, bars, planets) and
  `spacepixels_ships_stroked` (the stroked hulls).
- **Kenney** (<https://kenney.nl>) space backgrounds (`assests/background-*.png`).
- **Pixel fonts**: Pixelify Sans (body) and Press Start 2P (titles, banners, big
  numbers), both OFL, in `assests/fonts/`. `UITheme` finds them by filename and
  falls back to Godot's default font, silently, when either is missing.
- **Music**: the playlist in `assests/audio/music/`. **These tracks require
  attribution**: `assests/audio/music/CREDITS.md` lists the title, author,
  license and source URL per track (CC BY 3.0, CC BY-SA 3.0 and CC0, with the
  license links), and the CC BY-SA track keeps its share-alike terms. The citadel
  theme is mapped in `Tuning.MUSIC_CONTEXTS` and plays only for boss battles; it
  is kept out of the normal shuffle.
- **Sound effects**: TODO — add author, license and source for each pack used
  by `AudioManager.SOUND_MAP`:
  - The Essential Retro Video Game Sound Effects Collection (512 sounds) by
    Juhani Junkala — TODO: license, source URL.
  - Essential Game Audio pack by Ove Melaa — TODO: license, source URL.
  `assests/audio/README.md` lists every event, the files behind it and the
  per-sound volume trims.
- Everything else (HUD, map markers and links, tooltips, cards, stick, particles,
  starfield, icon) is drawn in code or in `icon.svg` and was written for this
  project.
