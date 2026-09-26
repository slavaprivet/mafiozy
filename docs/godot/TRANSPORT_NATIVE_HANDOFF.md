# Godot native transport — first logical slice

## Delivered scope

This slice is confined to `scripts/transport`, transport tests/data, and its exporter. It does not edit the player, main scene, project settings, export settings, navigation, NPC visuals, or `scripts/vehicle_physics`.

The tracked Walk sources are exported into `data/transport/vehicle_descriptors.v1.json`:

- all 12 real vehicle profile/model identities and source hashes, with post-assembly bounds/anchors projected from the actual `createArtistVehicle` factory oracle;
- each profile's actual two- or four-seat layout, left driver, door, handle, seat, and outside approach anchors;
- the current deterministic city parking plan: 39 lots and 59 bays with stable IDs;
- SI units and an explicit source-to-Godot basis conversion (`+Z/+X-left` to `-Z/-X-left`);
- fields absent from the Walk source remain `null` and are listed in `unavailable_in_walk_source`. The exporter does not fabricate suspension, centre of mass, track width, ground clearance, or angular drag.

`transport_logical_host.gd` owns the bounded logical roster, seat claims, and 0.3-second hold lifecycle. It accepts only explicit session and roster packets. It never creates an actor or vehicle by itself.

- `NEW_SESSION_BOOTSTRAP`: an explicitly supplied native roster may commit boarding and exit locally.
- `IMPORTED_EXISTING`: a completed hold returns `AWAITING_SOURCE` plus a stable command. Occupancy changes only after a newer authoritative roster confirms it.
- Identities are exact, case-sensitive `(id, life_generation)` pairs. Replacing a vehicle with a newer generation invalidates old references and leases.
- Source clocks and roster revisions must move forward. Continuous hold samples may be at most 120 ms apart, so a missed interval cannot satisfy the 300 ms requirement.
- Different actors may submit actions at the same authoritative source tick. A repeated action by the same actor at that tick is fenced.
- The driver is always `front_left`. Each occupant uses that seat's own door. Busy actors and occupied or claimed seats fail closed.
- Release, cancellation, an unsafe probe, and continuity loss clear the lease without detaching an occupant.

`transport_access_provider.gd` uses `PhysicsDirectSpaceState3D.cast_motion` and a destination overlap query with the actor capsule. Boarding or exit is admitted only when the capsule path and landing are both clear. The vehicle body RID can be excluded so the actor can move through its selected authored door while all other collision remains active.

`transport_runtime.gd` is the integration seam. It loads the catalog, hosts the roster, produces a fresh physical receipt for every begin/advance call, and exposes:

```gdscript
begin_session(packet)
bootstrap_new_session(request)
publish_roster(snapshot)
sync_native_vehicle_pose(vehicle_ref, bound_vehicle_rigid_body, source_clock)
begin_board(actor_ref, vehicle_ref, seat_id, source_clock, actor_feet, door_ready, excluded_rids)
begin_exit(actor_ref, vehicle_ref, seat_id, source_clock, actor_feet, door_ready, excluded_rids)
advance_interaction(token, e_is_pressed, source_clock, actor_feet, door_ready, excluded_rids)
begin_actor_transition(token, source_clock, actor_character_body, vehicle_rigid_body)
advance_actor_transition(token, delta, source_clock)
cancel_interaction(token)
```

`transport_bootstrap_provider.gd` ports the tracked `initCars/spawnParkedCar/_nativeParkingPrepare/_threeVehicleEntityId` new-session factory into an explicit one-birth first slice. The caller supplies the session ID/generation, both source clocks, one of eight source civilian factory slots, and a real exported parking bay. The result is `local_vehicle_1@1` plus the immutable `(vehicle_record, profile_descriptor)` physics spawn input and full source hash provenance. Reissuing the same packet is idempotent; changing an already-issued session is rejected. `IMPORTED_EXISTING` produces zero births.

