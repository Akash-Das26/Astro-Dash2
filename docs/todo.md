# Open TODOs

Everything still marked TODO or FIXME in the project, with where it is and who
has to decide it. Regenerate with:

```
grep -rn "TODO\|FIXME" --include=*.gd --include=*.tscn --include=*.md . | grep -v test_output
```

## Needs your decision

| Where | What |
| --- | --- |
| `assets/fonts/` | **Verify** the two Google Fonts pages used as sources: <https://fonts.google.com/specimen/Pixelify+Sans> and <https://fonts.google.com/specimen/Press+Start+2P>. Both fonts ship with their `OFL.txt` next to the file. |
| `assets/audio/music/Prepare for War.mp3` | **CC BY-SA 3.0 (share-alike).** Decide before publishing whether to keep it; to disable, add `"Preparing for War"` to `Tuning.MUSIC_EXCLUDE` or delete the file. Nothing in the code depends on it. |

## Known limits, not TODOs

- **CI is untested.** `.github/workflows/export-web.yml` was written without a
  runner; the `barichello/godot-ci` tag has to match the engine version.
- **Android was not exported.** No SDK, keystore or templates were present, so
  the preset was left alone.
- **Audio output, touch input and in-browser loading were not verified**: the
  checks in this repo are headless (no sound device, no framebuffer input) plus
  screenshots from a real window.
- **Boss balance follow-up:** SINGULARITY survives 32 s on average against the
  40 s target and EVENT HORIZON gets two station kills where the target allows
  one. The next knob is `BOSS_EARLY_DAMAGE_SCALE` (0.75 → 0.68); see the last
  section of `docs/balance_report.md`.

## After publishing

- **Comment on the Space Pixels itch.io page**
  (<https://hexadecimalwtf.itch.io/space-pixels>) with a link to the game: the
  author asked to see the projects the art ends up in.
