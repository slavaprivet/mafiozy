# Exterior guard posts — isolated candidate, 23 September 2026

Status: **CPU geometry verified, NOT APPLIED / not LIVE accepted.**
Owner: Художник21. Root: Координатор20. No production, authority, HQ, capture,
server or browser changes. This does not enable native routing for every empire kind.

## Problem and result

Existing `_empireHoldingGuardPost` selects a body-clear point around an anchor;
that does not prove a connected exterior path from the actual guard. The earlier
hospital negative is retained in `NPC_GUARD_POSTS23_REJECTION.md`.

The isolated producer consumes the **existing native entry approach**, existing
site identity and trusted owner/revision. It tests a direct, full-body exterior
path from the actor AND from the approach to each candidate. It returns a target
and a one-segment path, never an `arrived` result and never a partial path.

Actual GLB tests, closed doors, scale 4.1, full city static collision snapshot:

| Scenario | Source baseline | Candidate |
| --- | ---: | ---: |
| Three buildings × three slots × four turns | 23/36 real arrivals | 36/36 real arrivals |
| Route function says arrived | 31/36 | 36/36 |
| Unsafe movement steps | 2 | 0 |
| Interior steps | 3 | 0 |
| Added stationary guard bodies and occupied posts | Not compared | 30/36 arrivals, 6 explicit BLOCKED |

The six occupied-scenario failures are four hospital and two print-shop moves.
They return `no-connected-exterior-post`; no position change, assigned substitute
arrival or collision relaxation occurs. Thus this is NOT a complete crowd/patrol
solution. A narrow entrance can require waiting or a separate collision-safe
local detour supplied by the root integration. Do not immediately retry a failed
job every frame; wait for meaningful occupancy/geometry change or a bounded retry
interval, retaining the current valid guard position.

Buildings used: `REBUILD-VISUAL-hospital-001`,
`REBUILD-VISUAL-print_shop-001`, `REBUILD-VISUAL-bookmaker-001`.
Identity and approach are read from the real `createNativeSiteCatalog` contract.
Owner is explicitly synthetic **already-owned fixture input**, not a claim of
captured buildings in the actual game. No capture action is executed.

## Files and reproduction

- `npc_exterior_guard_post23_candidate.mjs` — isolated module, no runtime import.
- `test_npc_exterior_guard_post23.mjs` — 33 contract/budget/cancellation cases,
  36 actual-geometry matched comparisons, 36 occupied-post attempts.
- `outputs/npc_exterior_guard_post23_candidate.json` — all inputs, outputs,
  physical distances, collision checks, slice costs and limitations.

Run: `node test_npc_exterior_guard_post23.mjs`.

The source baseline uses the actual `_empireHoldingGuardPost` and actual coarse
guard planner with radius .7 / 9000 visits. Both variants receive identical
starting positions and the same native entry approach as anchor. Different goal
selection is the change under test. Baseline/candidate order alternates. Source
movement `_npcAdvanceRoute` is used verbatim for both; every physical step is
checked by native radius-.18 sweep and the existing full source path predicate.
Success requires actual remaining distance <.75 cell, not merely route termination.
No teleport; maximum step is speed × dt.

## Contract and bounded work

`beginExteriorGuardPost23(actor, site, slot, step)` snapshots:

- actor `id`, `siteId`, `ownerFactionId`, nonnegative integer `generation`, r/c;
- site `siteId`, `instanceId`, `ownerFactionId`, nonnegative integer `revision`,
  nonempty `manifestRevision`, `loaded:true`, finite `approach:{r,c}`;
- slot 0–2 and nonnegative integer patrol step.

`stepExteriorGuardPost23(job, ctx)` consumes current actor/site plus:

- `admitted:true`, `budgetMs` and monotonic `now()` from the existing shared
  scheduler. **The caller must own the budget and permit at most one slice for
  this job per frame.** This module creates no queue/admission of its own.
- `bodyClear(point)`, `exterior(point)`, `sweepClear(from,to)` from actual native
  geometry. Preserve water, supported ground, static and current dynamic bodies.
  Test exterior uses the actual building's `containsInterior` at supported feet
  for center plus all four body corners. It is not a polygon-only assertion.
- Later isolated detour extension may supply `siteBodyClear` / `siteSweepClear`
  for the **approach connectivity proof only**: full static building, water and
  ground checks without transient guard occupancy. Actor path, target and final
  movement checks still use the full dynamic callbacks. If omitted, existing
  stricter callback behavior is unchanged; the reported baseline tests omit them.
- Optional bounded `occupied` array of at most 64 local points/actor IDs. The
  array filters target spacing; body/sweep callbacks must include other guards
  if physical crowd avoidance is required. Test occupied scenario supplies full
  radius-.18 stationary guard circles to BOTH point and swept-path checks.

Limits: 36 candidate points (12 angles × radii 3.2/3.85, 2, 1.1 cells),
96 geometry callbacks per slice, 4096 per job, cooperative deadline
`min(2ms, caller budget)`. Samples are no more than .14 cell apart. Job resumes
the exact stage/sample across slices; bounded candidate/occupancy scans cannot
grow with total world population. A single callback cannot be interrupted.

Any owner, instance, site, manifest, generation, approach or actor-position
change cancels; death, combat, vehicle or interior state cancels too. Actor farther
than 8 cells from the approach returns `rejoin-approach-required`; this helper does
not teleport or solve the initial journey. Bad geometry/start/approach, exceptions,
exhausted budgets or no connected post fail explicitly.

After READY, consume promptly; this is a plan for a sampled scene, not a standing
reservation or arrival fact. Revalidate root authority when installing the route
and on patrol updates. Normal movement must retain collision checks and restart
selection after dynamic blockage. READY is cached if the same job is read again;
it does not re-scan a changed crowd on repeated reads. Only physical final arrival
may advance the gameplay patrol step. No production adapter is supplied here.

## Cost and limits of evidence

Recorded matched CPU run (36 requests, alternating order, same geometry/starts):

| Cost | Source | Candidate |
| --- | ---: | ---: |
| Job p50 | 1.105 ms | 1.821 ms |
| Job p95 | 112.105 ms | 5.746 ms |
| Job maximum | 114.728 ms | 6.185 ms |
| Sum | 739.344 ms | 85.724 ms |
| Largest slice | 4.816 ms | 2.196 ms |

Candidate used 5895 geometry callbacks overall; longest individual callback
0.565 ms. Median is higher because the candidate checks the full exterior path;
tail and total work are lower by avoiding impossible coarse searches. These are
process-local timings, not stable FPS estimates or a universal speed guarantee.
An earlier instrumented run saw a 4.960 ms slice despite a 2 ms deadline: timing
is cooperative and cannot guarantee a hard wall-clock ceiling under callback/GC
pauses. Query counts are hard bounded and independently tested with a frozen clock.

**Производительность общей сцены не проверена.** No renderer, full city update,
moving traffic/crowd, draw calls or triangles measured. Root retains the only
game/GPU window and decides integration and common LIVE measurement.

## Integration boundary for coordinator

Root's native authority adapter must supply current site ownership and the
actual approach, select eligible exterior guards, grant scheduler slices, install
only READY paths and retain physical arrival checks. Keep the actor at its valid
post when BLOCKED. No claim that all captured building exteriors support three
moving guards, no fake route fallback, no automatic broad native-kind enablement.
This candidate awaits review and a separately scoped adapter/queue integration.
