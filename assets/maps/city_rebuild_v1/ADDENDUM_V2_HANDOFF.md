# Addendum v2 compilation and host snapshot handoff

## API — no world/renderer changes

```js
import {compileAddendum} from './addendum.mjs';
import {capturePoliceProtectedCells,policeShapesFromAddendum} from './police_snapshot.mjs';
const policeProtectedCells=capturePoliceProtectedCells(
  oldMAP, // ONLY after existing buildMap has finished
  [...services.immutableGeometry,...policeShapesFromAddendum(addendum.protected_police_complex)],
  services.policeSolidRects.items,
);
const result=compileAddendum(addendum,{base:authoritativeHandoff,policeProtectedCells});
```

The snapshot copies real tile values only within the explicit police union.
No radius6 is invented; circle8 comes from the explicit source surface rule.
Protection uses positive-area unit-cell overlap, including fractional towers,
not only cell centers. The source union alone covers882 cells. The inventory
may additionally preserve mainland-square cells; these are unioned, not dropped.
Bridge-owner shapes are excluded from this **police** snapshot helper.

`grid` remains null when rejected. `analysisGrid` is a new complete36,000-cell
diagnostic grid, **not a playable approval**. Missing host tiles use a clearly
reported sidewalk9 analysis placeholder. Host snapshot values replace those
placeholders. Do not apply `analysisGrid` as if it passed the runtime gate.

## What v2 fixed

- All207 road profiles have explicit carriageway and sidewalk widths.
- 257 land fragments and77 gaps are rasterized independently, never flattened.
- Two enabled surface bridges use their explicit driveable polygons for tile19.
- Red bridge's full authored deck is protected, but deck sidewalks are tile9,
  not extra car lanes. The new explicit policy supersedes v1's broad210-tile19
  approximation; no bridge object is moved.
- Northern car tunnel and rail tunnel remain water at surface; zero tile19 from
  deferred subsurface crossings.
- The main connected network spans both sides through the existing red bridge.

## Remaining real-source blockers

The compiler's regression tests PASS, but the source candidate is still
**REJECTED**. `addendum_v2_analysis_checked.json` has every affected road and
finite-width water-conflict cell, plus all disconnected component IDs.

- **56 roads** still extend finite carriageway width into water.
- **62 roads** have total carriageway+sidewalk envelopes entering water.
- **10 roads** intersect the protected police union; reconcile exact host lanes
  or reroute, not overwrite police geometry. Host tile0/19 intersections are
  treated as retained lanes rather than automatically flagged as conflicts.
- Road graph has **11 components** before real host snapshot: main12526 cells
  and ten pieces sized31,20,9,6,4,3,2,1,1,1.
- Beach still has shoreline points only, no explicit sand polygon.
- Exact host snapshot is pending actual post-buildMap capture.

Minimum geometric fix is to clip road centerlines against water expanded by
**half the total envelope**, rather than clipping at the raw shore. For
arterials this is2.7grid; collectors2.15; locals1.5; alleys.85. This also requires
dry end caps. Parallel shoreline segments may need lateral rerouting.
Do not simply clip half of a carriageway away and call the narrowed road valid.

Concrete samples (all **[row,column]**):

- A-NORTH: wet carriageway[20,85],[20,94],[21,86],[21,93] at tunnel-side caps.
- A-CIVIC-SPINE: [114,69],[115,67],[115,68] at Lantern Cut.
- A-SOUTH: [130,53],[130,54],[130,121],[131,46] beside unbridged cuts.
- L-NO-H-003/L-NO-V-009 isolated20-cell piece: nearest main-network pair
  [27,53]→[27,56], distance3grid.
- AL-010 isolated6-cell piece: [43,57]→[43,59], distance2grid.
- L-IR-H-084/L-IR-V-090 isolated31-cell piece: [157,73]→[153,71].

Nearest pairs are **diagnostics only**, not permission to cross water or draw
straight connectors. Planner must reroute/remove isolated scraps or provide
an explicit safe crossing.

## Checks

`test_addendum.mjs <v2 path>` verifies exact v2 SHA and authoritative-base SHA,
frozen inputs and repeat determinism, actual257/77 counts, water/bridge envelope
invariants, deferred tunnels, source rejection, complete host snapshot copying,
thin-tower overlap, circle boundary semantics and preservation of host inputs.
`test_topology.mjs` continues passing the independent positive/negative compiler
fixtures. No browser, game files, server, commits or pushes were performed.
