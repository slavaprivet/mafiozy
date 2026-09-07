# Frozen placement topology — planner v3, no invented runtime repairs

Ready file: `topology_for_placement.json`.

Schema `mafiozy.city-rebuild-placement-topology/v1`, status
`ISOLATED_WALK_TOPOLOGY_PENDING_HOST`. Use for the separate pedestrian preview
and building/decor planning only. `pendingHostSnapshot:true`; vehicle, gameplay
and production readiness are explicitly false.

- `grid`, `roadMask`, `walkableMask`, `protectedMask`, `policeMask`,
  `bridgeDeckMask`: **200 row arrays ×180 columns**, masks numeric0/1.
- Geometry in `districts`, `crossings`, `terrain`: source points **[column,row]**.
- World scale:4.1 units/cell.
- `protectedMask` reserves police882 cells plus all4 enabled surface bridge
  decks. Buildings/decor must not occupy these cells.
- `walkableMask` excludes water and reserved police, but DOES NOT yet include
  placed-building/decor colliders. The placement host must combine those.
- `roadMask` has12276 cells in one connected component; it is not a vehicle
  clearance/turning-radius certification.
- Sand116 cells comes from the derivative authoritative beach polygon.
- Two deferred tunnel records remain source metadata, never surface tile19.

`placement_topology.mjs` exports `buildPlacementTopology(addendum,{base,...})`.
It rejects all structural errors. Missing host tiles alone are allowed ONLY
for this explicitly isolated output: the underlying compiler's missing-host
finding is preserved, not relabeled as unconditional PASS. Police tile9 is
an isolated reserved placeholder, not a capture from MAIN.

Optional actual host input:
`policeProtectedCells:capturePoliceProtectedCells(oldMAP,geometry,solidRects)`
and `policeSnapshotAuthority:'host-buildMap'`. Run after buildMap; see the
snapshot helper handoff. Real-host output still does not certify gameplay or
server migration. Never pass the planner's placeholder snapshot as host data.

Independent checks: source SHA
`dbd287d1aa692d3706ae7cc5c1cba17972538e248805100f19cd95a2ef9f5a0f`,
derivative base SHA
`562383a5df736ae765a1e5752949531afa338cef3f91d8e350d668f668ca2439`.
248 safe fragments;207 road IDs;1 connected component;zero finite-width
water/police conflicts, zero out-of-envelope bridges and zero tunnel tile19.

All planner changes remain explicit in `sourceCorrections`: shoreline reroutes,
two extra A-SOUTH approach bridges,8 removed disconnected fragments, and three
retained road IDs with no geometry (`L-GO-H-095`, `AL-010`, `AL-043`).
`runtimeRepairs:[]`: no extra invented repairs were applied here.

Run `node assets/maps/city_rebuild_v1/test_placement_topology.mjs` to verify the
published artifact, masks, deterministic generation and host-pending semantics.
