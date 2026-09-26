# Native vehicle physics — isolated package

Status: Stage 1 is consumed by Coordinator21's opt-in `preview_transport.gd`
main-scene integration. Coordinator21 reports the signed steering repair in
the sole LIVE vehicle13 instance; dedicated dynamic LIVE driving acceptance
remains separate from the short static capture. Damage, fire,
seat authority and server ownership remain separate components.

## Contract

- SI units: metres, kilograms, seconds, radians. Godot axes are `+Y` up and `-Z` forward.
- `NativeVehicleProfile` converts the immutable transport descriptor into body,
  wheel and control parameters and fails closed on invalid/non-finite geometry.
- `NativeVehicleBody` owns a real `RigidBody3D`, box collider, four suspension
  probes, internal bounded 120 Hz force substeps, one tyre friction circle,
  service/rear-handbrake forces, a bounded contact proposal ring, immutable
  state snapshots and body sweep admission.
- `NativeVehicleBodyFactory.spawn_from_descriptor()` consumes an explicit
  transport roster record plus one frozen profile. The record position is the
  source-ground pivot; collider/COM/suspension offsets remain physics-owned.
- Controls are monotonic by `sequence`, `source_clock` and vehicle life. State/contact rows carry
  `vehicle_id`, `life_generation` and physics/contact sequence numbers.
- The contact hot path uses fixed packed arrays and a fixed counterpart ledger.
  Persistent manifolds emit one onset, separation rearms them, and a full
  critical ring reports an explicit GAP instead of overwriting unread events.
- Contact receipts are proposals only. Server damage, fire, death and identity
  generation remain outside this module.
- Actor exit clearance remains the transport owner's capsule query. This module's
  `body_sweep` is only for vehicle placement/motion admission.

## Source fidelity

The production input is frozen Transport3 descriptor
`data/transport/vehicle_descriptors.v1.json`, SHA-256
`99d328bc4a581bc65815498b265ae5eec71a25b831512b15d376e1c0f5ac031a`.
All 12 profiles are admitted. The independent representative fixture is also
receipted against `vehicle_fleet_models.mjs` and checks exact mass, wheel radius,
wheelbase, acceleration and speed for compact sedan, sport coupe, bus and fire engine.
The descriptor now carries actual post-assembly visual bounds. Those values feed
the native collider, derived COM and track, so they are not presentation-only data.

Walk does not author ground clearance, centre of mass, track width, suspension
rest length or angular drag. They remain visibly listed in
`native_default_fields`; current neutral native defaults are derived from wheel
radius/body envelope and are not described as manufacturer/source facts.

## Validation

Run without creating another visible game:

```powershell
& 'C:\Users\Слава\AppData\Local\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk -s res://scripts/tests/test_vehicle_physics_native_body.gd
```

The headless scene contains a 40×70 m asphalt body, a 12×3×0.6 m impact wall
and a side barrier. The test exercises actual Godot settling, wheel contacts,
throttle, braking, steering/handbrake lateral motion, collision sweep, bounded
and deduplicated wall contact receipts, all-source admission and stable lifetime
identity. Per-wheel load/slip/longitudinal speed is exposed for wheel animation,
tyre marks and smoke without a second presentation-side dynamics solver.
Actual Godot 4.7.2 result after the descriptor/ground-root bridge update:
**127 checks PASS** plus **26/26 independent checks**
(update these numbers only
from a fresh run). Printed snapshot microseconds are isolated API measurements.

The actual exported compact-sedan visual was also mounted unscaled and without
an offset on the native body, then settled on a flat collider. The 25-check
alignment receipt verifies converted source bounds, all four authored wheel
bottoms, all four suspension probes, bounded probe/visual spacing, collider
margin, upright settling and the authored driver root. The suspension ray now
starts at the strut mount and uses the same explicit loaded-length ratio as its
spring-rate equation. The measured wheel bottoms are 3.5–3.9 mm above the flat
surface rather than the previous 104 mm.

```powershell
& 'C:\Users\Слава\AppData\Local\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk -s res://scripts/tests/test_vehicle_physics_visual_alignment.gd
```

Scaling command:

```powershell
& 'C:\Users\Слава\AppData\Local\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk -s res://scripts/tests/test_vehicle_physics_cpu_scaling.gd
```

Godot 4.7.2 / 60 physics Hz / 120 warmup + 240 measured ticks:

| Headless scenario | Physics-process CPU p50 | p95 | max |
| --- | ---: | ---: | ---: |
| baseline | 0.125 ms | 0.174 ms | 0.240 ms |
| 1 active | 0.699 ms | 3.048 ms | 3.048 ms |
| 16 active | 1.475 ms | 1.848 ms | 1.848 ms |
| 72 active | 4.840 ms | 4.930 ms | 5.386 ms |
| 72 sleeping | 0.871 ms | 5.226 ms | 5.226 ms |

