# First actual residents: native host

27 September 2026. Production component `godot/mafiozi_walk/scripts/npc_visual/preview_resident_host.gd` is ready for root integration. Main/player/provider/cache/source files were not changed. No GPU process or Git operation was started.

Root explicitly accepted the corrected offline NEW_SESSION_BOOTSTRAP packet during this task:

- Packet `res://assets/npc_visual/session/e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096.json`.
- Prepared directory `res://assets/npc_visual/session/prepared`; manifest SHA `3c07e72938a0918fa32de33ca442bf07cb50f21f0916b8b091b552473bd9aac0`.
- Source visual manifest SHA `37d56f98aeaa3f5d1152a09cdf14744223ae697e7c56ad85ea75941b74552de6`.
- Source IDs `resident_72`, `resident_169`, `resident_252`; respective bridge IDs `npc_resident_N`. Their exact descriptors are verified again by the existing prepared cache loader.
- Rejected historical packet `384f1f2d2b673bde13a49cfdff2f88b4e84469801b1f572624c53259a472901d` is explicitly refused. No catalogue avatar becomes a resident.

## Integration API

`configure(scene, navigation_host, packet_bytes, trust, prepared_manifest_bytes, prepared_directory, owners, source_admit, support_height)` returns `{ok,error?}`. Scene must already contain the real main/Printshop geometry, have an identity global transform, and be the same scene attached to the supplied `PreviewNavigationHost`. No private replacement world is created.

`trust` is supplied by root, never taken from arbitrary packet self-declarations:

```gdscript
{
    "accepted": true,
    "packet_sha256": accepted_packet_sha,
    "sources": accepted_source_path_to_sha_dictionary,
    "session_id": "godot-preview-new-session-20260927-01",
    "prepared_sha256": accepted_prepared_manifest_sha
}
```

Root may obtain receipt entries from the packet only after checking its externally pinned accepted exact SHA. `owners` maps each source ID to a distinct existing `PathJobQueue.Owner.new(source_id, 1)`. The host retains these owner records for its session; it does not invent generations. Only the current three healthy ordinary initialization candidates are supported. Changed health, injury, crawl, boss, routine override or nonfinite motion input is rejected instead of becoming a healthy walker. Packet/manifest/row data are copied; body/owner lifetime is checked before admission and every movement step.

Mandatory external callbacks, strict boolean and finite-height returns:

```gdscript
source_admit(point: Vector3, source_id: String, generation: int,
             footprint_radius: float, purpose: String) -> bool
support_height(source_xz: Vector3, source_id: String, generation: int) -> float
```

`purpose` is `placement`, `target` or `route`. Callback must enforce current source role/access/dry-walkable policy, with centre and square corners at radius `.738 m` (`.18 source cells * 4.1`). Physics solidity is not permission. Return false for unknown permissions. `support_height` receives only source XZ (Y=0 is not an assumed floor) and returns the current source-consistent physical support Y; **return NAN when unknown/no hit**. A top-down ray onto an unrelated roof is not a source ground resolver. Actual test uses the source surface palette height as the ray reference and the existing collision world as proof.

The host independently proves support under centre/four corners and rejects an overlapping `.738 m` square, 1.9 m high box, including ceilings and current door leaves. Support tolerance is .18 m, upward normal at least .70, small .025 m floor clearance for the overlap volume. Route samples repeat this check in the current world, excluding only that resident's body. The navigation capsule is .36 m radius/1.9 m height; it does not replace the original factory footprint test.

- `admit_next()` processes at most one unattempted candidate. Supported actors receive a CharacterBody, exact prepared appearance and canonical gait; blocked/unknown placement remains `PENDING_PLACEMENT`, invisible, at the same source XZ. `retry_pending(id)` explicitly retries after input changes. No relocation search or fabricated birth.
- `request_walk(id, target)` accepts only finite nearby targets within 8 m. It requests the actual navigation backend; it never writes a straight-line route. Root chooses a source-admitted nearby clear point as the first limited walking instruction. This is not an NPC agenda.
- Root calls `navigation_host.pump(Engine.get_physics_frames())` once per physics frame, then `resident_host.step(delta)` once (`0 < delta <= .05`). This host is the sole movement writer for its own bodies. `move_and_slide`, floor snap, engine collision and the previously verified nav path determine displacement. PENDING, NO_PATH, STALE, ARRIVED and BLOCKED remain distinct. No automatic repath.
- `occupants()` returns `Array[Dictionary]` with `{position,radius:.36,height:1.9,source_id,life_generation}`, directly compatible with existing PrintshopInterior door occupancy. Append these records to the root's existing occupants **both when requesting a door and advancing it**. Notify navigation of an accepted transition before the first door rotation, and pump after settled transitions as described in the navigation handoff. Door start and access revision changes stop all old receipts immediately.
- `snapshot()` returns detached identity/status/position/speed rows, not mutable bodies/source records. Owner death removes its owned body on the next host step; there is no birth fallback. `dispose()` cancels only its jobs and frees only its owned bodies; it is idempotent and hooked to scene exit. It does not dispose the externally owned navigation host/queue. Main-thread only, mutation reentry is rejected, callbacks must not mutate scene ownership while running.

