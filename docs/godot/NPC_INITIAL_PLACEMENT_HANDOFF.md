# NPC initial placement — implementation handoff

Frozen candidate implementation: godot/mafiozi_walk/scripts/npc_visual/npc_initial_placement.gd SHA7450d532ccf12e85eb04411c1d676faad43427fac472b44befa8ef10a667106a. Integration owner Root21; only this new helper and scoped tests/docs were edited. Independent acceptance status is recorded in the final delivery receipt. No candidate establishes physical admission.

## Public integration seam

configure(context_bytes:PackedByteArray, trust:Dictionary, source_body_pass:Callable, clock_ms:Callable) parses pinned full a05ad startup bytes once, builds private source-order326 rows and306 eligible queued rows. Complete startup normalization/births/RNG must not run again. The exact approved stage and source functions are in NPC_INITIAL_PLACEMENT_CONTRACT.md and outputs/astra21_npc_placement_stage/STAGE_RECEIPT.json. _ensureSpawnSafe is player-only, already executed before this stage.

Trust binds context_sha256, source_world_sha256, session_id, phase; provider{id,version,semantics:'ROLE_BODY_PASS',sha256}; and current interior_state{source_world_sha256,_buildingInt,_bankInt,_majorInteriorObjectId}. Source NEW_SESSION defaults are null, but caller must attest unchanged actual registration values; the full context does not serialize these globals. Interior-active setup reproduces source early return. Provider provenance is a trusted in-process label, never a geometry or authority proof.

source_body_pass(object_key:String,kind:String,raw:Dictionary,r:float,c:float)->bool must implement the COMPLETE source role-specific BODY query, including resident .18-cell/police .24-cell five-point policy, source access/MAP/route/water/prison checks and current resolver lease. Callback raw is an independent private copy. A center-only collision query or relaxed road rule changes behavior. Source native scale is4.1; r/c stay Float64 throughout search. Host conversion x=c*4.1-395.65,z=r*4.1-45.1 and native support are separate Root gates.

Call first step(128,4), then step(96,2) with a finite monotonic millisecond clock. Scripted frozen0 is for parity fixtures; use an actual monotonic clock during interactive slicing. Output {ok,status,done,events,stats} carries candidate events original/relocated with object_key/raw_id/kind/r/c/source/context/session/provider provenance and physical_admission:false. Use raw source_id from the immutable e926 packet to match raw_id; keep its separate bridge_id intact. Current packet source IDs are resident_72/169/252, not new object-key identities. Private route-clear command names are diagnostic equivalents; they do not authorize deleting external live routes.

The original eligible position passes without spacing. Relocated candidates check all326 private source objects, including skipped/named/alive=false rows; only dead-truthy rows cease blocking. Working coordinates update immediately in source queue order. Max16 radial checks per row and exact increasing radii/spokes preserve round-robin ordering. Exhaustion removes a row from queue while retaining pending and unresolved: queue-empty alone does not mean complete. Final support/collision/HP/life/provider-currentness/scene insertion remain Root-owned.

Failed provider/clock lifetime, invalid callback return, reentrancy or nonmonotonic/nonfinite time permanently FAULT the instance and suppress every event from that step. Private diagnostic progress remains truthful but cannot resume. Before/after stored callable is_valid guards prevent callbacks freed after configure from producing repeated engine errors. Recreate only through a new admitted source snapshot/lease; do not treat suppressed private events as delivered.

## Verification and measured costs

Original JS oracle688 checks PASS, source block unchanged8bf6b81a/source world9f5cc5/full contexta05ad. Explicit TEST_ONLY complete-BODY seam fixtures: blocked224 ordered queries after128+96; original306 passing queries bypass spacing; search765 queries over8 slices moves306 eligible rows while all326 spacing objects remain. Exact source route-clear functions execute. Full traces/rows/raw objects/queues/cursors/stats/provenance in outputs/astra21_npc_placement_oracle/ORACLE.json SHA3374336a2189833f817c65da2d0b95731f6ebf910bade943bf31b33c7d00515a. These fixtures prove algorithm parity, not actual source/native geometry admission.

Actual Godot4.7.2 parent author360218 checks PASS, exit0, clean output at frozen7450, scripts/tests/test_npc_initial_placement.gd. All full raw states/ordered queries/queues/radii and flags compare against originalJS after every slice; bytes and callback/snapshot private copies remain intact; trust/source/strictbool rejection checks pass. RESULT.json in outputs/astra21_npc_placement_tests pins the exact helper.

Independent review discovered historical b01 lifetime failure: freed Node provider produced128 invalid calls yet returned PENDING,431 checks exit1. Historical helper/failure logs remain in own author/reviewer outputs. Final7450 adds before/after callable checks. Historical source-parity authorPASS is not full acceptance of b01.

Parent standalone actual CPU profile, same25 runs with5warmup/20timed, TEST_ONLY constant false BODY seam: configure p50/p95/max22.762/25.330/26.355ms before,18.865/20.560/21.893ms after removing redundant326 deep copies of already-private newly parsed JSON raw objects. Exact algorithm/state parity stayed360218PASS. Parsing and validation costs remain; configure during loading or off the interactive frame. This change does not remove input data or gameplay content.

Current scripted-clock128 slice p50/p95/max1.468/1.829/1.932ms; actual-clock128 slice1.519/1.718/1.744ms, all20 samples completed128 checks. Instrumented author callback trace has1.606/1.882/1.900ms. Real role-specific five-point/source/physics provider cost is excluded from these fixtures. Snapshot diagnostics deep-copy full raw rows:5.284/6.821/8.438ms; never call snapshot each frame. Use the small returned events/stats and discard events after processing. Performance of the loaded scene is not checked here.

## Limits and reproduction

Godot console --headless --path C:/Users/Слава/Desktop/Мафиози/godot/mafiozi_walk --script res://scripts/tests/test_npc_initial_placement.gd
CPU profile samepath --script C:/Users/Слава/Desktop/Мафиози/outputs/astra21_npc_placement_tests/profile.gd.
Original JS: node outputs/astra21_npc_placement_oracle/oracle.mjs.

Pinned offline NEW_SESSION/before-server context only. Scheduling/input positions are frozen in parity fixtures; interleaved live movement requires a separately admitted current context. No main/preview_population/preparedcache/e926 assets/source exporter/HP/authority/physics/Git/GPU edits. No actual provider or runtime NPC insertion, autonomous agenda, commerce/phone/stockroom behavior or full-scene FPS acceptance is implied. Root supplies the provider and final collision gate, then sole-game ON/OFF measurement.

## Final independent acceptance

Final7450 independently accepted: actual Godot433 checks PASS, exit0, clean output, ~.93s; separate source/stage419 checks PASS (eligibility/full byte receipts, not another placement oracle). NATIVE_REVIEW.md and SOURCE_STAGE_REVIEW.md in outputs/astra21_npc_placement_review record exact provenance and limitations. Freestanding body/clock lifetime, recursive configure/step, strict callback results, source/interior/provider trust, private copies and scripted expired/backward/nonfinite clocks pass. The invalid experiment freeing the currently executing locked callback was retained as HARNESS_INVALID_self_free and excluded from final433. Full maximum-radius exhaustion was not independently executed; the source semantics were inspected and bounded earlier slices compared, not claimed as exhaustive-radius acceptance.

READY for Root21 integration with the real complete source-body provider. This supersedes historical b01 HOLD only for corrected7450; physical admission remains false. Frozen delivery receipt inventories exact code/tests/oracle/full context/review/CPU evidence bytes and SHA.
