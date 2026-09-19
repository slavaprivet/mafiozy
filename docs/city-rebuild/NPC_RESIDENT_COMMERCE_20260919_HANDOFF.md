# Resident visits and shopping — 19 September 2026

Source integration is present in `world.html`. This is a **session-owned resident economy**, not authenticated server commerce or player income. No backend restart or deployment was performed.

## Behavior

- Native entry records preserve explicit `assetId` and `buildingRole`, without inventing gameplay IDs/ownership.
- Resident destination choice prefers home, errands/shop, service, or leisure according to the existing routine; a retained trip destination remains authoritative. Unknown buildings are ordinary visits, never invented shops.
- Explicit catalogs: printing shop → newspaper ($3), pawnshop → used watch ($24), gun shop → cleaning kit ($12). Clubs and bookmaker remain visits; this does not create bets or fictional purchases there.
- A stable wallet belongs to the existing NPC object/ID. It starts at $35–119, never refills automatically. Inventory and at most eight receipts remain for that object's lifetime. It is **not saved across reload**.
- Payment occurs once after physical interior arrival, browsing and payment gesture (3.1 s). Merely approaching an entrance, a closed/blocked entry, interruption by panic/death/fighting, or leaving the interior does not debit. The same item has a five-minute need cooldown.
- `npc_activity_pose.mjs` shows inspect/reach/pay on both hero-based rigs, preserving bone lengths and source root. No new props or draw calls. Busy, armed, fleeing, and phone-call priorities remain ahead of this pose.
- The old native `_updateBizClients` proximity-thank-you behavior is disabled because it replaced collision-safe plans with direct targets; legacy renderer path remains unchanged.
- Existing physical exit → bench → reading/social cycle remains in charge. No new independent update loop.

## Verification

PASS `test_npc_resident_commerce.mjs`: wallet/receipt idempotency, genuine shop classification, needs, retained destination, interruption, capped history, plus extracted **actual** `_residentNativeVisitTick` blocked-entry → walk-inside → checkout integration.

PASS `test_npc_resident_building_access.mjs`, `test_npc_shop_pose.mjs` (male/female actual GLBs, root/rest lengths, continuous browse/pay, expiry), `test_civilian_purposeful_plan.mjs`, `test_resident_pending_origin.mjs`, and `test_civilian_native_lifecycle.mjs`.

CPU comparison, 384 simultaneously browsing residents, 600 batches: baseline p50/p95 0.0012/0.0149 ms; checkout tick 0.1866/0.2093 ms. This stress case has no resident scans, route requests, or rendering. Actual GLB actor update sample including existing presentation p50/p95 0.148/0.567 ms, not isolated incremental pose cost. Actual lifecycle fixture 752 frames, 39.10 m driving/34.58 m walking, p50/p95 0.0727/0.1933 ms; cold fixture navigation max122.8 ms is not a loaded-game FPS measurement.

**Performance and appearance in the shared live scene are not verified.** No GPU tab opened. Next shared reload should inspect `document.documentElement.dataset.npcResidentVisits.commerce` (inside JSON): purchases, spent, insufficientFunds, interrupted, authority. `npc_actor` receives `life.activity={kind:'shop',phase:'browse'|'pay',since,payAt,until}` from source.

## Economics boundary

`mafiozi_bot.py` already accrues business income through `_tick_owned_business_income` and `business_elapsed_income`. No NPC purchase command/receipt contract was found. This change does not modify those functions or credit the player. Server-backed shopping would need canonical resident wallet/inventory persistence, authenticated NPC arrival authority and idempotent transaction IDs; client assertions alone must not generate business revenue.

## Follow-up: real parked-car exit blocker

Traffic agent's authored-parking test reproduced a separate failure: after 286.6 m driving the NPC exited, then repeatedly planned the same impassable first edge beside its parked car. Both its actual position and grid cell destination were clear, but the diagonal connection crossed the car corner. Native `_planNpcRouteTo` checked only cell centres.

