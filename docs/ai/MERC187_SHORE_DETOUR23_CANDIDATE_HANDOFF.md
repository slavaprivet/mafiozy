# Merc187 shore detour — isolated candidate, 23 September 2026

**Candidate ready for coordinator review. Production unchanged; LIVE not run.**

The original cause and current-geometry baseline are in
`docs/ai/MERC187_NATIVE_ROUTE23_AUDIT.md`. The existing staged helper refuses
all five endpoints from the dry merc187 shore. This package is the subsequent
isolated experiment requested by Coordinator20, not an already integrated fix.

## Files and run

- `outputs/mercenary_shore_detour23_candidate.mjs`: independent proposed helper;
  no game module imports it.
- `outputs/test_mercenary_shore_detour23_candidate.mjs`: actual geometry and full
  production mercenary host, with only its imported long-follow factory replaced
  by this candidate. Production movement, source collision, roster, formation,
  and shared route deadline execute unchanged.
- `outputs/merc187_shore_candidate23.txt`: last complete result, **9/9 PASS**.
- `outputs/merc187_native_geometry23.mjs` and the two native geometry result
  files remain the baseline/current-static audit, not a candidate substitution.

Run `node --test outputs/test_mercenary_shore_detour23_candidate.mjs`.
All three investigation scripts pass `node --check`.

## Candidate behavior and bounds

The unchanged monotone stage helper runs first. After all five candidates fail,
the proposal builds a finite coarse dry-land corridor, then executes it through
the **unchanged production fine route planner** in separate legs.

- Coarse closed-node graph:4.1m spacing, at most2400 nodes. It finds which side
  of the lake to go around and cannot revisit its already discovered nodes.
- Its abstract edges check the supplied dry-body region predicate; outside the
  initial12m connector area, endpoint bodies also use authoritative `canMove`.
  The initial connector is only an abstract planning allowance. Every committed
  segment, including that connector, must pass the ordinary physical fine A*.
- Fine planner remains step0.65m/maxDistance48m/maxNodes2400. Candidate anchor
  selection uses≤24m straight distance; actual fine path length is independently
  checked. Last exact-shore run max committed leg32.704m, below48m.
- Each call expands≤8 nodes and receives≤0.75ms. Coarse searches suspend between
  edge queries. The host keeps its original rotating shared1.5ms deadline.
- At most32 committed stage endpoints are remembered across replans. Endpoints
  within3m of a visited stage are rejected, preventing repeated detour stages.
- At most8 temporary excluded points, expiring after5s: a teammate briefly
  standing in a narrow opening must not permanently label that opening blocked.
- After8 unsuccessful corridor replans, retry backs off2/4/8/16/30s. No repeated
  search occurs while time is unchanged. Goal changes>12m and explicit cancel
  clear the old corridor, fine path, exclusions and stage history.
- Within12m of the live goal, normal local following resumes, preventing an old
  corridor endpoint from trapping an NPC beside an already moved formation.

The abstract corridor is never itself a movement authorization. Every returned
movement waypoint comes from a physical fine route. `mercenary_world` then also
rechecks source sweep, crew spacing, native targets and local authority before
moving. No actor position is snapped; water thresholds and collisions are intact.

## Verified results

Exact LIVE start and destination for187:
x185.0676233678229/z113.97718677568092 → x161.5/z165.3.
Nearest woodland_crosswing_house actual GLB/entry, current native source body and
continuous sweep are used. All current generated static collision plans match
the checked fixture, as recorded by the baseline audit.

- Exact follower arrived through a304.169m physical street/shore route with no
  refused movement proposal in this run. Largest search1266 expanded nodes;
  no per-call expansion exceeded8.
- Full production host, five initial dry nearby followers:5/5 arrived after
  3240 nominal20FPS updates. Crew separation stayed≥1.1m.
- Moving leader:0.2m/s for20s, then held. Five followers arrived at each nominal
  FPS below; every final body remained dry, actual host movement steps stayed
  within their elapsed-time bounds, and search work remained≤8 per member/frame.

| Nominal FPS | Arrived | Simulated completion seconds | Host CPU p50/p95 ms |
|---|---|---|---|
| 7 | 5/5 | 213.29 | 1.588 / 2.085 |
| 15 | 5/5 | 154.93 | 0.970 / 1.846 |
| 60 | 5/5 | 119.35 | 0.284 / 1.650 |

These are Node host CPU figures, not GPU FPS or comparable live before/after
measurements. Low FPS naturally gives the finite route search fewer time slices
per simulated second. The route is a safe feasible route, not a shortest-route
claim. Completion times vary with actual CPU deadline scheduling.

Also verified:

- Cancel and large retarget while an actual-shore corridor is pending and while
  its fine path is committed: no stale waypoint survives.
- Closed U courtyard: body stays inside all four physical barriers; target never
  reports arrived. Three distinct stages only; repeated stage endpoints are
  refused. Max8 expansions/call, max search455,≤8 exclusions, delayed retries.
- Shared-deadline charged-query test: max charged native-path overhead0.480ms
  in the last run, below1.5ms plus the existing bounded query overrun; all five
  searches progressed. Actual CPU time also participates in the deadline.

Earlier greedy local-frontier and physical coarse-only experiments were rejected:
they either wandered back around a block or could not resolve the shore's narrow
initial connector. They were never integrated. The final candidate is the
dry corridor plus authoritative local physical route combination above.

## Proposed integration scope, after checkpoint/review

Only the staged-follow helper and its import/export/factory wiring should change.
The proposal adds a `regionAllows(worldPoint)` planning callback. In the source
host, bind it to existing native body water depth (the same centre+four corners
used by mercenary water egress), with finite native map bounds and native
resolver readiness. Do not replace it with a raw tile16 test: supported floors
and body depth belong to the existing native source contract. Missing native
region data must fail closed and preserve ordinary existing follow behavior.

The isolated test currently injects this callback from actual fixture water/body
sampling; it does not alter `mercenary_world.js`, `mercenary_core.mjs`,
`mercenary_long_follow.mjs`, `world.html`, or any browser state.

Coordinate the helper/export hunks with the long-follow owner. After authorized
integration, tests must import the resulting production helper directly, removing
the experimental factory override. Root then reloads the single existing game
and follows saved187 continuously around the actual shore to the hero, checking
movement reasons, dynamic cars/doors, appearance and frame timing.

## Remaining acceptance limits

No new GPU tab, browser interaction, backend/DB import, stage, commit or push was
performed. No LIVE or general-scene FPS claim is made. The inspection snapshot
does not reconstruct all dynamic cars/train, mutable fences, interior ceilings,
other buildings' live doors, or live source ownership. The source audit executes
Walk's actual static point predicates; the candidate host fixture uses native
static centre sampling plus actual source footprint/sweep, not the complete LIVE
player support/ceiling state. Local physical failure remains valid and must never
be bypassed if an omitted dynamic object blocks the planned route.
