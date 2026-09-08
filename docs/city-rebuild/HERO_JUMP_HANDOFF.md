# Directional hero jump — 2026-09-08

Scope: the isolated `http://127.0.0.1:18538/walk` preview. This adds a verified
third-person movement slice; it does not replace the production gameplay
controller or claim that the full game migration is complete.

## Player behavior

- Space while on foot launches immediately. With no movement key the hero jumps
  vertically; Space with W, A, S or D performs a camera-relative directional
  dive. Diagonal input is normalized, so it does not increase distance.
- The chosen direction is locked at launch, as in a committed shoot-dodge. The
  hero faces the travel direction, extends into a forward dive, lands, absorbs
  the impact and returns to the exact rest pose before normal movement resumes.
- The action lasts 1.25 seconds: 0.8 seconds of ballistic flight and 0.45 seconds
  of landing recovery. Peak root height is 1.05 m and directional speed is
  6.5 m/s. These values are preview tuning choices, not a production-game rule.
- The existing pedestrian footprint performs swept collision checks throughout
  flight. Buildings, props, water, the car body and map limits remain blocking;
  a dive cannot tunnel through a thin wall. A blocked dive still completes its
  landing animation safely.
- A new jump cannot begin during another jump, a vehicle transition, driving,
  loading or while the scene menu is open. E interaction is disabled during the
  action. Space while driving remains the handbrake.

## Implementation and validation

Pure jump state and collision stepping live in `hero_jump.mjs`; the actual
Artist 13 skeleton pose lives in `hero_walk.mjs`; `walk_preview.mjs` binds the
state to controls, camera tracking and interaction guards. The footer now shows
the distinct on-foot and in-car meanings of Space.

Validation commands:

```
node assets/maps/city_rebuild_v1/test_hero_jump.mjs
node assets/maps/city_rebuild_v1/test_hero_walk.mjs
node assets/maps/city_rebuild_v1/test_car_drive.mjs
node assets/maps/city_rebuild_v1/test_car_exit.mjs
node assets/maps/city_rebuild_v1/test_walk_motion.mjs
node --check assets/maps/city_rebuild_v1/walk_preview.mjs
```

The tests cover all eight camera-relative directions, vertical apex, normalized
diagonals, timestep consistency, thin barriers, boundary/water rejection,
completion and landing. The real GLB test samples deformed skinned vertices over
both jump types, verifies the directional silhouette, preserves root position
and yaw, and verifies exact bone restoration. Existing vehicle, moving-exit and
pedestrian suites remain green.