With root approval, native `building_entry` now validates connecting edges from the **actual starting position**, then between grid centres, using the supplied visit callback (which already includes body radius). No doubled inflation, collision bypass, car relocation or NPC teleport. The existing two jobs / four ms continuation budget is retained. This is sampled edge validation, not a claim of continuous collision detection for arbitrary thin geometry.

PASS `test_npc_native_route_edges.mjs`: old blocked route reproduced, new clear detour, planning preserves NPC coordinates, deferred search resumes without restart. Equal small CPU route sample before p50/p95 0.039/0.060 ms; after 0.091/0.193 ms.

PASS actual `test_native_parking_lifecycle.mjs`: 2830 frames, drive286.59 m, on-foot48.85 m, physical boarding/exiting, entering hospital, browsing, exiting. Whole fixture CPU p50/p95 0.049/0.116 ms; cold lane planning max77 ms, not scene FPS. Existing `test_civilian_native_lifecycle.mjs`, purposeful and pending-origin tests also pass. Both relevant fixtures now load the actual `npc_city_population_source.js` to retain root's new `_npcRoutineStep` implementation instead of stubbing it.

## Follow-up: personal destinations

`n._residentPersonalPlaces` now retains `homeDoorId`, `workDoorId` (work/service preference), and `leisureDoorId` from actual native metadata. IDs remain stable when the resident moves to another district or starts a new routine cycle. Existing hour-driven `home`, `work`, `study`, `errands`, and rest routines determine which preference is considered; work/study are no longer overridden by a modulo shopping cycle.

The helper receives the complete cached entrance catalog separately from the nearby/reachable candidate subset. A distant home is not mistaken for a deleted home. Blocked destinations are bypassed while retaining the preference; once their failure cooldown expires the original destination can be used again. If no public fallback exists, ordinary waypoint/wandering selection resumes. A genuinely removed or repurposed entry is reassigned from valid metadata. This is destination preference, not a new FSM, employment contract, property ownership, or compulsory travel to an unreachable building. Existing trip destinations remain authoritative.

Catalog indexing is shared by all residents and refreshed at most once per second (or immediately when array/length changes), including same-length replacements. Existing preferences use map lookup and purpose checks; no per-frame destination sort is added. `test_npc_personal_places.mjs` PASS covers persistence, blocked and deleted entries, candidate subset, retained trip, and wallet boundaries. Stress measurement of 384 already-initialized choices: p50/p95 0.465/0.666 ms; ordinary gameplay calls it only during destination choice, not each moving frame. Commerce and purposeful-plan regressions pass.

`test_npc_native_route_edges.mjs` normalizes CRLF before comparing legacy/current source variants; production planner was unchanged by this test portability fix.

## Follow-up: visit queue optimization, measured before activation

Coordinator's old loaded scene reported 169 pending residents after population expansion. That aggregate alone does not prove a deadlock; no claim is made about their precise LIVE ages. Controlled CPU queue testing reproduced a costly startup burst using **96 actual native starts and the actual hospital entrance**, full native water/solids/vehicle geometry, the existing scheduler and unchanged two jobs / four ms budget.

`npc_native_directed_route_source.js` provides persistent A* only for native `building_entry`. Other directed paths and legacy BFS are unchanged. Its heap and visited map survive scheduling slices. Actual origin, callback identity and native resolver identity invalidate stale searches; `_civilianRouteTo` retains its body-pass callback so ordinary resume does not rebuild the search. Node cap and partial-result behavior remain bounded. Native point/body edge samples and the police agent's exact capsule sweep both remain mandatory; movement still performs collision checking. Existing `_cancelNpcDirectedSearch` clears this same search/queue on plan interruption.

Measured activation criterion (`test_npc_native_route_queue_benchmark.mjs`, rerun after production wiring):

| Same 96 residents / actual scene geometry | BFS | A* |
|---|---:|---:|
| Reached / blocked / still pending | 88 / 8 / 0 | 88 / 8 / 0 |
| Completion simulated p50 | 15.05 s | 6.40 s |
| Completion simulated p95 | 29.30 s | 11.00 s |
| Total batch CPU | 2519 ms | 913 ms |
| Native queries including result verification | 809934 | 259545 |
| Frame CPU p95 | 4.77 ms | 4.76 ms |

