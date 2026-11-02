# Music credits

Every track in this folder is listed below. The playlist scans the folder by file
name, and the in-game credits (`config/credits.gd`) use the same base names, so a
file name is also the id behind **NOW PLAYING**.

| File | Title | Author | License | Source |
| --- | --- | --- | --- | --- |
| `Orbital Colossus.mp3` | Space Boss Battle Theme | Matthew Pablo | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) | https://opengameart.org/content/space-boss-battle-theme |
| `n-Dimensions (Main Theme - Retro Ver.mp3` | Space Dimensions (8bit/Retro Version) | Matthew Pablo | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) | https://opengameart.org/content/space-dimensions-8bitretro-version |
| `8-bit_perilous_dungeon.mp3` | 8-bit Perilous Dungeon | HydroGene | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | https://opengameart.org/content/8-bit-perilous-dungeon |
| `8bit.mp3` | 8bit thingy | extenz | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) | https://opengameart.org/content/8bit-thingy |
| `Preparing for War.mp3` | Prepare for War | Trevor Lentz | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) | https://opengameart.org/content/prepare-for-war |

Every file in this folder has a credit above; nothing is uncredited.

## Licenses

- CC BY 3.0 -- https://creativecommons.org/licenses/by/3.0/
- CC BY-SA 3.0 -- https://creativecommons.org/licenses/by-sa/3.0/
- CC0 1.0 -- https://creativecommons.org/publicdomain/zero/1.0/

## Notes

- **`Preparing for War.mp3` is share-alike (CC BY-SA 3.0) and stays in the
  playlist.** This track keeps its own CC-BY-SA 3.0 license and is included
  unmodified as a separate audio file; the rest of the game is not a derivative
  of it. The author asks for credit as "Trevor Lentz", which the credits card
  and the README both give. Nothing edits or re-encodes the file: no script
  writes to this folder. To switch it off without deleting it, add
  `"Preparing for War"` to `Tuning.MUSIC_EXCLUDE` (see
  `assets/audio/README.md`).
- `8bit.mp3` is the only copy of the track: an identical 22 MB `8bit.wav` used
  to sit beside it and was removed (the playlist plays a base name once and
  prefers ogg over mp3 over wav, so it never played).
- `n-Dimensions (Main Theme - Retro Ver.mp3` is the "Space Dimensions
  (8bit/Retro Version)" entry; the file name is missing its closing bracket.
  Renaming it is safe but the credits key in `config/credits.gd` has to change
  with it.
- `Orbital Colossus.mp3` is the `boss` context in `Tuning.MUSIC_CONTEXTS`, so it
  plays during citadel battles and stays out of the normal shuffle.
- All tracks play through the `Music` bus, so the volume slider and mute apply
  to all of them. Redistribution is allowed by the licenses above as long as
  this credit block ships with the game.
