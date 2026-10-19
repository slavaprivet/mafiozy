# `/walk` traversal host patch — HOLD until Coordinator20 slot

This is the exact bounded production integration first prepared against commit
`19fc1fb`.  During HOLD, Transport3 added only the incoming-fire bridge import,
state, init/beginFrame and disposal hooks to `walk_preview.mjs`; the movement,
traversal and pose anchors stayed unchanged.  The current review checkpoint is:

- `walk_preview.mjs` — `C2BA5F4F86862D3AE08BE334208D6419F9875A37D9EA091BC0AD76B9D6057574`
- `building_vertical_navigation.mjs` — `6020B7095F717E5A6FC55A22B7C6875FECB40CFBBB1AA569B71DAABCC0FDA1ED`

No traversal production host edit is authorised yet.
`test_walk_traversal_host_source23.mjs` uses semantic anchors rather than a
whole-file lock so unrelated owner hooks can land safely.  It must report
`hold` before the slot and `integrated` after this patch is applied; any mixed
state fails as `partial`.

## Frozen dependency manifest

| Dependency | SHA-256 |
| --- | --- |
| `pedestrian_surface_passability.mjs` | `1CDAA50C14F017AA642EF7958F95F621AC8196A59A62D8A09C33410641CE30D7` |
| `pedestrian_player_route_adapter.mjs` | `FFFD2F3F4C7CBB7934EC36AC3799809EF3E65EA14FE4E07224586C68ABF9E7EA` |
| `npc_pedestrian_edge_probe.mjs` | `8EA700C5654C9797756175BC19DC3F51EEFAD114C24A0E69AB2931D5FA4CA82F` |
| `hero_airborne_motion_pose.mjs` | `1C7499D3E38A2C7C0C59502A55478100B97A7F67106270065208BCBE5CA9CA71` |
| `hero_obstacle_motion_pose.mjs` | `347C50E4D0785D9E8FF4AF9EA991BA297607345D568AF4AEBA5140772FFF007A` |
| `hero_ladder_motion_pose.mjs` | `BFDE816739B364D03BF1F0E80998D13137B1E8E9231AF9467795D587B1BD887A` |
| `hero_slope_motion_pose.mjs` | `9510B0F5A73B83DE9BBF956F88C29980764EC6F13165701BF1CD44CCC7BC5E00` |
| `hero_motion_pose_orchestrator.mjs` | `C98222D318C66780E58ECEB315882E175631FF5FA93F060437E835B66DE79F39` |
| `hero_surface_motion.mjs` | `6C6623348EE6BCD233F7C09432801B5B857892EC39F8D7D6AF086F68BC208929` |
| `pedestrian_surface_integration_contract.mjs` | `A765264735FFD373CA505DD11F7417F453C2CED3079472F0740845FDF1AE065A` |
| `hero_vehicle_surface.mjs` | `3680D9681909AB2BDF1C3C3703316E401B5793EC274D1EC8646DE1C7D8D82233` |
| `hero_traversal_world.mjs` | `49D3CA9DEECF5C12CCDCFB62BA3F31B7BEE84AF320A0D1AB7BED9BDF62733094` |
| `hero_traversal.mjs` | `479E7D0B765316006C9438204A121E874CC09D8A4A6D55027CC28A1271982F86` |
| `surface_motion.mjs` | `A9CACFD619E65DA7F75CFE5AC756A97C003BD0F6D4BBE04D21D7EC6852CCE8F6` |
| `roof_ladder.mjs` | `A6A2982426053DF4A6AC8B38DB029EC36AF97AFA0FA868787C688BCA8B2B1733` |
| `roof_ladder_pose.mjs` | `E11ECFFCB1243D9AF6C8F1ACD7DDFFC6D165065B281606D510EB4C9A2EDF1003` |

The source gate verifies every entry before either HOLD or integrated mode is
accepted.  Shared support modules must be imported, never copied into the host.

## Atomic host changes

Only these two production files may change in the player patch.  NPC retry
scheduling and road vehicle access remain separate Artist21/Transport3 work.

### `walk_preview.mjs`

1. Import `createHeroSurfaceMotion`, `createPedestrianPlayerRouteAdapter`,
   `createHeroVehicleSurface`, and the pose orchestrator, applicator, surface
   airborne adapter, and ladder-state adapter.
2. Construct `surfaceMotion` with `stepHeight:.34`, `maxSlope:2.35`, and
   `snapDown:.34`.  This keeps a 34 cm curb and the admitted scramble grade in
   agreement with the new route classifier.
3. Construct one stable `heroVehicleSurface`.  Its vehicle supplier is exactly
   the local fleet plus `worldTrafficPresentation.getActors()`.  Update it once
   after vehicle motion and before player walking.  Pass it to
   `createTraversalWorld`; remove fleet/world-traffic body rejection from that
   world's `blocksDynamic` callback, because the height-aware surface owns both
   moving-car blocking and parked-car support.
