# Astro Dash 2

A small vertical space shooter built with **Godot 4.7** (GL Compatibility) for
desktop, the web and Android. Survive waves of incoming ships, shoot them before
they cross the blue defence line, and chase a high score across three lives.

Two modes share the same battle: **ARCADE** is the endless run, and **CAMPAIGN**
is a nine-planet sector map where the ship's lives carry from battle to battle.

## Features

- Wave director: a tunable enemy mix per wave, shrinking spawn intervals, and a
  boss every fifth wave that strafes, fires fan spreads and eventually leaves.
- Three enemy types (straight, zigzag, three-hit tank) plus the boss, all built
  on one shared `EnemyBase` (hp, score value, hit flash, boundary rule).
- Two modes from the menu: **ARCADE** (endless waves, high score) and
  **CAMPAIGN** (nine planets; clear a sector's 1-3 waves to unlock the sectors
  it links to, and conquer all nine to finish).
- Campaign map: a vertical planet graph drawn with primitives — rings and colour
  variations per planet, lines between linked sectors, a green glow on the ones
  you can attack now, a check on conquered ones and a dimmed, locked rest — with
  a confirmation card (BATTLE / CANCEL, 48px and up) and arrow-key / d-pad
  navigation.
- Campaign battles reuse the wave director with per-tier scaling and carry the
  ship's lives between battles; the sector score adds up across the campaign, a
  boss sector hands one life back, and a clear with no life lost pays a PERFECT
  VICTORY bonus.
- Sector victory summary (waves, kills, score, energy, bonus) and a campaign-over
  card with planets conquered and the highest tier reached, plus an
  end-of-campaign screen after the final sector.
- Campaign progress is saved as it happens (conquered sectors, lives, campaign
  score, best result), so the menu offers CONTINUE CAMPAIGN after a relaunch and
  puts NEW CAMPAIGN behind a confirmation card.
- Falling pickups: rapid fire, spread shot, shield and bomb, with HUD timers that
  refresh instead of stacking.
- Feel: CPUParticles2D bursts tinted per enemy type, capped trauma-based camera
  shake, hit flashes, a parallax starfield and tweened UI.
- Audio on Master / Music / SFX buses, with volume sliders, mute and pitch
  variation on shots and explosions.
- Energy: every kill drops motes that fly to the ship inside a magnet radius and
  bank into a spendable currency, shown on the HUD.
- Upgrade shop reachable from the menu or the game-over card: hull, speed,
  shields and fire power, ten levels each, with prices that scale and levels
  that persist between sessions.
- Combo scoring: kills chained inside a short window raise the multiplier up to
  x5, with a floating `xN COMBO` that decays as the window runs out.
- Game-over summary with waves reached, best combo and energy earned, plus a
  NEW HIGH SCORE banner when the run beats the record.
- Settings persisted to `user://save.cfg`: volumes, mute, reduce motion,
  auto-fire, high score, energy, upgrade levels and campaign progress.
- Touch controls on phones and tablets (relative drag, auto-fire, on-screen
  pause), keyboard and gamepad on desktop.
- Pauses itself when the window loses focus; Android's back button pauses a
  battle, closes the campaign card, leaves the map, or quits, depending on where
  you are.
- Web build starts audio on the first click so browser autoplay policy cannot
  silence the game.

## Controls

**Keyboard**

| Action | Keys |
| --- | --- |
| Move | `A` / `D` or `Left` / `Right` |
| Fire | `Space` |
| Pause | `P` or `Esc` |
| Map: pick a sector | `Left` / `Right` or `Up` / `Down`, then `Space` / `Enter` |
| Map: close the card | `Esc` |

**Gamepad**

| Action | Input |
| --- | --- |
| Move | Left stick |
| Fire | `A` / Cross |
| Pause | `Start` |
| Map: pick a sector | D-pad or left stick, then `A` / Cross |
| Map: close the card | `B` / Circle |

**Touch** (only shown when a touchscreen is detected)

