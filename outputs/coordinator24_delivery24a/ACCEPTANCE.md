# Cargo24a accepted scope — 30 September 2026

Candidate20 fixes two reproduced defects from accepted23h: a held movement key was
lost when taking a card through F/E; direct E while aiming with RMB reset the camera
before the second ownership/aim check and could reject the selected weapon.

Only four runtime/notes files were promoted with before/after SHA guards. All1724
other shared project file hashes were retained, including other owners' WIP.
The user export is the exact frozen candidate20, not an export of those shared WIP.

- Exact PCK: `634b9d3b48e4502538331da9b9e9efdb1641cfc83f04c40c65bd592bd4db7dd5`.
- Independent closure:209 source pins and316 embedded payloads verified. Six
  imported scenes differ only in internal node IDs; main scene also has the
  generated script resource UID. Geometry/material/animation bytes unchanged.
- `compiled20_headless01`:78 PASS, immediate release on all9 configured mappings,
  UID/ammo conservation, no unintended shot/jump, Esc/blur/authority negatives.
- `coordinator24_cargo_aim_race/compiled20`:28 PASS, original attached RMB camera,
  single E commits the exact UID with ammo preserved.
- `compiled20_focused02`:136 PASS, normal focused on-screen GPU window. Modal E
  restores actual mouse capture without a click, continued W works and stops
  after release. Five notes agree with runtime revision; no restart banner.
  Native input events are injected by the harness; this is not a manual OS-key test.
- Original3 NPC,8 buildings,377 colliders and377 shapes retained throughout.

The prior `compiled20_focused01` failure is preserved. Its fixed-three-frame stop
assumption was invalid with multiple physics ticks per rendered frame. The final
test records player movement serial and actual velocity. Both modal and ordinary
W release begin at1.8m/s, decay by0.3m/s per completed step, reach zero within6steps,
then remain still for3more. Production was not changed to satisfy the test.

Comparable baseline16/candidate20 sequential GPU runs used the same scene, camera,
settings, natural3NPC, warmup and cache policy:240 samples per phase. Wall p50
2.720→2.780 /2.833→2.862 /2.771→2.856ms; p95 3.758→3.430 /4.539→3.865 /
4.393→4.087ms. Max4.772→4.991 /11.166→10.180 /10.146→7.389ms.
GPU p95 2.582→2.652 /2.753→2.734 /2.669→2.655ms. Drawcall p95 unchanged
670/746/695. Static memory about0.24MB lower, VRAM2.36MB lower; no content cut.
No material sampled regression. Runs are offscreen NO_FOCUS conditional performance,
not whole-city FPS. First new-model hover was SKIP in both sides at fixed attached yaw.

Scope limits: Windows Computer Use capture failed before manual input could be
performed. The two concrete fixes are accepted, but the entire intermittent
extra-click/freeze report is not declared resolved. Actual blur/focus retains the
existing deliberate click-to-resume policy. RPG19, full migration, full-city NPC,
self/vehicle/building/server RPG damage and repeated body impulse remain pending.
