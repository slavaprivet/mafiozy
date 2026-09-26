# S01 independent dive review

27 September 2026. **Final independent headless run: 101 assertions PASS, exit 0**, on the frozen cinematic profile below. Independent reviewer owns only `scripts/tests/test_preview_dive_independent.gd` and this document. No player, sampler, main, GPU, export or visible game changes in this scope.

## Scope and reference

The test starts the actual imported player and physical floor/collision fixtures in Godot 4.7.2. Its reference process executes the repository's `hero_jump.mjs` and `surface_motion.mjs` with Node. The bounded jump-clock driver follows `walk_preview.mjs`: accepted time is capped at 0.25 seconds, divided into at most seven 0.04-second steps, with no hidden or invalid-time debt. This is an independent reference driver, not execution of the entire browser game. Source file hashes are recorded in the test result.

The test compares actual controller positions with the executed source trajectory, and independently reconstructs unarmed `hero_walk.jumpPose` rotations. Applied visual, chest, limb and world-head quaternions use `1 - abs(dot(q1, q2))`, so equivalent quaternion signs do not cause false failures. Full imported skin vertices are separately transformed with actual skeleton/skin bind matrices to check the body foot plane; this does not call the production support solver.

Eight physical input runs use a non-cardinal camera yaw, all cardinal and diagonal directions, and released Space events. Ownership interruption checks that body, bones and visual transform stay unchanged after external ownership. A visible focus-out check distinguishes control release from hidden-clock suspension. Native pointer-lock success and OS minimization remain outside headless verification.

## Confirmed finding before the cinematic profile

On player SHA256 `57e9762b7f836bb9729ac5f218886d8400c18a90e36cb4d022c3988027b7826b`, the first independent run passed 61 of 62 assertions and found one physical mismatch after jumping off an edge. Before a supplied 0.2-second callback, position differed from the source by at most 0.000444 metres. `createSurfaceMotion.update` caps the consumed time at 0.1 seconds; continued Godot falling used the full callback delta.

At the long callback the actual Y was −5.849375 metres, versus source −4.473750; actual vertical velocity was −14.65625 m/s, versus source −12.85625. The 1.375625-metre error was therefore isolated to the extra 0.1 second of gravity integration. The finding was sent to the runtime owner and coordinator before release finalization.

The same pre-profile run matched all eight actual directional pose sequences: maximum visual and limb quaternion error 2.3842e−7, world-head error 1.1921e−7, source elapsed error 2.22e−16 seconds. The real ceiling fixture with 0.04-metre reserve differed from source by at most 0.000738 metres.

## New user-requested profile

The user subsequently requested a longer cinematic dive. Its trajectory is an explicit design change; the ordinary jump and pure source profile remain separate regression baselines. The requested runtime contract is 1.25 seconds of flight counted continuously from the first Space, 4.2 m/s after upgrade, and 0.45 seconds of contact recovery. An immediate upgrade travels 5.25 metres; an upgrade at 0.1 seconds travels 5.18 metres, including the original 3.5 m/s movement before upgrade.

The independent analytic oracle preserves the normal arc's height and derivative at upgrade. During rising motion, velocity decays quadratically to zero and then a cubic Hermite segment descends to contact. A 0.1-second upgrade reaches 0.935 metres; the immediate profile targets 0.82 metres. This distinction preserves a late normal jump's existing energy. At a 0.49-second descending upgrade, the independent test requires downward continuation with no renewed upward impulse, immediate movement or elapsed reset.

The runtime owner fixed the continued-fall time cap and hidden gate. The final independent run passed all 101 assertions; the original failure remains above as a review receipt, not an outstanding blocker.