| Action | Input |
| --- | --- |
| Move | Drag anywhere on the lower half of the screen (relative, so your thumb never covers the ship) |
| Fire | Automatic while a finger is down; with **Auto-fire** off, hold the **FIRE** button in the bottom-right corner |
| Pause | The **II** button in the top-right corner |
| Map | Tap a planet, then **BATTLE**; **CANCEL** or Back closes the card |

Debug builds only: `B` drops a boss in, `1`–`4` spawn a rapid / spread / shield /
bomb pickup, and the bottom-left line counts live nodes.

## Campaign mode

ARCADE is one endless run. CAMPAIGN is a map of nine planets fought with the same
ship, the same pickups and the same wave director.

- **The map.** One vertical screen, drawn with primitives. Glowing planets can be
  attacked now, checked ones are conquered, dimmed ones are still locked. Lines
  between sectors show where clearing one can take you. Tap a planet (or use the
  arrow keys / d-pad and accept) for a card with its name, tier, wave count and
  boss flag, then BATTLE or CANCEL.
- **Battles.** A sector is 1-3 waves of its own enemy mix; the last wave of a boss
  sector adds the boss. Clear every wave to win the sector, or lose a life the
  usual way. Losing the last life ends the campaign.
- **Lives carry over.** A campaign starts with the hull upgrade's lives and keeps
  what is left from battle to battle. A sector won against a boss gives one life
  back, up to the hull maximum. Lives reset only when a new campaign starts.
- **Score and energy.** Each battle's score adds to the campaign total, and energy
  still banks per mote into the shop currency, so a failed campaign has still fed
  the meta-progression.
- **Victory summary.** Sector name, waves cleared, enemies destroyed, score and
  energy earned, plus a PERFECT VICTORY line when no life was lost (an extra
  score and energy bonus, set in `tuning.gd`). CONTINUE goes back to the map.
- **Defeat and completion.** A lost campaign shows planets conquered and the
  highest tier reached; RETRY starts a fresh campaign (sector progress and lives
  reset, energy and upgrades are kept). Conquering the final sector shows the
  campaign-complete screen and records the best result.
- **Resume.** Progress is written to `user://save.cfg` as sectors are conquered, so
  quitting mid-campaign and relaunching leaves CONTINUE CAMPAIGN and NEW CAMPAIGN
  on the menu.
- **Difficulty.** `CAMPAIGN_TIER_DIFFICULTY` in `tuning.gd` scales enemy health, the
  gap between spawns and the boss fire gap per tier; see the balancing table.

Android's Back button closes the confirmation card, leaves the map for the menu,
pauses a battle, and leaves a summary for the map (or the menu after a finished
campaign).

## Project structure

```
project.godot            input actions, display/stretch, autoloads
default_bus_layout.tres  Master / Music / SFX buses
game_manager.gd/.tscn    playfield root: score, lives, combo, energy, power-ups, spawning glue
tuning.gd                every balance number, in one file (see Balancing)
upgrades.gd              upgrade table -> prices and ship stats
campaign.gd              sector graph queries: unlocks, waves, tier difficulty

autoload/
  game_state.gd          MENU / MAP / PLAYING / PAUSED / GAME_OVER / BATTLE_WON,
                         owns tree pause, focus-loss and back-button handling
  save_data.gd           ConfigFile persistence in user://save.cfg
  audio_manager.gd       bus volumes, pooled SFX players, music, pitch jitter

entities/
  player/                ship, hurtbox, power-up effects, shield bubble
  bullet/                player projectile
  enemies/               enemy_base (shared), enemy, zigzag_enemy, tank_enemy,
                         boss, enemy_bullet
  enemy_spawner/         wave table and spawn director
  pickups/               one scene, four kinds, icons drawn in _draw()
  effects/               explosion, shake_camera, starfield

ui/
  hud.gd/.tscn           readouts and the menu / pause / game-over / how-to / shop panels,
                           the sector victory card and the campaign summaries
  campaign_map.gd/.tscn    map layer: top bar, confirm card, keyboard cycling, signals up
  campaign_map_view.gd     draws planets, links, glow, checks and the selection
  shop_panel.gd/.tscn      the upgrade card and its four purchase rows
  settings_panel.gd/.tscn  audio and gameplay toggles, instanced twice
  touch_controls.gd      relative drag, auto-fire, on-screen pause and fire buttons

assests/                 sprites, backgrounds and (empty) audio drop folder
                         (the folder name is misspelled on purpose; paths depend on it)
```

