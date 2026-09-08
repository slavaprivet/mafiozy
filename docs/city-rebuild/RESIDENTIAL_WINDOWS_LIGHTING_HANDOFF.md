# Residential windows and street lighting — `/walk` handoff, 2026-09-08

Scope: runtime presentation adapters for the isolated third-person preview.
Pinned GLB bytes, placement IDs, building silhouettes, porch lamps, collision,
doors, ownership and server state remain unchanged. No LIVE PASS is claimed.

## Residential windows

`residential_windows.mjs` covers the nine pinned residential LOD0 profiles used
by 43 placed buildings. The resulting placement contains 675 independently
addressable window instances: 14 Old Town panes, 42 Garden Walkup panes, 40
Stepped Apartment panes and three panes on each rural house clone.

The three urban GLBs store window layers as welded connected components inside
`*DeepGlass` and `*WarmInterior` primitives. The adapter discovers components by
welded XYZ position, removes only components larger than the audited window
threshold and preserves authored UV/normal seams. The one small WarmInterior
component in each urban template stays intact; no whole material mesh is hidden.
The six rural profiles remove only their named `Front/Rear/Side*Window` geometry.
Existing `PorchLamp` nodes keep their names, visibility, material and geometry.

Each opening receives a real 68 cm recess with dark rear surface, side/top/bottom
reveals, sill, offset curtain, perimeter frame, mullions and inset physical teal
glass. The generated group has no orange emissive panel. Glass is named
`ResidentialWindow_DeepGlass`; its mesh and material both set
`userData.breakableGlass=true`, so `glass_breakage.mjs` can isolate an individual
`instanceId` without breaking neighbouring panes.

All apertures on one source mesh are clipped in one triangle pass. The previous
sequential CSG path took about 90 seconds for nine unique templates in Node; the
current real-GLB test takes roughly 0.25–0.35 seconds total. Results are cached by
shared template geometry, reference transform and aperture signature. Every
application owns a cache reference; the last `dispose()` restores source geometry
and disposes the cached result. The second clone of every test profile reports
zero cache misses.

Integration after verified GLB clone creation:

```js
import {
  applyResidentialWindows,
  createResidentialWindowQueue,
  residentialWindowCacheStats,
} from './residential_windows.mjs';

const windows = applyResidentialWindows({THREE, visual, instance:item});
group.userData.residentialWindows = windows;

// Optional: spread first-template work across animation frames. enqueue returns
// a job with {done,result,error}; call update() once per frame while pending > 0.
const windowQueue = createResidentialWindowQueue({budgetMs:5});
const job = windowQueue.enqueue({THREE,visual,instance:item});
windowQueue.update();
```

Call `glass.prepare(visual)` after `applyResidentialWindows`. At teardown call
`glass.dispose()` or `glass.reset(visual)` before `windows.dispose()`, because
glass breakage owns temporary per-instance geometry derived from the window mesh.

## Street lamps

`street_lighting.mjs` pins the actual placement hashes and authored Glow nodes of
`lamp_pine_v1`, `lamp_bellini_v1`, `lamp_civic_double_v1` and
`lamp_foundry_v1`. The 128 placed assets contain 176 luminaires. Existing Glow
node IDs and curved 528-triangle shade geometry stay in place; only their flat
`Lamp_Warm` material is replaced on each clone with transparent physical
`StreetLamp_ClearGlass`. The shade and material opt into breakage explicitly.

A small bulb and a soft circular ground pool are each one bounded InstancedMesh
for all fixtures. A fixed pool of eight PointLights exists from manager creation
until manager disposal. `update()` assigns those lights to the nearest fixtures;
far/day lights retain intensity zero. Approaching a lamp never adds a light and
therefore does not change the scene light signature or trigger a new material
shader variant. PointLight shadows stay disabled.

```js
import {createStreetLighting} from './street_lighting.mjs';

const streetLighting = createStreetLighting({
  THREE,
  scene,
  maxLights:8,       // fixed for the manager lifetime
  maxFixtures:192,   // placement needs 176
  activeDistance:34,
  groundHeight:(x,z)=>groundHeight(x,z),
});

const lampFx = streetLighting.prepare(visual,item); // after clone/hash check
glass.prepare(visual);                              // after lampFx

// focus and night are world-space player/camera focus and a 0..1 host value.
streetLighting.update({focus:hero.object.position,night:environmentNight});

lampFx?.dispose();
streetLighting.dispose();
```

If `/walk` has no authoritative night value, use `night:0` in normal play and a
temporary QA control to inspect `night:1`; the module does not invent a world
clock. The manager reports `fixtures`, `activeLights`, `fixedLights`, `night`,
`maxFixtures` and active ground pools.

## Automated validation

```text
node assets/maps/city_rebuild_v1/test_residential_windows.mjs
node assets/maps/city_rebuild_v1/test_street_lighting.mjs
node assets/maps/city_rebuild_v1/test_glass_breakage.mjs
```

The tests load real GLBs. They verify all nine pinned residential hashes,
connected-component extraction, untouched porch lamps, absence of generated
orange emissive panes, recess depth/frame batches, physical breakable glass,
cache reuse/refcount disposal and the optional queue. Lamp checks cover all four
real models plus all 128 placement clones/176 luminaires, stable authored IDs,
physical breakable shades, instanced bulbs/ground pools, fixed PointLight count,
nearest/far/day behavior and restoration.

## Required LIVE run

1. Inspect Old Town, Garden Walkup and Stepped Apartment head-on and obliquely:
   no orange squares or residual orange rim; wall openings, side reveals,
   curtain/sill and deep glass read separately.
2. Inspect all six rural profiles, including every front and rear window. Confirm
   porch lamps still exist and no facade/roof/vegetation triangle was removed.
3. Shoot two neighbouring residential panes one at a time. Only the addressed
   `instanceId` breaks; frame, curtain and neighbour remain.
4. At `night:1`, walk through pine, Bellini, civic-double and foundry districts.
   Confirm small visible bulbs, glass shades and ground light; watch active light
   reassignment while moving. Repeat at `night:0`.
5. Reload building/decor generation and confirm cache refs return to zero on old
   generation disposal, no duplicated groups and no failed model loads.

