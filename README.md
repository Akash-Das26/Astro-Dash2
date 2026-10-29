# Astro Dash 2

A small vertical space shooter built with **Godot 4.7** (GL Compatibility) for
desktop, the web and Android. Survive waves of incoming ships, shoot them before
they cross the blue defence line, and chase a high score across three lives.

## Features

- Wave director: a tunable enemy mix per wave, shrinking spawn intervals, and a
  boss every fifth wave that strafes, fires fan spreads and eventually leaves.
- Three enemy types (straight, zigzag, three-hit tank) plus the boss, all built
  on one shared `EnemyBase` (hp, score value, hit flash, boundary rule).
- Falling pickups: rapid fire, spread shot, shield and bomb, with HUD timers that
  refresh instead of stacking.
- Feel: CPUParticles2D bursts tinted per enemy type, capped trauma-based camera
  shake, hit flashes, a parallax starfield and tweened UI.
- Audio on Master / Music / SFX buses, with volume sliders, mute and pitch
  variation on shots and explosions.
- Settings persisted to `user://save.cfg`: volumes, mute, reduce motion,
  auto-fire, high score.
- Touch controls on phones and tablets (relative drag, auto-fire, on-screen
  pause), keyboard and gamepad on desktop.
- Pauses itself when the window loses focus; Android's back button pauses,
  returns to the menu, or quits, depending on where you are.
- Web build starts audio on the first click so browser autoplay policy cannot
  silence the game.

## Controls

**Keyboard**

| Action | Keys |
| --- | --- |
| Move | `A` / `D` or `Left` / `Right` |
| Fire | `Space` |
| Pause | `P` or `Esc` |

**Gamepad**

| Action | Input |
| --- | --- |
| Move | Left stick |
| Fire | `A` / Cross |
| Pause | `Start` |

**Touch** (only shown when a touchscreen is detected)

| Action | Input |
| --- | --- |
| Move | Drag anywhere on the lower half of the screen (relative, so your thumb never covers the ship) |
| Fire | Automatic while a finger is down (can be turned off with **Auto-fire** in settings) |
| Pause | The **II** button in the top-right corner |

Debug builds only: `B` drops a boss in, `1`–`4` spawn a rapid / spread / shield /
bomb pickup, and the bottom-left line counts live nodes.

## Project structure

```
project.godot            input actions, display/stretch, autoloads
default_bus_layout.tres  Master / Music / SFX buses
game_manager.gd/.tscn    playfield root: score, lives, power-up timers, spawning glue

autoload/
  game_state.gd          MENU / PLAYING / PAUSED / GAME_OVER, owns tree pause,
                         focus-loss and back-button handling
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
  hud.gd/.tscn           readouts and the menu / pause / game-over / how-to panels
  settings_panel.gd/.tscn  audio and gameplay toggles, instanced twice
  touch_controls.gd      relative drag, auto-fire, on-screen pause button

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

## Exporting

All three presets live in `export_presets.cfg`. Icons come from `icon.svg`
(Godot converts it for Windows and reuses it for the Web and Android builds).

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
