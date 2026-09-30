# Building destruction → RPG23h: read-only integration route

Decision: **ready for a guarded isolated root stage, not production activation or mass rollout**. Industry owns the implementation. Root owns the committed RPG event seam, main installation, export and actual loaded acceptance. This review ran no engine, GPU or Git operation and changed no owner/production files.

## Evidence and mutable input warning

The latest captured owner verification is `2026-09-30T09:43:19.877Z`, SHA256 `a09eccaf8daac4b672bfa4dec0179539a0b6b6d4bf6a4d0836f78f142e6d9841`. Its exact bytes are preserved here as `OWNER_VERIFICATION_SNAPSHOT.json`. All11 suites report PASS. These are existing owner results, not newly executed receiver tests:

| Suite | Checks | Actual scope |
| --- | ---: | --- |
| Wall/material core | 23 | Local geometry/rules |
| Grouped collision | 138 | Real native synthetic geometry; no loaded FPS |
| Closed fragments | 299 | Cut composition/closed geometry; not rendered rubble behavior |
| Source glass blast | 309 | Executed JS oracle, lifecycle/replay/collector contracts |
| Committed damage bridge | 19 | Signal-only weapon test double |
| Glass collision | 24 | Real mixed-surface native contact/fracture/collider |
| Host lifecycle | 26 | Real synthetic geometry, signal-only weapon host |
| Glass core / JS oracle | 38 /17 | GPU/MultiMesh readback explicitly SKIP |
| Four GLB/eight placements | 586 | External fixture,7ordinary registrations/387parts/92groups; no main/player/NPC |
| Printshop interior adapter | 5252 | Actual native loader, real duplicate collider rays; explicit TEST_ONLY material profiles; renderer instance readback SKIP |

During review the owner continued editing. An initial check matched every input; the final53-input comparison found **3changed files after that evidence**: `building_destruction_runtime.gd`, `material_strength.gd`, `test_wall_core.gd`. Exact tested and observed SHA pairs are in `DESTRUCTION_ROUTE_PINS.json`. Current runtime observed `aff0f263ce4e16e71a61de0ee187399dabd823032cc7526a79468c62785b51a6`; tested runtime was `b0faf067a64c0f1838ef7334289178d0a88d267b93be236efe7cb61e7e22f1f6`. The new visible edit aligns mixed-material glass classification with Walk. **Do not treat the captured11PASS as testing those new bytes.** Obtain an owner-frozen closure and matching rerun before copying. Do not read/copy a changing folder piecemeal.

The HQ12:00 report is older than these results. Its single patch-fragment, missing glass AoE and absent interior-adapter statements are superseded at component level. Its production/HOLD boundary remains valid. `ROLLOUT_STATUS.json` also contains older limitations, so source and exact verification must be read together.

## User-approved showcase is preserved, separate from rollout

HQ05:38/05:40 and `docs/ai/BUILDING_DESTRUCTION_MEMORY.md` record approval of local, traversable breaches and light pushable rubble, then explicit instruction to connect all buildings/interiors incrementally with real measurements. Glass must retain its separate Walk mechanic.

The approved standalone v3 checkpoint has16/16manifest entries still matching. Manifest SHA `19972dbfd967ca5a12be4e40f429d6e652889e21d7b47d3e6ec9e7459353e241`; validation SHA `7854b37d76b96e9e0847af0c84aa7310d709790a415bb84ea918d0ed441df45e`. Its629fragments/support wake/reset/capsule passage are **showcase** evidence, not real production-player acceptance. The133.879ms full-collapse outlier remains unexplained; v2 screenshots/performance do not become fresh v3 or city evidence. Root already saved this package; it need not be duplicated or replaced.

## Exact gameplay seam and responsibilities

