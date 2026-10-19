# Resident lease for the full-world editor — source audit, 30 September 2026

Status: **HOLD**. This is a source-only contract, not an implemented pause or K
approval. No Godot, GPU, production, main, or navigation code was changed.

## Actual ownership and limit

`main.gd` constructs `PreviewPopulation` at startup, sends accepted printshop
door starts to it, calls `population.step(delta)` from `_physics_process`, and
disposes it at scene exit. `PreviewPopulation.step` pumps navigation, advances
residents, then advances the staged walking exercise. Its three public paths
`step`, `door_started`, and `request_walk` have no pause guard. The population
owns `Queue.Owner` identities, policy, navigation, queue, and the resident host.

`PreviewResidentHost` owns each `CharacterBody3D`, gait/motion objects, status,
request ID, yaw interpolation, walking-exercise clock, and admission. Public
mutators are `admit_next`, `admit_preview_stage`, `bind_placement_source`,
`admit_candidate`, `enable_walk_preview`, `preview_walk_step`, `retry_pending`,
`request_walk`, `step`, and `dispose`. `_route_admit` synchronously calls source
policy and physics during navigation work; `dispose` may defer through `_busy`.
`Queue.Owner.dead` is externally writable. `Policy.update_access` and nav
`update_access_version` are separate mutators. `queue_free` leaves a body valid
until deletion, so `is_instance_valid` and `occupants()` are insufficient as
quiescence tests. Resident `snapshot()` omits body/RID identity, velocity,
pose/gait, request IDs, exercise clock, `_busy`, and deferred disposal.

The actual native preview accepts **exactly three** local session residents
(`MAX_RESIDENTS=3`, IDs 72/169/252) in preview-stage placement. It explicitly
has no original agenda or source birth for this scene. It is not the claimed
full default population (~326), whose owner/admission and persistence have not
been shown. A lease over these three cannot approve default-residents K.

## Required owner API, compatible with the separate nav seam

The owner, not an external snapshot adapter, must expose
`begin_editor_pause(owner: Node) -> Dictionary`,
`verify_editor_pause(receipt: Dictionary) -> bool`, and
`end_editor_pause(receipt: Dictionary) -> bool` at the population boundary.
The same phase rules as the tools-only navigation seam apply: begin on main
thread before `SceneTree.paused`, verify while paused, end immediately after
unpausing and before the next physics tick. Receipt must be unforgeable in
practice by matching the exact active object-held lease (not merely its
client-supplied fields); non-reentrant, one lease, monotonic generation.

1. **Admission:** require exact scene/owner and active tree, no pending
   `queue_free`/`tree_exiting`, population `ready`, resident host and policy
   alive, no `_busy` or `_dispose_requested`, complete expected cohort, stable
   body/rig parent and collision, all `Queue.Owner` identities alive and their
   life generations current. Pin session/packet/prepared/source-policy hashes,
   population/host instance IDs, owner generations, placement modes, every
   body instance ID and RID, transform/velocity, motion yaw, gait/pose, status,
   request ID, walking-exercise clock/state, policy access version and nav
   receipt. Any pending admission, removal, route callback, door transition,
   path record/job, or body deletion rejects admission unless its exact state
   has a separately proven hold/replay contract. The current nav candidate
   already rejects active records/jobs; walking NPCs therefore remain HOLD.
2. **Hold:** an owner-held `_editor_pause` gate must reject or explicitly
   fault the receipt on **every** resident/population mutator above, including
   direct host calls; it cannot rely only on main's physics pause. Nav/queue
   callbacks and policy access changes must be held or rejected by their own
   owners. External `Owner.dead`, direct body movement/deletion, scene exit,
   and source-policy changes must invalidate the receipt (or be prevented by
   an identified upstream owner). No silent cancel, respawn, clock reset, or
   route rewrite. The pause receipt is a capability for editor orchestration,
   never a source-authority claim.
3. **Verify:** compare exact lease identity and pinned instances, session,
   cohort cardinality, source IDs/generations, parent/body/RID/rig identity,
   not-queued-deletion state, transform, velocity, gait/pose and presentation
   yaw, request/status, exercise clock/counters, and owner/policy generations.
   A changed map geometry may be expected during editing; it must not be
   mistaken for permission to move or silently alter a resident. Verify nav's
   separate receipt and new collision/access validity before release.
4. **Release:** while still holding residents, complete map commit/rollback
   and rebuild/validate relevant collision and nav against the final geometry.
   Release navigation and residents synchronously after tree unpause but
   before any physics tick, with a defined order that cannot run stale
   callbacks between them. Old paths must be invalidated by the nav owner;
   only the real resident owner may re-request from current body position and
   current source access/generation. Preserve exercise-clock elapsed time;
   do not replay missed `delta`. If any verification or rebuild fails, keep
   editor paused and receipt faulted; disposal is terminal, not resume.

## Minimum native test matrix before K

| Case | Required result |
| --- | --- |
| Ready stationary three, pre/post first physics step | Begin/verify/end; exact body/RID/pose/clock equivalence during hold; natural next tick. |
| `PENDING`, `READY`, `ARRIVED`, `BLOCKED`, stale route; backend job queued | Either exact held-job replay or explicit begin refusal; never cancellation disguised as pause. |
| Door opening/closing, access-version update, changed goal without leaf motion | Begin refusal or receipt fault; no stale path after release. |
| `admit*`, `retry_pending`, `bind_placement_source`, `enable_walk_preview`, direct `request_walk`, `step`, `preview_walk_step`, `door_started` during hold | Rejected/faulted by actual owner gates; no new body, route, clock tick or status change. |
| Source callback reentry and deferred `dispose`; `Owner.dead` flip/generation mismatch | No successful stale receipt; no orphan body or accepted route. |
| Direct body move, velocity/collision/rig change, `queue_free`, scene exit | Verify fails closed, even before deletion completes. |
| Repeated pause, wrong owner, copied/modified/old receipt, rollback/commit, failed nav rebuild | Reject stale or mismatched lease; no partial resume. |
| Full default cohort and save/reload | Must use its real owner, all expected IDs, agenda/persistence and source authority; **not covered by this three-resident preview**. |

## Why there is no tools-only resident adapter yet

A detached wrapper could suppress calls *through itself*, but callers also hold
`population.residents`, `population.navigation`, and `owners`; production
`main.gd` calls population directly. It cannot freeze direct owner mutators,
external body/owner changes, or pending `queue_free`, and public snapshots do
not expose enough state to verify those changes. Implementing a wrapper and
calling it a lease would be a false positive. The next legitimate step is a
source-pinned **tools-only subclass/fixture of the actual population and
resident owner** implementing the owner gates, followed by native negative
tests and root-controlled production integration; no nav candidate overlap.

Source SHA-256 pins: `preview_population.gd`
`4c25bf2644f29f91e0a75d38e4d553127fee8e127bf269435c42ab55b361c724`;
`preview_resident_host.gd`
`553bc08ac8f54fc3e64727aa7d3608e01bffe9042d6736c5495b9723b020f174`;
`preview_resident_world_policy.gd`
`f4e35012690fd4c6cd2c43a6973a8bb9d92b7ad34d493eba5084715eb6ed17f8`;
`path_job_queue.gd`
`dc19de386ccef8e23dcf1c2f0b62f6a46f7f816cf8fd5c3c26c8a6409b7be473`;
`preview_navigation_host.gd`
`0b6fd34bc1d77e1f27c2005b699477453f089f4f65bf7d21942e73adbad631d4`;
`main.gd`
`faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53`.
