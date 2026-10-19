# NPC shared pedestrian passability gate — 23 September 2026

Read-only audit of the current `world.html` ↔ `/walk` bridge. No production
file was edited.

## Verdict

**NPC pedestrian integration: NO-GO.** The pure shared classifier and bounded
edge probe both pass their own tests, but neither is imported by a production
host. The bridge still exposes the old synchronous point/body query and cannot
represent a deferred edge.

**NPC vehicle surface policy: GO for its scoped router.** The current vehicle
router admits ordinary routes on roads and requires an authored parking,
driveway, service-access or verified lane identity off-road. Generic NPC calls
cannot select the private active-player physical escape path.

## Current pedestrian path

`walk_preview.mjs` constructs `createNpcNativeNavigation` and registers
`npcNativeNavigation.query` directly through
`registerWalkNpcNavigationResolver`. That query supplies:

- point `blocked/depth/surface` results;
- a `mode:'sweep'` result for authored solid polygons;
- old `terrainAllows`, currently backed by `landscape.canWalk(...)` or the
  native land mask.

It does not call `createPedestrianSurfaceMotion`,
`createNpcPedestrianSurfaceConsumer` or `createNpcPedestrianEdgeProbe`. It
therefore does not share the `.34 m` step, continuous grade, scramble,
storey/reference-Y, ledge and capsule semantics defined in
`pedestrian_surface_passability.mjs`.

The World side remains boolean. `npcPassable` and `npcWaypointOk` reject a
native `road` for ordinary residents and fall back to legacy tile classes
8/9/14. `npcPassableForSnitch` separately admits roads. This is actor-specific
tile policy, not “every physically passable pedestrian surface.”

`_npcPathPassable`, native visit `edgeClear`, wander edges and route advance
call `mode:'sweep'` synchronously. Most treat only
`{swept:true,blocked:true}` as blocked. A future `{pending:true}` response
without a host migration could therefore be treated as clear or fall back to
the legacy path. The pure edge-probe file explicitly says it is not wired to
the boolean hook.

## Scheduler finding

World already has a fair route-search scheduler: `_npcRouteWorkQueue`, an
eight-actor cohort and a shared 4 ms deadline preserve A*/directed search
between frames. This is useful but is not an edge-probe scheduler.

Missing state:

- no per-search edge retry token;
- no edge signature/generation binding;
- no distinction between `clear`, terminal `blocked`, and `pending`;
- no call to `npcPedestrianEdgeProbe.beginFrame()`;
- no cancellation of a token when actor, route generation, destination,
  storey, height, swimming state or ignored vehicle changes.

Consequently long 4.1–32.8 m route edges cannot use the probe's hard work cap
without either losing progress or misclassifying `pending`.

## Exact missing hooks

### `/walk`

1. Import `createPedestrianSurfaceMotion` (or the compatible
   `createHeroSurfaceMotion`) and `createNpcPedestrianEdgeProbe`.
2. Construct one shared motion object from `traversalWorld.supportHeight`,
   `sample`, `canOccupy`, semantic walkability and terrain slope. Player and
   NPC consumers must receive this same policy; vehicles must not.
3. Construct one NPC edge probe with `npcSupportCache.sample`/reference Y,
   scale 4.1 and the tested hard work budget.
4. Extend the registered navigation resolver with a distinct
   `mode:'pedestrian-edge'` branch. Keep current point and authored-solid sweep
   modes for placement/legacy callers during migration.
5. Call the edge probe's `beginFrame()` beside the existing navigation/cache
   frame resets, before World route requests are serviced.
6. Forward `from.y`, `to.y` when known, capsule height, swimming and
   `ignoreVehicleId`; return the complete terminal/pending result unchanged.

### `world.html`

1. Add one tri-state edge helper around `_walkNpcNavigationResolver`:
   `clear`, `blocked`, or `pending`. It must never coerce pending to either
   success or permanent blockage.
2. Store the returned retry token on the owning directed/wander search and bind
   it to actor, search generation and exact edge. Retry it on the next admitted
   scheduler frame. Clear it on route cancellation, goal drift, turn-around,
   death, vehicle/ladder/water owner change or resolver replacement.
3. Migrate `_npcPlanNativeVisitRoute.edgeClear`, its direct connector,
   `_npcPathPassable`/`_npcAdvanceRoute`, wander edge calls and empire terminal
   connectors to the tri-state helper. While pending, pause the actor and keep
   `_routeSearchPending=true`; do not publish or advance the edge.
4. Replace the ordinary `nativeSurface!=='road'` and 8/9/14 admission with the
   shared physical pedestrian result, while retaining explicit gameplay zones
   such as arena/lair/prison only as separate policy overlays.
5. Publish diagnostics for pending edges, retries, stale-token cancellations,
   terminal blocks and hard work units so LIVE can prove bounded continuation.

## Vehicle separation

Keep the current vehicle path separate:

- `npc_vehicle_navigation.mjs` defaults to `roadsOnly`;
- an off-road route must provide an authored access identity;
- `npc_vehicle_surface_access.mjs` validates parking lots/bays, driveways,
  service routes or a verified lane segment;
- mountain/grass and forged or unrelated access identities fail closed;
- `queryPhysical` is a private, identity-checked active-player escape sweep,
  not a generic NPC route mode.

Do not route cars through pedestrian scramble/step semantics.

## Evidence

Current pure/read-only tests:

```text
PASS test_npc_pedestrian_edge_probe.mjs
PASS test_pedestrian_surface_integration_contract.mjs
PASS test_npc_native_navigation.mjs
PASS test_npc_native_route_edges.mjs
PASS test_npc_vehicle_surface_access23.mjs
```

The first two prove the candidate policy/protocol. They do not prove production
integration because the production import/hook/retry sites above are absent.
