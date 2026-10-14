# Incremental blast parts 20 — historical stages and current runtime

**Latest stage:** [preparation and latency reduction](NPC_BLAST_PARTS20_PREPARE.md) supersedes the per-death step counts and clone-cache limitation below; [ground integration](NPC_BLAST_PARTS20_GROUND_INTEGRATION.md) adds optional height support. The ledger contract below was corrected after 19's review: TTL maps and retryable capacity replace the former lifetime counter. Other measurements record the first incremental stage.

CURRENT UPDATE: imported by Walk through NPC_BLAST_RUNTIME20_HANDOFF.md. Default vertex cap is now2048 under the unchanged1.25ms soft time and2048work budget; old256 measurements below are historical. Actual7/15/60Hz full-chain regression passes;7Hz cold ready4.0–4.43s still needs faster presentation.

2026-09-20. Owner: Coordinator20 subagent. Production world/blood/actor/runtime untouched. This supersedes the synchronous prototype API and performance section in `NPC_BLAST_PARTS20_AUDIT.md`.

## Implemented

`assets/maps/city_rebuild_v1/npc_blast_parts_prototype20.mjs` now queues bake jobs. `admit({actor,receipt,now})` returns `{ok:true,ticket}` with `ticket.status === 'pending'`. It copies current world/bind/bone-inverse/bone-world matrices and morph influences once, clones material/texture handles, and leases immutable geometry CPU buffers. Three's actual skin/morph implementation runs later against a detached receiver containing these snapshots. No source skeleton, actor transform, HP/dead state or corpse visibility is changed.

`update(now)` works under **1.25 ms soft budget**, at most **256 skinned source vertices** and **2048 work units** per call. Triangle classification, vertex baking, remapping, normals and centering all yield; non-skin vertex/triangle operations are bounded by work units and time. The budget cannot preempt an allocation, GC, OS scheduling or a single Three operation; this is not a hard realtime guarantee. A ready result adds the complete group atomically and returns its ticket once in the array from that update. There is no visible partial group.

Partition cache: **WeakMap keyed by immutable BufferGeometry identity plus a short actual bone-region signature**, with at most 32 live partition entries. No full skin/index JSON serialization. The bounded entry ring holds no geometry key. Displaced arrays are released; in-progress jobs keep only what they need. Repeated deaths using the same geometry reuse partitions. **Different private NPC geometry clones deliberately miss this cache**; no cross-clone identity is guessed from model names or appearance.

Maximum pending + active victims **2**, maximum active moving groups **12**, maximum 36 meshes and 20,000 source triangles per victim. No source triangles are removed. Material leases are per input mesh with shared handles/refcounts, not per fragment. Actor disposal after admission is safe because buffers remain referenced and owned material/texture handles are separate. Geometry edits during an outstanding job violate the immutable-input contract; ordinary pose updates and actor disposal are supported and tested.

## Event and lifecycle contract

Receipt fields remain `actorId`, `eventId`, `deathKey`, `cause: 'blast'`, `confirmed: true`, `deathConfirmed: true`, finite `origin`, nonnegative `impulse`; **`eventAt` is now required**. `eventAt` and `now` use seconds on one monotonic host clock. The host must translate source age/clock once; never use local receipt time as event birth. Expiry is `eventAt + 8`, including queue time. Future event times or backwards host time fail closed.

**Corrected live-history contract:** receipts and death keys are bounded Maps expiring at absolute **`eventAt + 8`**. Both admission and update prune expired entries/effects. Stale events are rejected **before ledger lookup/insertion**, so re-delivery after history expiry allocates no memory and cannot replay. Only accepted pending jobs consume entries. A busy two-victim pool returns **`reason: 'capacity'` without consuming history**; the host may retry the exact unchanged receipt until its original TTL. Other invalid/unsupported admissions also create no accepted receipt.

`cull(actorId,deathKey)` removes pending/ready work but retains its accepted receipt until the original expiry. The cap is **256 concurrently live receipts**, not a lifetime event count. At live saturation `receipt-capacity` denies admission until pruning frees space; no permanent stop after 256 events. Keep `eventAt` immutable across retries. Host-owned `visualReplaced` state must independently prevent an intact corpse from reappearing after renderer/population recreation; short-lived transport history is not that persistent visual state. A destroyed controller also loses recent history, so recreation needs the host's accepted-presentation state.

