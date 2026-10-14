# Native post-ladder grounding — 27 September 2026

Owner traversal; new additive component. No main/player, source descriptor,
accepted interior adapter, existing controller, Git or GPU edit.
Base checkpoint78e67c826071f9c55d72a909d0c2ad4bd6488685.

## Result and limits

`scripts/traversal/ladder_landing_settle_probe.gd` proposes a bounded downward
physical settle from the exact authored roof step-off onto actual native support.
Actual source printshop authoredY6.585, queried roofY6.47, drop.115000248m.
Actual-main headless test also uses an extra TEST_ONLY CharacterBody with full
standing capsule: all four ordered roots are accepted by move_and_collide and
fresh support revalidation, reaching the roof without collision exceptions.
The real main player is untouched. This is NOT player integration or LIVE.

The prior source component still applies: source collision corridor/rails must
be connected separately. Current unchanged controller.try_begin still rejects
the unbound source route. This proposal alone does not make ladders playable.

## API and ownership

- configure(real direct_space_state, collision_mask, actor_rid)
- inspect(authored_feet, optional max_drop_m) -> valid/reason, authored_feet,
  grounded_feet, drop_m, ordered_roots, five supports and query authority.
- revalidate(receipt) -> fresh receipt or explicit rejection.
- dispose() clears space/query authority and rejects stale receipts.

No scene/body/root/shape/filter writes. No source/body floor exclusions.
Maximum drop .28m comes from existing native ladder support-ray envelope;
the optional requested bound can only REDUCE it. Existing .08m support height
spread and .22m support radius are preserved. Five real rays must agree with
walkability and static support; no upward or horizontal correction admitted.
Sweep uses full1.9m/.33m capsule, .012m floor skin, max.04m ordered root steps.
Terminal grounded support rechecked with existing native ladder five-ray test.

Each support receipt retains real RID/instance/sourceID/body transform and
PhysicsServer shape index/RID/local transform plus exact ray hit/normal.
Revalidation rejects removal, same-looking body or shape replacement, movement,
changed query mask/actor, malformed receipt, new blocker/ceiling or bad support.
AnimatableBody3D explicitly rejected (inherits StaticBody3D in Godot), as are
nonzero StaticBody conveyor linear/angular velocities. This is a STATIC roof
settle helper; moving vehicle/support transitions need their existing own policy.

Root/controller seam:
1. Lease actual source ladder identity and current support data. Use only after
   an admitted ladder traversal, not as a general teleport/step helper.
2. For route admission, validate authored route and this additional final settle
   as one ordered plan, keeping the source descriptor/path untouched. Existing
   raw try_begin lacks that integration and must not be claimed operational.
3. Keep traversal/input ownership until physical settling completes. Revalidate
   before each physical root sample, use native CharacterBody sweep, commit only
   accepted prefixes; never set final root blindly or advance pose optimistically.
4. Release input/ladder and restore own temporary route filters only after
   grounded final support; abort at actual accepted root when stale/blocked.
5. Dispose/reconfigure on scene/actor lease changes. Root alone owns player and
   one pose writer, collision filters, central E and Ctrl active ladder inputs.

## Verification

Official Godot4.7.2 headless test test_ladder_landing_settle.gd208 PASS:
48 functional checks including real main/extra physical actor, plus160 warm
query receipts (only128 after warmup used for profile).
Independent native test38/38 PASS in three owner runs; it caught the
AnimatableBody3D inheritance bug before freezing. Independent inspect+revalidate
warm cost p50 160-170us / p95 225-329us (isolated native fixtures, not city FPS).
Final frozen hashes/receipts are in
outputs/ladder_landing_settle27/manifest.json and accompanying reports.

Actual loaded-main isolated inspect cost observed p50/p95 85/118us over128 warm
queries. This is direct query/receipt CPU, not physics frame/GPU/full city FPS.
It is bounded to5 rays plus <=8 capsule samples plus terminal5 support rays.
No run loop, population work or cache rebuild per frame. Root must measure its
actual host application/revalidation cost after wiring; currently unconnected.
