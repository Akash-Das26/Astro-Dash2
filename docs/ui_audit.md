# UI alignment audit

Measured, not eyeballed: `tests/ui_audit.gd` instantiates each screen at the
project resolution, opens the card the pose asks for, waits three layout frames
and reads the live `Rect2`s.

```
godot --headless --path . res://tests/ui_audit.tscn
```

Last run: `AUDIT DONE findings=0` (after the two fixes below). Every number in
the tables is copied from that output.

What it checks on every pose:

| Check | Rule | Tolerance |
| --- | --- | --- |
| Card padding | `StyleBoxPanel.content_margin` of each `PanelContainer`, all four sides | spread ≤ 2 px (`-1`, i.e. unset, is skipped) |
| Leftover space | a shrink-to-fit card may not be taller than `get_combined_minimum_size().y`; cards that fill their parent are excluded | ≤ 4 px |
| Screen clipping | no visible `Control` may leave the 960x600 viewport; clipped scroll and credit-roll content is excluded | ≤ 2 px |
| Text overlap | two sibling `Label`/`Button` nodes with text may not intersect | ≤ 1 px each axis |
| Gaps | every `separation` value in use, listed per screen, to flag outliers | report only |
| Icons | every `UIIcon`'s opaque rect centred in its box | ≤ 1 px |
| Named cards | `*Card*` controls and plain `Panel`s: inset above vs below their content | spread ≤ 2 px |

## Per screen

| Screen | Card | Padding l/t/r/b | Content vs box | Result |
| --- | --- | --- | --- | --- |
| Main menu | (panels only, no `PanelContainer` card) | — | 161 controls | no finding |
| Difficulty picker | `Panel` 820x499 | 18/16/18/16 | 820 wide needed vs 820 used | no finding |
| Settings | — | 23 controls | — | no finding |
| Controls | `Panel` 780x477 | 18/16/18/16 | — | no finding |
| Credits | `Panel` 600x529 | 18/16/18/16 | roll clips on purpose (`clip_contents`) | no finding |
| Upgrade, Hull tab | `Panel` 896x568 | 18/16/18/16 | fixed screen size | no finding |
| Upgrade, Weapons tab | `Panel` 896x568 | 18/16/18/16 | fixed screen size | no finding |
| Galaxy map | — | — | — | no finding |
| Map tooltip | `Tooltip` 220x89 | 10/8/10/8 | 220x89 needed | no finding |
| Map CONQUER card | — | — | — | no finding |
| Battle HUD | upgrade-track cards 276x104, content 260x88 | 8 above / 8 below | — | no finding |
| Pause card | overlay `EndCard`-style, see gaps below | — | — | not presented by the pose |
| Victory card | `Panel` 660x298 | content 412x298 | fixed 660 width, centred | no finding |
| Defeat card | `Panel` 660x269 | content 350x269 | fixed 660 width, centred | no finding |

Gap values in use: 1, 2, 4, 5, 6, 7, 8, 10, 12, 14, 16 px. The 1–2 px values are
inside the upgrade stats column and the menu footer; 16 px appears only in the
map tooltip and the HUD bottom row. No value is an isolated outlier.

## Findings and what was done

| # | Finding | Evidence | Action |
| --- | --- | --- | --- |
| 1 | Skin thumbnails, the big preview and the HUD weapon icons were centred by texture box, so the visible ship sat left of and above centre (interceptor low) | centres off by up to 4 px; the 70x50 interceptor carries an asymmetric margin | fixed in `c35e181`: `UIIcons.opaque_rect()` measures the visible pixels once per texture and `UIIcon` draws the icon centred by them; thumbnails, preview (hull + flame block), weapon rack icon and both HUD slots now use it |
| 2 | Conquered map badge drew nothing and logged an engine error every frame | `ERROR: Drawing is only allowed inside this node's _draw()` ×3 per marker per frame, from `body_marker.gd:225/226/241` | fixed in `d2c66a9`: `MapBadge` draws the check in its own `_draw()`; the marker only places it (badge rect and z-index unchanged, badge tests still pass) |
| 3 | `ENEMIES 0/0` and the shield line overlapped by 130x15 px in the bottom bar | shield label x 658–810, enemies label x 680–948, both y 581–595 | fixed in `c5bd05a`: enemies line starts at 800, shield line ends at 790; new test asserts no two bottom-bar labels intersect |

No other defect of 2 px or more was found on the measured screens.

## Icon inventory (grepped)

`TextureRect` and raw `draw_texture_rect` icon boxes in `ui/` and `entities/`:
none left. Every icon-in-a-box now goes through `UIIcon`:

| Place | Box | Source |
| --- | --- | --- |
| Hull skin thumbnails (10) | `SKIN_ICON_SIZE` button, 3 px padding | `upgrade_panel.gd::_build_skins` |
| Large skin preview | preview box, 18 px margin; hull placed by its opaque centre so the tail joint is exact | `upgrade_panel.gd::_place_preview_pair` |
| Weapon rack icon | 72x72, 4 px padding | `upgrade_panel.tscn` `WeaponIcon` |
| HUD primary / secondary slots | 24x24, 3 px padding | `hud.tscn` slot `Icon` |

The shield pickup and the touch "SHLD" button are drawn shapes/text, not
texture icons, so there is nothing to centre.

## Coverage gaps (not measured here)

- The pause pose calls `HUD.show_paused()` but no card becomes visible in that
  state, so the pause card's own rect is not in the table above. Its layout is
  covered by the banner/overlay tests and the screenshot runner's asserts, not
  by this tool.
- Map body sprites, the selection ring, the glow, the attack arrow and the badge
  are `Node2D`s; their centring is asserted by `tests/run_tests.gd`
  (`the home badge …`, `the badge is drawn above the art`) rather than by pixel
  measurement here.
- Thruster anchors for all 10 skins and every enemy kind are asserted by the
  existing thruster tests (`the flame starts at the tail`), not re-derived here.
- Only 960x600 was measured. The other resolutions from the Stage 25 plan were
  not captured in this pass.
