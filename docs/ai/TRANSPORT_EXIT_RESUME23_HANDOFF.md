# Transport3 — resume an interrupted authored parking exit

23 September 2026. IMPLEMENTED / CPU geometry TESTED; LIVE not yet verified.
Second patch after `TRANSPORT_PARKING_LEASE23_HANDOFF.md`.

## Actual recorded failure

Coordinator20 exported read-only DOM diagnostics from the single game at
2026-09-22T22:17:34.049Z into
`.git/ai-pipeline-local/live23/transport-before23.json`.
Vehicle `local_vehicle_18`, resident88, was offered another trip from
r14.776657476657771 / c153.6783536585366 / angle3.60913887831611.
Recorded half-length/width: 2.449160099 / 1.100929990 metres.

On the static actual-city geometry this pose is clear and is exactly point22
of `parking:REBUILD-VISUAL-garden_lane_house_v1-001:exit:1`, a reverse exit.
Before this patch `parking-exit` rejected this exact pose as
`parking_exit_unavailable`: the resolver tried to join the current pose back
to the beginning of the exit. Its generic connector cannot do that manoeuvre.

The diagnostic `startBlocked: off-road` is not itself a definitive refusal:
the unchanged fallback native search finds 62 points after 875 expansions
on the static geometry. Its start diagnostic remains off-road even when ready.
The preceding LIVE lane job and all dynamic actors were not in the export.
This patch fixes the reproduced parking-origin refusal, not every possible
cause of the recorded route failures.

## Change

Only `city_parking_origin.mjs` runtime code changed (16 added lines).
For parallel reverse exits, find the current pose on an existing authored
segment, requiring both position and interpolated body yaw within 1e-7.
Continue the remaining suffix from the exact current pose. Every point and
intermediate full hull is revalidated by the existing `clearPath` and paved
support checks. Gear remains reverse; accessRouteId, endpoint and therefore
existing external-path control registration stay associated with that exit.
Other positions fall through to the existing planner; no snapping or teleport.
No search budget, source pose, road graph, vehicle ownership or render change.

The observed point now returns 43 remaining points. Regression covers the
beginning (65 points), exact middle, a 0.37 interpolation between samples,
last interior segment (35 points), and the finished road endpoint. A new solid
barrier blocks the suffix; mismatched yaw and an unrelated lateral position
cannot attach to the path.

## Verification and cost

`test_parking_exit_resume23.mjs` first failed on the exact recorded pose before
the patch and passes afterward. It uses actual static map/solids and the
recorded hull, independently sweeps at 4 cm, and checks reverse heading.
Seven existing `test_city_parking_origin.mjs` cases pass, including thin
barriers and profile validation. `test_city_parking_occupied_departures.mjs`
passes all compact-car bays and 20 occupied-neighbour scenarios. Syntax and
scoped diff whitespace pass.

40 warm samples of the newly supported midpoint: p50/p95 **1.2052/1.9291 ms**.
Previously the same call rejected early in **0.0372/0.0842 ms**; it did not
validate a usable exit. Cold supported call: **7.4183 ms**. Cost is route
preparation/initial admission, not per driving frame. Normal lane planning
performs this geometry in the existing worker.
Comparable successful full-bay departure, alternating before/after 40 times:
CPU p50/p95 **1.0373/1.7289 → 0.9904/1.5088 ms**. These are local geometry
measurements, not loaded-city FPS. No clearance cache was introduced.

Audit: `assets/maps/city_rebuild_v1/audit_transport_offroad23.mjs`, result
`outputs/transport_offroad23_audit.json`; regression results
`outputs/parking_exit_resume23.json`. Audit after-patch route to the recorded
fallback road target now reaches the next validation stage and reports
`destination_has_no_safe_directed_lane`; that arbitrary fallback target is
not the missing original lane destination. Do not report this as a ready lane
journey to the user's actual destination.

Before module retained at
`.git/ai-pipeline-local/live23/city-parking-origin-before23.mjs`.
`test_parking_exit_resume23.mjs --baseline=<that path>` runs comparison without
changing production. The actual lifecycle harness adds optional
`--resume-exit23 --async`, starting the source car from the recorded interrupted
pose without initial admission/relocation; regular modes retain their behavior.

## Remaining LIVE acceptance

Final actual-source async-worker lifecycle from the recorded interrupted pose
**PASS**, `test_native_parking_lifecycle.mjs --resume-exit23 --async`:
**287.335914 m**, 4,428 simulation frames, 14 boarding / 12 exiting frames,
all phases planning → approach → board → drive → parked → exit → walk_to_shop
→ entering → browsing → exiting → walk_to_bench. Same source identities;
every moved edge swept. Per-update fixture CPU p50/p95 **0.0661/0.2112 ms**.
Regular 248.413 m lifecycle also passed after this second patch.

The first attempt of this new harness omitted `_nativeParkingShape` while
bypassing initial admission, so the source's conservative fallback rejected
all destination bays before requesting a lane. The harness now retains actual
model dimensions just as an already-presented admitted car does; no runtime
size/parking rule was relaxed to make the test pass. It also fails immediately
if the new recorded-origin trip is released before driving.

Both patches are READY for coordinator20's shared reload; no other runtime
edits are pending in Transport3.

Coordinator20 owns the only game and batches reload with other authors. After
reload, observe a driver resume a stopped reverse exit, reach its destination,
park, leave and return to an activity. Preserve source IDs; if an obstacle is
still present the car must wait. New GPU tabs were not opened.

**Производительность общей сцены не проверена.** Do not call the living city
or all off-road failures fixed based on these CPU tests.
