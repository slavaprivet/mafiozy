# Blast parts 20 — optional ground integration, isolated

2026-09-20. Coordinator20-owned prototype integrates NPClead19's existing `npc_blast_ground20.mjs`. That helper was read and imported, not edited. Runtime, actor, population, world and blood remain untouched. Same fragment meshes, geometry, material leases and disposal owner as before; no second effect layer.

## API / ownership

Pass optional `{groundHeight: (worldX, worldZ, referenceY) => worldY}` to `createNpcBlastPartsPrototype20`. The third argument is the current safe part centre Y, allowing Walk's existing provider to select the relevant floor instead of its default first floor. Two-argument heightfields remain compatible. Coordinates and height must use the same world units as the actual baked fragments; no grid-to-world inference is performed. Missing/null callback preserves the original exact-reference ballistic path. Invalid non-function values are rejected.

With a callback, each ready part starts from its frozen actual pose and the union of its own local geometry bounds. The helper integrates translation plus axis-angle quaternion rotation and probes rotated support corners plus centre. It writes position/quaternion on the **same part group**; vertex/index/material data remain unchanged. The no-ground branch retains Euler rotation for comparison. Grounded and reference geometry/pose match exactly at event t0; their later rotations are intentionally not asserted equal.

Pending fragments are never attached to the scene. Host retains the ordinary corpse until ready, then performs its already-agreed atomic visual replacement in the same render turn. The prototype still does not hide the corpse or alter source root/HP/dead. `groundDiagnostics()` returns detached diagnostic records; `stats()` includes the shared budget, actual queries and helper visits from the last update.

## One query budget for every active part

The whole effect controller has **192 support queries/update**, not 192 per part. A scheduling turn grants **18** (9 for validating the last safe pose, 9 for one forward/contact-refinement sample). All parts share one persistent round-robin cursor. Remaining capacity below 18 is unused instead of repeatedly sampling without forward progress.

For twelve flying parts under backlog, one update advances ten parts using **180 queries**. The next update starts with the two that did not receive a turn. With fewer eligible parts the scheduler may revisit them using the remaining shared budget. Reached-current-time, blocked and settled parts do not waste turns. Actual callback calls are counted in tests against the controller's total, including callback errors; exceptions/non-finite heights block movement in place.

The existing 1.25 ms soft bake/preparation budget remains. Ground stepping follows it with the separate shared query bound; `lastSliceMs` includes both. A query-count bound cannot guarantee CPU cost of an arbitrary host height provider. Runtime must measure the real provider; the timings below use cheap synthetic heightfields.

## Elapsed time, gaps and expiry

Ready parts retain absolute `eventAt` and the original eight-second TTL. Delayed readiness supplies real current `now` to the helper, but never jumps directly to an unchecked old ballistic position. Unprocessed elapsed time remains debt; ground traversal advances only through budgeted safe segments. Diagnostics report current debt even for parts that missed their turn that frame. No unbounded catch-up loop runs.

Expired pending/active jobs are released before terrain sampling. A five-second-old event can therefore become ready near its frozen safe pose, retain about five seconds of movement debt, and still disappear at original `eventAt + 8`; it does not receive a fresh lifetime. TTL wins over completing the visual flight. Culling retains the accepted death/event receipt **until its absolute event expiry**; [corrected TTL-map/capacity contract](NPC_BLAST_PARTS20_INCREMENTAL.md). Busy capacity does not consume a receipt. Disposing the actor before readiness leaves the snapshot and leased resources valid; disposing the effect releases its existing resources and stops all querying.

## Verified

- `node assets/maps/city_rebuild_v1/test_npc_blast_parts_ground20.mjs` — **PASS**, actual male/female police appearances: **12 parts, 60 meshes, 866,132 geometry bytes**, unchanged by motion/collision.
- At event t0 all indices, positions, normals, UVs/colors and part transforms exactly match the synchronous reference. Normalized rotation and the eight corners of each actual rotated region bound remain above the tested ground during flight and at rest.
- Three-second gap: first update used **180 queries**, advanced ten parts by less than 0.1 seconds, and retained the remaining debt. All twelve had advanced within two updates. Flat-ground settling then took **61 updates**; elevated slope test took **26**.
- Ground-only update cost while draining that twelve-part debt: p50 **0.0547 ms**, p95 **0.1013 ms**, maximum **0.5612 ms**. These are CPU microbenchmarks, not game FPS.
- Unknown/throwing provider blocks in place; settled fragments make zero further terrain calls and retain their pose. Exact TTL expiry, delayed ready, pending expiry/cull, actor disposal before bake, active cull without replay, effect disposal, no partial scene attachment and global callback-count cap are covered.
- Reference-Y regression: a floor-selecting provider settles actual male parts on **3 m and 6 m** support, each in 11 updates; minimum supplied reference Y was 3.28269/6.28269 m. It no longer silently defaults to ground-floor Y=0.
- `node assets/maps/city_rebuild_v1/test_npc_blast_parts_prototype20.mjs` — **PASS**, all previous six cold + six prepared-clone exact comparisons and lifecycle/resource checks still pass without `groundHeight`.
- `node --test assets/maps/city_rebuild_v1/test_npc_blast_ground20.mjs` — **9/9 PASS**, existing helper suite including real male/female region bounds. No helper file was changed.

## Remaining limits

This is sampled heightfield support, **not wall/building collision** or a guarantee against arbitrarily thin terrain features. Selecting the relevant support in multi-level geometry belongs to the host provider. Settled pieces are not dynamically resampled for moving terrain. Closed cuts/seam caps, art acceptance, source-authoritative blast origin/impulse/event binding and runtime corpse replacement remain open. Ground integration does not remove the earlier preparation latency; delayed delivery may show slow debt recovery before TTL.

No browser/GPU run. **Производительность общей сцены не проверена.** Coordinate runtime integration with Coordinator20's presentation controller and NPClead19's blood consumer.
