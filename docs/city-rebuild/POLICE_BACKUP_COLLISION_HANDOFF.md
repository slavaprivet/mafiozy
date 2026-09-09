# Police backup and prison collision — 2026-09-10

Source changes are confined to police movement helpers in `world.html`. Wet/navigation owner supplies `_npcRouteWalkBlocked(r,c)` from the registered walk navigation callback; this patch consumes it without changing water helpers.

- `_movePoliceBackup`: removed direct coordinate movement and the distance-over-12 teleport. Backup units retain their own role/HP/action fields and reuse `_movePoliceFootCop`'s bounded shared cached BFS. Coordinates are synchronized between backup r/c and police x/y. Arrival, walking/running admission and speed bounds remain.
- `_movePoliceFootCop`: each step now validates the complete segment and body instead of only the destination point, preventing a thin obstacle from being skipped.
- `_policeCrewPassable`: native object/water rejection precedes the special prison layout branch. A free prison tile no longer overrides native obstacles.
- `_movePrisonEscortCop`: a sampled segment uses `_prisonEscortBodyPassable`, checking native collision and the five-point body footprint. Existing lawful personal-release/vehicle-gate exceptions remain for escort authority; they do not exempt unrelated objects or water.

Source police already using `_movePoliceFootCop` / `_moveMurderResponseCop` inherit the segment correction. Existing spawn/recovery placement is separate from locomotion and was not removed. No server combat, arrest sequencing, rewards, car/dog movement or gang capture changes.

Validation: `test_police_backup_navigation.mjs` executes the real police BFS, route cache and mover against a source wall and a native callback car obstacle at 30/60/144 FPS. Units reach the far side via detours without body overlaps, no frame exceeds 7.8 m/s, and a distant unit cannot teleport. It also verifies prison native rejection and lawful gate admission. Baseline fails wall-body collision.

Existing `test_police_foot_navigation.py` passes: 12 arrivals, 0 overlap frames. `test_service_npc_hero_pace.mjs` and `test_police_murder_custody_transport.py` pass. Service test imports the new segment/body dependencies; its empty-map collision stubs remain appropriate to its pace-only scope. Parent owns live scene verification and the native callback installation.
