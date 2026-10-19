# Source printshop ladder and conditional collision contract — 27 September 2026

Status: component ready, actual-main headless audited; NOT PLAYABLE / NOT WIRED.
Owner: traversal. Root owns accepted interior adapter, player, input and LIVE.
Base published checkpoint: 78e67c826071f9c55d72a909d0c2ad4bd6488685.

## Exact export

`tools/godot/export_printshop_ladder.py` evaluates the same actual source building
factory and transform as the accepted interior exporter, exporting the ladder's
worldDescriptor in preview metres. It never rewrites accepted interior data.
`--check` regenerates byte-identical output. Fixture is
`godot/mafiozi_walk/scripts/tests/fixtures/printshop_ladder_source.json`.
Runtime packaging/location belongs to root; tests/fixtures is not a runtime feed.
All source/asset/transform/origin/interior hashes are pinned in this fixture.

Source ID REBUILD-VISUAL-print_shop-001; lower (-8.911,0,-5.551553337),
upper (-4.611,6.585,-5.551553337); crest Y6.705; width .8, rungs .28.
Authored roof step-off (-3.861,6.585,-5.551553337) is retained exactly.

## Found dependencies in the actual accepted main

1. Current controller correctly rejects the unbound ascent, route_blocked at
   (-8.473038,6.705,-5.551553). The blocker is exact accepted staticBodies[5],
   source-static high exterior envelope. Its bounds min (-8.16,6.56,-7.151553),
   size (2.349,5.68,11.04456). This is not evidence to delete the collider.
2. Source Walk `walk_preview.mjs:1068`/`:1069` explicitly ignores a body's own
   buildingEntryId only within radius+.18 = .51m of the authored ladder path,
   excluding no Roof_Ladder_Rail_Collision parts. Source ceiling query likewise
   skips only inside this corridor. Outside it full source collisions return.
   Export pins this exact anchor/hash and eligible/rail static-body indices.
3. Accepted native adapter retains source ID but drops per-body index/part;
   root must provide an exact current index→RID mapping/lease. Test-only mapping
   checks cardinality and EVERY convex point against the source body in order;
   do not assume unstable node names or blindly exclude PrintshopInterior.
4. After selective source policy, all 304 ascent sweep samples are clear, but
   native five-ray support rejects the authored endpoint: actual roof top is
   Y6.47, .115m lower than descriptor feet Y6.585. All five rays agree. This is
   above the native .08m support tolerance. Do not increase tolerance globally.
   Test-only query-derived final .115m downward settle has 308 clear samples and
   valid five-ray support. Root must approve/connect physical settling after
   source route; authored source descriptor must remain unchanged. Neither
   this helper nor fixture changes the physical endpoint automatically.
5. Exact source descent has 284 clear samples and supported lower landing.

## New API (pure, no physics mutations)

`scripts/traversal/ladder_source_collision_policy.gd`:
- `near_path(feet, normalized_descriptor)` reproduces actual source .51m
  three-dimensional authored-polyline corridor; fails closed on malformed data.
- `bind_current(descriptor, records)` filters current records with keys rid,
  building_entry_id, storey_part, retaining foreign bodies/rails as collidable.
- `excludes_bound(feet, descriptor, current_bound_rids)` returns the current
  leased exact source RID set inside corridor, empty outside. Host must rebind
  on entry lifecycle/revision; this helper does not claim RID liveness authority.
- `excludes(...)` convenience form rebinding each call; prefer bound form for
  per-sample queries. No internal mutable cache, no shared filters changed.

Root seam: use conditional exclusions for capsule/swept body queries and actual
CharacterBody filters before each accepted move. Restore the previously owned
filters as soon as outside corridor and on completion/cancel/abort/dispose.
Do not put this set into existing blanket route_exclude_rids: source step-off
lies .75m outside the authored path and must have normal collisions. Support
queries MUST NOT exclude source floors/building. Preserve unrelated exceptions.
Input still E admission, Ctrl slide active only; one root/pose/input writer.

## Verification and cost

Actual Godot 4.7.2 headless `test_printshop_ladder_source.gd`: 143 PASS. PASS
certifies source identity, geometry mapping, conditional policy, exact known
rejections and test-only settled route. It does NOT certify integrated ascent.
Source exporter --check PASS. Native current controller/player remain unchanged.

Warm 256-sample isolated policy query p50/p95 2/3us after one-time binding134us,
versus rebinding each query128/236us in preceding same-main test. Measurement is
logic-only; general scene FPS, physical exception churn, full rig and LIVE have
NOT been checked. No GPU window, Git operation or foreign runtime edit.

Frozen manifest/actual output: outputs/printshop_ladder_source27/.
