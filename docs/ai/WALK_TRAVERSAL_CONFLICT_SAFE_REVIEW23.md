# `/walk` traversal — conflict-safe host review, 23 September 2026

Read-only review against the current shared files after the Transport3 changes.
No production host was edited.

## Checkpoint and gate

- `walk_preview.mjs`: `67C156DF219EB347CC729C7E3772D6368D20F0ED17F846563DE3B7D5445764D5`
- `building_vertical_navigation.mjs`: `6020B7095F717E5A6FC55A22B7C6875FECB40CFBBB1AA569B71DAABCC0FDA1ED`
- `WALK_TRAVERSAL_HOST_PATCH23.md`: `7BBEB6300BBB38753EC396076D3B702CB14862474F610FBBD394C060E526E6E7`
- `test_walk_traversal_host_source23.mjs`: PASS, `mode:"hold"`, all 16 frozen dependencies match.

The walk hash recorded inside `WALK_TRAVERSAL_HOST_PATCH23.md` is stale because
Transport3 has since added hooks.  This is not a traversal conflict: the semantic
HOLD gate is still clean.  Recheck this hash immediately before editing.  If it
changes again, stop and rerun the semantic gate/diff; do not apply a whole-file
patch by line number.

## Conflict-safe traversal hunks

These are narrow semantic edits and can be prepared independently, but they must
land together with the ladder legacy-pose guard.  A committed `partial` source
gate is forbidden.

1. Add the shared surface/route/pose imports beside the existing traversal
   imports.  Do not reorder or replace the Transport3 imports.
2. At `const surfaceMotion=createSurfaceMotion()`, supply only the agreed
   `.34 / 2.35 / .34` limits and add stable route/pose state nearby.
3. At `const traversalWorld=createTraversalWorld({`, add the stable
   `heroVehicleSurface`.  Remove only the duplicated
   `worldTrafficPresentation.blocks(...)` and fleet/car polygon terms from this
   callback; retain `explorationRailway.blocks(...)`, authored bodies, water,
   ceiling and `inBody` unchanged.  Do not alter `pedestrianAllowed`, vehicle
   exit admission, blast movement or driving collision worlds.
4. Split `tryBeginTraversal(direction)` by extracting its existing ownership,
   reset, weapon and UI work into `beginTraversalPlan(plan)`.  Both Space/E
   planning and the route adapter must enter that single owner.
5. Replace only the non-cover portion of `moveHeroOnFoot(delta)`.  Keep the
   cover early return, requested yaw, camera/target translation and source-car
   escape.  Forward posture height, swimming state, monotonic seconds and
   `sourceVehicleEscapeId`; preserve root Y for `free-fall`; consume no more
   than one traversal plan.
6. In `frame()`, update the vehicle surface exactly once after
   `stepSourceVehicleDrive(dt)` and local fleet movement, before either normal
   or QA on-foot routing.  This point is independent of the NPC bridge frame.
7. Replace only legacy traversal/ladder pose application with the motion pose
   orchestrator.  Keep the current base owners and order:
   `death > blast > vehicle > custody > interaction > explicit jump > traversal > ladder > water > cover > surface fall/landing > step > slope > walk`.
   Rebind the applicator after initial hero load and `applyHudHero`; reset route,
   airborne and orchestrator state on a hero replacement or hard owner change.
8. Add `heroVehicleSurface.dispose()` to pagehide without replacing the existing
   cleanup list.
9. In the separate vertical-navigation host patch, add only
   `applyLegacyPose:false` at the current constructor call and guard the legacy
   limb pose in `building_vertical_navigation.mjs`.  Preserve ladder root yaw,
   weapon holster, E begin/exit, Ctrl active slide and controller physics.

## Transport and input islands to preserve literally

Do not rewrite the surrounding blocks containing:

- `createNpcVehicleSurfaceAccess`, `createPlayerVehiclePhysicalResolver` and
  `createNpcVehicleIncomingBridge` imports;
- `npcVehicleIncoming` state, its construction, resolver registration,
  `beginFrame()` and pagehide unregister;
- `vehicleSurfaceAccess.query`, `playerVehiclePhysical(request)` and the complete
  `registerWalkTrafficNavigationResolver` dispatcher;
- source-vehicle 0.3 s E entry/exit, `stepSourceVehicleDrive(dt)`,
  `applySourceVehiclePresentation(dt)`, physical resolver and source identity;
- the on-foot/source-vehicle mutual exclusion and `sourceVehicleEscapeId`;
- Ctrl: ladder slide only while already active, otherwise cover; C: crouch only;
  E: the sole ladder admission and ordinary ladder exit;
- NPC `beginFrame` ordering and all cover, water, railway, building, custody,
  weapon and HUD hero-replacement hooks.

Shared neighborhoods (imports, `initNpcPopulation`, `frame`, pagehide) require
small insertion-only edits.  Never replace those functions wholesale.

## Acceptance commands

Run the source gate first.  It must say `integrated`, never `partial`:

```powershell
node assets/maps/city_rebuild_v1/test_walk_traversal_host_source23.mjs --expect-integrated
node --check assets/maps/city_rebuild_v1/walk_preview.mjs
node --check assets/maps/city_rebuild_v1/building_vertical_navigation.mjs
```

Then run the focused traversal/pose suite:

```powershell
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

Because the shared host now contains new Transport3 code, also run its direct
regressions before LIVE:

```powershell
node assets/maps/city_rebuild_v1/test_npc_vehicle_surface_access23.mjs
node assets/maps/city_rebuild_v1/test_player_vehicle_physical_resolver23.mjs
node assets/maps/city_rebuild_v1/test_player_vehicle_physical_world23.mjs
node assets/maps/city_rebuild_v1/test_npc_vehicle_incoming23.mjs
node assets/maps/city_rebuild_v1/test_vehicle_entry_hold_clock23.mjs
node assets/maps/city_rebuild_v1/test_vehicle_exit_host_surface.mjs
node assets/maps/city_rebuild_v1/test_vehicle_walk_integration.mjs
node assets/maps/city_rebuild_v1/test_world_vehicle_player_access.mjs
node assets/maps/city_rebuild_v1/test_world_vehicle_player_pose.mjs
```

Current read-only baseline: every command in that transport list passes except
`test_vehicle_entry_hold_clock23.mjs`, which fails in its Node harness before
game logic because `document` is undefined at `qa.onEntryHold`.  Treat this as
an explicit baseline/harness blocker; do not waive it as a traversal result and
do not change the production input flow to make the harness pass.

Finally review only the intended hosts and run the one-tab LIVE checklist:

```powershell
git diff --check -- assets/maps/city_rebuild_v1/walk_preview.mjs assets/maps/city_rebuild_v1/building_vertical_navigation.mjs
git diff -- assets/maps/city_rebuild_v1/walk_preview.mjs assets/maps/city_rebuild_v1/building_vertical_navigation.mjs
```

Use the existing single game tab for the continuous route and same-camera,
same-population p50/p95 comparison.  Do not open a second GPU game tab.
