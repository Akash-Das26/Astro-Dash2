# Audit report — stage 22

Date: 2026-11-02 · Version audited: 0.9.0 · Engine: Godot 4.7.2 (console build)
Scope: credits cleanup, full health/code/debug/security/licence/save/progression/
input/resolution/performance/accessibility/docs/export-readiness audit.
No gameplay, balance or feature changes were made; two defects were fixed.

Everything below was produced by the commands shown. Where a check could not be
run, the report says so instead of assuming a result.

---

## 1. What was run

| Command | Result |
| --- | --- |
| `rm -rf .godot && godot --headless --path . --import` | clean: no `ERROR`, `path mismatch`, `invalid UID` or `Cannot open file` line (the only grep hits were progress lines whose *file names* contain "error") |
| `godot --headless --path . res://tests/run_tests.tscn` | **323 passed, 0 failed** (was 274 before this stage) |
| 8 scene smoke runs (`--quit-after 300`) | 7 clean, `battle_game.tscn` prints `ERROR: 3 resources still in use at exit` (see M-6) |
| `battle_bot.tscn -- <difficulty> 2` for all five modes | ran; node counts and FPS below |
| `battle_bot.tscn -- cadet boss`, `-- singularity boss` | ran; station spawned, no errors |
| windowed `battle_bot.tscn -- cadet 1` | 60 s game time, `min_fps=142`, nodes stable |
| screenshot runner at `--resolution 640x400` and `1920x1080` | PNGs written, see §9 |
| `--script` per-file parse check | **not used**: `--script` runs without autoloads and cannot compile the project (documented in `tests/README.md`); the suite compiles every script it loads and the import step parses all of them |

### Health numbers from the bot (band 2 = elites in the mix)

```
BALANCE CADET        t=10 nodes=309 fps=145  t=40 hull=42/100
BALANCE VECTOR       t=10 nodes=331 fps=144  t=40 hull=40/100
BALANCE SUPERNOVA    t=10 nodes=317 fps=145  t=40 hull=38/100  shield=1/0
BALANCE EVENT_HORIZON t=10 nodes=316 fps=144 t=40 hull=44/100  shield=1/0
BALANCE SINGULARITY  t=10 nodes=367 fps=143  t=20 alive=false hull=0/100
BOSS CADET           station_hp=238 spawn OK, hull 64/100 at t=40
BOSS SINGULARITY     station_hp=295 spawn OK, hull 9/100 at t=40
BALANCE CADET band 1: victory=true hull=56/100 wraps=3 out_of_bounds=0
  nodes [273,286,286,286,286,286] growth=+13 min_fps=142
```

Node counts stay flat (the +13 is the two HUD banners plus pickups that die the
same frame). No orphan/memory growth was measurable, because **no 20-minute soak
mode exists**: the harness caps a row at 90 s of game time and never prints
`OBJECT_ORPHAN_NODE_COUNT` or memory. That is reported as M-7, not claimed as a pass.

---

## 2. Findings

Severity: CRITICAL blocks or loses content/progress, HIGH breaks a supported
input path or can crash, MEDIUM is a real defect with a workaround, LOW is hygiene.

### CRITICAL