The request also carries the Godot scene `origin_m`. Parking descriptors remain immutable source-world coordinates; bootstrap writes `vehicle.position_m = source_world_position_m - origin_m` exactly once and records both values in birth/session provenance. `origin_m` participates in idempotency. Omission maps to explicit zero only for legacy headless callers. Root's current scene origin is `[395.65, 0, 45.1]`; player, physics body, host anchors, and probes must all use that same localized Godot frame.

Root must instantiate this node and either use the explicit new-session factory or feed an imported authoritative roster. There is no fallback actor or session ID. The physics owner can read the immutable profile values from the descriptor. The player integration must pass the selected vehicle body's RID in `excluded_rids`, report the authored door as ready, and apply visible door/actor motion only from admitted results.

Access admission now rejects a capsule already overlapping at the start, requires floor support at the centre plus four footprint points, limits support step/slope, rejects water-tagged or blocked surfaces, and checks the complete capsule sweep and destination overlap. Sensor-only `Area3D` shapes may block the admission sweep but never count as physical foot support. Boarding additionally requires the actor to have physically reached within 0.25 m of the real door approach; a clear path from far away cannot advance the hold. Water exits remain deliberately dry-only/fail-closed until the source `planWaterExit/createVehicleWaterExitSurface/finishExit` authority is ported.

An EXIT receipt preserves the exact authored seated root in `from_m`, while its physics query may normalize only a nearby solid support seam up to 5 cm in `physics_from_m`. This covers the real pitched-car seat root just below the road plane without moving the visible seated actor. The correction is EXIT-only, requires a body support ray with a walkable normal, rejects water/blocked support, and cannot bypass a wall, the full capsule sweep, destination occupancy, or missing landing support.

Finishing the 0.3-second hold does not occupy or clear a seat. It returns `TRANSITION_REQUIRED`. By the 27 September LIVE user pacing override, boarding uses a 1.2-second staged entry and requires a `TRANSPORT_ACTOR_TRANSITION_V1` receipt proving the physical seat was reached. The normalized source door/reach/fold/leg phases remain continuous across the shorter interval. Exit keeps its separate source moving-exit contract unchanged: 0.55-second door release plus 0.6-second walk recovery or 1.7-second tumble recovery, followed by actual grounded, unblocked outside arrival. Only a receipt with those action-specific facts can produce `BOARDED`, `EXITED`, or an imported-session source command. Player/main wiring remains a root integration dependency.

`transport_actor_transition.gd` is the native producer. It binds the exact actor and vehicle generations to an actual `CharacterBody3D` and `RigidBody3D`, follows the source entry/exit curves against Godot collisions, tracks the vehicle transform during the move, and retains/removes its vehicle collision exception with seat lifetime. It also returns the source pose scalars (`door`, `fold`, `reach`, leg/duck phases) for root-owned visuals. `transport_runtime.gd` accepts completion only from this provider; caller-authored receipt dictionaries return `TRANSITION_PROVIDER_REQUIRED`. Root still owns attaching these calls to the player controller and vehicle factory.

Moving EXIT keeps the source 15 km/h tumble gate, inherits 60% of the actual vehicle velocity plus the 2.4 m/s outward impulse, publishes continuous `exit_kind/source_phase/body_progress`, and never writes velocity, braking, steering, or forces to the vehicle body. Root controller owns releasing driver input so the physical vehicle can coast.

Physical completion is two-phase: the provider retains its body state and exception ownership until the logical host returns `BOARDED`, `EXITED`, or `AWAITING_SOURCE`; early source clocks remain retryable. Host and physical provider both preload `transport_timing.gd`, the single 1.2-second boarding clock contract. Caller deltas up to one second are consumed as bounded 100 ms collision substeps, so a 200 ms step does not double the transition. Transition start is rejected before the host claim's authoritative transition clock.

