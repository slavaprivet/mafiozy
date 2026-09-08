# Vehicle contacts, blast and exit visibility — 2026-09-08

Integrated in the shared project served at http://127.0.0.1:18538/walk. This is walk preview integration, not a server/world migration. Existing IDs, buildings, ownership and interiors are preserved. Do not restore an older complete walk_preview.mjs: concurrent artist changes must remain.

## Applied behavior

- Second identical sedan is placed at the first safe position, normally 14 m ahead and perpendicular to the main car. It is a movable collision target with independent damage, rollover and explosion; it is not independently enterable yet.
- vehicle_contact.mjs and car_drive.mjs expose SAT contact location, normal and relative impact/slide speed. vehicle_damage.mjs produces localized cumulative dents and scratches. Bullet crater size/depth follows weapon damage. Glass hits still do not subtract body HP.
- vehicle_pair_impulse.mjs and crash_partner.mjs resolve mass-dependent collision impulses. Both current sedans have massKg=1500 in userData. The pure resolver verifies an 8:1 mass ratio; no truck model has been added.
- vehicle_rollover.mjs adds impact-driven tipping, side/roof rest and a tilted seated pose. It is a bounded ground rollover model on top of planar driving, not general suspension or rigid-body simulation.
- blast_response.mjs queues vehicle/RPG blasts, applies distance/cover-dependent hero launch, damages neighboring cars and allows damaged cars to chain-explode. vehicle_blast_motion.mjs moves the tumbling hero with ground, ceiling and wall collision checks.
- world_blast.mjs breaks local glass panels and blast_scorch.mjs adds bounded surface scorch patches. Buildings themselves are preserved. Mesh work is capped; dense nearby car parts can exhaust the 96-mesh budget before more distant windows. Glass processing does not currently ray-test intervening walls, unlike hero cover and opaque surface processing.
- vehicle_exit_camera.mjs explicitly restores hero visibility after exit and moves the camera outward if the opaque car body blocks its view. Exact screenshot disappearance was not reproduced: all four seat exit checks had visible meshes, finite coordinates and an on-screen hero.
- Persistent randomized wreck debris and clearDebris() cleanup API remain. Debris is local to the wreck; a moving/overturned wreck still needs a future world-space debris physics pass. No garbage truck is implemented.

## Validation

Node tests passed for contact damage, bullet energy, pair impulse (including 2000 energy/momentum/symmetry cases), rollover, blast motion, world glass, scorch and exit camera. Existing drive, 24 exit scenarios, tire tracks, damage, glass/wreck and continuous-fire tests passed.

Actual HTTP live run (.perf-blast/live-results.json in worktree 51b3) verified a ram contact, airborne hero and landing, one neighboring car hit, a two-event chain explosion, and a separate local blast breaking three building panes; no browser errors. Neighbor was pre-damaged to verify the chain threshold. .perf-crash/live-results.json verifies roof rollover and exit. .perf-exit-diagnosis/results.json verifies all four stationary seat exits. Own headless browsers are closed; user tab was not refreshed.

Later artist14 walk/hero integration is concurrent: latest shared walk passed syntax check and retains createCrashPartner, createBlastResponse and ensureVehicleExitVisible. Its complete behavior is under artist14 live QA.
