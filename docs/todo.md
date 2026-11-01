# Open TODOs

Everything still marked TODO or FIXME in the project, with where it is and who
has to decide it. Regenerate with:

```
grep -rn "TODO\|FIXME" --include=*.gd --include=*.tscn --include=*.md . | grep -v test_output
```

## Needs your decision

| Where | What |
| --- | --- |
| `assets/audio/music/Prepare for War.mp3` | **Share-alike decision:** the track is CC BY-SA 3.0. Keep it and the published game is bound by CC BY-SA 3.0, or drop the track from `assets/audio/music/` before publishing. Nothing in the code depends on it (it is one playlist entry). |
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

## Boss balance follow-up

- SINGULARITY survives 32 s on average against the 40 s target, and EVENT
  HORIZON gets two station kills where the target allows one. The next knob is
  `BOSS_EARLY_DAMAGE_SCALE` (0.75 → 0.68); see the last section of
  `docs/balance_report.md`.
