# Mercenary elapsed movement — ready for Coordinator 18

Task owner: `/root/mercenary_actions19`, handed off by Coordinator 17 to Coordinator 18 (`01a0bb23-8430-7262-b885-97bb496a2406`). Do not wake Artist 17; ordinary NPC motion belongs to Artist 18 separately. This change is limited to hired crew source movement.

## Change and safeguards

`mercenary_world.js` now measures elapsed movement time using the source document's monotonic `performance.now()`, independently of the already-clamped incoming world `dt`. Source-owned crew movement executes at most six substeps of at most 0.05 seconds each. Each substep still uses the existing source body/path sweep, native rendered collision predicate, crew avoidance and route waypoint checks. No teleport, new damage path, collision-radius reduction or global/NPC clock replacement.

- Maximum movement time accepted per update: 0.3 s. Excess time is discarded rather than replayed as a backlog.
- A gap above 0.75 s or a hidden document advances no crew movement; visibility changes reset the monotonic sample. The first update after reset accepts only a bounded incoming frame up to 0.05 s.
- Public `MafioziMercenaries.resetMovementClock()` permits an explicit pause/menu owner to reset the movement clock. No global menu hook was changed here.
- Action/fuse/hospital timers remain under their existing wall-time authority. The total approach timeout remains 40 seconds. Source-owned follow, rally, return, specialist approach/retreat and distant focused approach use the bounded substeps. The separate legacy `_updateGang` combat movement loop is unchanged.
- Existing formation heading smoothing is retained; it is not multiplied once per member/substep.
- QA `getMember(id).movement.clock` reports elapsed/used/dropped time, paused state and actual member substep count. No backlog is carried between frames.

## Verification

New `test_mercenary_elapsed.mjs` uses the actual source adapter, real core, and extracted `_npcBodyPassable` / `_npcPathPassable` from `world.html`, with the same continuous vehicle collision fixture as the existing route tests. The previous movement clamp is reproduced for comparison: 5 FPS yields **0.75 m in one second**. New movement yields **3 m** standing, **1.5 m** crouched and **0.65 m** prone at **5, 10, 30 and 60 FPS**, despite the clamped incoming dt.

Same 1.28 m half-width vehicle, start on the opposite side, physical route to authored plant anchor, four-second planting and six-second fuse:

| Simulated FPS | Working starts | Charge armed | Explosion | Maximum substeps/frame |
|---|---:|---:|---:|---:|
| 5 | 8.20 s | 12.20 s | 18.20 s | 4 |
| 10 | 6.20 s | 10.20 s | 16.20 s | 2 |
| 30 | 5.07 s | 9.10 s | 15.13 s | 1 |
| 60 | 4.78 s | 8.80 s | 14.82 s | 1 |

Every scenario explodes exactly once only after the live operator reaches at least 8 m from the car centre. Bounded route planning still requires more wall time at low frame cadence; it is not an unbounded path-search burst. Hidden-document, 20-second pause, explicit reset and discarded 0.6-second backlog tests all pass without catch-up teleportation.

Latest seven-file regression run: **119/119 PASS**. New elapsed suite **3/3 PASS**. A prior cancellation test used a one-second time jump as if it were a normal movement frame; that assertion now advances one ordinary 0.05-second frame, while the new pause test explicitly verifies long-gap behavior.

CPU-only source fixture p50/p95 per update (same car scenario; no GPU): 5 FPS **0.1268/0.6126 ms**, 10 FPS **0.0841/0.3204 ms**, 30 FPS **0.0729/0.1660 ms**, 60 FPS **0.0689/0.1133 ms**. These are fixture timings, not whole-game FPS or LIVE acceptance.

## Remaining coordinator checks

1. Load current source once and retry real-game demolition, with Coordinator 17's corrected target width/profile wiring. Verify plant, safe retreat and one visible explosion. This subagent did not use the browser.
2. Safe opening and money collection were confirmed by the user. Separate post-opening safecracker movement showed `no_route`, expanded 1 / checks 4; investigate open door leaf versus the operator's 0.738 m footprint. Coordinator 17 had not changed the proposed hinge-safe approach offset at handoff.
3. Existing LOS callback/60 m assignment and vehicle anchor changes belong to the root target/walk files; source changes here preserve those interfaces.

Prior mechanics and route context: `MERCENARY_CREW_ROUTES_20260919.md`, `MERCENARY_CONTEXT_X_SOURCE_20260919.md`, `MERCENARY_FOCUS_CONTACT_20260919.md`.
