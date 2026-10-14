# Pending ordinary resident source provider

`godot/mafiozi_walk/scripts/npc_visual/npc_preview_source_provider.gd` is a read-only presentation packet adapter for the explicitly chosen new session. It does not generate IDs, create characters, insert models, implement AI, mutate HP/progress or grant placement authority.

## API

`load_verified(bytes, trusted_packet_sha256, trusted_sources)` verifies the exact packet bytes and source receipts against caller-provided, independently admitted fingerprints. `trusted_sources` maps source paths to SHA256 strings. Hashes read from the packet itself are not an admission root. Maximum packet size is 8 MiB.

Success returns `{ok, provider, candidate_count, admitted_count:0}`. `provider.candidates()` and `provider.session_receipt()` return deep private copies. The latter omits rows. `provider.first_admitted()` always returns `HOLD_NATIVE_PLACEMENT_REQUIRED`: this adapter intentionally has no admission override. Root's actual navigation/support/placement owner must provide a separate runtime admission path after validating its host scene.

## Accepted phase

Only schema `mafiozi.npc-preview-session/v1`, mode `NEW_SESSION_BOOTSTRAP`, scope `ordinary_native_init_loop`, cutoff `BEFORE_NATIVE_RESOLVER` are supported. `IMPORTED_EXISTING` fails closed; it requires its real authenticated provider and cannot fall back to a new birth. The source loop has 288 calls, starts a fresh serial at zero, and records births/null results and full roster receipt before crop. A cropped packet may validly contain zero candidates.

Source identity must be an original canonical `resident_N` within the recorded full serial and bridge identity exactly `npc_resident_N`. Duplicate identities, wrong descriptor fingerprint/identity and crop escape fail. Original source row and bridge row are retained, including unknown fields. The provider does not reconstruct appearance or infer lifecycle from HP.

Quarter coordinates are source r∈[0,31), c∈[76,107), scale 4.1 m/cell, origin [395.65,0,45.099999999999994]. Pending rows must retain `_npcInitialPlacementPending:true`, placement.pending=true and support_known=false. Neither a fabricated support_y nor native_position is accepted. No unknown height defaults to zero.

RNG algorithm/seed/draw count, source clock and readiness phase must be explicit. Actual map is 200×180 with a fingerprint; the exporter/root independently validates the map/source closure. This provider validates an admitted receipt, not an untrusted self-declaration of source correctness. Full-roster replay, passability and source factory checks belong to the exporter review.

## Current evidence and next gate

Actual Godot 4.7.2 `--check-only` passed. Independent headless policy/negative/ownership suite has 60 checks PASS on helper SHA `017d46e68a629516703cb9899169d1c688b29a4d3aa996d44c49bc1b01ac0efa`; evidence is in `outputs/astra21_npc_preview_provider_review/result.json` and `REVIEW.md`. Synthetic policy fixtures are explicitly TEST_ONLY, not source roster evidence. Corrected actual packet compatibility must still be tested after the source startup closure passes independent review. CPU policy tests are not LIVE, factory replay or full-scene performance acceptance.

Parser-only CPU receipt: `outputs/astra21_npc_preview_provider_cost/result.json`. 20 measured imports after 5 warmups, 11179 bytes already in memory, p50/p95 **0.633/0.749 ms**. The input was the historical source-phase-rejected packet below, deliberately used only to measure schema parsing/copying with zero admitted bodies. This does not upgrade its provenance. Source file reads occurred outside timing. There are no per-frame callbacks in the provider.

The explicitly approved offline session is `godot-preview-new-session-20260927-01`, mulberry32/v1 seed20260927, source_now_ms0, game_minutes720 and frame `POST_BUILDMAP_BEFORE_NATIVE_RESOLVER`. URL `?render=3d&renderer=walk` satisfies the actual native renderer predicate; `?render=3d` alone would select the legacy loop and is not used. Root will reconcile actual runtime session identity with transport before admission.

**Source startup admission remains blocked.** The first generated packet SHA `384f1f2d2b673bde13a49cfdff2f88b4e84469801b1f572624c53259a472901d` is a historical rejected checkpoint. Independent review found omitted synchronous `_cacheBusinessExteriorCollisions()` before the delayed real initNpcs callback. Its 288 rows and three cropped models do not prove startup-equivalent resident creation. Do not admit its hash as a trusted runtime packet. Exact dependency/order correction and independent replay are required. `outputs/astra21_npc_preview_session/47ded349311184bdbca98e3c529ef0c3713f4eb7021233cbaabc32f89ae6c465/STARTUP_REJECTION.md` records the defect without replacing the original evidence.
