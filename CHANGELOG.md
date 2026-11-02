# Changelog

Newest first. One line per build stage; the version number is what
`project.godot` reports and what the main menu shows.

## 0.9.0 — release candidate (2026-11-02)

- **Stage 25, icon centring and UI audit.** Every icon in a box is centred by its
  opaque pixels (the ten skin thumbnails, the big preview, the weapon rack icon
  and both HUD weapon slots), the conquered map badge draws on its own node
  instead of failing an engine draw call every frame, and the shield readout no
  longer runs under the enemies readout. `tests/ui_audit.gd` measures the live
  rects of every screen and `docs/ui_audit.md` records the numbers.
- **Stage 24, clean history.** The history was rewritten from a fresh clone: the
  large blobs, build output and the three third-party zips are gone, and a
  commit-msg hook keeps tool footers out of future messages.
- **Stage 23, audit follow-ups.** Gamepad can open the controls card, keyboard
  aiming works in free aim, the shield display reads current/limit, reduce motion
  also covers hit flashes and elite glows, the duplicate font and the 22 MB
  `8bit.wav` are gone, and a soak harness samples node and orphan counts.
- **Stage 22, credits and audit.** All art, backgrounds included, is credited to
  Space Pixels by Hex; Prepare for War stays with its CC BY-SA 3.0 note on the
  card and in the README. `docs/audit_report.md` records a full audit; the two
  CRITICAL findings are fixed (hull unlocks reachable through lifetime
  conquests, and a corrupted save can no longer raise errors on load).
- **Stage 21, credits close-out.** The sprite and background packs are credited
  with the author's own free-use terms, and the credits card is captured at three
  scroll positions with a layout test.
- **Stage 18, boss coverage and release prep.** A dedicated bot mode flies each
  difficulty against a citadel station for 90 s and reports the fight, the
  station's HP over time and the damage per third of its bar; screenshots,
  controls, credits, version and changelog are in the README, and the Web and
  Windows builds are exported and size-checked.
- **Stage 17, upgrade panel and balance harness.** The Hull & Ship page fits its
  panel with the skin row and the wearing line visible, the preview flame is
  pinned to the tail in texture pixels, and the balance bot flies any distance
  band, citadel or gate at 4x time and records damage per attacker.
- **Stage 16, visibility and overlap.** The wave banner hides behind every card,
  elites and drones get a pulsing rim glow and larger hulls, small ships get a
  brighter exhaust, and the bot reports wins, hull and damage per enemy kind.
- **Stage 15, remaining sprites.** Elite red/green/yellow and the blue drone join
  the wave mix from band 2 up, every pack sprite now has a role, and the polish
  pass fixed the controls row, the upgrade preview and the enemy exhaust.
- **Stage 14, folder reorganisation.** `autoload/`, `config/`, `game/`,
  `entities/`, `ui/`, `assets/`, `resources/`, `tests/` and `docs/`; the
  misspelled `assests/` became `assets/`, every path moved with `git mv`, and
  `tests/check_paths.gd` keeps the tree honest.
- **Stage 13, QA by running the engine.** 561 unused SFX files deleted (55 MB),
  the import and parse sweep, a headless logic suite, the battle bot, scene
  smoke runs and the first real screenshots.
- **Stage 12, parse fix, shields per mode and the mixer.** `shield_capacity` is a
  real member, shield capacity comes from the difficulty table (0 on the hard
  modes, drops still grant one), every card is sized to its content, and the
  Master/Music/SFX sliders actually move their buses.
- **Stage 11, difficulty, healing and sound.** Five modes with per-planet
  healing, milestone jumps and per-mode defeat rules; citadel stations scale with
  the mode; thrusters anchored at every hull's tail; the SFX packs wired through
  one keyword map with per-sound trims.
- **Stage 10, layout and control schemes.** Map tooltip sized to its text,
  upgrade columns tightened, FREE AIM / CLASSIC schemes with turn/thrust/brake,
  a manual shield bubble, a global `C` controls card, double-click to conquer and
  the real music credits plus a boss track.
- **Stage 9, fixes and polish.** `_unhandled_input` marked handled before any
  scene change, the upgrade panel fits both tabs at 960x600 with a fading
  feedback line, the ship wraps at all four edges, movement is frame-rate
  independent and normalized, key remapping persists in the save, the map zooms,
  and the fonts and audio table are wired.
- **Stage 8, shields and weapons.** Enemy bullets are round, hot and readable on
  every band with a high-contrast toggle, shield pickups and a pip bubble,
  recharge from the SHIELDS track, and a two-slot weapon system.
- **Core build (stages 1-7).** Free-flight ship with thruster, HP and shields,
  three fighter types, splitting asteroids, waves, combo scoring, energy orbs,
  particles and shake, a seeded galaxy map campaign with citadels and a gate, the
  2x2 upgrade screen with ten hull skins, and the menu, pause, victory and
  game-over cards.
