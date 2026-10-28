# Audio drop-off

`autoload/audio_manager.gd` looks for these files here, by name. Drop the
files in, keep the names, and they are picked up on the next run. Anything
missing is skipped with a warning; the game never fails to start.

| File              | Used for                                  |
| ----------------- | ----------------------------------------- |
| `shoot.ogg`       | player shot (pitch jittered ±5%)           |
| `enemy_death.ogg` | enemy destroyed (pitch jittered ±5%)       |
| `player_hit.ogg`  | player takes damage                        |
| `pickup.ogg`      | power-up collected                         |
| `bomb.ogg`        | bomb detonated                             |
| `boss_spawn.ogg`  | boss enters                                |
| `wave.ogg`        | wave banner                                |
| `game_over.ogg`   | run ends                                   |
| `ui_click.ogg`    | menu / pause / settings button             |
| `music.ogg`       | looping background music (Music bus)       |

Notes

- OGG Vorbis is the safest format for all three exports (Windows, Web, Android).
- Loop the music in the Import dock ("Loop" on), or AudioManager replays it
  when the stream finishes.
- SFX go to the `SFX` bus, music to the `Music` bus (see `default_bus_layout.tres`),
  so the two volume sliders in Settings control them independently.
