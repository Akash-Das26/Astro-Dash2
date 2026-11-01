# Open TODOs

Everything still marked TODO or FIXME in the project, with where it is and who
has to decide it. Regenerate with:

```
grep -rn "TODO\|FIXME" --include=*.gd --include=*.tscn --include=*.md . | grep -v test_output
```

## Needs your decision

| Where | What |
| --- | --- |
| `README.md`, "License" section | Which license the **code** is under. MIT is the suggestion; nothing is chosen yet, and no LICENSE file exists. |
| `assets/audio/music/CREDITS.md` | Source URL for each of the five music tracks (title, author and license are already filled in). |
| `README.md`, "Credits" | Author, license and source URL for the two SpacePixels sprite packs. |
| `README.md`, "Credits" | License and source URL for the two SFX packs (Juhani Junkala's 512-sound pack and Ove Melaa's Essential Game Audio pack). |
| `assets/audio/README.md` | The same per-pack credit lines, from the audio folder's side. |

## Known limits, not TODOs

- **CI is untested.** `.github/workflows/export-web.yml` was written without a
  runner; the `barichello/godot-ci` tag has to match the engine version.
- **Android was not exported.** No SDK, keystore or templates were present, so
  the preset was left alone.
- **Audio output, touch input and in-browser loading were not verified**: the
  checks in this repo are headless (no sound device, no framebuffer input) plus
  screenshots from a real window.
