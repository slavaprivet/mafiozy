# Third-person car demo — 2026-09-07

Scope: `http://127.0.0.1:18538/walk` only. The procedural sedan is a temporary
inspection vehicle, not an artist-approved replacement for production traffic.
The old game's vehicle ownership, economy, AI and combat are untouched.

## Controls and integration

- Hold E for 0.3 seconds near either front door. Releasing early cancels.
- A 2.6-second staged transition opens the selected door, folds the character's legs,
  moves into the cabin and closes the door. Driver and steering wheel stay left.
- Hold E for 0.3 seconds to exit at any speed when a safe side is available.
  Up to 15 km/h the hero steps out; above 15 km/h (including reverse) the hero
  tumbles and recovers. The threshold is an implementation choice.
  The empty car coasts independently and stops through drag or obstacle contact.
  Entry into an unattended car remains limited to speeds at or below 0.5 m/s.
- W accelerates; S brakes first, then reverses. A is driver-left, D driver-right.
  The model faces +Z, so +X is its left side (do not invert this again).
- Space applies the handbrake; rear wheels lock, front wheel pivots follow the
  steering angle, and radial spokes visibly rotate with actual distance.
- Mouse movement rotates the third-person camera without holding a button.
  Pointer lock is optional; unsupported embedded browsers use free mouse movement
  and edge turning. Esc releases the cursor; C restores a rear view.
- The large debug header is hidden behind the small menu. The black/gold car
  prompt appears only within a reachable door's interaction range. Projection
  runs after camera update/render to avoid a one-frame jump while orbiting.

## Collision and validation

The full oriented car body checks authored obstacle polygons, including thin
poles/walls. Roads, flat grass, paving and bridge decks are allowed; water, reserved
police cells and tall props are blocked. Low colliders up to 0.22 m are traversable.
This remains a flat-map controller, not suspension/jumping/elevation physics.

Tests:

```
node assets/maps/city_rebuild_v1/test_car_drive.mjs
node assets/maps/city_rebuild_v1/test_car_exit.mjs
node assets/maps/city_rebuild_v1/test_hero_walk.mjs
node assets/maps/city_rebuild_v1/test_walk_motion.mjs
```

These cover steering signs, self-centering, reverse, handbrake, frame-rate
consistency, wall contact/recovery, exact city masks, half-second hold and
entry/exit curves. Actual skinned hero vertices fit above the cabin floor and
below the roof; animation restores the original rest pose. Wheel hierarchy tests
use a geometry stub; the live page uses Three's real RoundedBoxGeometry.
The hero test retains its existing Artist13 local vendor dependency.

Live scene/prompt and error-free loading were inspected. The user tested driving
and entry and reported the steering reversal/feet clipping; both received code
fixes and regression tests. This is not a claim of a completed full-city or
production gameplay QA pass. These demo changes have not been pushed to GitHub.

## Moving exit completed by the replacement coordinator

2026-09-07, task `01a07c31-ac4c-7db3-9721-9ecb65c3ff4e` continued the saved
implementation from Coordinator 13. The door sweep predicts coasting movement,
tries the opposite side when blocked, and refuses an unsafe departure. Detached
body motion checks world obstacles and the car; unattended car motion also
checks the hero. Camera tracking stays with the hero throughout recovery.

Fixed a one-frame standing pose between door departure and tumbling by applying
the initial tucked pose immediately at release. Also corrected zero-radius
point probes inside the oriented car body; the collision tests now exercise
this case rather than silently treating an interior point as clear.

Automated validation passed: all 24 combinations of moving exits (low/high,
forward/reverse, both sides, two headings), blocked-side fallback, future wall,
coasting and recovery; car driving/handbrake/entry tests; actual GLB skinned-mesh
grounding and rest restoration; pedestrian wall/slide tests; module syntax.

Live in-app browser checks used `/walk?carexitqa=1`, an explicitly enabled
slow-motion fixture with buttons for 8 and 60 km/h. The normal `/walk` has no
test buttons or slowdown. A checkbox can pause the fixture during the inverted
pose; clearing it resumes the same simulation.

- 8 km/h: hero finished outside, `state=on_foot`; empty car still moving at
  0.299767 m/s after recovery.
- 60 km/h: inverted skinned pose inspected at `exitProgress=0.230676`, hero
  clear of ground and vehicle, car still moving at 13.418967 m/s. The car
  subsequently stopped at the grass boundary under the old surface rule (corrected below). Console warnings/errors
  and the scene error display were empty during this check.
- After releasing the QA pause, recovery finished as `state=on_foot`,
  `exitKind=null`, door closed, normal standing pose and walking controls enabled.

This completes the moving-exit demo slice, not production vehicle integration,
ragdoll physics, fall damage or the full third-person gameplay migration.

## Flat grass correction

2026-09-07 user reported the car stopping on empty flat grass. Grass tile 8 is
now a traversable surface, including for an unattended coasting car. Authored
solid colliders, water, map bounds and the police reservation remain blocked.
Regression tests cover crossing the actual lawn near demo spawn (past the old
x=629.16 stop), free coasting across a grass boundary, and obstacles on grass.
