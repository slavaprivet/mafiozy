# Godot native traversal handoff — 27 September 2026

Latest opt-in actual Skeleton3D joint-anchor reader:
`TRAVERSAL_RIG_CONTACT_READER_HANDOFF.md`. Author actualhero701 PASS, full-affine
registered anchors exact0m; unapplied ladder proposal correctly fails contact
measurement. Strictly PARTIAL QA: displayed-root/skin/weapon/LIVE acceptance
still open, no new pose writer or root/main hook installed.

Latest synchronous ladder lifetime observer: `LADDER_LIFETIME_GUARD_HANDOFF.md`.
Actual-main427 PASS, independent31 x3 +parent31; source/actor tree exit aborts
before native body removal, no stale episode callback. Executor additive
readonly lifetime_authority pin is nowf222586a (supersedes old3be308e2); old
physical algorithm unchanged1327+77 PASS. Root recovery/input/rig/LIVE pending.

Latest opt-in physical ladder executor: `LADDER_PHYSICAL_EXECUTOR_HANDOFF.md`.
Actual-main1327 PASS /852physical samples with actual .30/.95 capsule;
independent77 PASS x3 +parent77. Own/borrowed exception lifecycle, actual committed
root, repeatE and native floor skin guarded. Root input/player/rig/LIVE adoption
and abort recovery remain pending; exclusive busy root/filter authority required.

Latest unified source ladder planner: `LADDER_SOURCE_ROUTE_HANDOFF.md`.
Actual-main2014 PASS includes full test-only physical ascent467 + fast slide385
root samples; independent100 PASS. Budgeted preflight16/cap32 samples, private
source/geometry lease, per-move corridor exit filters, actual roof endpoint.
Root adapter/input/rig/LIVE integration remains pending; raw controller unchanged.

New additive native roof grounding proposal: `LADDER_LANDING_SETTLE_HANDOFF.md`.
Actual-main208 PASS includes test-only CharacterBody ordered physical execution
of the115mm source roof gap. Existing controller/player remain unconnected;
source conditional collision policy and unified admission still need host wiring.

Latest source ladder integration dependency: `PRINTSHOP_LADDER_SOURCE_HANDOFF.md`.
Exact source export + conditional collision policy ready; actual-main 143 PASS
includes known route/support rejection evidence, NOT playable ascent. Root must
bind per-source body RIDs, conditional physical filters and query-derived roof
settling (.115m). No existing controller/player was modified by this package.

## Result

The package ports the physical vault, mantle and shore admission from the active
World source into Godot metres. It is proposal-only: it never teleports a player,
moves a support, or writes a rig. The main/player owner keeps the only authority
over `CharacterBody3D`, collision shape, gravity, input and the visible scene.

The native package covers:

- full 1.9 m standing capsule and 0.36 m footprint admission;
- a 1.1 m carry capsule with 0.04 m conservative sweep samples;
- vault to supported ground, mantle to a broad top, and dry shore exit;
- five-point destination support, headroom and low-ceiling rejection;
- car support identity, stability, velocity, tilt, revision and transform checks;
- abort at the last accepted root when a blocker appears or a support changes;
- source-parity lift/carry/land timing and collision-height blend;
- pure chest/head/lead-leg/trailing-leg and palm-contact animation proposals.
- a 120 ms controller-owned contact-preparation phase that keeps the physical
  root fixed until both valid palms reach full weight, without changing the
  source-parity root trajectory itself;
- accepted-prefix pose selection: a partially blocked sweep can never render a
  future root/phase that physics did not accept;
- mantle/shore palm loading through pelvis crossing, stable lead-side/foot
  targets, explicit pelvis/head clearance and central weapon-policy receipts;
- a 280 ms visual-only landing settle after the exact physical destination;
- a pure long-fall/impact-landing receipt driven by actual vertical speed, fall
  distance and impact speed; it owns neither gravity nor character physics.
- shared player/NPC kerb, doorway-threshold, slope, scramble and ledge proposals.
- ordered 12 mm floor-safe execution roots; rises above 4 cm are split into a
  world-up phase and a horizontal phase so the real capsule cannot cut through
  a kerb face.

All constants are already metres. The city scale `4.1` must not be applied to
capsule, reach, rise, clearance or sweep values.

