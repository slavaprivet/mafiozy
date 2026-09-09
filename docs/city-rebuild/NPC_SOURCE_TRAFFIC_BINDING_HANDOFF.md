# NPC source traffic binding — 2026-09-10

`walk_preview.mjs` creates `createWorldTrafficPresentation` before NPC population. Population's optional `onSnapshot(snapshot,{time,dt})` consumes its existing 10Hz source read; `onBeforePose({time,dt})` updates traffic once each frame before NPC poses. No extra source read, fleet insertion or AI is introduced.

Source `civilianTripCarId` uses `_threeVehicleEntityId(_civilianTrip.car)`. Binding resolves only an attached, visible traffic actor. Until that actor exists the NPC stays visible with the previous ordinary behavior.

The authored vehicle seat anchor is a **hero root anchor**, not a hip anchor (`driverRootY=floorTop-.25`). The integration uses the actual `seats.front_left.anchor` world position and vehicle `poseOccupant`. It then preserves the resulting visual world transform under the NPC visual pivot and restores the authoritative root position/yaw. This keeps vehicle-specific recline and steering grips; no guessed hip offset.

Page hide disposes traffic alongside NPC population. Existing 250ms `document.body.dataset.npcWorld` diagnostics now include `traffic`. Unsupported models and metadata-only damage/sirens remain explicitly reported by the traffic adapter.

Validation: `test_npc_traffic_binding.mjs` compares every bone world position against direct native `poseOccupant` for actual compact_sedan and both hero GLBs; also verifies shared snapshot reads and update ordering. `test_world_traffic_presentation.mjs`, `test_npc_behavior_binding.mjs` pass. Walk module syntax check passes. Browser/live city verification is parent-owned and has not been claimed by this handoff.
