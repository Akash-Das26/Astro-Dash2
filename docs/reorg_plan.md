# Reorganisation plan (stage 14)

Pure move stage: no gameplay, feature or balance changes. Every file is moved
with `git mv` (its `.gd.uid`, `.import` or `.tscn` partner travels with it), and
every `res://` reference is rewritten in the same commit. Class names do not
change, so code that calls a class by name needs no edit.

Current inventory: **404 tracked files** — 16 at the root, 78 scripts/scenes/
resources, 300+ files under `assests/` (sprites, fonts, audio) and 13 files under
`export/` (web export output, deleted in the working tree before this stage).

## Root (stays)

| File | Role |
| --- | --- |
| `project.godot` | engine config, autoloads, input map, bus layout path |
| `export_presets.cfg` | Android / Windows / Web presets |
| `icon.svg` (+ `.import`) | project and Windows icon |
| `icon-192.png` (+ `.import`) | Android launcher icon |
| `README.md`, `.gitignore`, `.gitattributes`, `.editorconfig` | docs and repo config |
| `.github/workflows/export-web.yml` | CI job; not part of the game tree, left in place |

## Scripts and scenes

| Old path | New path |
| --- | --- |
| `tuning.gd` | `config/tuning.gd` |
| `difficulty.gd` | `config/difficulty.gd` |
| `upgrades.gd` | `config/upgrades.gd` |
| `weapons.gd` | `config/weapons.gd` |
| `skins.gd` | `config/skins.gd` |
| `controls.gd` | `config/controls.gd` |
| `ui/ui_theme.gd` | `config/ui_theme.gd` |
| `battle.gd` | `game/battle/battle.gd` |
| `battle_game.gd` + `.tscn` | `game/battle/battle_game.gd` + `.tscn` |
| `entities/hazards/hazard_field.gd` | `game/battle/hazard_field.gd` |
| `entities/spawner/wave_director.gd` | `game/battle/wave_director.gd` |
| `campaign.gd` | `game/campaign/campaign.gd` |
| `galaxy.gd` | `game/campaign/galaxy.gd` |
| `autoload/game_state.gd` | `autoload/game_state.gd` (unchanged) |
| `autoload/save_data.gd` | `autoload/save_data.gd` (unchanged) |
| `autoload/audio_manager.gd` | `autoload/audio_manager.gd` (unchanged) |
| `ui/ui_overlay.gd` | `autoload/ui_overlay.gd` (it is the `UIOverlay` autoload) |
| `entities/player/ship.gd` + `.tscn` | unchanged |
| `entities/enemies/enemy_base.gd` + `.tscn` | unchanged |
| `entities/enemies/boss_station.gd` + `.tscn` | unchanged |
| `entities/enemies/enemy_bullet.gd` + `.tscn` | `entities/projectiles/enemy_bullet.*` |
| `entities/bullet/bullet.gd` + `.tscn` | `entities/projectiles/bullet.*` |
| `entities/effects/energy_mote.gd` + `.tscn` | `entities/pickups/energy_mote.*` |
| `entities/pickups/shield_pickup.gd` + `.tscn` | unchanged |
| `entities/effects/explosion.*` | `entities/fx/explosion.*` |
| `entities/effects/shockwave.gd` | `entities/fx/shockwave.gd` |
| `entities/effects/float_text.gd` | `entities/fx/float_text.gd` |
| `entities/effects/shake_camera.gd` | `entities/fx/shake_camera.gd` |
| `entities/effects/starfield.gd` | `entities/fx/starfield.gd` |
| `entities/fx/thruster.gd` + `.tscn` | unchanged |
| `entities/hazards/asteroid.gd` + `.tscn` | unchanged — see “fits nowhere” below |
| `entities/map/body_marker.gd` | `ui/map/body_marker.gd` |
| `entities/map/galaxy_links.gd` | `ui/map/galaxy_links.gd` |
| `ui/main_menu.gd` + `.tscn` | `ui/menu/main_menu.*` |
| `ui/menu_backdrop.gd` | `ui/menu/menu_backdrop.gd` |
| `ui/galaxy_map.gd` + `.tscn` | `ui/map/galaxy_map.*` |
| `ui/hud.gd` + `.tscn` | `ui/hud/hud.*` |
| `ui/touch_controls.gd` | `ui/hud/touch_controls.gd` |
| `ui/upgrade_panel.gd` + `.tscn` | `ui/panels/upgrade_panel.*` |
| `ui/settings_panel.gd` + `.tscn` | `ui/panels/settings_panel.*` |
| `ui/controls_card.gd` + `.tscn` | `ui/panels/controls_card.*` |
| `ui/difficulty_picker.gd` + `.tscn` | `ui/panels/difficulty_picker.*` |
| `default_bus_layout.tres` | `resources/default_bus_layout.tres` |
| `tests/*` | `tests/*` (unchanged) |

The end cards, pause card and confirm cards live inside `ui/hud.tscn` and
`ui/galaxy_map.tscn`, so they move with those scenes rather than into
`ui/panels/`; splitting a scene is a behaviour change, out of scope here.

## Assets

| Old path | New path |
| --- | --- |
| `assests/spacepixels-0.2.0/**` | `assets/sprites/spacepixels-0.2.0/**` (pack structure kept) |
| `assests/spacepixels_ships_stroked/**` | `assets/sprites/spacepixels_ships_stroked/**` |
| `assests/background-*.png` (+ `.import`) | `assets/backgrounds/background-*.png` |
| `assests/fonts/**` | `assets/fonts/**` (Pixelify Sans, Press Start 2P; currently untracked, added in this stage) |
| `assests/audio/music/**` | `assets/audio/music/**` |
| `assests/audio/README.md` | `assets/audio/README.md` |
| `assests/audio/The Essential Retro…/**` | `assets/audio/sfx/The Essential Retro…/**` |
| `assests/audio/EssentialGameAudiopackFixed/**` | `assets/audio/sfx/EssentialGameAudiopackFixed/**` |
| `assests/` (the folder itself) | `assets/` — the misspelling is fixed last, once everything is green |

The SFX packs keep their internal folder names, so `AudioManager.AUDIO_DIR`
becomes `res://assets/audio/sfx/` and the 73 `SOUND_MAP` relative entries are
untouched.

## Fits nowhere, and therefore kept where it is

- `entities/hazards/asteroid.gd` + `.tscn`: the target layout has no hazard
  folder (hazard *field* is explicitly placed in `game/battle/`). Asteroids are
  spawned entities, so they stay as their own `entities/hazards/` folder rather
  than being forced into `entities/projectiles/` or `entities/fx/`.
- `.github/workflows/export-web.yml`: repository CI, unrelated to `res://`.
- `reference/`: gitignored footage folder; gets an empty `.gdignore` so Godot
  stops scanning it, and stays out of git.

## Order of work (one commit per target folder)

1. `config/`
2. `game/` (battle + campaign)
3. `entities/` (projectiles, pickups, fx, hazards, ui/map hand-off)
4. `ui/` (menu, map, hud, panels) + `autoload/ui_overlay.gd`
5. `resources/`
6. `assets/` (restructure + `assests` → `assets` rename, last)
7. `tests/check_paths.gd`, README structure, `docs/ARCHITECTURE.md`, orphans list

After every two or three commits: delete `.godot/`, `--import`, run the logic
suite and the smoke scenes. Full bot and screenshot set at the start and at the
end.