## Files

- `scripts/traversal/traversal_probe.gd` — real `PhysicsDirectSpaceState3D`
  admission and support revalidation.
- `scripts/traversal/traversal_motion.gd` — deterministic source-parity root and
  collision-height proposals.
- `scripts/traversal/traversal_pose.gd` — pose and palm IK targets without bone
  or root writes.
- `scripts/traversal/traversal_airborne_pose.gd` — pure long-fall and
  impact-scaled landing proposal for the host's existing airborne owner.
- `scripts/traversal/traversal_controller.gd` — explicit host seam joining the
  three helpers while retaining proposal-only ownership.
- `scripts/traversal/traversal_surface_motion.gd` — real-physics 34 cm step-up,
  continuous slope/scramble and no-snap ledge proposal shared by pedestrians.
- `scripts/tests/test_traversal_probe.gd`
- `scripts/tests/test_traversal_motion.gd`
- `scripts/tests/test_traversal_pose.gd`
- `scripts/tests/test_traversal_controller.gd`
- `scripts/tests/test_traversal_surface_motion.gd`
- `scripts/tests/test_traversal_native_vehicle_support.gd`
- `scripts/tests/test_traversal_airborne_pose.gd`

## Player integration contract

Late-blocker addendum: after executing real body samples and `commit_step`, use
`committed_pose(rig_metrics)` for the sole rig write, rather than the predicted
`step.pose`. Exact order and new physical regression are documented in
`TRAVERSAL_COMMITTED_POSE_HANDOFF.md`.

1. Construct one `NativeTraversalController` and configure it with the player's
   `direct_space_state`, collision mask and RID. Do not construct it per frame.
2. On the traversal input, call `try_begin(feet, heading, options)` before the
   ordinary jump path. A rejected receipt leaves ordinary jump ownership intact.
   A swimmer should retry a blocked forward shore request no faster than 250 ms.
3. While active, stop ordinary locomotion, jump and dive state changes. Call
   `propose_step(min(delta, .04), options, rig_metrics)`. The first 120 ms are a
   `pre_contact` pose proposal with no sweep roots; apply the pose and commit it
   so the hands establish contact before physical lift.
4. Apply the returned accepted sweep roots in order through the existing player
   body authority. Then call `commit_step`; never jump directly to the endpoint.
   Use the returned pose: it is already sampled at the last accepted prefix,
   including a partial dynamic block. After the physical endpoint, the
   controller remains active for `landing_settle` pose-only frames with no root
   samples, then becomes terminal.
5. Drive the temporary capsule height from the motion proposal and apply the pose
   dictionary after resetting the normal base pose. Pose code must not own root,
   yaw, bone translation or scale. `pelvis.visual_offset_y_m`, feet/palm targets,
   head clearance and `weapon_policy` are presentation/validation receipts for
   the sole host owner; they are not permission to bypass collision.
6. On completion restore the 1.9 m capsule and ordinary floor snap. On blocked or
   support-invalid termination keep the last accepted root and resume gravity.
7. The admitted support identity and admission transform must be retained. A car
   moving above 0.08 m/s, rotating above 0.03 rad/s, tilting, changing revision or
   disappearing aborts the action; it stays a solid blocker.
8. Before ordinary horizontal movement, call the surface helper for the intended
   short frame displacement. Apply `path_points` in order. `auto_step` and
   `foot_lift_m` drive the leg lift; `scramble` multiplies walking speed by `.48`.
   A rejected medium obstacle requests the explicit traversal controller. Player
   ledges use `free-fall`; NPC ledges block. Cars never consume auto-step rules.
   The points already contain the conservative floor skin and explicit step
   phases; do not collapse them back into one diagonal motion.
9. For `vertical_transition.kind == "free-fall"`, feed actual post-physics
   `vertical_speed_mps`, accumulated `fall_distance_m`, airborne/landing ages and
   captured impact speed into `NativeTraversalAirbornePose.propose`. The result
   is a pose receipt only. `character_physics_input.authority_owned` is always
   false; the existing character-physics owner alone admits severe impacts.

