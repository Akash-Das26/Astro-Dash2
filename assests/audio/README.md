# Audio drop-off

`autoload/audio_manager.gd` looks for these files here, by name. Drop the files
in, keep the names, and they are picked up on the next run. Anything missing is
skipped with one warning; the game never fails to start and never plays a broken
sound.

**Format: OGG Vorbis (`.ogg`)** for every entry, mono or stereo. It is the
safest format for the Windows, Web and Android exports and every event in the
table is read as an `AudioStream`, so OGG is the tested path.

## Weapons

| File                  | Trigger                                    |
| --------------------- | ------------------------------------------ |
| `shoot_pulse.ogg`     | pulse laser fires (pitch jittered ±5%)      |
| `shoot_cannon.ogg`    | heavy cannon fires                          |
| `shoot_scatter.ogg`   | scatter shot fires (one sound per volley)   |
| `shoot_rail.ogg`      | rail laser fires                            |
| `missile_launch.ogg`  | homing missile leaves the hardpoint         |

## Combat and pickups

| File                  | Trigger                                    |
| --------------------- | ------------------------------------------ |
| `explosion_small.ogg` | fighter destroyed, rock shattered            |
| `explosion_large.ogg` | citadel station destroyed                    |
| `warp_in.ogg`         | a fighter warps into the arena               |
| `energy_pickup.ogg`   | energy orb collected                         |
| `shield_pickup.ogg`   | shield drop collected                        |
| `shield_hit.ogg`      | a shield charge absorbs a hit                |
| `shield_down.ogg`     | the last shield charge is spent              |
| `combo_up.ogg`        | every fifth kill in one combo chain          |

## Progression and screens

| File                  | Trigger                                    |
| --------------------- | ------------------------------------------ |
| `upgrade_buy.ogg`     | an upgrade, weapon or hull was equipped      |
| `upgrade_denied.ogg`  | a purchase was refused (energy, max, lock)  |
| `victory.ogg`         | a battle is won                              |
| `defeat.ogg`          | the ship is destroyed                        |
| `map_click.ogg`       | a galaxy body opens its confirm card         |
| `ui_click.ogg`        | menu, pause, settings, controls buttons      |
| `wave.ogg`            | wave banner / battle launch                  |
| `music.ogg`           | looping background music (Music bus)         |

## Older names still in the table

Kept so an older drop-off keeps working; the game no longer calls most of them.

| File                  | Formerly used for                          |
| --------------------- | ------------------------------------------ |
| `shoot.ogg`           | the single pre-weapon laser                 |
| `enemy_death.ogg`     | fighter destroyed                           |
| `player_hit.ogg`      | hull damage                                 |
| `pickup.ogg`          | any pickup                                  |
| `bomb.ogg`            | bomb detonated                              |
| `boss_spawn.ogg`      | boss enters                                 |
| `game_over.ogg`       | run ends                                    |

## Notes

- SFX go to the `SFX` bus, music to the `Music` bus (see
  `default_bus_layout.tres`), so the two sliders in Settings stay independent.
- Loop the music in the Import dock ("Loop" on); `AudioManager` also replays it
  when the stream finishes.
- A sound repeated within 30 ms is dropped, which is what stops a scatter volley
  from playing four reports at once.
