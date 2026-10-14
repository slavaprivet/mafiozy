# NPC vehicle → death20 — production READY

2026-09-20, approved by Coordinator20. Actor released. New helper `npc_death_entry20.mjs` plus scoped actor hooks inherit only an actually displayed vehicle pose. Prone/crawl is explicitly excluded. No source damage, AI clock, vehicle trip, root, ID or weapon ownership changes.

The last eligible pose is captured in a reused buffer. Confirmed fresh death starts from that pose and blends over raw death age0–0.28s to the existing fatal-cause renderer. A >0.25s observation gap cannot resurrect a stale seat. Local bone matrices, visual pivot and scaled offset are preserved; state becomes dead immediately. The entry is optionally serialized for cull/recreate; legacy saves without it keep previous behavior.

Validation rejects nonfinite/nonunit transforms, changed or nonpositive bone scale, changed authored rest translation (tolerance1e-5), missing/extra bones, excessive visual offsets/clearance and entry metadata on alive saves before mutating state. Pivot/clearance bounds are4×actor height; scaled offset bounds are source height. Captured invalid remote seat offsets decline the optional transition rather than create an unrestorable save. These constraints apply to the vehicle authoring contract and are not a generic prone-pose contract.

Grounding runs once per blended frame through a cached deferred-ground context. Initial positive clearance fades smoothly; no new meshes. After blend the renderer receives the original context, including the root's settled-death ground memo. One extra ground scan is needed at the accepted event to capture initial clearance.

## Verification

- Original `test_npc_vehicle_death_continuity20.mjs --require-fixed`:6/6 actual GLB cases, worst first step6.426e-8m, recreate difference<7e-16m.
- `test_npc_death_entry_prototype20.mjs` retains its historical name but is now production regression with exact entry patch rolled back only in memory. Current baseline first step0.47–0.60m; fixed<6.5e-8m. Next30 samples at60Hz max step0.07536m male /0.07960m female, equal to the canonical fall maximum. Actual skinned floor>=-6e-15m.
- Both rigs: six causes; nonfatal stun/knockdown and normal standing death unchanged; external sync/save before update; cull5s; stale observations1/5s; receipt death over custody/phone; respawn/new epoch; ten malformed entry saves atomic; legacy optional-field absence: PASS.
- Clock persistence, surface serialization, current lifecycle, death integration26 cases, recovery regression and original recovery audit8/8: PASS.
- Actual ground memo integration6 cases:89hits/1miss each, exact bones vs uncached baseline: PASS. Its test required no anchor change. Recovery test rollback anchors updated to preserve ground memo and entry callback; no assertions weakened.

Root separately requested actor `markDeathVisualReplaced(key)` / `isDeathVisualReplaced(key)` forwarding methods, guarded by exact sourceDeathKey. Added these two methods only; the persistent flag implementation and blast integration belong to root.

## Cost / limits

Fixed eligible death pose age0.13,15 warmups+30 samples: male p50/p951.479/1.568ms →1.532/1.931ms; female1.244/1.290ms →1.264/2.460ms. Small samples in an active shared workspace have noisy tails; p50 increment0.02–0.05ms. Reused per-frame bone-entry/pose buffers; temporary arrays only on save/restore and event validation. No GPU/browser run, no complete-scene FPS acceptance. LIVE vehicle/body collision review pending Artist19.

The previous broad proposal is historical: `NPC_DEATH_ENTRY20_PROTOTYPE.md`. Separate unresolved prone audit is `test_npc_prone_death_entry_audit20.mjs`; default intentionally reports failure until a belly-down final pose is implemented. It is not part of this vehicle acceptance and must never be described as ready.