4. Construct one `heroSurfaceMotion` from `traversalWorld.supportHeight`,
   `canOccupy`, and `sample`, plus `traversalMapWalkable` and
   `landscape.slopeAt` for semantic terrain.  Construct one player route adapter
   and keep `heroSurfaceSpeedScale` and the last route frame as stable host
   state.
5. Split current `tryBeginTraversal` into `beginTraversalPlan(plan)` and the
   existing direction-based planner.  A consumed route traversal must enter the
   same jump owner and the same reset/weapon/UI path; no second traversal state
   machine is permitted.
6. Replace only the non-cover body of `moveHeroOnFoot`: route the requested X/Z
   delta through the player adapter with posture height, swim state,
   `sourceVehicleEscapeId`, and monotonic seconds.  Apply returned X/Z while
   preserving root Y.  A `free-fall` result is therefore handed to the existing
   `surfaceMotion` gravity step without a Y snap.  Consume at most one returned
   traversal through `beginTraversalPlan`.  Keep requested-yaw behaviour and
   camera/target translation.  Apply `nextSpeedScale` to the following input
   frame and clear it whenever another owner takes control.
7. After `surfaceMotion.update`, derive signed grade from actual Y change over
   actual horizontal travel.  Feed that grade, the existing walker gait output,
   the latched step metadata, and the surface-airborne observer to the pose
   orchestrator.  Do not invent hand/foot contacts; missing verified contacts
   retain the articulated fallback.
8. Preserve owner order:
   `death > blast > vehicle > custody > interaction > explicit jump > traversal > ladder > water > cover > surface fall/landing > step > slope > walk`.
   Existing ordinary jump, blast, vehicle, custody, water, and cover base poses
   remain their owners.  Traversal uses the new obstacle layer instead of the
   legacy direct `applyTraversalPose`.  Apply the orchestrated layers once,
   after the normal walk base pose.  Honour its holster/restore result using the
   existing weapon visibility.
9. Rebind the pose applicator after initial hero load and HUD hero replacement.
   Reset route/airborne/orchestrator state on replacement and on hard ownership
   changes.  Dispose `heroVehicleSurface` on pagehide.

### `building_vertical_navigation.mjs`

The duplicate pose is confirmed: `update()` invokes `pose()` and
`walk_preview` invokes it again in the same frame.  Add one constructor option,
`applyLegacyPose=true`.  `pose()` must always keep ladder root yaw and weapon
holster, but call `applyRoofLadderPose` only when that option is true.  `/walk`
passes `applyLegacyPose:false`; its single pose application is the orchestrator.
The E mount, upper/lower entry, camera translation, Ctrl slide and controller
physics remain unchanged.

## Required source and runtime gates

Before LIVE, run the source test in integrated mode and all focused suites:

```text
node assets/maps/city_rebuild_v1/test_walk_traversal_host_source23.mjs --expect-integrated
node assets/maps/city_rebuild_v1/test_pedestrian_surface_integration_contract.mjs
node assets/maps/city_rebuild_v1/test_pedestrian_player_route_adapter.mjs
node assets/maps/city_rebuild_v1/test_hero_surface_motion.mjs
node assets/maps/city_rebuild_v1/test_hero_mountain_surface_regression.mjs
node assets/maps/city_rebuild_v1/test_hero_traversal_world.mjs
node assets/maps/city_rebuild_v1/test_hero_vehicle_traversal_actual.mjs
node assets/maps/city_rebuild_v1/test_hero_vehicle_surface.mjs
node assets/maps/city_rebuild_v1/test_hero_airborne_ladder_pose.mjs
node assets/maps/city_rebuild_v1/test_hero_slope_motion_pose.mjs
node assets/maps/city_rebuild_v1/test_hero_motion_pose_orchestrator.mjs
node assets/maps/city_rebuild_v1/test_ladder_input_contract.mjs
node assets/maps/city_rebuild_v1/test_roof_ladder.mjs
```

The one existing Coordinator20 tab then runs the agreed continuous route and
same-camera three-run performance A/B.  No extra GPU tab is opened.  Time of day
is a later atomic patch after traversal acceptance.

## Known optimisation follow-up

Functional and bounded-work gates are green.  Strict zero-allocation is not
claimed: the player adapter still creates route result objects, and existing
`hero_walk.mjs` IK helpers allocate vectors/quaternions.  The measured and
re-entry-safe plans are in `PEDESTRIAN_HOT_ALLOCATION_AUDIT23.md` and
`HERO_WALK_IK_ALLOCATION_PLAN_ASTRA15.md`; neither optimisation belongs in this
host patch.