| Final actual measurement | Result |
| --- | --- |
| Eight directions, delayed 0.1-second upgrade | 5.180340–5.180342 m; apex 0.934981 m |
| Cinematic analytic path maximum error | 0.000792 m |
| First physical floor contact | Frame 74 or 75, zero-based, at 60 Hz |
| Full selected pose lifetime | 103–104 physics samples, including contact recovery |
| Side-pose hold before physical contact | 18–19 samples per direction |
| Descending 0.49-second upgrade path error | 3.772e−8 m; maximum upward step 0 |
| Unchanged ordinary source path error | 0.000700 m |
| Pure source proposal versus executed JS | 4.441e−16 maximum numerical error |
| Real ceiling path error, 0.04 m reserve | 0.000738 m |
| Normal edge fall, all samples | 0.000589 m maximum error |
| Continued-fall 0.2-second callback after fix | 1.526e−7 m error |
| All 8,338 skin vertices, 56 actual pose samples | 0.00002450 m maximum foot-plane error |
| Applied visual and limb quaternions | 2.3842e−7 maximum `1-abs(dot)` |
| Applied world-head quaternion | 1.1921e−7 maximum `1-abs(dot)` |

The explicit hidden-clock seam freezes continued falling without accumulated debt; visible focus-out continues the trajectory and releases pointer/input control. External authority cancels the trajectory and pending pose and leaves body/bone/visual transforms stable. The production hashes were checked again at test completion and remained unchanged.

Final frozen player SHA256: `13e3d83baa7648be5040bde64d1b899404bc2d7984aed22afe8b02b0c9b4db57`.

Final frozen sampler SHA256: `32be580dbbfdc9169225e822acafb7c73c68c6e33a139c0b0970585808927ceb`.

Executed reference source hashes:

- `hero_jump.mjs`: `6315992afff118c63facd12c2957437ed46bd126642f49fc6619bd845df0d680`
- `surface_motion.mjs`: `a9cacfd619e65da7f75cfe5ac756a97c003bd0f6d4bbe04d21d7ec6852cce8f6`
- `hero_walk.mjs`: `60ad2135010926f9fe1f18c62a89a877eb2547c708b723d7926f513043cc28c3`
- `walk_preview.mjs`: `e80ebf4be2d0404ad5b51d4bf28b756a9cba2b486c43c0797de748c37364dd47`

## Old airborne assertions

The later small-floor-drop fix exposed a second, independent contact bug on player `e2a74267237480bb1ac2cc6b92776a4d0d35ebe418fb8858860bd5d0ab638325`. In the ±X runs, frame 74 had elapsed 1.25, progress 1.0, `contact_elapsed=-1`, and `is_on_floor=false`; physical contact followed on frame 75. The normal source floor-resolution branch assigned its progress to the cinematic state before physical contact. This was a real one-frame upright pose, not an obsolete test expectation. The reviewer retained the hold assertion and added exact per-frame failure diagnostics. The runtime owner restricted that progress assignment to the normal source branch. The final `13e3d83b` run passed all 101 original assertions with empty `premature_recovery` traces in all eight directions; there is no remaining independent blocker from either finding.

The old Godot airborne sampler's phase names and takeoff carry are not the source jump contract. `walk_preview.mjs` selects `hero.jumpPose` for a jump, and that function restores the canonical skeleton before applying the current source pose and solving skin support. The new player gives this selected pose one final skeleton writer. Tests should compare that resulting pose and physical contact rather than require the unused fallback airborne sampler to enter its former phase sequence.

A previously observed 0.215-metre boot step versus the old 0.13-metre threshold is not silently accepted by changing that threshold here. The independent tests instead check the actual source coefficient quaternions and full-skin support. A source boundary can still need visual review; exact source pose agreement alone does not establish that the visible transition is desirable.

## Reproduction and limits

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_preview_dive_independent.gd
```

Node must be available on PATH, and the source repository must be present above the Godot project. JSON output includes the assertion count, errors, numerical tolerances, actual source hashes and production hashes. Production files are checked again at completion to reject an overlapping edit.

This fixture is not loaded-scene FPS, rendered camera acceptance, swimming, weapon IK, traversal, slope/step parity or complete browser gameplay. Supplied long-frame replay tests elapsed-time handling and real collision queries; it does not claim rendering at that frame rate. The continued-fall 0.1-second assertion is the `createSurfaceMotion.update` API bound; the browser's surrounding regular frame path applies an additional 0.04-second cap before calling that API. No whole-browser elapsed-time equivalence is inferred from the local API test. No benchmark timing includes the external reference process as gameplay cost, and this review adds no production runtime cost. **Производительность общей сцены этим тестом не проверяется.**
