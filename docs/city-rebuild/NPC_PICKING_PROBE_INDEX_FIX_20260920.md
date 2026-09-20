# NPC picking: preserve acceleration during profiling

## Evidence and scope

Artist19 reported normal120 healthSync mean 0.04 ms, playerHud 0.30 ms,
mercenaryUpdate mean 16.43 / p50 16.3 / p95 19.6 ms; picking last 15.9 ms.
The last value is one sample, not a rolling attribution. Render mean 78.15 ms
remains a separate cost. These observations do not establish NPC picking as
the sole cause of lag or a controlled whole-scene A/B.

The detailed profiler replaced Mesh.raycast. Both native terrain and building
triangle indexes require canonical Mesh.raycast and therefore switched to
their slow fallback in profiled samples. CPU reproduction on actual Three180:
normal queries=1/fallbacks=0; profiled queries=1/fallbacks=1; next normal
queries=2/fallbacks=1. This invalidates interpreting profiled indexed-mesh
costs as the normal accelerated production path.

## Fix

mercenary_picking_probe receives the installed THREE from mercenary_walk.
For a canonical Mesh.raycast with an own callable _computeIntersections,
instrument the installed narrowphase instead. Other methods use the existing
wrapper. Restore the exact property descriptor in finally; preserve deliberate
self-replacement and exception identity. No index implementation, target
algorithm, hover cadence, visibility, NPC behaviour or collision changed.

Report version 2 includes methodCalls and timingScope. Indexed mesh timings
are narrowphase-only; their bounding checks join traversal/sort/probe overhead
in the residual. This residual is NOT pure sorting time. Assisted LOS remains
inside resolveMs, not the centre-ray category totals. Detailed profiling is
still opt-in perfqa=1&mercenarypickqa=1 and has overhead.

## Validation

- Actual terrain AND building indexes retain accelerated queries with no new
  fallbacks during profiling; native and measured full hits match, including
  duplicate roots, face/instance/UV/point data and order.
- Exception restoration and deliberate self-replacement tested.
- test_mercenary_picking_probe, test_mercenary_targets, test_mercenary_walk PASS.
- Normal production profiling-off path remains disabled; no FPS gain claimed.

READY on disk after Artist19 checkpoint 7370157; not included in that snapshot.
LIVE reload/profile reading is coordinated by Artist19. No new GPU tab opened.

## Rejected optimization candidate

npc_pick_visibility and its standalone test are NOT imported by runtime and
default OFF. Nine parity cases pass, but synthetic timing difference is noise
(.382/.366 ms on one run, .324/.395 on another), and real custom callbacks
force fallback. Do not activate or count this as an optimization win.

## Follow-up: split assisted LOS after v2 LIVE

Artist19 sample28/rolling26: intersect p50/p95 11.4/21.1 ms;
resolve 13.3/33.5; exclusive 6.5/13.4; prepare 6.1/10.3;
restore 1.5/2.5; whole 34.8/59.7. One sample categories: cars
3.1 ms/8271 calls, NPC 0.8/1988, environment 1.2/728, terrain
narrowphase 0.2 ms/four calls. These are profiler-on numbers, not FPS gains.

Added QA-only assistScanned/assistLosQueries counts and assistLosMs nested
timing. No extra raycast; no wrappers around the LOS query, so index identity
guards remain intact. assistLosMs is included in resolveMs; never add both.
Normal and sampled near-miss selection have identical result and two total
queries (centre + LOS). Off-state adds no timer, and exceptions propagate.
Need one new sample to distinguish repeated LOS from one expensive LOS or
the candidate scan. Do not sort the live registry blindly: recognize may
append newly discovered targets while assistedPick iterates it.