Regression: default 256 simultaneous live history entries + overflow rejection; expiry/pruning via admission without an update; successful renewal and **300 further admit/cull cycles**; both Maps bounded and pruned by update; stale packets add no history; invalid input adds none; busy retry succeeds after a slot opens; accepted cull still rejects replay before TTL. Actual GLB/ground regressions continue to pass.

All roles follow the same path: actual male/female civilians, bosses and police pass the same confirmed-death checks. The prototype does not decide who can die or infer semantic cause from a blast nearby. It cannot manufacture a measured impulse; the accepted damage producer must supply the eventual directional/impulse record.

**Atomic replacement owner contract:** retain the ordinary corpse visual while pending. In the same render turn that receives a ready ticket, the host suppresses that corpse visual and the matching legacy proxy. The prototype deliberately does not hide any NPC. Calling `update` without this host action is only suitable for this isolated test, because body and parts would coexist. On cull/expiry retain the source death state and consumed-presentation state; do not restore an intact corpse as a side effect of fragments expiring. Snapshot/legacy binding and this visual owner remain unimplemented. Root/HP authority is untouched.

## Actual GLB regression and costs

Run `node assets/maps/city_rebuild_v1/test_npc_blast_parts_prototype20.mjs` — **PASS**.

The retained `npc_blast_parts_sync_reference20.mjs` is test-only baseline code. On all six appearances the new result matches it **exactly** for positions, normals, UVs, colors and index arrays, with matching group positions and rotations. The test changes pose and disposes the source actor before the first deferred vertex is baked. No weapon mesh appears in fragments. Every admitted triangle is retained. Original root/bones/source state remain unchanged at admission.

| Actual appearance | Sync baseline ms | Snapshot/enqueue ms | Steps | Max slice ms | Geometry bytes |
|---|---:|---:|---:|---:|---:|
| Male civilian | 27.355 | 1.594 | 75 | 1.503 | 426,300 |
| Female civilian | 21.986 | 0.631 | 66 | 1.333 | 397,640 |
| Leila | 18.897 | 0.342 | 65 | 1.329 | 393,496 |
| Marat | 16.230 | 0.785 | 72 | 1.722 | 426,300 |
| Male police | 19.118 | 0.431 | 71 | 1.253 | 445,052 |
| Female police | 19.196 | 0.332 | 65 | 1.225 | 421,080 |

Last-run per-appearance slice p95 <= **1.254 ms**, max **1.722 ms**; two-police queue max **1.275 ms**. Earlier run observed a **2.880 ms** slice and the first cold snapshot reached **2.144 ms**; these are not hidden or claimed fixed. Original synchronous baseline had 9.5–30.6 ms admissions; paired runs here showed 15–31.5 ms depending on warmup/scheduling.

The two completed police victims allocate **60 fragment geometries / 866,132 attribute+index bytes, 16 material handles, zero texture handles** for these vertex-colored actual assets. Temporary JS remap/partition arrays, immutable source buffer leases, snapshot matrices and renderer GPU overhead are additional to that byte count. Cache stays <=32 entries. Texture handle ownership is implemented, but these actual assets do not exercise textured materials.

Regressions also cover both pending slots being occupied, maximum 12 ready groups, no partial scene attachment, dropping a third victim without replay when a slot opens, culling and reactivation dedupe, changed-event same-death dedupe, expired/future/missing-time events, source-age expiry, 30-second update gap, pending expiry before ready, repeated same-geometry partition hits, disposal partway through geometry allocation, and exact geometry/material dispose events on expiry. All live resource counters return to zero after disposal/expiry.

**Latency tradeoff:** 65–75 updates is roughly 1.1–1.25 seconds at one call per 60 Hz frame, with FIFO two-victim latency up to about 2.5 seconds. This is a budgeted preparation proof, not acceptable-looking instant blast integration. Prewarm partitions / prepare reusable layouts during loading and further reduce work before runtime acceptance. Source-age TTL still applies while waiting. Microbenchmark calls used a fixed event time for exact comparison; wall-clock queue expiry was covered separately.

**Limits:** no source/profile/renderer integration, ground collision, floor settling, closed seams/caps, art approval or GPU/LIVE run. No general scene FPS claim. Производительность общей сцены не проверена. Coordinate future runtime ownership with 19's ground-blood consumer; do not add another unbound blast particle path.
