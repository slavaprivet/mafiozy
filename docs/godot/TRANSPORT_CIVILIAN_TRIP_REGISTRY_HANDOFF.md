# Civilian planning trip registry

Additive transport component; frozen boarding revision6 unchanged.
Source: civilian_parking_trip_source.js lines7–11, SHA460b197ee52c2facf2b63cdc8d4877aaa6314257ebaccda30459b50bcde2fabc.
Admission dependencies: TRANSPORT_CIVILIAN_DRIVE_MAPPING.md.

API: begin_session(id,generation); reserve(session_id,generation,caller_token,actor_ref,vehicle_ref); trip(token); release(token,incarnation); reconcile(session_id,generation,complete_actors,complete_vehicles); clear/count.
Refs require exact existing actor_id/vehicle_id and integer life_generation.
Only phase planning; sixteen trips, exclusive actor/car lifetime indexes, defensive snapshots and duplicate no-op. Returned incarnation is local registry identity, never a source entity ID or authority receipt. Caller retains incarnation for cancellation; stale cancellation cannot remove replacement. Counter survives clear/session disposal. Stale reconciliation is inert and same-session generation rollback rejected.

Root seam: admitted real NPC/vehicle owners and source intention/access selection approve BEFORE reserve. Only RESERVED allows caller to cancel old civilian plan/route. Helper does not set source flags, complete agenda, reserve parking, grant seat/driver or execute movement. Caller publishes source flags and reconciles interruptions/removals using complete same-session rosters. Cropped preview is insufficient. Physical begin_board comes later; missing providers retain migration pending.

Actual Godot4.7.2 author and independent41 checks PASS: conflicts, replacement, stale token/session, capacity, defensive copies and reset. Independent reviewer caught reusable-token cancellation; fixed with monotonic incarnation and independently rechecked. Cross-session stale handle behavior statically reviewed; explicit fixture covers same-session reuse. Ten thousand reserve/read-handle/release cycles author197131us, independent142796us (14–20us/cycle), isolated fixtures, not loaded-scene FPS/LIVE. No runtime population created.

No foreign runtime/Git/GPU changes. Full candidate grid, attempt budget, body policy and lane/parking lifecycle remain separate dependencies.
