# Artist22 — dynamic / mercenary frame components

Status: CPU component review; NOT registered NPC integration or actual capture.
Root22 owns main/player/host/Git/LIVE. No runtime hook is installed by this package.

## Mercenary metadata repair

`tools/godot/export_npc_mercenary_colliders.mjs`
SHA256 `76ba432338ff2673062d88b3695af4a424afaddd7d12bff8cd6dd7f0c80e1d8d`.

The old exporter required capture frame and input receipts but dropped them from
its result. Native capture configuration therefore rejected otherwise complete
exported evidence. The result now preserves `frame` and a private deep copy of
`input_proof_receipts` from input `proof_receipts`, including Float64 transport.
Production-shaped input requires explicit `fixture_only:false` and a safe integer
revision (0..9007199254740991); omitted fixture status cannot imply source capture.
Original constructors, geometry/order, storage catch behavior and gate are unchanged.

`godot/mafiozi_walk/scripts/npc_visual/npc_source_mercenary_colliders.gd`
SHA256 `a2fdbccfe6bc2a7598497d7dd203bc2ed72090330d43f1aa9b988b0c67f33773`.
Only EXPORTER_SHA changed. Configure still validates packet/scalar bytes, static
source pins, fresh context/session, frame/receipts and the current external lease.
`collections()` always returns physical_admission:false / registered_frame_known:false.
Source-shaped schema canaries are QA, never authenticated captured sessions.

Author evidence: `outputs/artist22_mercenary_author/test.mjs` and RESULT.json:
132 PASS, 22 actual original constructor cases + 20 HOLD regressions and new
metadata ownership/type checks. Original failed/historical logs remain untouched.
Actual Godot4.7.2 native.gd / NATIVE_LOG.txt: 180 PASS. Compact fixture setup
p50/p95 687/851 us; collections 28.2/29.79 us, 2 warmups/50 samples.
These observations do not establish improvement or loaded-scene performance.
Independent review evidence is in `outputs/artist22_mercenary_review`:
45 metadata checks and 192 native checks PASS, exit0/clean final logs. Includes
direct native decoding of the actual new exporter canary bytes (8 bodies), frame
and receipt preservation, all lease identity/type fields, owner queue/free,
reentrancy, body mutation, and worker calls without main-thread poisoning.
Earlier failed test-harness logs remain; they were scalar-hash and numeric
container comparison defects in the harness, not production fixes.

## Dynamic ce4 verification

`godot/mafiozi_walk/scripts/npc_visual/npc_source_dynamic_blocks.gd`
SHA256 `ce4db3d94bb8fcf679634ecb8636dbec4335fba463c2642f8710c53a4b6f59ef`.
Unchanged by Artist22. Exporter remains `a277c9ddb6c10af54551047a55a39c284c2f1b0a070e346dbad6987c2a990d0d`.
New independent actual Godot4.7.2 checks: 677 PASS; inherited regression 3903 PASS
including 1263 source fixture queries. Evidence: outputs/artist22_dynamic_review.
All lease fields are checked at configuration and before/after queries; queued
or freed owners, reentrancy, worker operations and caller-owned mutation tested.
No new component defect found in these scenarios. TEST_ONLY fixtures, not current
source fleet/train/logical frame. Previous parent10/lifecycle12 remain historical.

## Root integration prerequisites

1. Obtain a genuinely fresh original source capture; preserve source HTTP/script
   identity and distinguish the old static a05ad context from the new capture.
2. Validate input receipt bytes and their binding to actual captured inputs.
   A caller-supplied receipt path/hash is not independent authentication.
3. Feed each helper the exact verified exporter/packet/scalar hashes and a main
   thread lease for that same source session/frame/revision. Any missing state
   stays unknown, never an empty or clear scene.
4. Combine source ground/static/mercenary/dynamic components only after all belong
   to the same validated capture. Actor placement, body admission, behavior,
   server authority and host lifecycle remain separate root integration gates.

GPU remains HOLD. Actual source frame, uninterrupted births, runtime NPC presence,
LIVE behavior and overall scene performance are NOT verified. The debugger-based
capture tool can provide diagnostic evidence only; debugger pauses alter the
source placement wall clock. Capture-plan review is a separate package.