Every completed route edge was rechecked using actual production `_npcPathPassable`. This improves throughput under the same frame budget; it does not increase the budget or bypass collisions. 50 ms simulated source frames, no rendered NPCs. **LIVE FPS and final queue ages still require the next sole game-tab relay.** Report: `outputs/npc_native_route_queue_20260919.json`.

PASS `test_npc_native_astar.mjs`: persistent frontier, resolver/callback/origin changes, cancellation, exact sweep rejection, maxVisited, immutable coordinates and legacy fallback. Existing pending-origin/purposeful/native-edge regressions pass. Both actual car→building lifecycle fixtures pass with the new helper loaded. The native-parking fixture now drives243.1 m due to the concurrent traffic agent's route update; do not compare that path length with the earlier286.6 m as an A* effect. Ordinary native fixture remains39.10 m driving and reaches the same hospital visit/exit.

## Actual shop acceptance and entry-lane correction

Additional actual-GLB testing found a real shop blocker missed by hospital visits and metadata-only checkout tests. `print_shop-001` opened its door but the NPC could not reach the inside anchor; after three seconds it retreated and had **no purchase**, correctly retaining its wallet. The authored entry centre was 9 mm too close to the open leaf for the historical NPC radius0.18 tiles (0.738 m). Frame width is1.652 m, usable opening with the leaf is about1.556 m: the unchanged footprint can fit with proper alignment.

With root approval, `_residentNativeEntryLane` now chooses a small lateral lane **once after the door opens**. At most nine offsets are tried, with the same body/swept predicate for approach, inward segment and reverse exit. The NPC physically aligns outside first, then enters, and returns on that lane. No global radius change, geometry deletion, position snap, or collision exception. The actual print shop needs a5.125 cm adjustment. Failed selection retains ordinary blocked-entry/retreat behavior.

`test_npc_actual_shop_visit.mjs` now PASS against real `print_shop` GLB and source visit/movement/commerce functions: walk → opening/entering → browse → pay → one inventory item/receipt → physical exit. First debit is asserted inside the actual model's `entry.containsInterior`. Wallet55→52, newspaper quantity1, distance8.98 m, max individual step0.082 m, identical NPC/HP throughout. CPU p50/p95 latest0.048/0.149 ms; no GPU or server-economy acceptance. Report `outputs/npc_actual_shop_visits_20260919.json`.

The shared actual-geometry fixture now loads the commerce/lane script too; hospital lifecycle still passes (and correctly records service purpose with no purchase). Commerce unit and purposeful-plan regressions pass. The optional attempted pawnshop scenario did not satisfy its initial closed-leaf assertion, so **pawnshop physical checkout is not claimed accepted**; the completed production acceptance is print_shop. No browser/GPU tabs were opened.

### Review correction: custom entry callbacks require an explicit sweep

Root review correctly found that the first lane patch passed `_residentNativePassable` to `_npcPathPassable`, whose continuous sweep is intentionally limited to two standard callbacks. Thus the earlier claim that all lane probes already ran the continuous sweep was incorrect: they ran body samples only.

Corrected with `_residentNativeSegmentPassable`: the existing custom samples/gates run first, followed by an explicit native sweep at the unchanged0.18 radius. All three lane-selection segments use it, and **each actual interior/alignment/exit movement step** does too. No global change to custom vehicle-ignore or door callbacks.

PASS `test_npc_entry_lane_sweep.mjs`: a real narrow polygon between sample points reproduces the old miss; entry and reverse exit reject it, no candidate lane crosses it, actual source visit movement remains stationary, a clear lane calls all three sweeps, repeated selection is cached, and a custom point refusal still wins. Actual print-shop checkout and hospital lifecycle were rerun and PASS after the correction. Print-shop CPU p50/p95 about0.058/0.160 ms on this run.