These are headless engine physics-process CPU monitor values, not render frame
time, GPU, full-city LIVE or FPS. The sleeping tail needs a longer investigation;
the median proves sleep removes steady callbacks, but the p95 spike is not yet accepted.

Independent boundary tests additionally verify strict malformed/non-finite profile
rejection, clean life-generation reset, COM-relative anchor velocity, reusable
contact slots, exact 30/60/120 Hz force partition and fail-closed rotation sweeps.
Rotation-only admission is explicitly unsupported until a rotational cast is
implemented; it never returns a false safe result.

This Stage 1 is a native 3D force model, not numerical parity with the source 2D
dynamics solver. Independent evidence currently measures a different first-tick
steering response and rear-grip release curve. Source trajectory/yaw/slip parity
is therefore OPEN and must not be claimed from these tests.

## Stage 2 pure crash rules

### Directed manifold candidate — 27 September

`vehicle_contact_manifold.gd` provides fixed-capacity per-body/per-global-tick
aggregation of world-space contact points, full vector impulses and COM-relative
angular impulses. It retains zero-impulse onset closing speed, marks invalid input
or overflow as a GAP, and exports proposal-only rows. Runtime IDs are local lookup
keys and are never declared server identities. Snapshot export allocates; raw
observation uses preallocated packed arrays.

Actual Godot headless result: 26 checks PASS, including pure torque with zero
net translation, symmetric frontal contacts, point-order reversal and overflow.
A warmed synthetic 72-body/eight-contact workload measured 656 us p50 / 842 us
p95 per tick for one counterpart; eight distinct counterparts measured
766 us p50 / 835 us p95. This includes synthetic input construction and is an isolated CPU
diagnostic; it does not accept full-fleet runtime cost. Further pair lifecycle,
canonical two-body reduction and direct-state bridge are required before wiring.
Direct-state integration and lifecycle cost remain unmeasured.
Collection, overflow and invalid-input GAP flags are separate. A single
zero-impulse onset retains its normal; exact opposing normals are marked invalid.

```powershell
& 'C:\Users\Слава\AppData\Local\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk -s res://scripts/tests/test_vehicle_contact_manifold.gd
```

`NativeVehicleCrashRules` is an isolated proposal-only source-parity package. It
freezes the 12 structural part IDs, debris proposal caps, deformation envelope,
collision-damage formula and smoke/fire thresholds. It rejects malformed or
out-of-source-range geometry, keeps structural deformation separate from the
sub-threshold local collision-damage proposal, and never mutates HP, starts fire,
starts an explosion or revives a wreck. Current Godot result: **47 checks PASS**.

```powershell
& 'C:\Users\Слава\AppData\Local\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk -s res://scripts/tests/test_vehicle_crash_rules.gd
```

Runtime contact reduction, panel nodes, debris bodies, fire visuals and occupant
damage are not implemented by this pure package. Stage 2 runtime wiring remains
blocked until the first opt-in car proves the Stage 1 bridge in the integrated scene.

## Integration gate

### Signed steering repair after user feedback

The source visual wheel uses positive steering toward vehicle-left after its
PI-around-Y export wrapper. The native tyre basis previously rotated by the
opposite sign. With the host's `-Input.get_axis(left,right)` this made A show a
left wheel while physics turned right, and D the reverse. The native front
direction now rotates by positive steering, matching the authored visual; the
existing host mapping stays consistent. New body SHA:
`a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401`.

`test_vehicle_physics_steering_response.gd` exercises ordinary full-throttle
turning without handbrake in both directions at 3/8/16/28 m/s. All eight signed
yaw/displacement scenarios pass. Native127 and unchanged independent26 pass on
the same body. This verifies the simulation change; Root21 updates the sole LIVE
instance and owns the final input/visual check.

The new `test_vehicle_physics_all_profiles.gd` adds actual 12-profile flat-floor
settling evidence: 138 checks PASS, all four rays grounded for every profile,
60 consecutive stable ticks reached at tick239. Worst root height was 5.56 mm,
worst velocity 0.0101 m/s and worst consecutive-frame root displacement 0.475 mm.
This proves flat-floor equilibrium; building, curb and rollover collision behavior
requires the separate actual-block driving investigation requested after LIVE feedback.

### Actual-block fall diagnosis, 27 September

