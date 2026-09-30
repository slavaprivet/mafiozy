# Coordinator24 cargo controls — isolated proposal

Status: one reproducible modal movement defect fixed; intermittent direct-E click/freeze report remains unproven. No shared production source edited, no GPU process launched by this subagent.

## Defect and exact scope

Accepted23h's cargo modal calls Input.action_release for movement on every key. The physical key remains held. On successful E take, close_window restores logical capture but releases actions again. Holding W before/during the modal therefore leaves physical W=true, forward action=false, and actual movement=0.0m until a new key-down arrives. A direct aimed E transfer preserves held W and movement. This is a separate, narrower reproduced issue than the user's complete report (both direct and modal).

The proposal changes only scripts/weapons/preview_weapon_cargo.gd from candidate16. At the existing admitted, focused modal-return branch, restore only physically still-held mapped movement and run keys. E/SPACE/fire are excluded. No every-frame polling, no changes to pointer/focus policy, no changes to transfers, UID, ammunition, lid/seat, renderer or presentation. Esc, the focus-loss handler and invalid pose authority retain suspension.

Input authority is checked again via _allowed before restoration. Window focus/unfocusable guard remains exact accepted16 behavior. Missing/disabled actions have no mapped keys; already-released keys remain released.

## Files and guards

- files/scripts/weapons/preview_weapon_cargo.gd — complete proposed file, **not promoted**.
- merge.patch — reviewed two-hunk delta against accepted16.
- Before raw SHA256: 6126dc3de6339e303a20ea37e79b32b7be54e41527d11010727d02fc99010883.
- After raw SHA256: e647d6cf902097ef4b9e4c8eb993cc95c6e8b1fb1b42ab4fb8c17aefe556359b.
- Base PCK: exports/win64/s01-20260930-quality23h-play/MafioziPreview.pck, exact accepted23h; no RPG candidate18/19.

## Tests

test_inputs.gd loads the real compiled accepted23h PCK, actual player/input routing/transport/renderer/inventory/cargo. --patch loads the single proposed cargo script into ResourceLoader cache before the real scene is instantiated. The component test alone disables NPC; headless Dummy cannot establish OS mouse capture/focus proof.

- baseline_final.log: 35 assertions, **two expected failures** for held-W restoration and physical movement. All others pass. Actual physical W=true, forward action=false, movement=0.0m. Uses --expect-restored.
- patched02.log: **55 PASS**. Same physically-held W resumes immediately, movement=0.0299987793m over three ticks without mouse click or another key-down. Native input injection, not action_press, drives this regression test.
- Negatives: W released in modal never resumes; all WASD/arrow/run mappings; held SPACE never replays jump; Esc and focus-out remain suspended; pose authority loss blocks restore; E release quarantine; exact TT UID and finite ammo retained; no activation shot. Direct E already-held movement stays working. Focus notifications were injected into the original player handler; these tests do not establish OS focus behavior.
- baseline03.log: initial 23-check pass with explicit before finding; baseline01/02 failures were fixture aiming errors, fixed by existing accepted triangle-target setup. They are not runtime regressions.

There is no full-city frame/memory acceptance here. The patch adds a bounded scan of nine configured movement key mappings at modal close and zero work to steady-state frames. Root must validate the loaded candidate and actual focused gameplay.

## Interactive diagnostics

interactive23h.gd + cargo_input_observer.gd: exact original main with original residents enabled, actual paired APIs populate all14 cargo items (100/100), open hatch and place player at rear. Camera stays attached to original player (top_level=false). No game script override. Initial pointer is deliberately released; first focused click enters gameplay.

Launch engine with --main-pack exact23h PCK --script absolute interactive23h.gd -- --cargo-trace-out=<new local output folder>. READY.json confirms fixture setup. events.jsonl records at most512 sparse event rows: pre/post input, focus notifications, changes to control flags/weapon identity, and >100ms wall gaps for5s after input. It only observes; never changes input, focus, capture, inventory or authority. All state is from Godot APIs. Read-only observer flush cost is included in dispatch timing, so this diagnostic run is not a precision performance comparison.

interactive_smoke.log: headless initialization succeeds, original residents ready,14items/100units and camera_top_level=false. Actual Windows native mouse/keyboard reproduction remains root-owned, not claimed by this package.

CPU slot released after final baseline run. No task-owned Godot processes remain.
