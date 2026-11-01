# Orphans

Produced at the end of Stage 14. A file counts as an orphan when **no** `.gd`,
`.tscn`, `.tres`, `project.godot` or `export_presets.cfg` in the repository
contains its `res://` path, and (for scripts) no file uses its `class_name`
either. 72 files were scanned.

## Scripts and scenes

| File | Verdict |
| --- | --- |
| `tools/resave.gd` | **Kept on purpose.** Run by hand after a folder move so every scene stores the new paths: `godot --headless --path . --script tools/resave.gd`. Nothing loads it at runtime, which is why the scan flags it |

Nothing else was orphaned: every script is reachable through a path (autoloads
from `project.godot`, tests from `tests/run_all.ps1`, gameplay from `preload`)
or through its `class_name`, and every scene is instanced by another scene or
loaded by name.

## Art

**No PNG is orphaned any more.** The five that were listed at the end of Stage
14 were all wired up in Stage 15 instead of being deleted:

| File | Now used by |
| --- | --- |
| `spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship.png` | `MenuBackdrop.SHIP_TEXTURES`, the fifth drifting escort |
| `spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship3_red.png` | `elite_red`, the dive bomber |
| `spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship3_green.png` | `elite_green`, the sniper |
| `spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship3_yellow.png` | `elite_yellow`, the shield carrier |
| `spacepixels-0.2.0/spacepixels-0.2.0/pixel_shape3_blue.png` | `drone`, the swarm fighter |

`assets/audio/**` and `assets/fonts/**` are **excluded** from the scan on
purpose. Their files are resolved at runtime, not by path literals:
`AudioManager.SOUND_MAP` builds the SFX paths from pack constants and the music
folder is scanned by extension, while `UITheme` scans `assets/fonts/` for the
two families. A zero-hit file there is normal and does not mean it is unused.

## Deleted in this stage

| Item | Why |
| --- | --- |
| `tools/rewrite_paths.gd` (+ `.uid`) | The one-shot rewriter that performed this stage's moves; keeping a writer that rewrites every path in the project would be a foot-gun |
| `tools/move_map.tsv` | Its input table (394 lines); only the rewriter read it |
| `.check_project.js` | An abandoned pre-Godot brace/path checker from the first stages, superseded by `tests/check_paths.gd` and the suite. It was never committed |
| `game_manager.gd` / `shop_panel.*` and the other retired systems | Removed in earlier stages; only `.tmp` leftovers were deleted here, never art or audio |

Nothing else was deleted: no `.gd` file, scene, resource, sprite, font or sound
was removed in this stage.
