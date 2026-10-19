# Native physical ladder executor — 27 September 2026

Traversal owner. Additive opt-in component only; root main/player ownership unchanged.
Frozen executor SHA256 `3be308e27dc5726e36b38c47082eca84545d2d3071b4e891ddacd1a872e628d1`.
Files/receipts: `outputs/ladder_physical_executor27/manifest.json`.

## Result and evidence

`scripts/traversal/ladder_physical_executor.gd` executes the admitted source route
through real `CharacterBody3D.move_and_collide`. It owns no automatic process,
input binding, node process flags, velocity, root yaw, shape or rig writes.
Actual main TEST_ONLY player-sized capsule radius .30 / height 1.9 / collider Y .95
completes source Printshop ascent and Ctrl slide: 1327 PASS, 852 physical samples.
Actual convex source-index mapping verified point-for-point. Repeat E after slide
and a late dynamic blocker preserve actual root and restore only owned filters.
The foreign host exception survives both routes, abort and dispose.

Independent 77 PASS x3 with unchanged executor hashes; parent current-byte77 PASS.
Coverage includes 10/30/60/144 Hz, cancel return, native floor skin, actor geometry,
root/mask/layer/margin/basis/lifetime changes, freed source cleanup and reconfigure.
Independent report: `outputs/GODOT_LADDER_PHYSICAL_EXECUTOR_INDEPENDENT27.md`.
This is NOT actual PreviewPlayer/input/Skeleton3D/default main/export/LIVE adoption.

## Root API / authority contract

1. Configure once with the caller's actual in-tree CharacterBody3D. Exactly one
   standing capsule: height1.9, radius<=.33, collider centerY .95.. .962, identity
   body/shape basis, safe_margin finite 0.. .012. Current actor shape RID/data,
   transform, mask/layer, margin and space are leased. No standing-size rewrite.
2. A single admitted E calls `begin(source_descriptor, end, records, &"interact")`.
   Other input_action passes through. Current source records retain exact real
   body/source_static_index/building_entry_id/String storey_part proof from the
   planner handoff. Missing source roles or fabricated source IDs are rejected.
3. While `busy()` (pending OR active), root MUST suspend all other actor root
   writers, gravity/move_and_slide and external collision-exception mutations.
   E baseline captures host exceptions once. Godot4.7.2 has no PhysicsServer3D
   collision-exception getter; runtime tracking uses borrowed/owned RID sets.
   Never start with stale caller-owned exception objects awaiting host cleanup.
4. Automatically call `advance_admission(16)` each physics frame until complete;
   do not require repeated E. Pending admission never physically moves the body.
   Ctrl is admitted only after active E, through `request_slide()`. Pending Ctrl
   passes through this component; root's ownership arbiter must suppress cover
   while ladder E admission owns the actor.
5. Active `step(delta_s, optional_actual_rig)` validates each <=4cm segment against
   fresh source geometry/support/identity and current conservative capsule, then
   performs real movement. `state`, `actual_root` and `committed_pose` all use the
   actual body position. Root keeps sole rig/weapon/input authority.
6. Active `request_cancel()` returns physically through Motion history; pending
   cancel revokes admission without movement. `abort`/`dispose`/reconfigure/normal
   completion remove ONLY exceptions added by this executor. Direct native RID
   removal safely handles an owned exception body freed after admission; native
   object enumeration in that case caused engine errors and is intentionally
   avoided during runtime/cleanup. Preexisting valid host exceptions persist.
7. `move_and_collide` does not update CharacterBody floor flags. Root must resume
   its ordinary floor/gravity/velocity state from actual support after completion,
   and needs an explicit physical recovery branch for aborted mid-route ownership.
   `needs_physical_recovery` is true for an aborted active state. Releasing source
   corridor filters mid-crest can leave overlap in an authored source envelope;
   this helper does not invent an escape teleport or claim recovery is implemented.

## Native floor skin / accepted-prefix fidelity

Actual .30/.95 capsule has feet at the authored floor; native safe_margin can
recover it by <1mm before/after movement. Requiring an exact planned endpoint
wrongly rejected ordinary ascent, upper E and lower landing. Bounded handling:

- First proposal only, starting state.travelled_m==0: each correcting segment
  starts from real five-ray-supported feet. Error length<=min(.012, safe_margin
  +10um), vertical error>=-10um; any reported collision must be walkable. Handles
  the initial tiny source-alignment segment plus subsequent first upward segment.
- Terminal targets include repeated final nodes in cancel history, not just the
  Motion release/index receipt. XZ error<=10um, upward error within the same margin,
  real five-ray support and walkable reported normal are mandatory.
- Every nonexact accepted endpoint is re-queried at its actual position before
  restoring corridor exceptions. Intermediate unsupported corrections are rejected.
  Actual partial movement still wins on failure; no planned-root teleport.

Source descriptor/path/stepOff and Motion/Pose remain unchanged. The planner's
derived roof settling remains .115m to actual roofY6.47; native skin is additional
actual physics evidence, never a source endpoint rewrite.

## Cost / limits

Current loaded-main headless final: admission call p50/p95 2.197/2.767ms (62 calls,
includes third repeat-E attempt); executor step 2.511/3.955ms (402 calls across
ascent and slide). Includes native body movement, source leases, shape queries,
filter changes and pose proposal, excludes render/full rig application.
Removed redundant whole-frame inspect: every segment already revalidates source
lease plus conservative endpoint before moving. Earlier equivalent two-route
headless run was3.528/4.714ms, final2.511/3.955ms. Separate-process measurements,
not a paired GPU/full-scene FPS acceptance. Full loaded source CPU work remains
material; root must measure actual integration and choose budgeted admission.
No content/colliders/IDs/authority deleted, no GPU window or Git changes.

Main/root wiring and exact Skeleton3D pose application remain dependencies;
standing actor shape is required, so root must exit ordinary crouch/cover through
its central state owner before successful configure. No NPC ladder reuse claim.