1. `preview_weapons.gd` commits inventory and native launch synchronously, then emits `shot_emitted(shot,muzzle,camera_origin,camera_direction)`. The bridge records shotId, itemUID, sequence, source damage, muzzle origin, pellet count, bullet producer epoch and the current actor/life/scene binding. Keep the existing transaction unchanged.
2. `rpg_flight.gd` supplies the full terminal receipt: `native_rpg_impact`, actor/life/scene, shot/item/sequence/token, origin, point/normal/direction, travelled distance, damage and exact native `hit`. It remains an observation until a consequence owner admits it.
3. Root's only necessary weapon edit is `integration/rpg_native_terminal.proposed.patch`: add `signal native_impact(receipt:Dictionary)` and emit a deep-copied complete receipt at the end of `_impact`, guarded by `_live()`. Preserve existing explosion/scorch rendering, including range-end explosion. **Never subscribe building damage to cosmetic_impact.** This signal can serve a separate later actor-blast owner; destruction code does not implement NPC/vehicle HP.
4. `local_building_damage_bridge.gd.configure(weapons,blast_port,glass_port,options)` consumes only a matched current committed shot, validates its straight native terminal ray and61.5m bound, consumes before callbacks and labels consequences `authority=local_preview`, `server_authority=false`. This is local preview admission, not server authority.
5. `building_destruction_host.gd.configure(world,runtime,approved_source_ids,glass_port,glass_registry)` restores static-batch leases before collecting source owners, registers reviewed ordinary buildings, and binds the bridge to `runtime.apply_explosion`. **Keep the approved-ID list empty by default.** Printshop remains explicitly HOLD in this host despite the new independent interior adapter.
6. A direct building terminal yields `{event_id,source_id,position,normal,direction,collider,power=committed_damage,radius=0.8,weapon_id=rpg,...}`. Only the hit collider's owned `source_id` is selected; range-end must not invent a nearest wall. Material/cut code decides localized damage and updates matching geometry/collision.

Current production pins reviewed: RPG effects `bbd4ec325524afe4fea2a11ebd1343635b84bde758c25e4848ea66d6ef266a9e`, flight `03e119d3feedcdee11415922ab391e02d4375654df76896835bb43a93497bc6f`, weapons `cdf590013e5808a32b529fd75f3cd42c03f9dc6c3526560dc01e36f6f7c51c38`. The compose tool's expected RPG hash matches; main's old documented hash does not match current `f14976f4c2611481e1edcfbb1a8f4026a016e6eb784f4f9a7d4e661ecd74620f`. Merge the narrow main seam manually against the frozen root base, not by assuming historical line numbers.

## Separate glass and interior boundaries

Glass direct bullets use exact native contact → `glass_collision_bridge.admit` → actual surface/local triangle/instance → Walk pane core;85ms fracture updates the corresponding grouped collider. Opaque triangles are preserved.

RPG glass AoE uses the **original Walk presentation profile11m/168**, independently from wall breach0.8m, weapon damage160 and flight metadata2.7cells. `walk_preview.mjs` power1.4/radius11 followed by `blast_response.mjs` power×120 is the source. The original `world_blast.mjs` glass branch has **no LOS ray**; actor/vehicle cover is a separate contract. Do not silently add wall shielding here or claim it exists. The source oracle explicitly checks glass behind an opaque wall.

Collector defaults are96meshes/96panels/24optional surface hits, capped256/256/64; caches256. These cap retained candidates, not total hierarchy traversal or triangle work. The path may inspect up to96×180000indices. Actual loaded first-use and repeat costs remain required. The host currently limits roots to registered ordinary buildings; it does not authorize vehicle glass or unregistered printshop.

`interior/interior_part_adapter.gd` exposes configure, prepare/commit/cancel/rollback damage, reset/dispose and snapshots. It stages visual plus **both** source-static and aggregate floor/ceiling representations atomically.8partitions/headers are mapped; all11real material profiles remain UNKNOWN. Tests deliberately override wood/plaster as TEST_ONLY. Ceiling/roof/furniture/safe/items remain outside that proof. Do not remove the host's printshop hold or install guessed material profiles merely because5252passes exist. The adapter does not spawn rubble; its caller must reserve fragments before commit and rollback if finalization fails.

## Remaining integration-grade gaps

