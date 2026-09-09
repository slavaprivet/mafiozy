# Source traffic presentation — 2026-09-09

`assets/maps/city_rebuild_v1/world_traffic_presentation.mjs` is prepared, not connected to walk_preview.

API: `createWorldTrafficPresentation({THREE,RoundedBox,loader,scene,groundHeight,originR,originC,worldScale:4.1})`. Feed full current `bridge.getDynamicEntities().cars` into `sync(cars)` after each source snapshot; call `update(dtSeconds)` once per render frame. `getActor(sourceId)` provides the real authored vehicle object/seat/door anchors. `diagnostics()` reports skipped IDs and model failures. `dispose()` releases actors and cached source assets. `whenIdle()` is for tests, not the render loop.

There is no fleet simulation, AI, source movement, new authoritative ID, car spawn, driver or ownership write. Positions map x=(c-originC)*4.1, z=(r-originR)*4.1, yaw=PI/2-ang. Exponential interpolation follows latest snapshot without extrapolating. Movement over15m snaps and does not spin wheels. Cosmetic wheel travel is signed actual rendered movement, source steer/braking only. Source paint changes the private LowerBody material; damage and emergency fields remain read-only metadata for a later verified source-effects adapter.

Models are loaded sequentially, cached once per profile. At most one actor is instantiated per update. Actors removed from source snapshot are disposed. Models' geometry/material clones are private; shared source textures live until entire presentation is disposed.

Mapping uses the actual world CAR_MODELS flags: sedan/taxi→compact_sedan; hatch→city_hatchback; wagon→family_wagon; classic/limo→executive_sedan; sport/coupe/cabrio/muscle→sport_coupe; SUV→city_suv; van→delivery_van; pickup/truck→utility_pickup; bus/ambulance/fire/police→corresponding authored profiles. Exact authored profile IDs also accepted. These are family approximations, not claims that exotic source silhouettes, taxi signage or limo proportions have been individually authored. Helicopters, tow trucks, armored police and unknown models are skipped and reported; never replaced with generic police cars.

Not yet implemented: wreck geometry, fire/smoke, siren animation, authoritative door-progress binding, source-size/collision-anchor reconciliation, integration/live review. Do not claim finished traffic migration or NPC driving animation from this adapter alone.

`node assets/maps/city_rebuild_v1/test_world_traffic_presentation.mjs` PASS: stable source identity,4.1 coordinates, special vehicle skips, sequential cache, one actor/frame, interpolation, no source mutation, teleport no wheel spin, removal/idempotent disposal.