## Collision layers

One table, six layers. Bullets and pickups find their targets by mask, never by
node name, so a new enemy type only has to inherit `enemy_base.tscn`.

| # | Layer | Used by | `collision_layer` | `collision_mask` | Reacts to |
| --- | --- | --- | --- | --- | --- |
| 1 | player | `Hurtbox` on the ship | 1 | 20 | enemies (3), enemy bullets (5) |
| 2 | player bullets | `Bullet` | 2 | 4 | enemies (3) |
| 3 | enemies | every `EnemyBase` scene | 4 | 8 | the boundary (4) |
| 4 | boundary | blue bar in `game_manager.tscn` | 8 | 0 | nothing (only detected) |
| 5 | enemy bullets | `EnemyBullet` | 16 | 0 | nothing (only detected) |
| 6 | pickups | `Pickup` | 32 | 1 | the ship (1) |

Masks are bit values, so "layers 3 and 5" is `4 + 16 = 20`.

## Running the project

1. Install **Godot 4.7** (standard build; the project uses the GL Compatibility
   renderer so it runs on older GPUs, the web and mobile).
2. Open `project.godot` in the editor and press `F5`, or from a terminal:
   ```bash
   godot --path .
   ```
3. Export templates are only needed for exporting
   (*Editor > Manage Export Templates*).

## Balancing

Every number worth tweaking lives in **`tuning.gd`** in the project root. Nothing
in the game logic depends on the exact values, so edit and press `F5`.