For bootstrap sessions, `sync_native_vehicle_pose()` copies the exact bound `RigidBody3D` position/yaw into the logical host before access queries. It preserves occupancy and active claims. Imported sessions return `SOURCE_AUTHORITY`. Runtime pins the first validated vehicle and actor instance IDs per `(id, life_generation)`, so duplicate nodes with copied metadata cannot replace the body binding. A successful session replacement cancels every physical transition and releases provider-owned collision exceptions; an invalid session packet leaves the running transition intact.

An exact `DUPLICATE` retry from the bootstrap provider is a runtime no-op: it returns the original packet without restarting the host, rewinding clocks/roster, clearing actors, or dropping native body bindings.

## Astra9 contract review

The routed proposal `outputs/astra14_collection_20260926/a9/detach_consumer.contract.json` was verified at SHA-256 `34f8c890013b63eb036d780ed344d3a98dfc8d3fea619aeb1550caa94e023c78`.

Batch15's static negative validator `validate_detach_contract.py` was recorded at SHA-256 `7f0b56f9c660845eb4270de5b370b491df86509288483bdbf3c04896e3681b28`; its receiver reports 5 positive and 23 negative checks passing. This is a static baseline only. The R2 durable consumer remains `NOT_EXECUTED` and `NO_GO`.

Compatible guarantees are implemented here: exact opaque identity/generation matching, no detach on timeout/cancel, fresh physical evidence before motion, no source-authority mutation in imported sessions, and no life/HP/corpse writes. The proposal explicitly marks its durable DETACH consumer as `PROPOSAL_ONLY_INTEGRATION_NO_GO`. This slice does not claim its unimplemented durable journal, crash transaction, deduplication ledger, checkpoint compaction, or ActionArbiter integration.

## Reproduction and verification

Regenerate the descriptor:

```powershell
node tools/godot/export_transport_factory_oracle.mjs
node tools/godot/export_transport_descriptors.mjs
```

The exporter rebuilds parking from tracked placement/topology and the tracked compressed collision fixture. Repeated generation is byte-identical.

Headless tests use Godot 4.7.2:

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path godot/mafiozi_walk --script res://scripts/tests/test_transport_descriptors.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path godot/mafiozi_walk --script res://scripts/tests/test_transport_bootstrap_provider.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path godot/mafiozi_walk --script res://scripts/tests/test_transport_logical_host.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path godot/mafiozi_walk --script res://scripts/tests/test_transport_access_physics.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path godot/mafiozi_walk --script res://scripts/tests/test_transport_actor_transition.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path godot/mafiozi_walk --script res://scripts/tests/test_transport_runtime.gd
```

Current results:

- descriptors: 17 checks, 12 profiles, 59 bays, actual factory bounds/anchors and oracle byte pin;
- source bootstrap: 15 checks for provenance, source-world-minus-origin frame, real parking anchor, idempotency and zero imported births;
- logical host: 31 checks for bootstrap/import authority, generations, same-tick multi-actor clocks, occupied seats, native pose authority, action-specific transition timing and exit;
- physical access: 12 checks with actual Godot capsule sweep, initial overlap, bounded seated-root floor normalization, wall/deep-overlap negatives, body-only floor support, edge/water rejection, excluded vehicle RID, blocked path, and occupied landing;
- actor transition: 37 checks with actual `CharacterBody3D`, `RigidBody3D`, static collision, non-zero origin, 1.2-second smooth boarding and cancellation, two-phase source-clock lag, 200 ms bounded substeps, imported exception ownership, moving 15 km/h tumble/velocity continuity, source pose curves, safe board/exit and blocked cancellation;
- runtime seam: 25 checks with end-to-end non-zero-origin bootstrap, idempotent duplicate no-op, current moving-body pose, unique instance binding, early-clock rejection, session cleanup, far/closed-door rejection, fabricated-receipt rejection, 0.3-second hold and physical 1.2-second seat arrival.

All 137 scoped checks pass. Root's actual `test_preview_transport_scene.gd` adds 14/14 end-to-end main-scene checks for board, moving ride, supported exit, driver release, and restored walking. These are headless physical/logical checks. Visible LIVE acceptance, export and GPU cost remain Root-owned.
