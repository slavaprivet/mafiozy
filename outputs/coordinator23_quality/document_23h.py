from pathlib import Path
import json
root=Path(__file__).resolve().parents[2];out=root/'outputs/coordinator23_delivery23h'
running=json.loads((out/'RUNNING.json').read_text(encoding='utf-8-sig'))
text=f'''## 30 September 14:19 — accepted23h delivered: cargo hover, return, game cursor

Current exact export: candidate16 PCK8051926d109704cb4f85eb46cd2af8dd5b9a84d9cc4e71480db22b699dce7741.
One accepted game PID{running['pid']} responding; project-root «Мафиози — актуальная версия.lnk» updated.
Fresh inventory required next turn. Shared13 scoped paths and3 cursor import/UID metadata promoted,
all unrelated NPC/transport/palette work preserved. Ordinary shared F5 main14guns/3NPC/transport/cursor imports PASS.

Latest user requests completed: camera hover on actual stored model gives depth-tested gold tint and E exactUID/ammo take;
E with no item uses existing lid open/close. F opens contents, mouse-hover card + E or Take immediately returns
to gameplay; activation is consumed, held release quarantined, next deliberate click shoots. Q/X return,
Esc frees mouse; modal has close-lid action. Custom muted ivory/gold arrow and hand installed once/released on exit.
Pointer follows actual GUI event coordinates, clears on window exit; no stale row on E. Phase/focus invalidation
releases both logical/OS controls. No other full migration feature is claimed done.

Evidence: docs/godot/WEAPONS_23H_CHECKPOINT.md; exact pack actualGPU247PASS/root viewed clear model andUI,
joint compiled277+85+49+18 and final sole changed renderer source85PASS with full source closure. First material
binding32.467ms→0.052ms by startup empty native instance bind/free; no extra mesh/draw/collision/retainednode.
Sequential comparable720frames per build old11 vsfinal16: GPU p95 ~unchanged, wall p95 differences+.447/+.299/-.278ms,
maxima improved; ~180KB RAM/~1MB VRAM added. Offscreen one-camera short sample, NOT city FPS or focused OS-input proof.
Headless verifies logical native events, rendered backend capture/release is synchronous; offscreen NO_FOCUS is explicit.

GPU QA and heavyCPU quiet RELEASED; user's sole game stays. Hourly pendingproof main36b22251693e9951018679cd26d003169f657240
was pushed/remoteverified. Read Git/current delivery23h PUBLISHED for final accepted runtime commit.
RPG source/HP/Industry audit begun this turn then deferred for direct cargo/cursor steering: outputs/coordinator23_rpg23h,
already saved in36b2225; proposals not enabled. Preserve source horizontal radius11.07m/no NPCLOS/current-impact marksman,
opaque authentic flight tickets; old lifecycle packet must not overwrite newer head/point policy. Active medical corpse
uniform finishing impulse remains HOLD. Recent HQ Artist23 sever candidate/leg topology packets are isolated, not gameplay.
Industry all-building rollout staysHOLD despite componentPASS; check fresh pins. Full Walk migration, RPG blastHP, native
player HP/authority and full NPC city remain unfinished. Reports only HQ; pinned5 staysOFF; no direct Astra polling.

'''
for rel in ['docs/ai/COORDINATOR_23_MEMORY.md','docs/ai/COORDINATOR_23_HANDOFF.md','docs/godot/MIGRATION_BOARD.md']:
    p=root/rel;p.write_bytes(text.encode('utf8')+p.read_bytes())
