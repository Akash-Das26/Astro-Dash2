# Tests

Everything here runs headless:

```powershell
pwsh -File tests/run_all.ps1
```

or directly:

```bat
"D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" ^
  --headless --path . res://tests/run_tests.tscn
```

Each check prints `PASS <name>` or `FAIL <name> (<detail>)`, then a
`SUMMARY n passed, m failed` line. The process exits `1` when anything failed,
so CI can gate on it.

## Why a scene and not `--script`

Godot's `--script` mode runs a custom `MainLoop` **without the autoloads**, and
the GDScript compiler then cannot resolve `SaveData`, `GameState`,
`AudioManager` or `UIOverlay`. Measured on 4.7.2: 25 of the project's 42 scripts
report `Compile Error: Identifier not found: SaveData` under
`--check-only --script`, and a two-line probe script fails the same way. Starting
the suite as a scene brings the autoloads up exactly as the game does, so the
tests exercise the real singletons and the real classes.

## What is covered

- **Difficulty healing:** the fraction for planets 1–15 in all five modes, plus
  the clamped, max-HP-based heal through `Campaign.award_victory`.
- **Defeat rules:** what each mode keeps, resets or wipes.
- **Shields:** base and capacity per mode and SHIELDS level, the full start, a
  pickup at capacity 0, and a pickup at the limit.
- **Upgrades:** prices, the four tracks' effects, the max-level stop.
- **Save persistence:** energy, levels, volumes and shield mode through
  `save_data()` / `load_data()`.
- **Weapons:** the planet gate, purchase rules, the two-slot rule, persistence
  and FIRE POWER scaling.
- **Galaxy:** seed determinism, reachability from home, five citadels and the
  three-citadel gate seal.
- **Audio:** the three buses, sliders writing bus dB, mute, the playlist size,
  shuffle never repeating back to back, the boss track staying out of rotation,
  and saved volumes applying on load.
- **Controls:** `pause` cannot be rebound, a binding reaches the InputMap and
  survives a reload, and reset clears it.

## The save file

`user://save.cfg` is copied to `user://save.tests-backup.cfg` before the first
write and restored when the run ends, so a real playthrough is not damaged.

## Notes

- `Performance.get_monitor(Performance.OBJECT_NODE_COUNT)` growth checks and the
  bot runs live in `tests/battle_bot.*`, not here: they need a battle scene.
- Nothing here renders, so FPS is not measurable from this suite.