The explicitly temporary crop boundary is now supplied as
`scripts/preview_boundary.gd`, SHA-256
`ba9b9797e8982ede31909786ff8fe3e5c2a34a1537643eb84356d60a864c1e87`.
API: `configure(bounds_value: Variant, label_anchor_local_m: Variant = null) -> bool`.
Four visible, matching static walls stay inside actual source bounds; no
fabricated floor or water replacement. `test_vehicle_preview_boundary.gd`
SHA-256 `e462fad314907d7266606cf1dc791ccb34a27a74bf80b0760c88ce1f7757f897`
passes 56 checks. Its east test uses exact source dry strips, actual parking,
normal gravity and free roll/pitch at 6.5 m/s: maximum front X42.76375 versus
edge43.05, minimum root Y0.003506, final support mask15. The other four wall
tests are explicitly axis-locked geometry isolation, not rollover acceptance.
Root owns main wiring and reports the visible boundary in LIVE13.

### Proven next defects — not part of the a382 freeze

Coordinator21 requested production remain exactly a382 for the imminent LIVE
moving-exit capture. This exact hash has been restored and verified. Candidate
body is preserved separately in `outputs/vehicle_native_body_candidate_873976.gd`,
SHA-256 `873976e64de0ae56fabb87af9f73df8a6940901a0f10a3368b825321cd5fc1d7`.
It combines supported-normal admission, tangent tyres and grounded-only road
coast. Unchanged independent26 passes on this candidate. Prior efb candidate
had airborne coast and failed five isolated impulse checks; it is superseded,
not accepted. Native127/wall24/steering8/coast18 were run on efb before the
grounded-only adjustment and must not be reported as fresh873 acceptance.
New test files currently describe candidates, not production a382 acceptance.

Candidate873 coast regression now separately passes22 checks. It SHA-verifies
the exact candidate and removes only the duplicate global class declaration
in memory before compilation (production already registers NativeVehicleBody).
Grounded coast8.226727 versus source8.252822 has a measured0.0261m/s tyre
difference, checked with explicit0.04 tolerance. Airborne horizontal10 and
vertical3 are conserved; hatch28.01717/compact31.03491 reach authored caps.
This is not LIVE or productiona382 acceptance.

Production handbrake diagnosis intentionally fails two source gates: coast
stops4.317s/11.572m, neutral+handbrake2.500s/8.843m, throttle+handbrake never
stops in15s (50.514m, final2.8025m/s). Source disables propulsion when braking;
native front drive currently overcomes grip-limited rear braking. A separate
outside-production candidate `outputs/vehicle_native_body_candidate_handbrake.gd`
SHA `67da32426d7b503eee0f92294f7e57c0406a857a17ee1f6e91a2eabf34cc4c0d`
adds only handbrake/service-brake propulsion suppression to873. Its regression
is pending; no production adoption while Root LIVE QA is frozen.

Tyre-mark source audit establishes a bounded1200-segment10-second ring with
0.28m spacing/0.19m width and source fade timing. Implementation is separate
from current body; actual same-tick wheel contact position/normal and trusted
source surface metadata are required before wiring. Visible crash deformation
remains OPEN: current collector drops static colliders without vehicle_id,
so buildings/walls cannot yet feed the proposal pipeline. Pure47-check crash
rules are not a visible dent/debris implementation.

An isolated vertical-wall test with no floor proves rotated suspension rays
can incorrectly report ground support at roll70/80/90 degrees. All hit normals
have world-up dot0, yet old body reports masks10/10/15 and positive loads.
Support admission and tangent-plane tyre forces are being repaired separately.

The source `coastDrag` value0.75 is a deceleration in m/s², not velocity
damping. Mapping it to Godot `linear_damp` combines with project0.1 and slows
every axis even under full throttle. Actual 10-second tests on a382 reached
only hatch7.023/compact7.393 m/s versus source caps28/31. A separate source-
branch planar coast regression is required before replacement is released.

An actual headless main-scene investigation reproduced the reported fall using
the parked hatchback: its settled centre was `(37.082, 0.00356, -9.734)` and the
exported dry surface ended at local X43.05. The front bumper was only 3.85 m from
that edge. Driving east crossed the cropped surface, lost all wheel support and
fell into empty space (tick180 Y-4.56; tick600 Y-78.8). Building and low-object
impacts stopped at their expected collision boundaries without tunnelling in
the investigated runs. Coordinator21 owns extending the actual source surface
export; native body and profile remain frozen. This diagnosis does not establish
every wall/curb/rollover case, and does not authorize fabricated ground over water.

Root/Coordinator21 should connect this module only after reviewing the descriptor
bridge from Transport3. The first runtime hook must remain opt-in and preserve one
physics owner per vehicle. Do not run a parallel browser dynamics controller.

Still open after Stage 1: all-profile/LIVE model-hull bridge, surface coefficient map, water/sunk
state, panel damage/destruction, two-vehicle canonical impulse aggregation,
occupant crash response and authoritative damage/fire receipts. This owner does
not alter `main.gd`; LIVE admission belongs to Coordinator21.
