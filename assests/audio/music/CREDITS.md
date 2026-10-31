# Music credits

One line per track file in this folder. The playlist scans this folder by file
name, so the name is also the track id shown in **NOW PLAYING**. Replace every
`TODO` before shipping.

| File | Title | Author | License | Source URL |
| --- | --- | --- | --- | --- |
| `8-bit_perilous_dungeon.mp3` | TODO: title | TODO: author | TODO: license (e.g. CC0 / CC BY 4.0 / OFL) | TODO: URL |
| `8bit.mp3` | TODO: title | TODO: author | TODO: license | TODO: URL |
| `8bit.wav` | TODO: title | TODO: author | TODO: license | TODO: URL |
| `Orbital Colossus.mp3` | TODO: title | TODO: author | TODO: license | TODO: URL |
| `Preparing for War.mp3` | TODO: title | TODO: author | TODO: license | TODO: URL |
| `n-Dimensions (Main Theme - Retro Ver.mp3` | TODO: title | TODO: author | TODO: license | TODO: URL |

## Notes

- `8bit.mp3` and `8bit.wav` are the same track in two formats. The playlist
  plays a base name once and prefers ogg over mp3 over wav, so `8bit.wav` is
  skipped while `8bit.mp3` is present. Keep both credited anyway, and delete the
  duplicate if you only want one copy in the project.
- The last file name looks truncated (`...Retro Ver.mp3`) and has an unbalanced
  parenthesis. Renaming it is safe: the playlist is rebuilt from the folder on
  every launch, and nothing else references a track by name.
- All files are played through the `Music` bus, so the volume slider and mute in
  Settings apply to every track.