**C-1 — Two hulls could never unlock (FIXED, `a0f4574`).**
`Tuning.GALAXY_BODY_COUNT_MIN = 50` (`config/tuning.gd:546`), of which 5 citadels
+ 1 gate + 1 home leave **43 conquerable planets** on a minimum seed, while
`Skins.LIST` unlocks at 0/5/10/15/20/25/30/35/**40/45** (`config/skins.gd`). The
old counter was `max(best_planets, current_conquests)`, i.e. one campaign, so the
last two hulls were unreachable on any galaxy that rolled 50–52 bodies.
Evidence: the numbers above, and a suite check that now asserts
`top milestone > GALAXY_BODY_COUNT_MIN - 7`.
Fix: `SaveData.lifetime_planets`, incremented on every new conquest, persisted in
`[campaign] lifetime_planets`, kept through a SINGULARITY wipe (cosmetic unlocks
survive it); `Skins.planets()` reads `max(best, current, lifetime)`.
Tests: every hull unlocks exactly at its own milestone; 45 conquests raise the
counter; the counter survives save/load and `wipe_meta_progress()`.

**C-2 — A corrupted save could raise runtime errors during autoload init (FIXED, `a0f4574`).**
`ConfigFile` returns whatever the file holds. `load_data()` used typed casts and
assignments (`int(value)`, `bool(value)`, `var conquered: PackedStringArray = ...`),
so `energy = "lots"`, `conquered = 7` or `owned = 5` produced script errors before
the menu drew; the old suite had **no** test for a missing/empty/truncated/mistyped
save (grep for those cases returned nothing).
Fix: `_as_int/_as_float/_as_bool/_as_string/_as_string_array` coercion on every
read, plus an unknown `skin` id falling back to `Skins.DEFAULT_ID`.
Tests: six hostile files (missing, empty, truncated, wrong types, unknown keys,
oldest schema) load, keep volumes in range, keep a known difficulty and hull, and
a normal save still round-trips afterwards. This was the one failing check during
the stage (it caught the skin-id gap), then green.

### HIGH

**H-1 — A gamepad alone cannot open the CONTROLS card.**
`controls` has one InputEventKey (`C`) and **no** joypad event
(`project.godot:151`); every other action has a pad binding. `C` is the only way
into the read-only controls card, so a controller-only player cannot read the
bindings. Suggested fix: add a joypad button (Back/View, index 4) to `controls`
and list it on the card; it is a data change in `project.godot` plus one line of
`Controls.help_text()`.

**H-2 — The keyboard cannot aim in FREE AIM without a mouse.**
`aim_left/aim_right/aim_up/aim_down/aim` are joypad-axis-only
(`project.godot:68-93`). With no mouse the ship cannot aim at all, although
`shoot` is keyboard-bound. This is likely intentional twin-stick design, but it
means "keyboard-only play" is not fully supported. Suggested fix (design
decision, not applied): bind the arrow keys or IJKL to `aim_*`, or document that
FREE AIM requires a pointer.

### MEDIUM

**M-1 — HUD can print "SHIELD 1/0".**
At `shield_base_capacity = 0` (SUPERNOVA and above) a shield pickup grants a
charge up to `SHIELD_PICKUP_MIN_CAPACITY = 1` but does not raise capacity, so the
bot log shows `shield=1/0` and `ui/hud/hud.gd:206` formats exactly that.
Suggested fix: display `max(capacity, 1)` as the denominator once a charge exists,
or grant the pickup a temporary capacity of 1.

**M-2 — A duplicate display font sits in the body-font folder.**
`assets/fonts/pixelify-sans/PressStart2P-Regular.ttf` is byte-identical to
`assets/fonts/Press_Start_2P/PressStart2P-Regular.ttf` (md5 scan), next to
`OFL (2).txt` and the pack's `README.txt`. `UITheme._scan_fonts()` searches one
folder deep, so the scan can pick the display font from the wrong directory with
the wrong licence file next to it. Suggested fix: delete the duplicate ttf and
`OFL (2).txt` from `pixelify-sans/`.

**M-3 — 22 MB duplicate track in the music folder.**
`assets/audio/music/8bit.wav` (22,492,060 B) is the same track as `8bit.mp3`
(5.1 MB); the playlist plays the mp3 and skips the wav
(`MUSIC_FORMAT_PRIORITY`), so the wav only costs repository size. Suggested fix:
delete the wav (the credits entry already covers both formats).

**M-4 — 37.9 MB Web build and a 103 MB blob in git history.**
`git log --all --oneline -- export/index.wasm` → `7eed960 "Update game export
files"`, `08b3b7d "baseline checkpoint"`; `export/index.zip` 10.2 MB in the same
commits, plus one 103 MB blob named `Space…` (truncated by the scanner). `export/`
is ignored now, but history keeps the weight. Not rewritten, as instructed.
Suggested fix (requires your go-ahead): `git filter-repo --path export --invert-paths`.

**M-5 — Export presets ship the test and reference folders.**
`export_presets.cfg` sets `exclude_filter=""` on the presets and only
`include_filter="assets/audio/music/*.ogg, *.mp3, *.wav"`. `tests/`, `docs/`,
`reference/` (which has `.gdignore`, so Godot does skip it) are therefore
candidates for the build. `tests/` is code that would be exported and is not
needed at runtime. Suggested fix: `exclude_filter="tests/*, docs/*, reference/*"`.
Read-only finding; no preset was edited.

**M-6 — `battle_game.tscn` leaves 3 resources in use at exit.**
`godot --headless --quit-after 300 res://game/battle/battle_game.tscn` prints
`ERROR: 3 resources still in use at exit (run with --verbose for details).`
Harmless for a real session (the process is ending), but it hides real leaks in
CI output. Suggested fix: identify them with `--verbose` and drop the static
references.

**M-7 — No soak harness.**
Item 1 of the audit asks for a 20-minute game-time soak with orphan/memory
monitoring. `tests/battle_bot.gd` has no soak mode: rows are 35–90 s, it prints
node count and FPS only, and never `OBJECT_ORPHAN_NODE_COUNT`. What was run is
listed in §1; no growth conclusion should be drawn from it.

**M-8 — `.gitignore` has an absolute path that does nothing.**
Line 12 is `D:\Project\Game\Astro-Dash2\reference`; git ignores patterns, not
local absolute paths, so the intent (ignore the reference footage) is not
achieved by that line. `*.mp4` already covers the videos. Suggested fix: replace
it with `reference/` — and note the folder is tracked with a `.gdignore` today.

**M-9 — Test tooling hard-codes a machine path.**
`tests/README.md:12` and `tests/run_all.ps1:5` contain
`D:\Godot_v4.7.2-stable_win64.exe\...`. Fine for this machine, wrong for anyone
else; the script already falls back to `godot` on PATH. Suggested fix: make the
parameter's default `godot`.

### LOW

- **L-1** `load_data()` is 107 lines (`autoload/save_data.gd:329`), over the ~80
  line guideline; it is now a flat list of coercions, so splitting it is optional.
- **L-2** Large scripts (list only): `config/tuning.gd` 843,
  `game/battle/battle_game.gd` 808, `autoload/audio_manager.gd` 791,
  `ui/map/galaxy_map.gd` 733, `ui/panels/upgrade_panel.gd` 667.
- **L-3** Long test functions: `_test_credits` 124, `_test_elite_fighters` 101,
  `_test_galaxy` 93, `_test_audio` 85 lines.
- **L-4** One `print()` in shipped code: `autoload/audio_manager.gd:781`, inside
  the debug-only audio summary (`OS.is_debug_build()` guard at line 763). Correct.
- **L-5** Magic numbers: card paddings and some sizes live in the `.tscn`
  (`16`, `14`, `18`) instead of `Tuning`; not a bug, just not tunable in one place.
- **L-6** `docs/todo.md` still lists the two font URLs as *verify*; they were
  taken from the pack pages and were not re-fetched here.
- **L-7** `assets/fonts/pixelify-sans/static/` ships extra static weights that
  nothing loads; harmless, worth pruning with M-2.

### Checks that came back clean

- **Reserved-word identifiers:** regex over every `var`/`const`/`func` name in
  `*.gd` found no 4.7 keyword used as an identifier.
- **TODO/FIXME:** no code TODO/FIXME left; the only match is a comment in
  `config/credits.gd:6` explaining the TODO convention, and `docs/todo.md` tracks
  the real ones.
- **Secrets:** `git grep` over all 183 commits for API keys, tokens, passwords and
  keystores found only documentation ("keystore paths … are deliberately not
  stored") and the export preset's `permissions/*=false` lines. No secret is
  committed. The two e-mail addresses in history are inside third-party licence
  files (`OFL.txt`, the sound pack's `INFO.txt`), not ours.
- **`.gitignore`:** covers `.godot/`, `export/`, `test_output/`,
  `test_output*.zip`, `*.mp4`. It does not cover `*.zip` generally (M-8).
- **LICENSE:** MIT, "Copyright (c) 2026 Akash Das", matching the README
  statement; art/music/SFX explicitly excluded from it.
- **Font licences:** `OFL.txt` sits next to each font family, including the
  duplicate in M-2.
- **Asset size:** `assets/audio` 51 MB (of which 22 MB is M-3), `assets/fonts`
  588 KB, `assets/sprites` 316 KB, `assets/backgrounds` 52 KB.
- **Duplicate assets:** md5 scan across png/wav/mp3/ogg/ttf found exactly one
  duplicate pair — the display font in M-2.
- **Debug gating:** every debug feature is inert in a release build except the
  game-over restart, which is gameplay, not debug:

  | Key / feature | Guard | Where |
  | --- | --- | --- |
  | F3 thruster/hull overlay | `OS.is_debug_build()` | `game/battle/battle_game.gd:396` |
  | F4 panel-rect audit | `OS.is_debug_build()` | `autoload/ui_overlay.gd:47` |
  | F9 debug battle | `OS.is_debug_build()` (and not a campaign) | `battle_game.gd:392` |
  | F9 map debug | `OS.is_debug_build()` | `ui/map/galaxy_map.gd:477` |
  | `R` restart | *not* debug-gated, but only fires on the GAME OVER card (`if _campaign or state != GAME_OVER: return`, `battle_game.gd:386`) — a gameplay shortcut |
  | Bot/harness args | separate scene under `tests/`, not reachable from the game | `tests/battle_bot.tscn` |
  | Audio debug summary | `OS.is_debug_build()` | `autoload/audio_manager.gd:763,770` |

- **Runtime folders:** `tests/`, `docs/`, `reference/` are never loaded by the
  game (`run/main_scene` is the menu; no `res://tests/` or `res://docs/` string
  exists in any shipped script — the path test would fail otherwise).
- **Save file keys** (34 constants, sections `progress`, `audio`, `gameplay`,
  `upgrades`, `campaign`, `weapons`, `controls`, `high_scores`):
  `progress`: `high_score`, `energy`, `skin`; `audio`: `master_volume`,
  `music_volume`, `sfx_volume`, `muted`, `music_order`; `gameplay`:
  `reduce_motion`, `auto_fire`, `high_contrast_bullets`, `control_scheme`,
  `shield_mode`; `upgrades`: `<kind>_level` ×4; `campaign`: `active`, `seed`,
  `difficulty`, `score`, `hp`, `shields`, `conquered`, `best_score`,
  `best_planets`, `lifetime_planets`; `weapons`: `owned`, `primary`,
  `secondary`; `controls`: `<action>_key`, `<action>_pad`; `high_scores`: one key
  per difficulty.
- **High scores per difficulty** survive reload (suite covers submit/read), and
  SINGULARITY's wipe does not touch them, the settings or the bindings.
- **Galaxy reachability:** the suite generates seeds, asserts every body is
  reachable from home and that the gate opens at 3 of 5 citadels; 5 citadels per
  galaxy, so the seal is always satisfiable.
- **Weapon gates** 3/6/12/18 planets are all below the 43-planet minimum galaxy,
  so they are reachable in a single campaign (unlike the hulls, C-1).

---

## 9. Resolutions

Captured on a real window, real theme, after layout settled:

| File | Size |
| --- | --- |
| `test_output/shot_menu_640.png` | 640×400 |
| `test_output/shot_menu_1920.png` | 1409×881 |

The project uses `window/stretch/mode="canvas_items"` with a 960×600 base, so a
different window size **scales** the same layout instead of reflowing it: the
1920×1080 request came back as 1409×881 (the OS capped the window), the 640×400
request as 640×400. This means these captures cannot prove anything about a
smaller *viewport* — layout is resolution-independent by construction, and the
rect assertions in the suite run at 960×600. Capturing 7 sizes × 7 screens was
therefore not done; that is a gap, not a pass. Visual correctness was not judged.

## 10. Performance

Windowed `battle_bot -- cadet 1`, 60 s of game time (time scale 4):

```
t=10s nodes=273 fps=142   t=20s nodes=286 fps=144   t=30s nodes=286 fps=144
t=40s nodes=286 fps=144   t=50s nodes=286 fps=144   t=60s nodes=286 fps=143
result ... min_fps=142 growth=+13
```

Average ≈144 FPS, minimum 142, node count flat at 286 after the first seconds.
Draw calls and per-script timings are not exposed by the monitors used here, so
they are not reported.

## 11. Accessibility

- **Reduce motion** is wired to the shake camera only
  (`entities/fx/shake_camera.gd:32`). Screen flashes (damage, boss telegraph)
  and the victory banner tween are **not** gated by it — a real gap for the
  setting's promise ("removes shake and flashes everywhere").
- **Text sizes** are theme constants (`UITheme.SIZE_BODY` etc.) with no user
  scaling option; the smallest text on screen is 11 px (credits detail lines) at
  960×600.
- **Enemy vs player bullets:** shape differs (enemy orbs vs player dashes) and
  `high_contrast_bullets` adds an outline/halo, so the distinction is not
  colour-only by design; this was verified by reading the code and the existing
  capture modes, not by eye.

## 12. Documents checked against the code

| Document | Mismatch | Action |
| --- | --- | --- |
| `README.md` "What is not in this build yet" | still said per-pack SFX credits were missing | removed (done in stage 20, text was stale) |
| `README.md` credits | said the backgrounds' author was unknown | corrected in Part A |
| `README.md` hull skins | did not mention that the top milestones need more than one campaign | added with the lifetime counter |
| `README.md` difficulty/shield/weapon tables | match `Tuning` and `Weapons` | no change |
| `tests/README.md` | coverage list did not include save robustness or hull reachability | added |
| `CHANGELOG.md` | stopped at stage 20 | stages 21–22 added |
| `assets/audio/README.md` | matches `SOUND_MAP` (spot-checked names) | no change |
| Relative links in README | `LICENSE`, `docs/*`, `assets/audio/*` all resolve | no change |

## 13. Export readiness (read-only, nothing exported)

| Preset | Findings |
| --- | --- |
| Windows / Web / Android | `exclude_filter=""` — `tests/` is a candidate for the build (M-5) |
| Web/Android music | `include_filter` adds the raw `assets/audio/music/*.ogg,*.mp3,*.wav`, required by the playlist scan on PCK builds — correct |
| Android | `package/unique_name="com.astrodash.spaceshooter"`, `version/name="1.0.0"`, `version/code=1`, arm64-v8a only, keystore paths absent (documented) — consistent |
| Icons | `icon.svg` for desktop/Web, `icon-192.png` for Android — both exist |
| Permissions | all default permissions false, no custom permissions — good for a game with no network use |
| Version | project `config/version="0.9.0"`, Android preset still says `1.0.0`; recommend aligning before publishing |

---

## 14. Summary

| Area | Status | CRITICAL | HIGH | MEDIUM | LOW | Fixed here | Remains |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Health (import, suite, smoke) | ISSUES | 0 | 0 | 1 | 0 | — | M-6 exit-time resource line |
| Bot / soak | ISSUES | 0 | 0 | 1 | 0 | — | M-7 no soak mode |
| Code scan | PASS | 0 | 0 | 0 | 4 | — | L-1…L-4 |
| Debug gating | PASS | 0 | 0 | 0 | 1 | — | R is gameplay, documented |
| Security / privacy | ISSUES | 0 | 0 | 1 | 2 | — | M-4 history blobs, M-8, M-9 |
| Licences / assets | ISSUES | 0 | 0 | 2 | 1 | Part A credits | M-2, M-3 |
| Save data | PASS | 0 | 0 | 0 | 0 | C-2 | — |
| Progression reachability | PASS | 0 | 0 | 0 | 0 | C-1 | — |
| Input / UI | ISSUES | 0 | 2 | 0 | 0 | — | H-1, H-2 |
| Resolutions | ISSUES | 0 | 0 | 0 | 1 | — | only 2 sizes captured |
| Performance | PASS | 0 | 0 | 0 | 0 | — | no draw-call data |
| Accessibility | ISSUES | 0 | 0 | 1 | 0 | — | reduce motion misses flashes |
| Docs | PASS | 0 | 0 | 0 | 0 | Docs commit | — |
| Export readiness | ISSUES | 0 | 0 | 1 | 0 | — | M-5, Android version mismatch |

Totals: **2 CRITICAL (both fixed), 2 HIGH (open), 7 MEDIUM (open), 9 LOW (open)**.
Commits from this stage: credits (Part A), `Fix:` save coercion + lifetime counter,
`Docs:` corrections.

---

## Stage 25 — icon centring, UI alignment and the delta since Stage 22

Measured this stage with `godot --headless --path . res://tests/ui_audit.tscn`
(see `docs/ui_audit.md` for the per-card table) and the usual suite, smoke, bot
and soak runs.

### Fixed (one commit each)

| # | Finding | Severity | Root cause | Commit |
| --- | --- | --- | --- | --- |
| A-1 | Skin thumbnails, the big preview and the HUD weapon icons sat off-centre | HIGH | icons were centred by texture box while the hull art carries a different transparent margin per skin | `c35e181` |
| A-2 | Conquered map badge drew nothing and logged 3 engine errors per marker per frame | HIGH | the badge's `draw` signal was connected to a method on the marker, so `draw_circle` ran outside any `_draw()` | `d2c66a9` |
| A-3 | `ENEMIES` and the shield readout overlapped by 130x15 px | MEDIUM | both labels share the 24 px bottom strip and their x ranges crossed | `c5bd05a` |
| A-4 | `grab_focus()` on a control that had left the tree, once per soak restart | LOW | the last wave can be cleared in the frame the battle is torn down | this stage |

### Delta audit (what was actually re-run)

| Area | Status | Evidence |
| --- | --- | --- |
| Clean import (`.godot` deleted) | PASS | `IMPORT_EXIT=0`; the only "error" grep hits are filenames such as `sfx_sounds_error1.wav` |
| Suite | PASS | `SUMMARY 422 passed, 0 failed` |
| Scene smoke, 7 scenes, 5 s each | PASS | `main_menu`, `galaxy_map`, `battle_game`, `upgrade_panel`, `settings_panel`, `controls_card`, `difficulty_picker` all `exit=0` |
| Boss mode, CADET | PASS | station down at 90 s, hull 8/100, boss 68 of the damage |
| Boss mode, SINGULARITY | PASS | ship down at 26 s, station 248/305 |
| Soak, SINGULARITY 20 game minutes at time_scale 8 | PASS | 74 restarts, nodes 440 → 462, orphans 0, static memory 78.1 → 78.5 MB, objects 2778 → 2820, `no growth over 15%` |
| Soak re-run after the focus fix (CADET, 2 game minutes) | PASS | no `!is_inside_tree()` error, objects +7 (0.3 %) |
| Code scan | ISSUES (LOW) | 5 scripts over 600 lines (`config/tuning.gd` 878, `game/battle/battle_game.gd` 819, `autoload/audio_manager.gd` 791, `ui/map/galaxy_map.gd` 733, `ui/panels/upgrade_panel.gd` 684); no reserved-word identifiers; one `print()` and it is inside the debug-gated mixer summary |
| Debug gating | PASS | F4 in `ui_overlay.gd:47`, F3 in `battle_game.gd:404`, F9 in `battle_game.gd:399` and `galaxy_map.gd:477`, all behind `OS.is_debug_build()`; R is gameplay (needs `GAME_STATE == GAME_OVER`) |
| Security / privacy | PASS | no secrets, no `D:\` or `C:\Users`, no e-mail in the tree, no codebuff/freebuff mention; three tracked files over 5 MB and all three are music tracks (`8bit.mp3` 5.1 MB, `Orbital Colossus.mp3` 6.1 MB, `Preparing for War.mp3` 5.2 MB) |
| License / assets | PASS | only duplicate hash is the standard OFL text beside the two font families, one per family as intended |
| Save data | PASS | hostile-file tests still cover missing, empty, truncated, mistyped and unknown-key saves plus the old schema |
| Progression | PASS | lifetime-conquest hull unlocks, weapon planets and gate reachability tests still pass |
| Input | PASS | every gameplay action has a gamepad binding, the declared exceptions are listed, remaps persist |
| Export readiness | unchanged | read-only: `exclude_filter` is still empty (`tests/` would ship), Android preset name still `1.0.0` against project `0.9.0` |

### Not done in this stage

- Bot rows on every difficulty and band: only CADET band 1 and SINGULARITY band
  1 were flown (plus boss on two modes). The remaining band combinations were not
  re-run.
- Screenshot captures at 640x400, 800x500, 1280x720, 1920x1080 and 2560x1080, and
  the 60 s real-window performance run: not captured, so no draw-call or FPS
  numbers beyond the headless soak's `fps=142` (which is not a real-window
  measurement).
- Stage 22 backlog: M-5 (export exclude filters) is an export-preset change and
  stays open; M-6 is reduced but the "resources still in use at exit" line and
  19 leaked ObjectDB instances at exit remain; M-8/M-9 and L-1..L-4 are untouched.

### Summary

| Area | Status | CRITICAL | HIGH | MEDIUM | LOW | Fixed here | Remains |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Icon centring | PASS | 0 | 1 | 1 | 0 | 3 | — |
| UI alignment (960x600) | PASS | 0 | 0 | 0 | 0 | 1 | pause card not presented by the audit pose |
| Health (import, suite, smoke) | PASS | 0 | 0 | 0 | 0 | 1 | M-6 exit-time leftovers |
| Bot / boss / soak | PASS | 0 | 0 | 0 | 0 | — | band coverage incomplete |
| Code scan | ISSUES | 0 | 0 | 0 | 1 | — | 5 long scripts |
| Debug gating | PASS | 0 | 0 | 0 | 0 | — | — |
| Security / privacy | PASS | 0 | 0 | 0 | 0 | — | — |
| License / assets | PASS | 0 | 0 | 0 | 0 | — | — |
| Resolutions / performance | NOT RUN | — | — | — | — | — | no captures beyond 960x600 |
| Export readiness | ISSUES | 0 | 0 | 1 | 0 | — | M-5, Android version |
