# Pedestrian hot-allocation audit — 23 September 2026

Scope is the pure surface, player-route and retryable NPC-edge packages. This
audit and benchmark are unimported. Runtime hashes remain frozen.

## Current hot allocations

`pedestrian_surface_passability.mjs` allocates work/meta/options/context,
previous/next/state and result objects for every route, plus five query closures.
Every probe allocates a `to` state object for `walkable`. A blocked route may
also allocate traversal callbacks and a plan. These objects are short-lived but
scale with player frames and NPC chunks.

`pedestrian_player_route_adapter.mjs` allocates direction/options/target,
accepted-position copies and the public result per input. It sanitizes animation
with `Object.entries` + `Object.fromEntries`. Axis slide adds intermediate route
results. Its metadata latch is stateful, so one shared output object would be
incorrect under nested calls.

`pedestrian_surface_integration_contract.mjs` uses `JSON.stringify` for each
uncached NPC key and spreads route/request objects into cached values. The Map
is reused per frame, but its strings and rows are not.

`npc_pedestrian_edge_probe.mjs` computes the request signature with
`JSON.stringify` on every retry and again when issuing a pending token. Each
chunk allocates request/target/cursor/result and each pending frame allocates a
new nested retry token. Retry state must outlive the call, so blindly pooling
that public object would corrupt concurrent NPC routes.

## Frozen baseline after warmup

Run with Node 26.1.0 and exposed GC. Timing is uninstrumented; builtin calls are
counted in a separate pass with the same operation count. The reproducible raw
report is `outputs/pedestrian_hot_allocations23.json`.

- Surface scramble: 100,000 routes, batches of 1,000; p50 0.488 ms and p95
  0.812 ms per batch (0.488/0.812 microseconds per route). Peak heap delta was
  1,094,688 bytes. No measured stringify/entries/fromEntries calls.
- Full player adapter: 100,000 routes, batches of 1,000; p50 1.973 ms and p95
  2.257 ms per batch (1.973/2.257 microseconds per route). Peak heap delta was
  2,025,664 bytes. Exactly one `Object.entries` and one `Object.fromEntries`
  per route.
- Retryable flat NPC edge 32.8 m: 600 complete edge applications, batches of
  10; p50 2.114 ms and p95 2.692 ms per batch (0.211/0.269 ms per complete
  edge). Peak heap delta was 2,179,272 bytes. There were 35,400 stringifies,
  exactly 59 per complete edge.

Forced-GC retained deltas were -6,128, +14,656, and -11,720 bytes respectively;
their sign and small size show no retained-growth signal in this run, but do not
prove absence of short-lived allocation.

## Candidate design

1. Add an optional caller-owned `out` to surface route and player adapter.
   Keep existing allocating calls for compatibility. The host owns one output
   per actor. Clear scalar fields manually; pre-create nested `position`,
   `work`, `verticalTransition`, `edge`, and animation objects.
2. Give each factory a scratch stack indexed by call depth. Allocate a new slot
   only when a previously unseen recursion depth occurs, then reuse it. A single
   global scratch object is rejected because `canOccupy`, `sample`, or a test
   resolver may re-enter the same motion instance.
3. Store work/options/context and both axis targets in each scratch slot. Replace
   per-probe closures and `{from,to,surface,...}` literals with mutable scratch
   records. Add a context-aware traversal entry point so clear routes never
   create traversal closures; traversal plans may allocate because they persist.
4. Replace adapter `Object.entries/fromEntries` with explicit scalar copies.
   Never expose scratch references. `traversal` and retry state remain either
   caller-owned or newly allocated persistent records.
5. Replace consumer string keys with a fixed-capacity open-addressed numeric
   cache. Store exact scalar fields alongside a 64-bit hash so collisions are
   compared, not trusted. Distinguish `-0`, non-finite values, storey Y, height,
   swimming and canonical vehicle ID. Clear epochs instead of clearing rows.
6. Replace edge JSON signatures with a primitive route handle backed by a
   bounded registry. The registry owns exact from/to/Y/height/swim/vehicle
   fields and cursor/work/chunk state. Generation counters reject stale handles.
   Eviction returns explicit retry cancellation; it never means clear/block.
7. Preserve the hard work reservation before every chunk. Admission keeps
   `withTraversal:false`. Persistent NPC traversal belongs to a separate
   executor and budget.

## Correctness and rollout gate

- Zero new objects after warmup for clear single-axis surface/player calls when
  caller supplies `out`; bounded one persistent allocation for an actual
  traversal or newly admitted retry route.
- No `JSON.stringify`, `Object.entries`, or `Object.fromEntries` in the measured
  player/NPC loops.
- Re-entrant depth-two route produces independent positions/work/metadata and
  leaves the outer result unchanged. Depth slots may grow only to the observed
  maximum and must not alias.
- Two simultaneous NPC tokens with identical X/Z but different Y, height,
  swimming or ignored vehicle never share state. Stale generation fails closed.
- 32.8 m edge retains exact 60 chunks, monotonic cursor, hard work cap and final
  result parity. Pending is never interpreted as clear or permanent block.
- Existing curb, ridge, free-fall, wall, car, water, ladder and 3–144 Hz pose
  suites remain green. One-tab LIVE p50/p95 uses the existing acceptance matrix.
- Candidate CPU p95 must not exceed frozen baseline by 3%; retained heap after
  forced GC must be flat across doubled operation count. Report peak heap as a
  churn signal, not proof of allocation count.

Production files affected by a future approved slot:

- `pedestrian_surface_passability.mjs`: highest correctness risk; output/scratch
  aliasing could corrupt a nested collision query or persistent fall metadata.
- `pedestrian_player_route_adapter.mjs`: medium risk; metadata latch and one-shot
  traversal ownership must remain per player.
- `pedestrian_surface_integration_contract.mjs`: high NPC correctness risk;
  numeric cache equality and epoch rollover require adversarial tests.
- `npc_pedestrian_edge_probe.mjs`: high retry risk; registry generation,
  cancellation and capacity pressure must fail closed.
- `hero_traversal.mjs` only if a context-aware non-closure planner is approved;
  otherwise keep rare blocked/traversal allocations outside the clear hot path.
