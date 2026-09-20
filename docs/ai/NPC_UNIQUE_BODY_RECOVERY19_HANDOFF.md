# Unique NPC body placement recovery — 20 September 2026

Scoped changes: `world.html` unique placement gate and protected-state helper; `assets/maps/city_rebuild_v1/test_unique_placement_body19.mjs`. Empire planner, targets, HQ/site ownership and transport are unchanged.

## Reproduction

Actual geometry fixture at Leila's reported rounded position `(24.95, 23.49)` gives center depth `0.0045`, but both rear footprint corners have depth `0.6687`. The center-only unique recovery gate accepted this position. Native initial placement excludes unique/boss actors; water escape also checks center depth and does not start here. The body-safe finder itself was already correct.

The field-encounter hydration API can reproduce this invalid placement by assigning that raw anchor. This proves an admission path, **not** that the observed LIVE Leila arrived through that API. Legacy unique placement from this preferred position chooses `(25.5, 23.5)`, which is safe in the fixture.

## Repair

With a native resolver, existing unique placement recovery now checks the full footprint. Legacy mode retains its point predicate. The eligibility guard is captured before the existing unique-character state resets. Interior, vehicle, combat, custody, medical, conversation, stun and active server field-encounter ownership prevents correction. Ordinary empire travel orders remain intact.

Recovery reuses the existing safe-position finders, discards a stale route only on successful correction, limits native displacement to two source cells, and retries an unresolved placement at most once per two seconds. A valid actor is not moved. A server field encounter is deliberately excluded; correcting its anchor admission is separate work.

## Checks

- Actual source + geometry regression: Leila moves locally to `(25.5, 23.5)` with a dry footprint, preserving ID/order/target; the next 200 frames do not relocate her again.
- Marat `(75, 34.54)` is body-safe and retains position and route. His reported stall is not explained by this issue.
- Thirty protected states, long-distance refusal and retry throttle pass.
- Existing empire pending-slice, admission, generation and stall-recovery suites pass.
- One actual fixture repair measured 1.60 ms CPU. This is not a comparative whole-scene measurement; LIVE/FPS acceptance remains with the root task.

Separate read-only diagnostics: among 254 local valid-start/goal pairs around Leila, coarse empire BFS published five paths containing invalid physical edges. A VM-only directed-helper candidate found safe paths for all five; **no planner swap was applied**. For Marat, 21 of 32 sampled goals at radius 2.37 were body-safe and all 21 current routes advanced to arrival; exact LIVE destination is required to reproduce that stall.

Fixture limitations: actual static map collision snapshot, native water, one loaded building and compact sedan; excludes other runtime cars, streamed railway, rendering and whole-world update. No browser/GPU used by this subagent.
