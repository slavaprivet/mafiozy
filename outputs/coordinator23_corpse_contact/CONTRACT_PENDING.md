# Player contact / NPC final-dead owner — proposal only

No production or NPC file edited. No masks, transforms, HP, pose, bone or ragdoll state written. No GPU. The sampler parses, but actual-world behavior/performance has NOT been accepted. Do not enable until Artist23 publishes the public owner methods and measures the force limits.

## Root hook

`root_player_contact_PROPOSAL.patch` adds an optional sampler ONLY around the normal grounded `move_and_slide()` path. With no explicitly bound owner there is no sampler, no shape query and no force. Existing jump/dive branches and non-on-foot vehicle ownership return before it. Both start/end floor, pose epoch and physics frame must match; menu/free cursor, invalid delta, zero motion and teleport-sized movement are rejected.

The sampler sweeps the unmodified original PlayerCapsule along actual completed movement, not desired movement. Query mask256 is a read-only physics query; player mask1 and NPC mask257 remain unchanged. Native rest-info supplies exact collider instance/RID, shape index, contact point, normal and body point velocity. Only low contact points are admitted for consideration. Positive horizontal closing speed is required. A separate layer1 ray rejects contact through a wall. No vertical impulse is requested.

Work bound: at most one cast, two rest-info calls and one world obstruction ray per eligible moving frame; one owner readiness call after cheap motion gates. Global admission cooldown is at least50ms, with owner-supplied stronger rate. No scene/actor/body scans, no generation cache, and no per-frame mesh work. Initial overlaps use native `get_rest_info` at the actual starting capsule transform before attempting a sweep. The sweep runs only when that initial real contact is absent; moving-away and stationary cases still reject. No proximity or synthetic normal/contact fallback exists.

## Public NPC owner contract requested

Root binds two **public** Callables via `player.set_final_dead_contact_owner(ready, admit)`. Names below are proposed, not claims that these methods exist:

1. `player_final_dead_contact_ready() -> Dictionary`: `{ready:true, schema:"npc_final_dead_contact/v1", epoch:<owner contact epoch>, max_impulse_ns:<measured positive cap>, impulse_ns_per_mps:<measured gain>, cooldown_ms:<50..1000>, max_contact_height_m:<positive <=.65>, max_relative_speed_mps:<measured cap>}`. Any missing/not-ready contract disables work. No force defaults supplied by root.
2. `admit_player_final_dead_contact(request) -> Dictionary`: sole authority to validate the current contact and apply force. Request contains actor instance/RID/pose epoch/frame/start/end/actual velocity; exact target instance/RID/shape/contact normal/point/velocity; source owner epoch; bounded horizontal suggested impulse; unique event ID; `delivery:"command_unapplied", damage:false`.

The owner MUST atomically recheck:

- same scene/session/source ID/life generation/rig epoch/body identity and active physical lease;
- accepted authoritative final death (HP0/dead plus current physical final_dead), never alive, medical survivor, recovering, replacement, retired or stale binding;
- request RID/shape belongs to that exact current articulated body, actual local contact is sufficiently close, current point velocity/relative speed remain plausible;
- same current physics frame and player on-foot grounded movement, no externally claimed event replay;
- per-corpse cooldown and duplicate event IDs **before** applying. A root global cooldown alone is not sufficient when another producer may exist;
- owner-measured total/body impulse and post-impulse linear/angular energy limits, preserving joints and collisions.

Only then use the existing native body impulse path. The current private `apply_impulse(point,J,event_id)` wakes its nearest segment and preserves joints, but does NOT deduplicate event IDs and accepts contact distance up to.75m. Those are insufficient as public admission guards. It may select another nearest segment of the SAME owned articulated body at a joint; the public receipt should report exact applied segment and J. Never apply to another actor based only on spatial proximity.

Return `{ok:true, event_id, source_id, life_generation, applied_segment, applied_impulse_ns, woke_sleeping, owner_epoch}` only after success. Rejection must be mutation-free. Root never falls back to direct private-body calls.

## Sleeping versus frozen

`exit_ragdoll_body.gd:339` wakes ordinary sleeping native bodies in `apply_impulse`. In contrast, `freeze_at_rest -> stop_preserve` sets body layer/mask0, disables shapes and marks `_paused=true`; such a body cannot be discovered by the query and the impulse API rejects it. This is an owner lifecycle decision, not permission for root to restore masks. Artist23 and root confirmed the actual current NPC ACTIVE final-dead path does NOT call `stop_preserve` or `freeze_at_rest`; its layer256 bodies remain active and ordinary sleeping can be awakened. `stop_preserve` in this host belongs to recovery only. The frozen-state distinction is a future/invalid-state guard, not a diagnosis of current corpses. Root should never reactivate RECOVERY_HOLD, retired or invalid bodies.

## Acceptance after the owner contract

Native fixtures must cover moving player vs current dead sleeping body (visible physical response, joints intact, no pose/root teleports), second independent corpse, wall separation, stationary proximity, glancing/negative relative motion, grounded vs jump/dive/vehicle, medical and alive actors, stale RID/life/epoch, duplicate event IDs, 16-segment contact bursts, disposal and future frozen-state behavior. Confirm HP/blood/death revisions unchanged. Compare full-scene frame time before/after with same NPC count; no GPU acceptance claimed here.

This adds physical nudging along actual walking contact, not hard player-body blocking. If solid blocking is also desired, collision-mask ownership needs a separate explicit integration contract; this proposal does not silently change it.

## Native query test result after initial-overlap fix

`test_native_contacts.gd`: **54 PASS**, internal154ms / process0.53s, real production preview_player and original capsule, native floor and sleeping (not frozen) RigidBody3D layer256. Entering and continued initial-overlap each produce one real-contact proposal. Moving away, stationary, wall-blocked, vehicle, jump, stale pose epoch and stale physics frame produce zero. Same-frame duplicate call produces one proposal only. Exact collider instance/RID/shape, finite native contact, bounded horizontal J and unchanged sleeping target checked.

Spy owner ONLY records and returns rejection; it never applies force, changes HP or accepts an NPC lifecycle. Therefore this proves query/guard behavior, NOT real NPC force strength, owner final-death admission, wake-up, physics response or full-scene performance. `NATIVE_QUERY_RESULT.json` retains these limits. The first fixture run failed only because the newly created body had not naturally gone to sleep;90 warmup physics ticks now let the native body settle before testing, with no freeze or force patch.