- **Actual pipeline absent from evidence:** `test_actual_eight_bindings.gd` exists but is not among11captured suites. It is a read-only binding collector even when run; it does not prove install→actualRPG input→native flight→admitted cut→standing-player traversal. No loaded render or whole-scene performance acceptance is present.
- **Backpressure is not observable completion:** runtime can return `queue_full_retry`; bridge currently consumes the committed shot first and ignores the result of `_blast_port.call`. `_cut_part` can hit debris limits, then `_physics_process` unconditionally increments `job.index`. Consequently a genuine shot can be silently discarded rather than retried/completed. `admitted_blast_events` is a forwarded-call counter, not a successful-breach receipt. Root must not present it as destruction success. Owner needs bounded acknowledged completion/retry semantics, with no replayed duplicate damage.
- **Callback lifecycle gap (static finding, not a reproduced failure):** `_on_native_blast` calls external `_glass_blast_port`, then continues toward `_blast_port` without rechecking `_current()`/callback validity. Glass callback disposal/rebinding can retire the host in that interval. The collector itself tests disposal inside its own tracking callback; the19bridge suite does not test disposal during the outer glass→opaque callback sequence. Require this negative and post-callback revalidation before enabling the combined owner.
- **Frozen receipt consistency negative missing:** RPG bridge validates top-level ray tuple, but does not compare nested `hit.point` to `receipt.point` or prove collider/contact coherence independently. This may be acceptable with the sole guarded native emitter, but the19signal-double tests do not establish the actual producer contract. Bind exact native flight and add mismatched nested contact/replay negatives rather than trusting arbitrary Dictionary emission.
- **Material/thickness admission still provisional:** ordinary runtime permits name aliases and default0.2m thickness; this is not a reviewed per-part physical metadata closure. Preserve UNKNOWN holds; select a representative source surface and explicitly review its profile/thickness before ordinary-building admission.
- **Performance work remains:**387source meshes become92collision groups replacing16filled hulls. This preserves detail, but increases collision cooking/query work. Native asset max cut job in captured report is7992µs; it is diagnostic CPU evidence, not loaded FPS. New `rubble/pooled_fragment.gd` and `parked_batch.gd` are work in progress; they are not proof of completed pool integration. Do not copy unreferenced work blindly.

## Next safe root stage

1. Freeze accepted23g as baseline and obtain Industry's stable complete source closure plus matching verification. Rehash the exact files listed in `DESTRUCTION_ROUTE_PINS.json`; new dependencies require explicit addition, not a relaxed hash guard. Keep existing user game unchanged while staging.
2. In a new isolated root candidate, apply the narrow full-receipt RPG signal only once. Copy the reviewed destruction module/dependency set under `res://scripts/destruction/`. Use the composer's guarded resource list after checking it against the frozen runtime preloads; explicitly include required scripts in the selected-resource export. Keep main admission empty initially.
3. Run actual8binding inventory against that complete candidate. Review one ordinary building/sourceID first, including visible source mesh coverage, original16-hull ownership, glass contact mapping, static-batch restore cost and approved material/thickness. Keep all8buildings/3NPC/transport; never shrink content to manufacture a performance gain.
4. Close the callback/backpressure gaps through Industry's owner package. Bind actual committed RPG/fire/ammo and native flight, not fixture signal emissions. Check onehit/replay/lifetime/dispose/reset, point tuple, sourceglass/range-end, neighbour/behind-wall opaque protection and delayed glass collider refresh. Preserve source itemIDs and protected interior owners.
5. Root's serialized compiled-PCK acceptance then measures identical loaded scene/camera/settings: intact, first blast, repeated local breach, settled rubble, real-player entry/return/push/wake, reset. Record frame wall/GPU/physics p50/p95/p99/max, first-use spikes, memory, draws/triangles, collisions and pending/completed job counts. A p95-only report cannot hide another first-hit stall. Geometry/collider counts may legitimately change through destruction; their source coverage and resulting traversability must remain evidenced.
6. Only after those pass enable that reviewed ID increment and export/deliver. Broader ordinary buildings, printshop adapter, additional23models and missing67source placements remain staged follow-ups under Industry's existing goal, not implied by this one connection.

All exact hashes and captured owner outputs accompany this document. No newly tested behavior is claimed by this read-only review.
