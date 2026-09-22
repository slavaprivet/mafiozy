# Isolated exact grounding correction memo for stable NPC death poses

## API and ownership

`createNpcGroundCorrectionMemo({THREE, context, poseMeshes})` returns:
`apply()` (applies grounding and returns numeric local visualPivot Y delta),
`invalidate()`, `stats()` (`hits`, `misses`, `fallbacks`, `disposed`), `dispose()`.

This task changes ONLY the new helper, its actual-GLB test and this document.
No imports/hooks were added to npc_actor, hero_walk or npc_death_pose20.
Coordinator20 owns NPC-only integration and disposal after its reload window.

Caller MUST provide the exact immutable baseline list of mesh references used
by original groundPose. Capture `clone.traverse(mesh => { if(mesh.isMesh)
poseMeshes.push(mesh); })` immediately after createHeroWalker returns, before
scene.add/phone/cash/surface constructors. Full constructor review confirmed
this is identical in references and preorder to hero_walk's private list:
after private capture, reset/melee/transition setup does not mutate topology.
Include plain meshes, invisible meshes; never infer the list from a later
traversal including wounds/props. Missing authority falls back to groundPose.

## Exactness and invalidation

On miss, call the original groundPose without changing its vertex algorithm.
On hit, reuse the corrected local pivot Y. Preserve original skeleton updates
per pose mesh and final world-matrix refresh. Returned arrays/geometry/bones
are never modified by the memo. No approximate box/sphere ground contact.

Key includes local node matrices/parents, mesh and geometry identity, raw
position/skinIndex/skinWeight/morph arrays, influences, bind/rest/inverse
matrices, scaled/offset/pivot, and root.matrixWorld. Raw array comparison
detects unversioned geometry edits, including bruiser-style deformation;
there is no hash or version-only trust. Unsupported custom methods,
interleaved buffers, detached/external bones or removed baseline meshes
fall back to unchanged groundPose. Original exceptions propagate.

### Rejected root invariance assumption

Actual male GLB counterexample: root x137.125,z-89.25,yaw0.91, height3.4→-0.27.
Reused correction was -0.2329935312521889; native correction became
-0.23299364062670425 (difference1.09e-7, exceeding1e-8 acceptance threshold).
Float32 skin weights need not sum to exactly1, so inverseRoot does not make
native arithmetic perfectly invariant. Coordinator20 accepted conservative
root.matrixWorld invalidation. Root translation/yaw, moving platforms and
water-height changes therefore MISS; stationary corpses remain cacheable.
We did not loosen tolerance or normalize/change geometry to hide the issue.

## Evidence and limits

Actual male/female GLBs + createHeroWalker + current npc_death_pose20.
Initial58 cases PASS; stable fixed pose, changing direction/bones/rest/bind,
root/platform/water/scale, raw geometry/bruiser/weights, morph, hidden plain
meshes, late wound exclusion, repeated apply without reset and exceptions.
Final test count and later rerun numbers may supersede this initial result.

Total key+apply CPU, including raw data comparisons and matrix refresh:
male p50/p95 native1.714/1.879 ms → memo0.778/1.260;
female1.416/1.464 →0.460/0.550. Each steady run recorded19hits/1miss.
These are isolated CPU results, not full actor update, LIVE or FPS acceptance.
Cache key has nonzero cost; changing poses invalidate, so integration should
target the approved stable-death path rather than all living animation.

No existing stable-death early return was found in current npc_actor.update:
walker.update and surface.update run on every admitted pose tick.
npc_population gates pose frequency via LOD and does transform-only updates
between ticks; this is not a stable-death ground-scan cache.

Run `node assets/maps/city_rebuild_v1/test_npc_ground_correction_memo.mjs`.
No new GPU tab, source/world rewrite, actor hook, commit or push by this task.

## Final READY (main verification)

68 actual-GLB cases PASS. Added explicit root translation/yaw/water MISS
assertions, current groundPose replacement, removed baseline mesh and external
skeleton-bone fallbacks. Main rerun: male native p50/p95 1.5299/1.7164 ms →
memo total0.6550/0.8607; female1.5045/1.6005 →0.4844/0.5428.
Fixed-root correction uses cached absolute final pivot Y to avoid an extra
subtract/add rounding step; apply returns the original numeric Y delta.

Ready manifest consists solely of npc_ground_correction_memo.mjs,
test_npc_ground_correction_memo.mjs and this handoff. All are new standalone
files; production actor/hero/pose integration remains with Coordinator20.
