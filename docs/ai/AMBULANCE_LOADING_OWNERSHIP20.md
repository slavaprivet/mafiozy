# Ambulance loading ownership 20

## Result

- A wounded source NPC stops crawling as soon as `_ambulanceLoading` starts.
- During lifting, the source NPC remains the only body until `liftProgress > .42`.
- At the threshold, source visibility and stretcher-body visibility switch in the same update.
- Existing civilian helpers cancel their stale route/gesture when the patient is loading or carried; new helpers do not claim that patient.
- Cancellation keeps the same patient object, injury and position before transfer. After transfer it restores that same object at the stretcher position.
- Death during loading remains fatal and is never healed by cancellation.

## Files

- `assets/maps/city_rebuild_v1/ambulance_transport.js`
- `world.html`
- `assets/maps/city_rebuild_v1/test_ambulance_loading_ownership20.mjs`

## Verification

- `test_ambulance_loading_ownership20.mjs`
- `test_ambulance_transport.mjs`
- `test_npc_hospital_actual.mjs`
- `test_corpse_dispatch_policy.mjs`
- `test_npc_lifecycle.mjs`
- `node --check assets/maps/city_rebuild_v1/ambulance_transport.js`
- `py -3 check_world.py`
- scoped `git diff --check`

All passed. CPU helper test remains about 0.0024 ms p50 / 0.0035 ms p95 per update. Loaded-scene GPU/FPS still requires the single live game tab.
