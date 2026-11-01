# Architecture

Astro Dash 2 is a Godot 4.7 game with one scene per screen and a shallow,
signal-driven object model. Everything below is a rule the project actually
follows; the tests in `tests/` enforce the path half of it.

## Folders and responsibilities

| Folder | Holds | May depend on |
| --- | --- | --- |
| `config/` | Pure data and tables: `tuning.gd`, `difficulty.gd`, `upgrades.gd`, `weapons.gd`, `skins.gd`, `controls.gd`, `ui_theme.gd` | Nothing but the engine. No scenes, no nodes, no autoload use at load time except `SaveData`/`Tuning` constants inside static functions |
| `autoload/` | The four global services: `GameState`, `SaveData`, `AudioManager`, `UIOverlay` | Each other only through signals; never a scene |
| `game/battle/` | The arena: `battle_game`, the `Battle` resource, `hazard_field`, `wave_director` | `config/`, `entities/`, `ui/hud/`, `autoload/` |
| `game/campaign/` | `campaign.gd` (run state), `galaxy.gd` (seeded map, graph, names) | `config/`, `autoload/save_data.gd` |
| `entities/` | Things that live in the arena: `player/ship`, `enemies/`, `projectiles/`, `pickups/`, `fx/`, `hazards/` | `config/`, and only its own kind |
| `ui/` | Screens: `menu/`, `map/`, `hud/`, `panels/` | `config/`, `game/campaign/`, `autoload/` |
| `resources/` | Shared `.tres` (the bus layout) | — |
| `assets/` | Sprites, backgrounds, fonts, `audio/sfx/`, `audio/music/` | — |
| `tests/` | Headless suite, battle bot, screenshot runner, path checks | The whole game, as a scene |
| `docs/` | This file, the reorganisation plan, the orphan list | — |

## Dependency rules

1. **`config/` is inert.** It never instantiates a scene and never holds a node.
   Anything that needs a number asks `Tuning`, `Upgrades`, `Weapons`, `Skins`,
   `Difficulty`, `Controls` or `UITheme`.
2. **`entities/` never talks to `ui/`.** A fighter, rock or bullet knows nothing
   about cards or bars: it emits (`died`, `damaged`, `shot_requested`) and the
   battle scene decides what to draw.
3. **`game/` reaches `ui/` through signals, one way.** `battle_game` connects to
   HUD signals (`pause_requested`, `end_continue_requested`, `menu_requested`)
   and pushes state in (`set_hp`, `set_shields`, `show_victory`). The HUD never
   calls back into gameplay.
4. **Autoloads are the only global services.** `GameState` owns the tree pause
   and the back handler, `SaveData` owns persistence, `AudioManager` owns buses
   and the playlist, `UIOverlay` owns the global controls card. A new global
   needs a reason; a plain class in `config/` usually does not.
5. **Collision detection is one-way.** Fighters, rocks and projectiles are
   found by the ship's hurtbox and the bullet areas; nothing reaches back to the
   ship for collision.

## Main flow

```
MainMenu  --NEW GAME-->  DifficultyPicker  --choice-->  Campaign.begin_run()
   |                                                        |
   +--CONTINUE--> GalaxyMap <-------------------------------+
                     |  double-click a glowing body (or Enter/A)
                     v
              Campaign.start_battle(id)  ->  BattleGame
                     |                          |
                     |  victory                 |  defeat
                     v                          v
              Campaign.award_victory      Campaign.record_defeat
              (heal by difficulty)        (keep / new galaxy / wipe)
                     |                          |
                     +------>  GalaxyMap  <-----+
```

`GameState` gates the whole loop: only `PLAYING` unpauses the tree, `PAUSED`,
`GAME_OVER` and `BATTLE_WON` freeze it, and `MENU`/`MAP` are hubs. Every screen
installs a `back_handler` for Android Back and `Esc`.

## Adding things

| I want to add… | Do this |
| --- | --- |
| A fighter | A row in `Tuning.ENEMY_TYPES` (hp, speed, points, radius, orbit, fire, colour), a sprite in `EnemyBase.SPRITES`, then put its key in a band's `mix` in `Tuning.GALAXY_BANDS` |
| A weapon | A row in `Tuning.WEAPONS` (damage, interval, speed, count, spread, pierce, life, scale, homing, area, knockback, cost, unlock) plus its id in `WEAPON_ORDER`. The upgrade panel and the HUD read the table, so nothing else changes |
| A sound | Drop the file under `assets/audio/sfx/<pack>/` and add it to `AudioManager.SOUND_MAP` (logical event → file list) with an optional trim in `SOUND_VOLUME_DB` |
| A planet or station look | A texture and tint pair in `Tuning.GALAXY_BODY_ART` / `GALAXY_TINTS`, and the art under `assets/sprites/` |
| A UI card | A scene in `ui/panels/` with `open()` / `close()` and a `closed` signal; open it from the owner screen, and let its `Esc` be handled by the screen's back path |
| A difficulty knob | A column in `Tuning.DIFFICULTIES` and a getter in `Difficulty`; the battle multiplies it in `_apply_difficulty()` |

## Why the tests are scenes

`godot --headless --path . res://tests/run_tests.tscn` starts the real autoloads,
so `SaveData`, `GameState` and `AudioManager` are the ones the game uses.
`--script` mode has no autoload globals, which is why every script mentioning
`SaveData` fails to compile there; `tests/README.md` documents that measurement.