Admission is initialization work, not a normal tick: cache verification, private resources and one-time actual boot hull extraction cost 27–38 ms per candidate here. Prepare the three residents during scene startup/loading; do not call all three inside an established gameplay frame. The three-actor maximum is explicit. No city-wide scaling claim.

## Source speed and presentation boundaries

Raw source speed is **not** directly multiplied by 4.1. This component freezes the source `_npcEffectiveSpeed` healthy civilian branch at receipt time: `.4` civilian base, fatigue `.35`, fear `.5`, final 1.8 m/s civilian cap. Actual JS function oracle returns:

| ID | m/s |
|---|---:|
| resident_72 | 1.3118482738187358 |
| resident_169 | 1.8 |
| resident_252 | .912652391870984 |

The generator extracts and executes the real current function from world.html, not a handwritten oracle. Function SHA `6812fa521db4a3b63e387da2a728d0a95a96ca6d276a52749641cca22217d6a0`. No ongoing fatigue/health simulation is asserted.

Existing `PreviewLocomotion` applies the source canonical hero standing gait to actual prepared rest transforms, and actual boot geometry supplies ground correction. Gait phase follows measured physical displacement, not requested speed. Source initial angle uses `PI/2-ang`; one visual PI rotation maps canonical +Z to the native body's -Z heading. Appearance and scale are not applied twice. **Additional source `npc_locomotion_pose.mjs` stride/stance footplant IK is not ported by this host**. Boarding, wounds, agenda, commerce, service FSM, network/save authority and full-city population are outside this slice.

## Actual tests and costs

```powershell
node godot/mafiozi_walk/scripts/tests/fixtures/build_resident_speed_oracle.cjs
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_preview_resident_host.gd
```

Godot 4.7.2 official: **73 checks PASS**, actual main scene, existing crop/Printshop colliders and actual three accepted prepared residents. Tested missing root acceptance/owner/callback; wrong lifetime; historical packet; no support; access denial; source-square corner obstacle beyond .36 capsule; actual low ceiling; duplicate physical identity; immutable descriptor and source XZ; correct initial facing; native map/path arrival for every actor; moving actual thigh bones; revoked source permission during delayed query; explicit retry; access-version invalidation; door transition STALE before rotation; owner death; teardown preserving the original player. Maximum physical step **.030013 m**, no actor teleport. Each actor walked roughly 1.85 m toward its 2 m target (backend arrival tolerance .15 m).

Same actual polygon scene/three actors, source square queries and physical path follower:

| CPU host update | p50 | p95 | max |
|---|---:|---:|---:|
| Before query reuse and removing redundant circle samples in test source guard | .953 ms | 1.412 ms | 1.973 ms |
| 73-check run before final height/dead-owner guards | .765 ms | 1.023 ms | 1.685 ms |
| Final 73-check module | .757 ms | 1.167 ms | 6.661 ms |

Repeated optimized runs had p95 .894–1.182 ms; the final run also had a 6.661 ms tail outlier, whose cause is not established. Do not promise a sub-millisecond worst-case budget. Final cold admission maximum 33.665 ms. Update costs include the three gait writes and `NavigationHost.step` physical checks; asynchronous bake/query/startup costs are separate. The permission callback cost belongs to the host integration budget: check the five required source square samples directly, not five redundant 13-point circle guards. Physics queries are reused without caching answers across frames; dynamic geometry/access is never hidden behind stale cached clearance.

Final module SHA256: `c8f3019aed3df7c6c908852ef95d2d70ee36750dd2b143c4574cc85f1ea71b06`.

**Performance of the full visible scene is not verified.** Root must perform the single-window LIVE/FPS check after wiring. No new visible window was opened for these tests.
