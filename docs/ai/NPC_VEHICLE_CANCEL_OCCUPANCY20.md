# NPC vehicle cancellation and occupied-seat continuity — 20 September 2026

Status: source/world integrated and CPU verified. LIVE visual acceptance remains with Artist 19.

## Fixed

- Cancelling a partially completed civilian boarding now reverses from the current body fold. Exit progress starts at `1 - boardingFold` and then advances to 1 while the NPC walks back to the same authored door point. This removes the one-frame jump to a fully seated pose.
- The driver seat is reserved during both civilian and ambient `board` phases. Player entry is rejected with `Водительское место занято` until that transition finishes, so the player and NPC cannot overlap at the door or in the seat.
- A boarding reservation is returned without writing the seated-occupant cache. If the NPC dies or the trip is cancelled during boarding, no false seated corpse remains cached.
- Existing extraction of a fully seated live/dead driver, passenger exit, car physics and source entity identity remain unchanged.

## Production files

- `assets/maps/city_rebuild_v1/civilian_parking_trip_source.js`
- `assets/maps/city_rebuild_v1/npc_vehicle_hijack_source.js`
- exact marked copies in `world.html`

## Regression coverage

- `test_npc_vehicle_access.mjs`: actual source cancellation during partial boarding, physical reverse exit, exact progress mapping.
- `test_npc_vehicle_hijack_source.mjs`: board-phase seat reservation and rejected overlap, plus existing live/dead extraction and entry/exit cases.
- `test_npc_vehicle_transition_continuity.mjs`: actual compact sedan and actual male/female GLBs. Worst cancellation-frame bone movement: male 0.04785 m, female 0.04940 m (limit 0.10 m).

All related source/world equality, traffic binding, seated contact, hero pose, hijack pose, impact and `check_world.py` checks pass. The hijack VM input block remains approximately 0.004 ms/update p50 and 0.005 ms/update p95; this is CPU-only, not whole-scene FPS.

## LIVE check

Reload the existing single game tab through Artist 19. Verify: begin entering a civilian car, trigger a threat mid-entry and observe a smooth reverse; try the driver door while an NPC is still boarding and confirm no overlapping entry; then hijack a fully seated driver and confirm the normal pull-out sequence still runs.

## Follow-up audit: exit, cull and confirmed death

- Alive exit actors recreated during a nearby cull reproduce the same `front_left` and `front_right` pose exactly for both actual character GLBs (`0 m` maximum difference). The source root and exit side remain stable.
- `test_npc_vehicle_death_continuity20.mjs` isolates a separate actor/death continuity defect without changing production death code. On the first confirmed-death frame, the current vehicle pose is reset before the death pose is applied. Worst bone displacement is 0.4974 m across actual male/female board, seated and exit cases, despite an unchanged source root and yaw.
- Death-state save/dispose/recreate/restore is deterministic (`0` to `4.44e-16 m` difference), so nearby culling is not the cause. The fixture's default mode records the baseline; `--require-fixed` enforces the future `< 0.10 m` acceptance limit.
- The defect and fixture were transferred to Coordinator 20, owner of death continuity. Transport production files remain untouched by this follow-up audit.
