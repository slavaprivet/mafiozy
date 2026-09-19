# Hero custody seat in the actual source traffic vehicle — 13 September 2026

Root LIVE after camera correction showed the real police car and its seated police NPCs, but the player retained a standing pose at vehicle center.

`hero_custody_vehicle_pose.mjs` now resolves the exact source traffic car and applies the existing `createNpcTrafficVehicleBinding` / `resolveNpcVehicleBinding` / `applyNpcVehicleBinding` / vehicle `poseOccupant` path to the male/female hero. Source root position/rotation remain authoritative; only the visual skeleton binds to the real rear seat. No active fleet/car switch, player driving ownership, vehicle controls or navigation changes.

`world.html` `_threeCustodyPassengerSeat` returns a free rear_left/rear_right seat only when phase=transport, playerBoarded is true, and playerAttachedVehicleId matches the custody vehicle. Occupied/reserved police seats are excluded. getPlayerState publishes custodyVehicleId and custodySeatId. No rear seat means no overlapping fallback occupant.

`walk_preview.mjs` prepares/relinquishes this pose before normal hero/health animation and applies it after source traffic presentation updates. Transport uses the seated pose rather than also running the generic idle/weapon pose. The ordinary weapon model stays hidden. A missing asynchronous car actor hides the standing fallback until the exact seat exists. Unloading/escort restores normal skeleton presentation; actual health death retains higher priority.

Checks: `node assets/maps/city_rebuild_v1/test_hero_custody_vehicle_pose.mjs` loads the real police_interceptor GLB and both canonical hero GLBs. Checks rear seat identity, lower head/folded thigh, authoritative root unchanged, current vehicle transform following, pending actor hide/reappear, no accumulated offsets without idle reset, normal pose on unloading and death priority. Source seat selector tests cover occupied rear seats and mismatched/unboarded attachment. `test_npc_source_camera.mjs` and `test_world_walk_health_integration.mjs` remain GREEN.

CPU 50 warmup +250 samples per real rig: prior generic idle p50/p95 male .0138/.0210ms and female .0121/.0139ms; actual seat pose male .0756/.0992ms and female .0699/.1273ms. The generic idle call is skipped during active transport, avoiding duplicate animation work. This is a small single-hero cost; **производительность общей сцены не проверена**. No additional browser/GPU opened; root owns LIVE convoy verification. Rendered roof/door appearance still needs that live viewing. Existing server custody/HP/ownership contracts are unchanged.
