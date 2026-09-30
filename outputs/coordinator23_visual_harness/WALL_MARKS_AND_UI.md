# Root-only close-wall + integrated UI verification

No GPU run by author. Running user game and frozen candidates unchanged.

## Actual wall marks: `capture_wall_marks.gd`

Extends sibling `capture_effects.gd`, retaining root NO_FOCUS, deferred-after-physics freeze, passive pose receipts, native input and bounded58s deadline. External watchdog/root GPU ownership remain required. Works with an imported `--path` project or a complete `--main-pack` PCK:

```
GodotConsole --main-pack ABS_PACK --script ABS/capture_wall_marks.gd --position -32000,-32000 --resolution 1920x1080 -- --qa-out=ABS_NEW_OUTPUT
```

Do not change a frozen candidate. Before/after comparison means the SAME external harness against baseline and art-upgraded root builds in separate sequential GPU runs, distinct output directories. It never swaps mark meshes, injects contacts, paints replacement marks, changes weapon scale, extends marks'5s life or writes camera transform.

Two real AK shots using actual viewport LMB/RMB, one ammo commit each. It finds an existing vertical world wall using ordinary mouse orbit, validates actual floor + original player capsule at fixtures, then logs player fixture repositioning. Close inspection needs legal wheel minimum3m after firing because aim spring4.2m otherwise holds the camera farther away. After real contact it releases RMB and orbits yaw5° so the real mark leaves the reticle. Captures before-shot RMB and after-hit clear-reticle for nominal4.5m and10m camera distances: **four PNGs**, each with actual camera/player-to-impact distances, native/logical pixel scaling, projected mark position and estimated native mark pixel diameter. No count change to existing captures in other scripts.

`check_wall_fixtures.gd` geometry/input preflight was run headless against unchanged `candidate03/.../s01-20260930-quality23c-final/MafioziPreview.pck`: **12PASS**, camera distances4.51764m and10.01412m; player distances2.27994m and7.14131m. This validates floor/capsule support, source wheel, and same real wall ray only—not real-shot/screenshots/mark art. Receipt: `wall_fixture_preflight/RESULT.json`.

Direct `--path godot/mafiozi_walk` preflight encountered missing loader/import for `scope_optic.svg`, leaving no weapon host. No import or production edit was performed; only the agent's failed headless test was stopped. Both new harnesses now fail clearly when the weapon host is unavailable. Root should use its complete packed build or properly imported candidate for GPU.

Long-distance holes cannot show detailed facets: source normal diameter remains5.04cm. The previous18.6m captures were ~2pixels under the white reticle; new close framing helps judge actual chipped rim/recess without oversized marks.

## UI soft14 + zoom38 + source crosshair: existing `capture_behavior.gd`

Updated outputs-only and syntax checked. Keeps current root S-facing, RMB and sniper extra frames. Counts remain19PNG/resolution with `--qa-visibility-probes`,17without. New post-RMB checks require FOV38±.12, crosshair Control `snapshot()`, four source arms, and gap3..64. Sniper requires14±.12 and ordinary reticle hidden. Snapshots include crosshair gap/spread/arms/redraws/rects when available, and never assume Label/text. Root must integrate the crosshair module and requested38FOV before this run; old42FOV intentionally fails.

No texture acceptance is inferred from hashes: root should view menu01/selected02/launcher and compare natural wood/metal/gold plus accepted none skin at actual UI sizes. Capture16 checks zoom/crosshair,17checks scope. Use one resolution first to stay within the80s internal deadline; another root run can cover1920.