| What | Constant(s) |
| --- | --- |
| Starting lives | `BASE_LIVES` |
| Energy per kill | `SCORE_POINTS_PER_ENERGY` — integer division of the enemy's score value, floored at `MIN_ENERGY_PER_KILL` (10 points = 1 energy, so a 50-point tank gives 5 and the boss 50) |
| Mote feel | `MOTE_MAGNET_RADIUS`, `MOTE_DRIFT_SPEED`, `MOTE_HOME_SPEED`, `MOTE_LIFE_SECONDS`, `MAX_MOTES_PER_KILL` |
| Combo window | `COMBO_WINDOW` — seconds a kill keeps the chain alive |
| Combo steps | `COMBO_KILLS_PER_STEP` (4 kills per step), `COMBO_MAX_MULTIPLIER` (x5 cap) |
| Upgrade prices | `UPGRADES`: price of the next level is `base_cost + cost_step * current_level`; `UPGRADE_MAX_LEVEL` is the cap |
| Upgrade effects | `HULL_LEVELS_PER_LIFE`, `SHIELD_LEVELS_PER_CHARGE`, `FIRE_LEVELS_PER_DAMAGE`, `SPEED_PER_LEVEL`, `FIRE_INTERVAL_PER_LEVEL`, `MIN_FIRE_INTERVAL`, `MIN_RAPID_INTERVAL`, `MAX_SHIELD_CHARGES` |
| Waves | `WAVE_TABLE`, `BOSS_EVERY`, `FIRST_WAVE_INTERVAL`, `MIN_SPAWN_INTERVAL`, `INTERVAL_STEP`, `WAVE_GAP` |
| Campaign tiers | `CAMPAIGN_TIER_DIFFICULTY` — one row per tier: `hp_scale` multiplies enemy health, `interval_scale` multiplies the seconds between spawns (below 1 = faster) and `bullet_scale` multiplies the boss spread interval (below 1 = more often). Tier 1 is the arcade pace; tier 3 is 1.6x health, 0.8x spawn gaps and a 0.7x boss fire gap |
| Campaign sectors | `CAMPAIGN_SECTORS` (`name`, `tier`, `waves`, `mix`, `boss`, `pos`, `links`), `CAMPAIGN_ORDER` (map and keyboard order), `CAMPAIGN_START` (sectors open on a fresh campaign) |
| Campaign rewards | `CAMPAIGN_PERFECT_SCORE_BONUS`, `CAMPAIGN_PERFECT_ENERGY_BONUS` (a sector cleared without losing a life), `CAMPAIGN_BOSS_LIFE_BONUS` (+1 life, capped at the hull upgrade's maximum) |
| Drops and power-ups | `PICKUP_DROP_CHANCE`, `POWERUP_DURATION` |
| Effect budget | `MAX_LIVE_EXPLOSIONS`, `BOSS_EXPLOSION_COUNT` |

Per-enemy character stays on the scenes, because it is not global pacing:
`max_hp`, `speed`, `points` and `effect_color` on each enemy scene. The ship's
`move_speed` and `fire_interval` exports are starting values only — the upgrade
totals overwrite them at the start of every run.

## Exporting

All three presets live in `export_presets.cfg`. The Windows and Web builds use
`icon.svg` (Godot converts SVG to ICO for the executable); Android uses the
pre-rendered `icon-192.png`, because its launcher icon field wants a bitmap.

### Windows

*Project > Export... > Windows Desktop > Export Project*. The preset writes
`Space Shooter.exe` next to `project.godot`; built `*.exe` files are git-ignored.
Check *Embed PCK* in the preset if you want a single-file build.

### Web

*Project > Export... > Web > Export Project* into `export/`. Then serve the folder
over HTTP — opening `index.html` from disk will not load the WASM build:

```bash
cd export
python -m http.server 8000
# then open http://localhost:8000/
```

The preset runs single-threaded (`variant/thread_support = false`), so the server
needs no `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` headers.
Canvas resize policy is *Adaptive* and the stretch mode is `canvas_items` with
aspect `keep`, so 400x600 is letterboxed into any window or iframe. Music starts
on the PLAY click, because browsers block audio until a user gesture.

To publish on **itch.io**: zip the *contents* of `export/` (not the folder), upload
it as an HTML project, set the entry point to `index.html`, and use an embed size
of 400x600 with the fullscreen button enabled.

### Android

The preset targets **arm64-v8a only**, portrait, with no permissions beyond the
engine defaults. Package id `com.astrodash.spaceshooter`, version `1.0.0` (code 1).

1. In the editor: *Editor > Editor Settings > Export > Android* and set the
   Android SDK path (plus Java/JDK if it is not bundled). Install the *Android
   Build Template* and the SDK command-line tools through the project setup dialog.
2. **Debug keystore.** Godot needs one even for debug builds. Create it once,
   *outside* this repository, and point the editor at it:

   ```bash
   keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
     -keystore ~/android-debug.keystore -storepass android \
     -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
   ```

   Then set *Editor Settings > Export > Android > Debug Keystore* to that absolute
   path (user `androiddebugkey`, password `android`).

   Keystore paths and passwords are deliberately **not** stored in
   `export_presets.cfg` or anywhere in the repo. For a release build, tick
   *Use Custom Keystore* in the export dialog's *Keystore* section, or point
   editor settings at a release keystore on the machine that builds it.
3. Connect a device with USB debugging and use *Project > Install Android Build
   Template* / the one-click deploy button, or *Export Project* to write an APK.

## Credits

- **SpacePixels** sprite packs (`assests/spacepixels-0.1.0`,
  `spacepixels-0.2.0`, `spacepixels_ships_stroked`): ships, lasers, asteroids
  and the blue defence bar.
- **Kenney** (<https://kenney.nl>) space backgrounds (`assests/background-*.png`).
- **Audio**: TODO — the project ships no sound files yet. `assests/audio/README.md`
  lists the file names `AudioManager` expects; add the source and licence of each
  file you drop in here.
- Everything else (HUD, pickups, particles, starfield, icon) is drawn in code or
  in `icon.svg` and was written for this project.
