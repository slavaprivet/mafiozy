# Transport3 — first lane rejection history, candidate only

23 September 2026. **CANDIDATE TESTED; NOT APPLIED / NOT LOADED.**
Coordinator20 explicitly froze runtime until the next published root SHA.
No shared runtime file was changed by this task and no GPU tab was opened.

## Purpose and semantics

The source planner currently overwrites its lane result with road-target/fallback
trace in the same call. A later snapshot cannot reconstruct why car17's original
directed lane route was rejected. This candidate saves the first rejection
that actually ends the lane attempt, independently of current trace and actors.

History is opt-in only for exact `npcqa=1` or `npctransportqa=1` in this page or
its accessible parent URL. `perfqa`, `npccombatqa`, and the manual trip-debug
boolean alone do not enable it. With QA off there is no history buffer/WeakMap,
no dataset write, and no diagnostic flag in the navigation request.

The ring retains at most16 records, oldest first. A separate WeakMap keyed by
the planning job remembers its last captured lane request ID. Repeated polls
do not overwrite the first record. No field is written onto the NPC, car,
trip, planning job or worker cache for this deduplication.

`route_queue_full`, `route_worker_uninitialized`, `async_routing_unavailable`
are still waiting responses during the producer's existing30s admission
window. They are not recorded prematurely: otherwise a transient queue reply
could hide the subsequent real lane rejection. If the existing30s limit is
reached and the producer ends the lane attempt, that reason is recorded.
This reads the same already-computed `now` and `job.createdAt`; it changes
neither that time limit nor the producer's decisions.

Each record contains:

- source `carId`, source-to-presentation `npcId`, original lane `requestId`;
- `sourceClockMs` at the refusal, `status` and `reason`;
- exact source `from` pose; destination `to` r/c, optional angle, id/buildingId;
- `allowedLotIds` copied from the actual outgoing target, if supplied;
- `shape` with the validated halfLength/halfWidth, collisionPadding, optional
  collisionHull; dimensions explicitly in metres. Absent/invalid profile stays
  null rather than inventing a model or performing a second lookup.

## Exact profile without additional geometry or gameplay work

The source asks its existing navigation call for QA shape metadata. The
navigation wrapper has already obtained and validated the profile for that
call, so it copies that profile on blocked results only. The diagnostic flag
is removed **before** calling the real worker cache: request fields/signature,
queue admission, worker messages, results and gameplay counters remain equal.
If a profile changes, the existing worker signature rules still apply.

History is written to
`document.documentElement.dataset.civilianLaneRejections` only on a new event,
before the existing `_civilianTripPlanTrace` can be overwritten. The regular
JSON download receives an additive `civilianLaneRejections` field. The existing
inspection panel is also available under npctransportqa, so either allowed QA
mode can download the record. No non-QA gameplay UI is added.

Candidate target scope (not yet edited on disk):

1. `civilian_parking_trip_source.js`: separate QA buffer/recorder and the
   existing `_civilianTripNativePlan` lane-call site.
2. `world.html`: the exact same CIVILIAN_PARKING_TRIP block only.
3. `city_road_navigation.mjs`: reuse validated profile; strip diagnostic flag
   before the existing async query and return metadata on blocked replies.
4. `npc_inspection_export.mjs`: optional JSON field.
5. `npc_runtime_inspection.mjs`: read that dataset on download and allow the
   npctransportqa flag for the existing inspection panel.

No changes to worker implementation, routing, budgets, collision callbacks,
movement, visual models, doors, gameplay counters or actor state.

## Tests and cost

`test_transport_lane_qa23_candidate.mjs`: **18 checks PASS**. It applies text
transforms only in VM/data-module memory against actual current files:

- strict off modes and both on flags, including parent URL;
- pending/ready do not create a rejection; temporary admission replies do not
  hide the first actual refusal; a real30s producer timeout is retained;
- first lane refusal survives actual producer trace overwrite by fallback;
- bounded16 history after23 requests; independent copies survive mutation of
  later profile/target objects; missing invalid shape remains null;
- same worker request payloads/profile reads and same source car/NPC/job data
  as baseline; geometry callbacks are armed to throw, and receive **0 calls**;
- actual `createLaneRouteJobs` roundtrip: one posted request across repeated
  QA polls, frozen worker rejection, exact sent profile in the recorded row;
- actual inspection click handler → Blob/download JSON → parse preserves
  all16 records, including exact hull and first refusal;
- candidate world/helper block parity.

Burst cost (20 batches ×100 fresh rejected producer requests, ring already
bounded16; controlled worker replies): CPU p50/p95 before
**0.015246/0.019215 ms**, QA enabled **0.045493/0.058715 ms** per request.
This intentionally stresses serialization of a full ring for every new
rejection; ordinary repeated polls do not rewrite it. No full-scene/FPS claim.

## Review package and freeze

- `assets/maps/city_rebuild_v1/transport_lane_qa23_candidate.mjs`:
  guarded, single-anchor transforms; not imported by runtime.
- `assets/maps/city_rebuild_v1/test_transport_lane_qa23_candidate.mjs`:
  actual producer/cache/export verification.
- `assets/maps/city_rebuild_v1/emit_transport_lane_qa23_candidate.mjs`:
  emits patch/manifest only, has no apply mode.
- `outputs/transport_lane_qa23_candidate.patch`: reviewable five-file patch.
- `outputs/transport_lane_qa23_candidate_manifest.json`: normalized SHA256 of
  each before/after file; generated against HEAD
  `31f8ea6c6e52c44e1c545b1fecef843355415c94` plus current shared WIP.
- `outputs/transport_lane_qa23_candidate_results.json`: machine-readable result.

`git apply --check` passes. An initial emitter run exposed Windows stdout
CRLF conversion in patch output; the emitter now writes normalized LF and
the unchanged candidate applies cleanly in a dry run. No apply was performed.

**Wait for coordinator20's new root SHA.** Then verify manifest/anchors against
that published state, regenerate the candidate if necessary, rerun the same
tests and patch dry run, and have the owner apply only these scoped hunks.
The patch does not include unrelated current world changes.

Once integrated and reloaded in the single game, record car17 (or another
actually rejected lane) and use the existing download. Correlate request ID,
source clock, exact profile and allowed lot IDs with the later fallback.
These records diagnose one lane request, not counts of unique residents or
proof that a whole trip failed. **Производительность общей сцены не проверена.**