`NativeVehicleBody` supplies the current supported contract through the
`native_vehicle_body` group, stable metadata, `global_transform`,
`linear_velocity`, `angular_velocity`, and `is_upright()`. Water/sunk and open
panel state are not yet published by that body; when those authoritative fields
arrive they should set `traversal_vehicle_blocked` or increment the support
revision. The traversal package intentionally does not invent duplicated state.

## Verification

Godot 4.7.2 headless, 27 September 2026:

- `test_traversal_probe.gd`: **329/329 PASS**. Real physics bodies cover flat
  ground/kerb, thin 1.1 m vault, broad 1.2 m mantle, 2.5 m rejection, low ceiling,
  unsupported landing, 1.75/2.1/beyond-reach shores, parked/frozen/awake cars,
  `Area3D` triggers, static seams and compound floor/wall bodies.
- `test_traversal_motion.gd`: **40/40 PASS**. It executes the actual
  `hero_traversal.mjs` oracle; maximum root error is
  `0.000000119209289550781 m`, collision-height error is `0`.
- `test_traversal_pose.gd`: **57/57 PASS** across vault/mantle/shore and
  0.4/1.1/1.7 m obstacles, endpoint blending, palm anchors and unreachable release.
  The animation refinement suite now passes **86/86**, including contact-before-
  lift, maintained mantle/shore contact, lead-side swap, foot/pelvis/head/weapon
  receipts, landing compression and 1.75/1.90 m metric envelopes.
- `test_traversal_controller.gd`: **122/122 PASS**, including support-transform
  change abort at the last safe root, a real dynamic partial-sweep blocker whose
  pose equals the accepted prefix, 120 ms contact prep, 280 ms settle and exact
  60/30/15 Hz terminal-root parity. A support change during pose-only settle
  cancels the settle without moving the accepted destination or leaking active
  controller state.
- `test_traversal_surface_motion.gd`: **25/25 PASS** on a 32 cm kerb, medium
  obstacle, building sill, low lintel, walkable hill, steep scramble, cliff,
  parked/sloped car, deep void, `Area3D`, compound collider, player/NPC ledge
  policies and real 0.30 m capsule execution.
- Independent actual-scene review: the real capsule accepts all **39/39** ordered
  kerb points and **84/84** open printshop-ramp points with zero endpoint error;
  the closed door and compound wall remain blocked. The thin 1.1 m physical
  vault completes in 53 frames with `0.000353 m` root error.
- `test_traversal_native_vehicle_support.gd`: **6/6 PASS** against the actual
  awake `NativeVehicleBody` created by `main.tscn`. All-wheel-grounded solver
  jitter below 0.02 m/s admits immediately; 0.05 m/s drift, rotation and the
  authoritative blocked flag reject. Frozen/sleeping generic bodies retain the
  stricter path.
- `test_traversal_airborne_pose.gd`: **16/16 PASS**. Downward-speed/distance
  response remains live through long falls; first contact has zero discontinuous
  compression, impact speed scales the settle, weapon restore is terminal,
  1.75/1.90 m receipts are finite and 60/30/15 Hz analytic partitions agree.
- The four current World source contracts also PASS: traversal, traversal-world,
  surface-motion and mountain-surface regression.
- The original package handoff recorded `git diff --check` as PASS. For this
  isolated follow-up, a scoped trailing-whitespace scan of the touched
  traversal modules, tests and this handoff is PASS; no Git write was made.

Current isolated warmed headless results: flat probe p50/p95 `0.276/0.459 ms`;
short flat surface route `0.046/0.066 ms`; pose receipt `0.034/0.058 ms`;
controller proposal over real physics `0.121/0.230 ms`; long-fall receipt
`0.011/0.017 ms`. These are CPU micro-measurements, not a LIVE or FPS claim.
The full traversal probe
belongs on an input/blocked-movement event, not every render frame.

## Acceptance boundary

This package is not yet connected to `preview_player.gd`, the imported Godot
skeleton, the single visible game, NPC navigation, ladders, or the World
time-of-day system. Coordinator 21 owns those shared files and the one sequential
restart. LIVE acceptance requires the player hook, male/female rig application,
real curb/slope/car/shore playthrough, and a comparable loaded-scene performance
check. Ordinary jump and Max Payne dive parameters must stay unchanged.
