# Astra research delta — 2026-09-19

## ACCEPT — npc-adapter-callback-effects-20260919

Source freshness passed for `assets/maps/city_rebuild_v1/mercenary_world.js`:
`37eaa69b7ee470a2a1a042e1c044568983ae9a708ceb4ac5575371291480f59e`.

- `getMember/getTarget/scanReviveTargets` directly read state and call external `core`/target helpers whose purity is unknown.
- `moveMember` writes `_mercenaryReturnMove=false` and replaces or clears `_mercenaryMove`; `onAction` writes `_mercenaryAction`.
- Confirmed counterexample: deduplicating repeated `moveMember(id,null)` can preserve a goal installed between the calls. Idle gating must not suppress the clear.
- Research only. No production patch, runtime test or LIVE acceptance.

## ACCEPT — world-inventory-duplicate-contract-20260919

`mercenary_world.js` exactly matches the supplied hash. The whole `world.html` changed after dispatch, but the bounded current
`_syncMyWeaponsFromInventory` contract was re-read and still matches the analyzed behavior: reconcile runs before UI dedup,
`id||item_id` selects the raw ID, and the first positive duplicate row wins UI display.

Confirmed defect: with two fresh distinct weapon rows `[1,1]` and one reserved weapon, current
`reconcileInventory` subtracts the full reserve from both rows and produces `[0,0]`; the quantity invariant requires `[0,1]`.

Bounded proposed implementation (not applied):

```diff
- function reconcileInventory(items){if(!ready||!local()||!Array.isArray(items))return items;const reserved=new Map();for(const r of core.getRoster())if(r.weapon)reserved.set(String(r.weapon.id),(reserved.get(String(r.weapon.id))||0)+1);for(const item of items){if(!item||typeof item!=='object'||item.type!=='weapon'||inventorySeen.has(item))continue;inventorySeen.add(item);const n=reserved.get(String(item.id))||0;if(n)setQuantity(item,Math.max(0,quantity(item)-n));}return items;}
+ function reconcileInventory(items){
+  if(!ready||!local()||!Array.isArray(items))return items;
+  const reserved=new Map();
+  for(const r of core.getRoster())if(r.weapon)reserved.set(String(r.weapon.id),(reserved.get(String(r.weapon.id))||0)+1);
+  for(const item of items){
+   if(!item||typeof item!=='object'||item.type!=='weapon'||inventorySeen.has(item))continue;
+   inventorySeen.add(item);
+   const id=String(item.id||item.item_id);
+   if(!reserved.has(id))continue;
+   const available=quantity(item),remaining=reserved.get(id),used=Math.min(available,remaining);
+   setQuantity(item,available-used);
+   reserved.set(id,remaining-used);
+  }
+  return items;
+ }
```

Limits retained from the result: fresh copies of already-reconciled quantities are indistinguishable from a new raw package;
`qty:0,count:1` has different mutation/UI precedence; no tests or LIVE were run.

## STALE_REVIEW — camera-damping-dt-boundary-20260919

`indoor_camera.mjs` still matches its supplied hash, so its scalar result remains useful in isolation: immediate retraction,
bounded monotonic recovery, and large-step cap non-equivalence (`dt=.2` clamps to one `.1` step).

The task as a whole is not accepted because two supplied sources changed materially:

- `indoor_camera_clearance.mjs`: sent `df5eb1...`, current `0cae66...`; current code adds a 6 m/s recovery cap.
- `walk_preview.mjs`: sent `a83c4d...`, current `6074fe...`.

Therefore the old statement that clearance has no speed bound is stale. A fresh package is required before accepting current
clearance/caller behavior. No repeat was sent in this cycle because the dispatcher already used its five-message rolling limit.

## ACCEPT — grass-cell-index-parity-20260919

All four supplied grass source hashes still match. Astra 1 delivered an actual bounded CPU-only regression diff comparing the
real indexed update with an independent full traversal. It checks IDs and order globally and per mesh, counts, fade, negative
boundaries, equal-distance ties, tuft/triangle/batch budgets, shuffled construction order and widest-radius AABB halo probes.
The diff is preserved in ASTRA_GRASS_CELL_INDEX_PARITY_20260919.md; it was not applied or run.

## PARTIAL_ACCEPT_REVIEW — inventory-test-body-coverage-20260919

The old implementation finding is superseded because the reserve fix and two focused duplicate tests are already integrated.
Do not apply the proposed 157-line scenario matrix. Two genuinely separate coverage gaps remain useful: failures of equip/dismiss
must leave inventory/gang/persistence callbacks unchanged, and real source dismissal must preserve its delegation guard,
single former-gang row and exactly-one refund. A fresh narrow task was issued against current source for at most two tests.
The external provenance/version contract for fresh copies of already-reconciled rows remains unresolved.
