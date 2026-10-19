# NPC source BODY query — integration handoff

Final hashes and acceptance are in outputs/astra21_npc_source_body_delivery/DELIVERY_RECEIPT.json. This package implements original resident/police logical access checks for the approved frozen full new-session context; it does not admit NPC actors into the scene. Root21 owns main, current providers, physical host and LIVE. Production changes are limited to the new npc_visual helper and its test.

## Integration

Preload res://scripts/npc_visual/npc_source_body_query.gd. Load the original a05ad context and c5f576 static geometry bytes. Configure once using the five-argument API in NPC_SOURCE_BODY_QUERY_CONTRACT.md. Supply source-derived current snapshot and proven native_nav/water/ped_blocked/city_surface primitives only when present/visited. The helper binds source/session/snapshot revision/provider identity and preserves explicit UNKNOWN for missing proof.

Pass Callable(body_query,"body_pass") into npc_initial_placement.gd, whose five arguments already match. A known source decision returns bool; missing proof returns null, which deliberately prevents relocation under fabricated passability. The solver's logical events must feed a separate root candidate-position seam, never overwrite immutable source_raw.r/c. Root still validates current support, overlap, life/generation, interior access and actual actor placement. Full crop-only native geometry is not a whole-world provider; do not substitute TEST_ONLY clear callbacks to enable runtime.

query() retains full private source/primitive diagnostics. The optimized body_pass() uses the same private policy/lease core with diagnostics disabled and replaces last_report with a compact report marked diagnostics_recorded=false and empty traces. snapshot() remains a private copy. This avoids trace construction/copies on every placement probe; it does not cache access decisions or suppress proofs. Diagnostic query has diagnostics_recorded=true and unchanged ordered source observations.

## Source fidelity

Resident BODY: all five .18-cell route prechecks, then the five npcWaypointOk checks, preserving early returns and direct unique policy. Police BODY: five .24-cell checks with route before prison override and literal snitch/native/pedestrian fallback. Static full prison/arena/lair/pit geometry and MAP come from unchanged source receipts. Dynamic release/alarm proof is required only when its actual branch executes; no jail timers or authority functions execute here.

Native source water depth is metres for npc_native_navigation.mjs (water.level-groundHeight), so .025 is25mm; r/c/offsets remain cells at4.1m/cell. MAP16 fallback1 is a nominal sentinel. JS strict booleans, finite depth selection, truthiness and unique-depth numeric coercion are retained. Optional native/water resolver absence differs from missing proof. Direct pedestrian/city functions cannot be absent; their proven return contracts are bool and null/Dictionary respectively.

Historical failures and intermediate receipts are retained: bb81 borrowed response containers corrupted earlier diagnostic trace entries; 4989 oversized hex coercion emitted an engine error; a460 fixes both plus direct-function absence handling. No failed checkpoint is claimed as final. Test harness StringName key mistakes were isolated and corrected without weakening exact String-key validation.

## Verification and performance

Original JS source oracle:952 checks PASS, all326 rows and7902 ordered observations;314 known (308 residents pass,6 prison police reject),12 police UNKNOWN for uncaptured pedestrian caches. Source receipt/static reviews:76+102+54 checks PASS. This proves the captured source semantics and complete static receipts, not a complete live geometry provider.

Actual Godot final author and independent checks, source/helper/test hashes, final CPU metrics and logs are listed in the delivery receipt and attached final author/reviewer handoffs. Same-source before/after CPU measurements use 50 warmups and2000 calls on an actual pinned source row; they exclude native physics, render and full-world provider cost. Configure parses the full context once; it is not a per-frame operation. Body queries must remain bounded by an actual monotonic work budget. No whole-scene FPS or LIVE acceptance is claimed.

## Open dependencies

Root's candidate-position consumer and proven current primitive providers are required before native NPC admission. Life/HP/death/respawn, phone calls/reactions, budgets/commerce, physical sellers and stockroom doors, police/EMS scheduling and server authority remain separate runtime work. The helper supports the pinned approved new-session table/MAP, not arbitrary server sessions. No models, raw IDs, actor births/progress or source content were changed; no main/player/host/project/export/Git/GPU operations were performed.

Export dependency: context.json and STATIC_GEOMETRY.json currently live in outputs and are passed as exact bytes. They are not automatically PCK resources. Root's exporter must bundle byte-identical inputs at agreed res:// paths and verify their hashes in the exported build before configuration; this package does not edit export/project files or claim packaged runtime loading.

Final acceptance: helper eb1282e4258f6e879bf994ba8105f47b34531435ecf85a73a77d4d13b9a6f91e; test00934abdba17bf92941fcf1ecc1c4d8d578414091cbc8b2dcf3107ad1c36b447. Actual Godot4.7.2 author23332 PASS and independent187 PASS, exit0/clean diagnostics; all326 rows/7902 ordered source observations retained. Independent provider-reuse and huge-hex canaries also pass. No physical/LIVE claim.

Matched CPU control: a460 body_pass p50/p95/max246/304/654us -> final101/134/331us (2000 calls,50 warmups). Source fixture is object_0/resident_1, native_nav_present=false,water_present=false,water_bypass=0,prison_enabled=true, primitive callbacks empty: ZERO real native/proof geometry calls. Diagnostic query final195/279/457us; trace-copy36/54/142us. Configure final16.711/22.864/22.864ms versus a46015.693/17.104/17.104ms; no configure speedup is asserted. These process timings have ordinary host variance, do not include a loaded scene and do not establish frame-time/FPS improvement. Configure once, slice interactive BODY work under a real clock budget; never run the complete326 diagnostic scan per frame.
