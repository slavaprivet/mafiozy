# Existing-building traffic owner — tools-only, partial and HOLD for K

`traffic_owner.gd` is a real, reversible **no-impact** traffic lease for the
immutable Coordinator22 Godot checkpoint. It implements the `verify`,
`commit`, `rollback` token shape required by `ordinary_building_tx.gd`.
It pins the actual main, block, full catalog and native vehicle descriptor
bytes. It checks the live `PreviewTransport` body/RID/pose, phase, logical host
diagnostics, vehicle reference and parking catalog while the tree is paused.
Commit publishes a monotonic local traffic-owner revision; rollback restores
the prior publication. It does not alter visual quality or reduce content.

The source planner builds 4,870 conservative exclusion rectangles from the
39 actual lots, 59 bays, parking surfaces/access, walking and driving routes,
parking signs, road signs and traffic signals. The candidate also rejects
new collision envelopes outside the live 31×31 crop or on native road/bridge
tiles. Linked parking buildings refuse *before mutation*, including the
real parked hatchback's townhouse-004. No associated bay is silently left
behind or teleported. The token can admit only a change proven to leave
transport/parking geometry unchanged, for example deletion of an unlinked
building. Terrain/navigation/pause leases remain independently mandatory.

## Actual isolated verification

`node .../stage_checkpoint.mjs --dry-run` passed: 192 checkpoint files,
197 staged files, 83,864,133 bytes. The staged project is
`outputs/map-editor-traffic-owner-5CcvPW`. Godot 4.7.2 headless import exited
0 without script/import errors. The headless fixture loaded the actual
8-building, 3-resident, one-car checkpoint and passed **12/12** checks,
exit 0: linked townhouse refusal, unlinked townhouse deletion publication,
post-commit verification, exact publication rollback, and outside-crop move
refusal. This is an isolated mechanics test, not visible-game FPS or editor
acceptance. No production file, main scene or GPU preview was changed.

## Linked townhouse-004: stationary-bay route prototype

`build_linked_packet.mjs` runs the actual pinned source planner twice: original
placement and an exact +0.25m X move of townhouse-004. The resulting 948,130
byte packet pins all 39 lot IDs, 59 bay IDs and 57 sign IDs. Bay positions,
signs, collision geometry, parking surfaces, access and road-support geometry
are byte-identical between plans; only lot distance/coverage and walking-route
metadata change. The native parked bay has yaw 0 while the source road-facing
bay records yaw PI. Both existing conventions are checked explicitly; the
candidate never rotates the car to reconcile them.

`linked_stationary_bay_owner.gd` accepts only this hash-pinned fixed delta.
It checks the actual paused tree, live empty parked car, body/RID/pose/velocity,
brake, logical host record/clock/parking ID and native catalog bay before
issuing a token. Commit publishes a revised route-plan snapshot without
moving the native car or changing its logical record; rollback and user-level
undo/redo switch the plan back and forth. Its `route_plan()` returns a copy.
The clean isolated stage `outputs/map-editor-traffic-owner-3eclHx` imported
with Godot 4.7.2 exit 0; the linked fixture loaded the actual checkpoint
scene and passed **22/22**, exit 0, no engine errors or leak warnings. The
unlinked no-impact fixture also passed **12/12** in that same clean stage.

This is a genuine isolated route-owner state transition with a real parked
car binding, **not production publication**: the current main/navigation/NPC
owners do not read this new route owner, no authoritative map save/import
records the revised route, and other terrain/nav leases remain absent. It
proves neither arbitrary drag nor K readiness. A source planner or trusted
plan-packet service must be available for every arbitrary edit; hard-coding
sampled deltas would not be equivalent.

## Linked building full publication still missing

Townhouse-004 and every building named by a parking lot/bay remain HOLD. The
source `createCityParkingPlan` replans not just bays but road-support surfaces,
driveways, signs, access keepouts and walking routes; its 39 lots/59 bays are
not a collection of transforms that can safely follow the building. The
current Godot `transport_descriptor_catalog.gd` loads static parking data;
`transport_bootstrap_provider.gd` consumes a bay only at new-session birth.
`PreviewTransport` owns a live rigid body plus player/seat/cargo state, and
`transport_logical_host.gd` has roster publication but no paused atomic
parking-replan/native-body transaction. A direct dictionary edit, body move,
or fresh `publish_roster` would lack exact rollback and could desynchronize
the vehicle source clock, doors, occupancy, physics or source IDs.

To lift HOLD, the transport owner must provide a paused two-phase API that
validates an exact replanned source-plan digest and bay IDs, checks live
vehicle generation/seat/transition/velocity/damage/cargo state, stages native
geometry and logical roster together, commits all new road/parking/nav
dependencies without yielding, and retains a rollback receipt until the
building transaction fully commits. Undo/redo and save/load must use the
same authority route. No such safe API exists in the current checkpoint;
this package deliberately does not counterfeit one with synthetic callbacks.
The source plan/traffic constraint snapshots are read-only and do not prove
mutation-history integrity. Loaded-city frame time and visual parity are
unmeasured. Do not wire K or claim all buildings movable from this test.
