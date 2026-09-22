# Local patrol fallback — 20 September 2026

Scope: `world.html` local-work marker, confirmed EMPTY hook and `_empireLocalPatrolFallback`; `assets/maps/city_rebuild_v1/test_empire_local_patrol_fallback19.mjs`. No Git operations performed; this patch follows the parent's already-staged checkpoint.

## Proven failure

Actual hospital geometry: patrol actor `(7,164)`, style 7, previous work step 7. `_empireBossWorkWaypoint` chooses `(10.198526098792687,164.09711228213794)` at step 8. The endpoint footprint is valid, but the approach crosses a closed entrance. Native routing correctly returns EMPTY. Actual boss update and queue pump over 180 simulated seconds repeat the same goal 45 times and never move. Local work selection previously only advanced after arrival.

## Change

Only a waypoint explicitly selected by the local-work branch of a `patrol` action is eligible. Its marker records generation, action key, target and unchanged base. After a completed EMPTY (never a pending slice), all marker/request/current values must still match. Initial or distant patrol, raid, HQ, business and escort goals are not retargeted. Combat, active field encounter, conversations, vehicle/interior, custody, medical and stun ownership veto recovery.

At most 12 candidate points are examined, all within 3.2 source cells of the existing patrol base. Candidates must be sufficiently separated from the failed goal and actor, have full footprint clearance along the entire direct approach, and pass continuous solid sweep. The actor is not moved; the new target is traversed by normal routing next tick. Action, base, generation and identity remain unchanged. If no alternative is found, the normal retry backoff remains.

Fallback uses the unspent portion of the already-admitted four-millisecond route budget, capped at two milliseconds. Its elapsed work is added to the shared budget. Candidate cursor advances when the bounded check is interrupted. If the admitted search consumed the whole budget, no additional fallback work occurs; the unchanged backoff governs another attempt.

## Verification

Run `node assets/maps/city_rebuild_v1/test_empire_local_patrol_fallback19.mjs`.

- Actual source/geometry 180-second repro: 45 EMPTY and stationary before; 2 EMPTY / 2 successful local fallback selections after, with actual arrival at the replacement and continued work.
- First replacement `(8.699216989983615,164.05159089988578)`, within the original patrol area. Zero displacement inside planning/fallback.
- 34 protected-state cases plus initial/distant patrol, raid/HQ/business/escort, stale generation/action/goal/base reject retargeting.
- Maximum candidate count, full sweep veto, unchanged failure backoff and exhausted shared budget checked.
- Two observed fallback calls cost 0.61 and 0.68 ms CPU in the fixture.
- Existing empire pending-slice/admission/generation/stall suites pass; the prior 64-pair native route test still reaches all 64 destinations with zero unsafe paths or blocked movement.

This intentionally does not repair an unreachable initial patrol destination. Existing LIVE work targets lacking the new local-work marker are not guessed to be safe to replace. Root owns reload and visual verification. GPU, whole-scene performance and FPS were not checked by this subagent; the checked-in compact physical fixture excludes other runtime traffic and streamed geometry.
