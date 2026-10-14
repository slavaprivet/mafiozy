# Guard waiting / two-leg detour — PAUSED, NOT READY

23 September 2026, Художник21. Root explicitly paused this work for the urgent
bruiser surface cache exception. Do not import, apply or include in the current
production release.

Inputs: the six rejected occupied scenarios from the verified exterior producer,
saved in `assets/maps/city_rebuild_v1/test_fixtures/native_guard_crowded23.json`.
These are controlled actual-geometry fixture records, not live NPC captures.
Each has actual instance ID, actor start, entry approach and two stationary guard
body points. Four hospital and two print-shop cases.

Unfinished files:

- `npc_guard_wait_detour23_candidate.mjs`
- `test_npc_guard_wait_detour23.mjs`
- `outputs/npc_guard_wait_detour23_candidate.json`

Prototype sequence: direct post → wait 1500 ms → one direct retry → at most 12
bend candidates. Uses the same admission supplied by caller, 96 callbacks/slice,
4096/job, cooperative 2 ms. Planned lifecycle fields: owner/revision/generation,
30-second whole-job deadline and a 12-second post reservation. Actual actor
movement remains source `_npcAdvanceRoute` without modifying the guard kind.

Two-leg design intentionally exposes separate single-leg commands. First is a
**staging point**, never gameplay post arrival. Once source physically arrives
within .34 cell of that point, validate the second leg from the ACTUAL position
and only then issue the post leg. This avoids pretending an intermediate corner
is reached exactly; it does not snap the guard or loosen a collision predicate.

First actual-geometry result: **0/6 arrivals, 6 finite rejections**, no movement,
0 wall/interior crossing. Four `no-safe-two-leg-post`, two `query-budget-exhausted`.
Total CPU 173.84 ms, largest cooperative slice 2.93 ms; not FPS. The test currently
checks bounds/safety/waiting and writes this negative result, so exit code zero
does NOT mean the detour objective passed.

Next work when root resumes:

1. Add explicit reservation expiry/cancel/owner revision tests, unchanged-scene
   query-free waiting, expired reservation versus STILL PRESENT physical body.
2. Investigate why bend→post search still cannot connect. The approach→post check
   currently includes other guard bodies, which may overconstrain static site
   connectivity; do not weaken current-actor sweeps or exterior proof to gain PASS.
3. If a valid short detour exists, demonstrate each source physical movement
   step and second-leg revalidation. Preserve explicit BLOCKED for fully occupied
   corridors; do not claim all crowded configurations are solvable.
4. Compare bounded cost against the failed retry case, then hand off separately.

No runtime work, authority/capture/HQ writes, telemetry claims or GPU tabs.
