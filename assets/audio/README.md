# Audio drop-off

Sound effects are **not renamed** to match code. `autoload/audio_manager.gd`
holds `SOUND_MAP`: a logical event (for example `shoot_pulse`) maps to a list of
real files inside the packs under this folder. One file is picked at random per
play, with a small pitch spread, and `SOUND_VOLUME_DB` trims the loud ones so
they sit under the music. A missing file is skipped; events with no file at all
are listed in **one** `push_warning` on startup, never one warning per path.

Two packs are used, and **only the files the game actually plays are kept**:
the unreferenced remainder of both packs was deleted, together with its
`.import` files and the folders that became empty. Every remaining pack file is
named by `SOUND_MAP`, and `assets/audio/music/` was not touched.

| Folder | Contents |
| --- | --- |
| `The Essential Retro Video Game Sound Effects Collection [512 sounds]/…By Juhani Junkala/` | the 69 weapon, explosion, impact, pickup, menu and portal files `SOUND_MAP` names, plus the pack's `INFO.txt` |
| `EssentialGameAudiopackFixed/Sound Effects/RandomSfx/` | `gem.ogg`, `click.ogg`, `lvlup.ogg`, `win.ogg` |

The `.zip` archives mentioned earlier were **not present** in `assets/audio/sfx/`;
everything was already extracted. There is therefore no `assets/audio/sfx/sfx/`
copy, and nothing was moved or renamed.

**Formats:** the map points at the pack files as shipped (`.ogg`, `.wav`,
`.mp3`). Godot imports all three; keep the originals where they are.

## Music playlist

Music lives in `assets/audio/music/`, not next to the effects. `AudioManager`
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
  `assets/audio/music.ogg` still plays as a one-track playlist; with neither,
  music is off after one warning and nothing errors.
- **Boss context.** `Tuning.MUSIC_CONTEXTS` maps a track's base name to a
  context; `Orbital Colossus` is the `boss` theme. A citadel battle calls
  `AudioManager.play_context(&"boss")` and the normal rotation resumes with
  `release_context()` after the fight. Mapped tracks are left out of the shuffle
  bag and the in-order walk; if the file is missing the context is ignored.
- **Excluding a track.** `Tuning.MUSIC_EXCLUDE` is an array of base names
  (file name without extension) that stay on disk but never enter the playlist
  or the shuffle bag. It is empty by default; add `"Preparing for War"` there to
  ship without the CC BY-SA track. Excluding a name never deletes a file and the
  credits entry stays, so the card still lists the track if it is put back.
- **Exports.** The listing comes from `ResourceLoader.list_directory` when the
  engine has it, plus a `DirAccess` scan with `.import` / `.remap` suffixes
  stripped. Each export preset also includes the raw files under
  `assets/audio/music/` (`include_filter`), because an imported audio resource
  is not stored at its source path in a PCK: that is what makes the scan work on
  the Web and Android exports.

## Event map

Paths are shortened to file names; the folder follows the table above.

| Event | Files used |
| --- | --- |
| `shoot_pulse` | `sfx_wpn_laser1..4.wav` |
| `shoot_cannon` | `sfx_wpn_cannon1..3.wav` |
| `shoot_scatter` | `sfx_weapon_shotgun1..3.wav` |
| `shoot_rail` | `sfx_wpn_laser10..12.wav` |
| `missile_launch` | `sfx_wpn_missilelaunch.wav` |
| `explosion_small` | `Explosions/Short/sfx_exp_short_hard1..3.wav` |
| `explosion_large` | `Explosions/Long/sfx_exp_long1..3.wav` |
| `energy_pickup` | `RandomSfx/gem.ogg`, `sfx_coin_cluster1..2.wav` |
| `pickup` | `RandomSfx/gem.ogg`, `sfx_coin_cluster1.wav` |
| `shield_pickup` | `sfx_sounds_powerup1..3.wav` |
| `shield_up` | `sfx_sounds_powerup11..13.wav` |
| `shield_hit` | `sfx_sounds_impact1..3.wav` |
| `shield_down` | `sfx_sounds_error1..3.wav` |
| `combo_up` | `sfx_sounds_powerup16..18.wav` |
| `warp_in` | `sfx_movement_portal1..3.wav` |
| `upgrade_buy` | `RandomSfx/lvlup.ogg` |
| `upgrade_denied` | `sfx_sounds_error9..11.wav` |
| `victory` | `RandomSfx/win.ogg`, `sfx_sounds_fanfare1..2.wav` |
| `defeat` | `sfx_damage_hit1..2.wav`, `sfx_exp_medium1.wav` |
| `map_click` | `RandomSfx/click.ogg`, `sfx_menu_select1.wav` |
| `ui_click` | `sfx_sounds_button1..3.wav` |
| `shoot` | `sfx_wpn_laser5..7.wav` (legacy callers) |
| `enemy_death` | `Explosions/Shortest/sfx_exp_shortest_hard1..3.wav` |
| `player_hit` | `sfx_damage_hit1..3.wav` |
| `bomb` | `Explosions/Clusters/sfx_exp_cluster1..3.wav` |
| `boss_spawn` | `sfx_alarm_loop1..2.wav` |
| `wave` | `sfx_sound_neutral1..2.wav` |
| `game_over` | `sfx_sounds_error13..15.wav` |

Every logical name above has at least one existing file (checked against the
folders). `bomb`, `boss_spawn`, `game_over` and `pickup` are mapped for
compatibility but no current script calls them.

## Adding or replacing a sound

1. Drop the file into one of the pack folders (or a new folder under
   `assets/audio/sfx/`).
2. Add its path to the matching list in `SOUND_MAP` (all paths are relative to
   `res://assets/audio/sfx/`).
3. Add a `SOUND_VOLUME_DB` trim if it is much louder or quieter than the rest.
4. Open the project once so Godot imports the file.

## Notes

- SFX go to the `SFX` bus, music to the `Music` bus (see
  `resources/default_bus_layout.tres`), so the two sliders in Settings stay independent.
- A sound repeated within 30 ms is dropped, which is what stops a scatter volley
  from playing four reports at once.
- **Credits.** Both packs are credited in the README, in the in-game CREDITS
  card (`config/credits.gd`) and here:
  - *512 Sound Effects (8-bit style)* (The Essential Retro Video Game Sound
    Effects Collection) — SubspaceAudio (Juhani Junkala), CC0, credit given
    though not required. https://opengameart.org/content/512-sound-effects-8-bit-style
  - *Ove's Essential Game Audio Pack Collection* — OveMelaa, CC BY 3.0,
    attribution required. Used files: `gem.ogg`, `click.ogg`, `lvlup.ogg`,
    `win.ogg`.
    https://opengameart.org/content/oves-essential-game-audio-pack-collection-160-files-updated

  Only the used files from each pack are still in the repository; the deleted
  remainder does not need attribution but the kept files do.
