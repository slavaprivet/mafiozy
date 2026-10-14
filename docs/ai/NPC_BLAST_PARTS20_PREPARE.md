# Blast parts 20 — bounded latency reduction / prepare API

**Latest addition:** [optional shared-budget ground integration](NPC_BLAST_PARTS20_GROUND_INTEGRATION.md). This preparation API and the no-ground exact reference path remain unchanged. The ground helper is still isolated from gameplay/runtime.

2026-09-20, latest isolated stage. `npc_blast_parts_prototype20.mjs` and its actual-GLB regression are ready for Coordinator20 review. No actor, population, world, blood or runtime production file changed.

## Outcome with unchanged budgets

The limits remain **1.25 ms soft time / 256 source vertices / 2048 work units per update**, at most two pending+active victims and twelve moving parts. Tests compare the actual change in baked-vertex count with the reported quota. No triangle/vertex quality was removed.

| Actual appearance | Previous stage steps | New cold steps | Prepared new-clone steps | Vertex-quota lower bound |
|---|---:|---:|---:|---:|
| Male civilian | 75 | 52 | 40 | 33 |
| Female civilian | 66 | 44 | 37 | 31 |
| Leila | 65 | 42 | 35 | 30 |
| Marat | 72 | 47 | 40 | 33 |
| Male police | 71 | 46 | 41 | 35 |
| Female police | 65 | 42 | 38 | 33 |

Prepared death-time latency falls about **42–47%** from the preceding stage. At one update per 60 Hz frame, 35–41 steps still means **0.58–0.68 seconds per victim**, with FIFO two-victim latency around **1.3 seconds**. The 30–35-step lower bound follows from retaining all actual source vertices at 256/update; this CPU bake contract cannot honestly provide immediate all-parts presentation. Further major latency reduction requires a different reviewed architecture, not pretending the existing budget permits more vertices.

Latest actual run: cold bake max slice **1.524 ms**, prepared max **1.264 ms**, preparation max **1.507 ms**; prepared admission **0.295–0.441 ms**. Paired synchronous reference takes **16.1–28.7 ms**. Time budget remains soft: a previous stage iteration observed a **3.447 ms** overshoot before dense allocation cleanup, and earlier incremental runs also exceeded 2 ms. No hard maximum or scene FPS promise is made. Preparation runs ahead of death, not invisibly inside admission.

## Work removed

- Triangle partitioning now also builds the unique-vertex remap and packed output index arrays once. Death-time remap maps and duplicate triangle-index walks are gone on cache hits.
- A dense typed destination table replaces thousands of tiny per-vertex JS arrays. Cached packed indices are copied into independently owned fragment attributes.
- Each actual vertex bake writes its fragment positions/UVs/colors and bounds directly. No intermediate posed buffer or separate copying/bounds pass is needed.
- Normal normalization and centering share one pass. The **two normalizations in that pass are intentional**: the exact reference normalizes in `computeVertexNormals()`, rounds to Float32, then normalizes again in `geometry.translate()`'s identity normal matrix. Both rounded operations remain to preserve exact output.
- The scheduler announces vertex work before executing it. After reaching 256 baked vertices, it can finish following non-skin work within the same time/work budget, stopping before another vertex.

## Loading-time API

`prepare({geometry, boneNames, rigidBoneName, sharedFrom})` returns `{ok,ticket}`. For skinned geometry pass actual ordered bone names; for a rigid accessory pass its actual attachment bone name. `sharedFrom` is optional and must be a real prepared source BufferGeometry. No model-name or role-based aliasing is performed.

Drive preparation through the same `update(now)` calls and wait for `ticket.status === 'ready'`; there is no scene attachment, material allocation or receipt consumption during preparation. Death bake jobs take priority. Queue and partition cache are each bounded to 32 entries; repeated preparation of the same geometry/signature returns the pending ticket. Disposal cancels pending preparation.

Recommended first use: prepare final immutable geometries after actor/model appearance construction, before they are needed for a death. This took **6–10 budgeted updates** for the tested appearances. Final geometry/private clones are currently owned by existing actor code; that owner must supply the real preparation inputs later. This patch does not alter that code.

Optional sharing to a **new private clone**: supply its geometry and an explicit prepared `sharedFrom`. The background task compares vertex counts, ordered region signature, every index and every skin-index/weight component. Only exact topology shares the cached entry. Different positions/UV/colors are safe because they are copied from the destination at death, not from the template. Index or skin-data mismatch falls back to an independent exact partition; it never publishes an unchecked alias. Evicted candidates cannot be reused. Both source and new-clone preparation are outside admission.

**Tradeoff:** verifying a private clone cost **24–26 budgeted updates**, longer than recomputing its own partition in this fixture. Explicit clone sharing is primarily a cache-memory/reuse option, not a claimed preparation speedup. Prefer direct preparation when lower background CPU work matters; use sharing only when its reduced duplicate cache storage justifies exact verification. Source and clone buffers must remain immutable while their preparation/bake is pending.

WeakMap lookup remains by real geometry identity plus short bone-region signature. Cache entry arrays are bounded and shared aliases reference the same entry; no full-array JSON keys. Two police victims retained **325,344 bytes** of packed cache data in the 32-entry ring, in addition to **866,132 bytes** of fragment geometry, 60 fragment meshes and 16 material handles. These figures exclude JS object/snapshot/source-buffer and GPU overhead. No new textures were present in these actual assets.

## Verification and remaining limits

`node assets/maps/city_rebuild_v1/test_npc_blast_parts_prototype20.mjs` — **PASS**. All six cold and prepared-clone outputs exactly match the synchronous reference's positions, normals, indices, UV and color. The clone test deliberately changes vertex position before preparation: shared topology never reuses the source's baked shape. Actor pose changes and disposal before baking remain covered. Separate changed-index and changed-skin-weight hints fall back safely. Preparation dedupe/cancellation and zero cache bytes after disposal are checked.

Absolute event age/8-second TTL, actor/death/event dedupe, pending/active capacity, expiry during pending work, culling without replay, actor resource disposal and atomic-ready ownership rules remain unchanged. The runtime host must retain the corpse while pending and replace it in the same render turn as ready; this isolated module does not hide any corpse. It still requires authoritative blast origin/impulse and event binding from the accepted-damage path.

Ground collision/settling, closed cut surfaces/seam caps, art acceptance and renderer integration remain open. NPClead19's separate ground module is not imported here. No GPU/browser run: **производительность общей сцены не проверена**.
