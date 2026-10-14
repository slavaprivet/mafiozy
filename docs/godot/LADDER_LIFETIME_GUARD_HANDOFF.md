# Synchronous native ladder lifetime guard — 27 September 2026

Traversal owner. New additive `scripts/traversal/ladder_lifetime_guard.gd`.
Frozen guard `2d72852ea12657e393bbb5e03e05586730e323cce3f16dae87ed1ab00a117aca`.
Dependent executor `f222586aca891cda631005b07c11a872d98c7e280084d800d3a452b0c574ab4a`.
Manifest and actual-main/native logs: `outputs/ladder_lifetime_guard27/`.

## Result / superseded pin

Synchronous actor/source `tree_exiting` observers abort the busy executor before
the source body finishes leaving/frees its native RID. They release only executor
filters and notify the central recovery owner with real-root receipts. No polling,
per-frame observer, automatic processing, input/rig/root/HP/gravity/velocity write.

The executor's ONLY change from previous3be308e2 package is read-only
`lifetime_authority()`. It returns current busy actor identity and canonically
captured source body/RID/instance identities. No caller-supplied node list can
replace the admitted source mapping. The previous physical execution algorithm
is unchanged. Earlier manifest remains historical; use this NEW executor pin for
adoption, NOT the old3be308e2 pin. Old exact bytes archived when pin verified.

Actual-main427 PASS includes exact source-index convex geometry proof, pending
and active source direct free, native filters acquired/released before free,
unchanged real root, explicit active-only recovery requirement, persistent host
exception and one-shot callbacks. 192 arm/disarm cycles do not accumulate actor
connections or revoke executor ownership. Independent31 PASS x3, parent31 PASS:
pending/active actor and source queue_free/free, duplicate arm, disarm, listener
dispose/rearm/stale epochs, completed-route source exit with no interruption.
Executor regressions unchanged1327 actual-main +77 independent PASS after addon.

## Root integration seam

1. After single E `executor.begin()` accepts pending ownership, call
   `guard.arm(executor)`. This connects exact actor plus ALL current source nodes,
   including rails. If arm fails, the host must abort its pending/active executor
   and handle the returned recovery need; do not leave unobserved ownership active.
2. Connect `interrupted(reason, receipt)` to the central owner. Reasons are
   `source_tree_exiting` / `actor_tree_exiting`; these do NOT imply HP death or
   authenticated gameplay damage. Receipt.actual_root is captured at interruption;
   pending interruption needs no active-route recovery, active interruption does.
3. The guard revokes/disconnects links BEFORE calling executor.abort and BEFORE
   emitting to external listeners. A recovery callback may dispose or arm a new
   executor safely. Epoch checking rejects the old node's already queued callbacks.
4. On normal completion, external authority takeover or host abort, explicitly
   `guard.disarm()`; on host teardown `guard.dispose()`. Disarm only disconnects
   this observer, does not abort an executor. Re-arming first disarms old links.
   It is not an automatic ownership-transfer or recovery action.
5. A late source/actor exit after normal completion silently disarms without
   emitting interruption because the executor no longer owns movement.
6. All existing busy root/filter-exclusivity, standing shape, source proof and
   E/Ctrl/input arbitration requirements remain in LADDER_PHYSICAL_EXECUTOR_HANDOFF.

`lifetime_authority()` is a read-only lifecycle receipt, not a substitute for
planner geometry/support validation. Source transform/mask/geometry changes
remain checked by normal admission/step. Central owner must clear/restore pose
according to its current epoch and higher-priority vehicle/physical/death state.
No dedicated skeleton writer or source event bus is installed by this component.

## Cost and remaining limits

Warmed actual-main128 measured arm+disarm cycles: p50/p95 .619/1.065ms,
64 warm cycles excluded, all accepted source nodes included. Single cold arm
.457/.506ms (two scenes), not a percentile/FPS proof. Event-only setup/teardown;
there is no per-frame observer cost. Reuse guard per host and arm once per episode.

No full-scene/GPU/frame-time claim. Source removal callback notification and
filter cleanup are ready; actual main/player input/rig/export/LIVE wiring remains
Root21-owned. Active mid-crest abort may overlap another preserved source envelope;
central physical recovery STILL required, no escape teleport or collider deletion.
Native scene collider fidelity, content, IDs and authority are unchanged.
