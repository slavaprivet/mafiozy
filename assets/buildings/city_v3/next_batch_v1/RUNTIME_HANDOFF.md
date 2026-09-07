# Next three buildings runtime slice

`runtime.v1.js` is executable host-injected Three.js integration, not another
asset catalogue. Original GLBs, manifests, binding snapshot and its hashes are
unchanged. Its availability is **not a live-game PASS**.

## Renderer call

Call `installCityV3NextBuildings({THREE,GLTFLoader,scene,bridge,originR,originC,
worldScale,signal,renderer})` before generating the world snapshot / legacy
render geometry. The returned object contains `roots`, `receipt`, `activation`
and idempotent `dispose()`. Use the host's bounded startup AbortSignal. Late
parse completion checks cancellation before adding any scene object.

The three original files contain 194, 166 and 130 mesh nodes respectively and
**no authored LOD**. No invented LOD or performance PASS is claimed. Keep this
slice to these three placements and measure GPU cost in the actual game.

## Atomic map bridge

The caller provides two synchronous methods:

- `activateCityV3NextBuilding(receipt)` validates all three current map parcels,
  exact legacy IDs and tiles, both road probes and access corridors, protected
  POIs, street objects, water and rail. Only if every row passes does it
  suppress the three exact legacy shells and register new footprints/door
  identity. Return `{ok:true,rollbackToken}`; otherwise `{ok:false,reason}`
  **with no partial mutation**. An exception must likewise leave no mutation.
- `rollbackCityV3NextBuilding(rollbackToken)` restores all previously removed
  identities/tiles/doors and unregisters new collision bodies, returning
  `{ok:true}`. On refusal the module retains visible GLBs instead of leaving
  invisible active collisions behind.

Receipt schema: `mafiozi.next-buildings-runtime-receipt/v1`. Its `buildings`
array has exactly `gun_shop@1`, `bookmaker@1`, `strip_club@1`. Each includes
`assetSha256`, `legacyStructureId`, `legacyTileBounds` (original snake_case
members), `legacyTileIds`, `legacyDoorId`, `legacyDoor`, `gameplayPoi:null`,
`centerGridRC`, `uniformAssetScale`, `yawDeg`, `footprint`,
`clearanceFootprint`, `pad`, `groundCollisionNode`,
`groundCollisionBoundsLocal`, `door`, `service`, `loaded`, `registered`,
`eligible`, `visibleMeshCount`, `doorAnchorGridRC`, `serviceAnchorGridRC`,
`runtimeWorldScale`. `door` and `service` contain `anchorR`, `anchorC`,
`corridors` (array, including the strip club L route), `roadProbe:{r,c}` and
`routeGridRC`. A building facade does not create/replace an unrelated fixed
`BUSINESS_POIS` record.

All three models are fully decoded, hash-checked and added to scene before
the single synchronous activation. No partial-success path exists. Map
preflight rejection removes all staged GLBs and leaves legacy intact.

## Corrected collision and source discrepancy

`footprint` uses actual named, mesh-verified ground-contact plinths, not the
old candidate's full render AABB. The old visual AABB remains as
`clearanceFootprint` for overlap rejection; pad stays unchanged.

| Key | minR | maxR | minC | maxC |
|---|---:|---:|---:|---:|
| gun_shop@1 | 86.42921951219512 | 88.06287804878049 | 16.36512195121951 | 18.960731707317073 |
| bookmaker@1 | 46.48163414634146 | 49.13529268292683 | 46.344219512195124 | 47.96958536585366 |
| strip_club@1 | 96.74451219512196 | 98.43621951219512 | 149.59524390243902 | 151.78451219512195 |

These rectangular proxies conservatively include the plinth bevel; they do
not claim exact convex or rounded collision. Decorative overhangs do not
expand the wall collision.

The frozen strip-club manifest mislabels the accepted approach `(0,0,5.7)`
as the public door node. Real GLB leaf centers are `(±.72,1.8,4.93)`.
Both leaf positions are now independently validated through GLTFLoader raw
node associations. The accepted interaction anchor remains unchanged and is
explicitly labeled `door.anchorRole:'accepted-front-approach'`; actual paired
door threshold is separately provided as `door.visibleThresholdGridRC`.
This does not authorize moving that interaction anchor, baking a new door or
removing the model's door leaves. Other buildings use
`anchorRole:'authored-door-threshold'`.

## Executable verification

`node assets/buildings/city_v3/next_batch_v1/test_runtime.mjs`

Uses actual Three.js / GLTFLoader, defaulting to the existing local Three
0.180 test install at `%TEMP%/mafiozi-glass-three180/node_modules/three`.
Override with `THREE_MODULE_ROOT` when needed. No browser is opened.

Verified: immutable metadata/asset hashes, actual GLB bounds, raw-name node
resolution despite GLTFLoader name sanitization, doors/service positions,
ground-body bounds, nonzero mesh counts, recenter/yaw, host scale/origin,
all-three-before-single-activation, host rejection cleanup, tampered asset
failure before map activation, pre-cancel and idempotent rollback.

Host map bridge and renderer wiring are now implemented in `world.html` and
`three_preview.js`. No extra hidden opt-in: the existing
`preview=1&previewcityv3=stage-a&cityv3buildings=1` gate loads this slice.
`cityv3focus=gun_shop%401`, `bookmaker%401` and `strip_club%401` work through
the shared focus bridge. Startup has a 20-second cancellation deadline;
failure preserves all three original shells.

The host preserves original resident door IDs and interior tile identity;
cached resident door positions are rebound transactionally to the accepted
approach and restored on rollback. NPC collision classification understands
walkable replacement aprons without destructively changing original MAP=1
tiles. Street objects/lamps, protected POIs/HQs, water, roads, active decor,
business exteriors, reserved rail and complete L-shaped service access are
checked before activation. Map mutations are not used for suppression.

`node assets/buildings/city_v3/next_batch_v1/test_host.mjs` verifies complete
host syntax, loader/host receipts, preflight against the frozen real-map
snapshot, 16+16+12 addressed tiles, both access routes, preserved door IDs,
all-three rollback and protected-object rejection. The older static test
now tests gated integration instead of asserting the renderer never loads
this folder; its immutable artifact assertions are unchanged.

Still required from coordinator: one-tab live day/night verification at the
three focus points, door interaction and collision walkaround, NPC
appearance/exit visuals, vehicle clearance and frame-time assessment. Do not
call these executable geometry/host tests visual approval.
