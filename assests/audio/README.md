# Audio drop-off

`autoload/audio_manager.gd` looks for these files here, by name. Drop the files
in, keep the names, and they are picked up on the next run. Anything missing is
skipped with one warning; the game never fails to start and never plays a broken
sound.

**Format: OGG Vorbis (`.ogg`)** for every entry, mono or stereo. It is the
safest format for the Windows, Web and Android exports and every event in the
table is read as an `AudioStream`, so OGG is the tested path.

## Music playlist

Music lives in `assests/audio/music/`, not next to the effects. `AudioManager`
scans that folder once at startup and plays every `.ogg`, `.mp3` and `.wav` it
finds, sorted by file name.

- **Rotation.** When a track ends the next one starts; tracks are never looped
  (`loop` is cleared on Ogg/MP3 and `loop_mode` is disabled on WAV at runtime).
  A playlist with a single track loops that track.
- **SHUFFLE** (default) draws from a shuffled bag: every track plays once before
  anything repeats, and the track that just ended never starts the next pass.
  **IN ORDER** walks the sorted list. Switch it in Settings; the choice is saved
  in `user://save.cfg`.
- **Crossfade.** Two players on the `Music` bus fade 1.5 s between tracks
  (`Tuning.MUSIC_CROSSFADE`). The pause card dips the Music bus to 45%, and the
  volume slider and mute still apply on top.
- **Duplicates.** A base name exported in several formats is played once;
  ogg beats mp3 beats wav (`MUSIC_FORMAT_PRIORITY`).
- **Start.** Music starts after the first key, click, tap or pad press (Web will
  not play audio before a user gesture), and then carries across the menu, the
  map and battles without restarting. Quitting stops it cleanly.
- **Adding a track.** Drop the file in this folder, open the project once so
  Godot imports it, and the next launch includes it. A file that cannot be
  loaded is skipped with one warning.
- **Fallback.** With an empty or missing folder, the old single
  `assests/audio/music.ogg` still plays as a one-track playlist; with neither,
  music is off after one warning and nothing errors.
- **Exports.** The listing comes from `ResourceLoader.list_directory` when the
  engine has it, plus a `DirAccess` scan with `.import` / `.remap` suffixes
  stripped. Each export preset also includes the raw files under
  `assests/audio/music/` (`include_filter`), because an imported audio resource
  is not stored at its source path in a PCK: that is what makes the scan work on
  the Web and Android exports.

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
