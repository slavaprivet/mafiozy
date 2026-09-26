# Godot native transport — first logical slice

## Delivered scope

This slice is confined to `scripts/transport`, transport tests/data, and its exporter. It does not edit the player, main scene, project settings, export settings, navigation, NPC visuals, or `scripts/vehicle_physics`.

The tracked Walk sources are exported into `data/transport/vehicle_descriptors.v1.json`:

- all 12 real vehicle profile/model identities and source hashes;
- each profile's actual two- or four-seat layout, left driver, door, handle, seat, and outside approach anchors;
- the current deterministic city parking plan: 39 lots and 59 bays with stable IDs;
- SI units and an explicit source-to-Godot basis conversion (`+Z/+X-left` to `-Z/-X-left`);
- fields absent from the Walk source remain `null` and are listed in `unavailable_in_walk_source`. The exporter does not fabricate suspension, centre of mass, track width, ground clearance, or angular drag.

`transport_logical_host.gd` owns the bounded logical roster, seat claims, and 0.3-second hold lifecycle. It accepts only explicit session and roster packets. It never creates an actor or vehicle by itself.

- `NEW_SESSION_BOOTSTRAP`: an explicitly supplied native roster may commit boarding and exit locally.
- `IMPORTED_EXISTING`: a completed hold returns `AWAITING_SOURCE` plus a stable command. Occupancy changes only after a newer authoritative roster confirms it.
- Identities are exact, case-sensitive `(id, life_generation)` pairs. Replacing a vehicle with a newer generation invalidates old references and leases.
- Source clocks and roster revisions must move forward. Continuous hold samples may be at most 120 ms apart, so a missed interval cannot satisfy the 300 ms requirement.
- The driver is always `front_left`. Each occupant uses that seat's own door. Busy actors and occupied or claimed seats fail closed.
- Release, cancellation, an unsafe probe, and continuity loss clear the lease without detaching an occupant.

`transport_access_provider.gd` uses `PhysicsDirectSpaceState3D.cast_motion` and a destination overlap query with the actor capsule. Boarding or exit is admitted only when the capsule path and landing are both clear. The vehicle body RID can be excluded so the actor can move through its selected authored door while all other collision remains active.

`transport_runtime.gd` is the integration seam. It loads the catalog, hosts the roster, produces a fresh physical receipt for every begin/advance call, and exposes:

```gdscript
begin_session(packet)
publish_roster(snapshot)
begin_board(actor_ref, vehicle_ref, seat_id, source_clock, actor_feet, excluded_rids)
begin_exit(actor_ref, vehicle_ref, seat_id, source_clock, actor_feet, excluded_rids)
advance_interaction(token, e_is_pressed, source_clock, actor_feet, excluded_rids)
cancel_interaction(token)
```

Root must instantiate this node and feed the real source/native roster; this package deliberately has no fallback vehicle, actor, session ID, or birth. The physics owner can read the immutable profile values from the descriptor. The player integration must pass the selected vehicle body's RID in `excluded_rids` and apply visible door/actor motion only from admitted results.

## Astra9 contract review

The routed proposal `outputs/astra14_collection_20260926/a9/detach_consumer.contract.json` was verified at SHA-256 `34f8c890013b63eb036d780ed344d3a98dfc8d3fea619aeb1550caa94e023c78`.

Compatible guarantees are implemented here: exact opaque identity/generation matching, no detach on timeout/cancel, fresh physical evidence before motion, no source-authority mutation in imported sessions, and no life/HP/corpse writes. The proposal explicitly marks its durable DETACH consumer as `PROPOSAL_ONLY_INTEGRATION_NO_GO`. This slice does not claim its unimplemented durable journal, crash transaction, deduplication ledger, checkpoint compaction, or ActionArbiter integration.

## Reproduction and verification

Regenerate the descriptor:

```powershell
node tools/godot/export_transport_descriptors.mjs
```

The exporter rebuilds parking from tracked placement/topology and the tracked compressed collision fixture. Repeated generation is byte-identical.

Headless tests use Godot 4.7.2:

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path godot/mafiozi_walk --script res://scripts/tests/test_transport_descriptors.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path godot/mafiozi_walk --script res://scripts/tests/test_transport_logical_host.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path godot/mafiozi_walk --script res://scripts/tests/test_transport_access_physics.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path godot/mafiozi_walk --script res://scripts/tests/test_transport_runtime.gd
```

Current results:

- descriptors: 13 checks, 12 profiles, 59 bays;
- logical host: 23 checks for bootstrap/import authority, generations, clock fencing, occupied seats, hold and exit;
- physical access: 5 checks with actual Godot capsule sweep, excluded vehicle RID, blocked path, and occupied landing;
- runtime seam: 6 checks with the actual physical provider and complete 0.3-second boarding.

All 47 checks pass. These are headless physical/logical checks. Production scene wiring, visible door and actor animation, export, GPU cost, and the single LIVE game remain open for Root integration and acceptance.
