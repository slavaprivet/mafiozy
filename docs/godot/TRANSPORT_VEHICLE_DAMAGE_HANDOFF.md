# Vehicle crash and blast migration — current transport components

Direct user instruction: preserve crash damage; exploded cars release physically flying/falling parts; optimize without removing content. Transport owns presentation/debris/local-state adapters. Physics owner owns contacts and mutable mechanical solver. Coordinator21 owns main, damage/event authority, Git and the sole LIVE scene.

Source vehicle_damage.mjs SHA e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92. Ordinary source collisions retain HP>=1 and cannot independently ignite/explode. Preserve this rule; blast/RPG destruction must come from the actual damage/event contract.

Completed separate components:

- transport_vehicle_damage_state.gd: actual JS360-row create/apply/step fixture, 18081 headless checks PASS. Invalid dt retains valid state. No server authority. Idle10000 calls4454us isolated.
- transport_vehicle_damage_bindings.gd: exact13 actual imported GLBs/source assembly receipt,497 author+497 independent headless checks PASS. Forged profile/IDs/RNG/order/receipt rejected. Canonical per-row receipt rejects coherent removal, reordering and eligibility/RNG tampering; preparation-only file read. Six actual two-door models have8 blast assemblies; remaining seven have10. Missing rear doors remain absent.
- transport_vehicle_debris_launch.gd: exact7 supplied shared RNG draws,15 author+15 independent checks PASS. Native axis conversion once. Physics owns the eventual landing rather than the original analytic trajectory.
- transport_vehicle_debris.gd frozen1cf791ea:264 author+264 parent PASS; two cars/20 parts, actual ground collision and natural sleep. Persistent parts, no TTL. Parent launch523us; preparation113665us occurs outside events; bounded prewarm p9556us/max113us. See TRANSPORT_VEHICLE_DEBRIS_HANDOFF.md and manifest for receipts.
- transport_mesh_subdivision.gd frozenf923e741:15586 author+15586 parent PASS against actual source DFS/budget/depth oracle. Preserves geometry/material attributes and rejects unsupported layouts explicitly. Preparation only; synthetic fixture5.585ms is not actual fleet cost.

Current implementation: transport_vehicle_deformation.gd consumer of physics-owner deformation_snapshot_native, identity/life/profile/revision-bound45 nodes. Source mesh deformation/parity/performance verification is in progress; this component is not frozen or runtime accepted yet.

Root integration seam: a single owner for each detachable assembly across structural damage, compartments/cargo and blast. Geometry deformation invalidates cached debris; rebuilding must be prepared outside the impact frame. One event must not clone the same part twice. Actual authoritative contacts/damage/explosion receipts remain required. Prepared physical values (mass/layers/damping/friction/bounce) are explicit caller inputs, not invented source defaults.

Rejected historical performance: first implementation39–47ms launch and415ms initial activation. Current prepared/prewarmed implementation replaced it; do not adopt old versions.

Performance of the loaded shared scene has NOT been checked. Coordinator21 must test actual crash/blast behavior and comparable loaded-scene p50/p95 after integration. Separate CPU checks do not justify a lag-free LIVE claim.
