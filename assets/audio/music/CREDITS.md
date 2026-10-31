# Music credits

Every track in this folder is listed below. The playlist scans the folder by
file name, so the file name is also the id shown in **NOW PLAYING**. All five
tracks require attribution (see the licenses); the source URLs are the only
fields left to fill in.

| File | Title | Author | License | Source URL |
| --- | --- | --- | --- | --- |
| `Orbital Colossus.mp3` | Space Boss Battle Theme | Matthew Pablo | CC BY 3.0 | TODO: URL |
| `n-Dimensions (Main Theme - Retro Ver.mp3` | Space Dimensions (8bit/Retro Version) | Matthew Pablo | CC BY 3.0 | TODO: URL |
| `8-bit_perilous_dungeon.mp3` | 8-bit Perilous Dungeon | HydroGene | CC0 (credit optional) | TODO: URL |
| `8bit.mp3` / `8bit.wav` | 8bit thingy | extenz | CC BY 3.0 | TODO: URL |
| `Preparing for War.mp3` | Prepare for War | Trevor Lentz | CC BY-SA 3.0 (credit requested by the author; share-alike applies) | TODO: URL |

License texts:

- CC BY 3.0 -- https://creativecommons.org/licenses/by/3.0/
- CC BY-SA 3.0 -- https://creativecommons.org/licenses/by-sa/3.0/
- CC0 1.0 -- https://creativecommons.org/publicdomain/zero/1.0/

## Notes

- `8bit.mp3` and `8bit.wav` are the same track in two formats. The playlist
  plays a base name once and prefers ogg over mp3 over wav, so `8bit.wav` is
  skipped while `8bit.mp3` is present. Keep both credited anyway.
- `n-Dimensions (Main Theme - Retro Ver.mp3` matches the "Space Dimensions
  (8bit/Retro Version)" entry; its file name is missing the closing bracket.
  Renaming it is safe: the playlist is rebuilt from the folder on every launch,
  and nothing else references a track by name.
- `Orbital Colossus.mp3` is mapped to the `boss` context in
  `Tuning.MUSIC_CONTEXTS`, so it plays during citadel battles and is left out of
  the normal shuffle. If it is missing, citadel battles simply keep the current
  track.
- Every track plays through the `Music` bus, so the volume slider and mute in
  Settings apply to all of them.
- No track here comes from the reference video, and all redistribution is
  allowed by the licenses above as long as this credit block ships with the
  game.