checkpoint='''# Accepted23h — cargo controls, cursor and first-hover cost

Final frozen candidate16 PCK `8051926d109704cb4f85eb46cd2af8dd5b9a84d9cc4e71480db22b699dce7741`.
Exact exported executable copied to the `s01-20260930-quality23h-play` folder; existing project-root shortcut updated.
Source13 guards and all unscoped before/after hashes: outputs/coordinator23_delivery23h/PROMOTION.json.
Cursor metadata/cache exact import handoff: CURSOR_IMPORTS.json. Shared headless normal startup verifies14guns,
3hit owners, population/transport readiness and both36×44cursor textures. Actual running PID in RUNNING.json.

## User-visible behavior

- Aim actual trunk item: gold tint, E take. E without a picked item reaches existing transport lid control.
- F contents. Hover any card and E or click Take; ownership and finite ammunition preserved. Success closes
  the modal and resumes focused gameplay in the same call. Failure stays in the modal.
- The activation cannot become a shot; held activation is suppressed only until release. The next deliberate
  shot works. Q/X close to play, Esc frees pointer; explicit Close lid button remains.
- Arrow and pointing hand use muted warm ivory, dark outline and gold accents. Hardware cursor installation
  is one-time; textures released before renderer shutdown. Native asset rasters verified separately because
  hardware cursors do not appear in viewport PNGs.

## Evidence and actual bounds

- Compiled candidate15 joint native277 pointer/controls +85 real world pickup +49 independent real GUI input
  +18 pose/Q handoff PASS; tests use actual Input.parse_input_event and scheduled player physics, never pressed-signal
  emission. Candidate16 changes only the renderer's startup material preparation; native85 stage's317 source
  files exactly equal16. All other315 packed payloads are byte-identical15→16.
- FINAL16_GUARDS:209 source receipt inputs/316payload MD5,13shared guards,116NPC/transport/vehicle inputs preserved.
- Exact finalGPU `outputs/coordinator23_cargo_visual16/gpu16_01`:247PASS, clean engine exit. Original3NPC,
  8buildings,377collision bodies/shapes;1280×720/800×600 layouts. Root viewed actual clear TT tint and UI.
  Closeup uses the original camera temporarily reparented and hero moved to a valid side access position;
  actors/geometry/physics stay active. It is an explicit observer, not normal-camera usability parity.
- Dummy headless ignores Input.mouse_mode setter, so it proves logical native-input flow. Rendered backend
  CAPTURED/read/VISIBLE checked synchronously; no await while captured. NO_FOCUS tests check suspension;
  focused OS-level mouse behavior is supported by the real branch/backend, not claimed as manual OS acceptance.

## Performance

Visible first material binding was32.467ms in15, next78us. Moving its native empty-instance binding to configure
  (no mesh, tree, pixel, collision or retained node) makes exact16 first hover52us, next73us in the same harness.
Full diagnostic with duplicated queries fell39.534ms→6.671ms; those duplicate queries are disclosed test overhead.

Pair `outputs/coordinator23_cargo_perf13/COMPARISON16.json` is comparable: exact accepted11 vs16, same frozen
  harness50aaa930…, attached camera, settings, original content,14real items, same unchanged cache policy;
  one offscreen NO_FOCUS process at a time. Three240-frame phases on each build:

| Phase | wall p95 before/after ms | max before/after ms | GPU p95 before/after ms |
|---|---:|---:|---:|
| closed |3.165 /3.612|4.925 /4.425|2.583 /2.589|
| contents |3.736 /4.035|10.525 /8.963|2.676 /2.675|
| closed again |4.232 /3.954|8.889 /6.489|2.609 /2.597|

~179–186KB static RAM and1,054,448bytes VRAM delta. No scene-content reduction. Camera fixed-ray model hover
  is explicitly SKIP in pair; the clear observer separately measures actual model selection/material cost.
This short loaded-quarter pair is not a cityFPS, long-run leak or true-cold driver cache result.

## Corrections retained as evidence

Candidate12 GPU failed initial card hover: OS-polled coordinates disagreed with delivered GUI events. Pointer14
  uses event coordinates and window-exit invalidation. Windows cached has_focus remained true even with NO_FOCUS;
  explicit unfocusable admission prevents synthetic capture. Static/native Input cursor texture ownership needed
  release before renderer shutdown.14observer spring arm overwrote top-level camera position;15reparent fixed this,
  but its first closeup was hero-occluded and rejected visually.16harness moves hero to valid side access and lets
  stale test feedback expire. Failed/raw evidence is retained and does not substitute for final acceptance.

Full migration remains incomplete: RPG blastHP/authority, full NPC city, medical and Industry building rollout
  are still pending. No new NPC/physics/transport mechanics were enabled with this UI patch.
'''
(root/'docs/godot/WEAPONS_23H_CHECKPOINT.md').write_text(checkpoint,encoding='utf8')
print('Updated coordinator memory, handoff, migration board and honest checkpoint')
