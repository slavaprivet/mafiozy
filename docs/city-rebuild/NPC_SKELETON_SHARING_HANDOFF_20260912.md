# NPC skeleton sharing — 2026-09-12

## Scope and integration

New helper: `assets/maps/city_rebuild_v1/npc_skeleton_sharing.mjs`.
API: `shareNpcCloneSkeletons({THREE, root: independentNpcClone})`.
Main owns the separate `npc_actor.mjs` integration: call after verified private
clone creation and before appearance/walker/render; dispose unique skeletons.
This agent changed only the new helper, test and this handoff.

The helper groups within one call/root only, and requires:

- Exact host `THREE.Skeleton.prototype`, standard own data fields only.
- No allocated bone texture, no custom instance methods/state or subclass.
- All ordered bone references belong to this clone.
- Identical **boneInverses array object**, not merely equal matrix values.
- Equal current bone matrices, preserving immediate CPU reads.

It only changes `mesh.skeleton`. Bind matrices, geometry, materials, morphs and
transforms stay unchanged. Displaced skeletons have no texture and need no
disposal; CPU arrays are collected normally. No global skeleton cache is used.

## Actual assets and correctness

Raw male GLB: 7 skinned meshes → 1 skeleton; female: 5 → 1.
All use the same 28 clone-local bone objects in the same order and the same
boneInverses array identity. Actual configured actors have **4 core skinned
meshes each**, because `npc_appearance.mjs` removes authored hair/headwear.
Thus the normal NPC renderer workload is **4 skeletons/textures → 1**, not 7/5.
This refines the earlier raw-GLB texture census; no leak is implied by that census.

`node assets/maps/city_rebuild_v1/test_npc_skeleton_sharing.mjs`: **21 PASS**,
including main's automatic production integration. The baseline keeps distinct
skeletons through a temporary custom-state opt-out, removed after actor creation.

Eight actual poses cover idle, walking, crouch, prone/running, water and confirmed
death. Exact equality, no tolerance, for all posed world vertices and matrices:

| Actor | World vertices compared | Bone-matrix values compared |
| --- | ---: | ---: |
| Male | 53,920 | 14,336 |
| Female | 54,088 | 14,336 |

Source and other-actor bone/skeleton independence is asserted. CPU DataTexture
allocation verifies 4 → 1 textures; disposing either actor does not dispose the
other or allocate/dispose template textures. Repeated disposal is safe.
Negative tests cover inverse-array ownership, bone order, differing matrix data,
external bones, allocated textures, custom methods/state and subclasses.

## Bounded CPU measurement

Reproduce with `node assets/maps/city_rebuild_v1/test_npc_skeleton_sharing.mjs --benchmark`.
Actual actors, one actor per sample, 80 warmups then 400 alternating A/B samples.
Only unique `Skeleton.update()` calls are timed, matching the renderer's
per-frame identity memoization. Node v26.1.0; no renderer/WebGL context.

| Actor | Before p50 / p95 ms | Shared p50 / p95 ms |
| --- | ---: | ---: |
| Male | 0.1353 / 0.2415 | 0.0341 / 0.0615 |
| Female | 0.1287 / 0.2332 | 0.0323 / 0.0595 |

An earlier independent in-memory run gave male 0.1255/0.1506 →
0.0317/0.0447 ms, female 0.1150/0.1732 → 0.0291/0.0514 ms.
Host noise affects tiny measurements. These are **not total actor CPU, GPU time,
draw-call savings, or FPS**. Explicit per-mesh skeleton updates in wet clothing
and pose queries are not deduplicated by this helper: an instrumented eight-pose
run remained 12 explicit calls before and after for each sex. The saving applies
to the renderer's identity-deduplicated stage and lazy bone texture allocation.

## Ownership and future changes

Never apply across NPCs or to immutable templates. Existing SkeletonUtils clones
already share inverse arrays with their source; this helper does not introduce
new inverse-matrix writes. Rig bone order and inverse-array ownership must remain
immutable after canonicalization. A future per-part rebind, `calculateInverses`,
replacement of `skeleton.bones`/`boneInverses`, or custom per-part skeleton state
requires a private Skeleton (copy-on-write) before that mutation. Current actor,
appearance and Artist pose code has no such per-part mutations. Sharing does not
change ownership of each mesh's separate bind matrices.

CPU-only acceptance completed. GPU/LIVE visual acceptance was deliberately not
run because other active user scenes own the GPU; do not claim an in-game FPS
improvement from this audit alone.
