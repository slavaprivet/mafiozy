# Vehicle physics and destruction team — 2026-09-23

Owner: `Физика Автомобилей` (`01a06e4d-e3ed-7f13-bda3-7fd677972336`). User explicitly assigned this task to supervise `Астра 12` and `Астра 13` continuously.

## Product target

Heavy, readable road handling inspired by GTA IV without cloning its values: convincing mass and weight transfer, progressive grip loss, recoverable oversteer, meaningful braking and handbrake, surface-dependent traction, visible tyre tracks and restrained assists. Crashes must be enjoyable to watch: location/direction/energy-driven staged damage, glass and authored parts, bounded debris and occupant impulse reactions.

This is not permission to replace authoritative source damage, NPC navigation, existing vehicle entry/exit, seats, fire, water, doors, weapons or transport logic.

## Ownership

- Astra 12: isolated vehicle dynamics/tyres and an idempotent local-space crash-pulse output. No damage visuals or occupant pose edits.
- Astra 13: isolated zoned damage state, authored part state, debris/glass pool and performance limits. It consumes a crash pulse but does not change driving physics or authoritative HP.
- Team lead: contracts, tests, conflict checks, production integration and LIVE acceptance. Production remains frozen until the project checkpoint and explicit coordination.
- Transport3 keeps current seat/board/ride/exit ownership. Future occupant reaction must preserve the seat root and legs and may affect only bounded upper-body/head/arms layers. Door exit, fire, anatomy and health states have priority.

## Mandatory event contracts

Driving layer emits one event per accepted contact identity:

```text
eventId, vehicleId, partnerId, time,
localImpulse { longitudinal, lateral, vertical },
angularImpulse { roll, pitch, yaw },
contactPointLocal, contactNormalLocal,
relativeSpeed, effectiveMass, severity 0..1, surfaceKind
```

Damage presentation consumes this only after authoritative contact acceptance. It must not create source HP damage. Re-entry/save/load must not replay an old event.

Occupant presentation derives a short onset/hold/decay response from the same event. It is not continuous camera shake and not based merely on vehicle speed. Driver and passengers vary slightly by seat but share the same physical impulse.

Confirmed vehicle detonation additionally captures an immutable authoritative occupant roster at the detonation instant. Every player/NPC/crew occupant still seated receives a lethal/survival-state receipt exactly once under the explosion event ID. A person who completed exit before that instant is excluded. Visual fire, smoke and debris never manufacture gameplay death, and save/re-entry cannot replay the receipt.

Fire presentation stages are ignition at engine/fuel source, growing exterior/cabin fire, peak burn, burnout and smoulder. Near presentation may use pooled flame tongues, sparks/embers, layered hot-to-cold smoke, velocity/wind response and soot. Mid/far LOD reduces emitters and animation rate; all stages share global caps and deterministic clocks. Existing fire ownership must supply the integration seam after checkpoint.

## Performance gates

- Per-car steady update O(1), no new arrays/vectors/objects per frame.
- Fixed/substep integration has a hard maximum and a defined long-frame fallback.
- Deformation uses bounded authored zones/LOD states or persistent parameters; no full-geometry vertex scan on every contact.
- Debris/glass pools have per-vehicle and global caps, TTL, sleep, distance LOD and reuse. No unbounded receipts, meshes or particles.
- Every benchmark reports p50/p95 CPU, sample count, allocations/memory proxy, active meshes and estimated draw calls. CPU-only results are never called an FPS or GPU win.

## Acceptance sequence

1. Read-only audit and isolated deterministic prototypes.
2. Cross-review the two contracts and exact parity/idempotency tests.
3. Production integration behind an explicit opt-in QA flag after checkpoint.
4. Same-car/same-camera baseline and candidate LIVE run in the coordinator's single GPU tab.
5. Tune by vehicle class and surface; then enable only if handling, visuals and performance all pass.

Required driving scenarios: start/stop, emergency braking, constant-radius circle, slalom, J-turn, power oversteer, handbrake turn, countersteer recovery, asphalt/wet/dirt, 30/60/120 Hz and long frame.

Required crash scenarios: weak scrape, side impact, head-on, rear impact, rollover, repeated impacts, multi-car pile-up, RPG, C4 and vehicle explosion, save/re-entry and duplicate event delivery.

Required detonation scenarios: empty vehicle, one and four occupants, mixed player/NPC/crew seats, occupant completes exit immediately before explosion, duplicate explosion delivery, already-wrecked vehicle, cull/re-entry and save/load. Required fire scenarios: moving ignition, stopped peak fire, wind/velocity direction, near/mid/far transition, simultaneous vehicle cap, burnout and smoulder cleanup.

## Current project constraints

Coordinator reports current main `e33212e` with a new reviewed gameplay checkpoint pending. Root has the only GPU game. Transport3 seat/ride/exit package is READY/frozen and separately audits ordinary NPC trips. Vehicle entry/fire and Artist21 locomotion/jump have active owners. Do not overwrite their shared WIP.

## Baseline checked by lead

Current code is not a blank slate. The following suites passed before new work:

- `test_vehicle_dynamics.mjs`: 6/6, including fixed 120 Hz parity at 30/60/120 render Hz, drift/recovery, damage and collision momentum.
- `test_vehicle_crash_mechanics.mjs`: localized crush, mass/energy bounds, mirrored impacts, idempotent contacts and 600-impact stability.
- `test_vehicle_damage.mjs`: HP/armor, thresholds, collision cooldown, bounded receipts and reset/disposal.
- `test_vehicle_fire_fx.mjs`: fixed 122-particle GPU pools, fire/blast/dust/smoke fade, no idle allocation, anchors and disposal.
- `test_vehicle_impact_reaction.mjs`: damped occupant inertia, 30/60/120/144 Hz parity, dedupe and cabin/hand safety across real vehicles.
- `test_tire_tracks.mjs`: bounded ring, surface mask, braking/slip and expiry.
- `test_vehicle_crash_visual.mjs`: authored geometry/material preservation, bounded subdivision, cached cage deformation, detached assemblies and repair.

Therefore new work extends and connects `vehicle_dynamics.mjs`, `vehicle_crash_mechanics.mjs`, `vehicle_damage.mjs`, `vehicle_fire_fx.mjs`, `vehicle_impact_reaction.mjs` and `tire_tracks.mjs`; it must not replace them with a second parallel simulation. The known coverage gap is source-player and source/NPC occupant impact presentation. Local hero/fleet already have partial impact integration.

Lead-created baselines:

- `outputs/benchmark_vehicle_dynamics_baseline23.mjs` (`node --expose-gc`), 1/60 step p50/p95: executive sedan 0.00118/0.00247 ms, sport coupe 0.00107/0.00145 ms, SUV 0.00112/0.00193 ms. This is Node CPU only, one active car, not FPS.
- `outputs/benchmark_vehicle_fire_baseline23.mjs` (`node --expose-gc`): CPU update remains tiny, but active draw calls scale linearly: 1/8/16/32 burning vehicles use 3/24/48/96 draws and reserve 122/976/1952/3904 instances. The new rich near effect therefore needs shared mid/far batching or a global active-detail budget, not just more per-car meshes.
- `outputs/vehicle_fire_lod_budget_candidate.mjs` + test: deterministic near/mid/far assignment with hysteresis and 4/8/32 caps. 128 active vehicles are bounded to 30 estimated draws instead of 384; 512-candidate scheduler p50/p95 0.294/0.499 ms and is intended for a throttled (not per-frame) census. Shared far rendering is still missing, so this is not production-ready.
- `outputs/vehicle_explosion_occupants_candidate.mjs` + test: confirmed immutable occupant snapshot, lethal receipt per inside/alive actor, duplicate-event/vehicle conflict handling, partial-authority retry and JSON save/restore idempotency. Five tests PASS. An authoritative owner-side seat snapshot and health/death application seam are still required before integration.
- `outputs/vehicle_occupant_crash_pulse_candidate.mjs` + test: authoritative before/after velocity or contact-impulse input becomes a local cabin inertia event with linear/angular channels, severity, onset/decay metadata and replay deduplication. Front/rear/side/rollover, impulse fallback, raw-speed rejection, bounded pile-up and 30/60/120/144 Hz parity are covered by six passing tests. Existing `vehicle_impact_reaction` and integration suites still pass (8/8); production should adapt the existing reaction rather than run two springs.
- `outputs/vehicle_fire_far_batch_candidate.mjs` + test: the previously assumed far-fire renderer now exists as an isolated real Three.js two-batch candidate. Thirty-two distant burning vehicles share one flame and one smoke draw, with fixed 4+8 quads per vehicle (384 total), deterministic seeds, reused typed arrays, duplicate filtering, smoke-only handling, hard overflow accounting, reset and disposal. Five tests PASS. `benchmark_vehicle_fire_far_batch_candidate.mjs` measures 128 active rows as 4 near/8 mid/32 far/84 off and 30 estimated total draws; far update p50/p95 was 0.0374/0.0625 ms, throttled scheduler 0.0645/0.1671 ms, with the same typed storage after 100k updates. This proves Node CPU/scene-graph topology only; shader compilation, GPU cost and visual quality still require the coordinator's LIVE gate.
- `outputs/vehicle_occupant_snapshot_candidate.mjs` + test: one atomic source frame is normalized across the local player, source player/custody, mercenary crew and exported source NPC riders. It excludes entry/board/reservations, exit-body and dead actors; preserves local/crew exit-door occupants; canonicalizes presentation/source vehicle IDs and deduplicates actor identity. Six snapshot tests plus the five lethal-receipt tests PASS, including an end-to-end snapshot-to-lethal-plan case. Production still needs the owner to supply a genuinely atomic source frame and canonical ID resolver.
- `outputs/vehicle_fire_stage_candidate.mjs` + test: presentation-only deterministic timeline for ignition, growth, peak burn, explosion flash, burnout and smoulder. It exposes flame/smoke/embers/soot/light/heat plus wind/vehicle drift, applies hard near/mid/far/off instance and update-rate budgets, and performs finite cleanup without changing damage authority. Six tests PASS, including 30/60/120/144 Hz parity and stale-light reset.
- `outputs/vehicle_crash_step_noalloc_candidate.mjs` + test + `benchmark_vehicle_crash_mechanics_baseline23.mjs`: exact existing 45-node/beam solver math using one fixed 1,080-byte typed scratch buffer per active car instead of 46 force objects per 1/240 substep. Serialized state remained exactly equal to production through 1,400 frames, repeated contacts, long frames, settling and thermal damage; three tests PASS. In the Node 72-car stress, current p95 was 9.2082 ms versus candidate 4.8483 ms (47.3% lower), while eliminating an estimated 13,248 transient force objects per fully active 60 Hz fleet frame at a fixed 77,760-byte scratch cost. This is pure solver CPU, not render/FPS; integrate only after checkpoint and rerun production/LIVE gates.

Combined verification after these isolated additions: 89/89 tests PASS across current dynamics, structural crash mechanics, vehicle damage, fire FX, impact integration/reaction, tyre tracks, real crash visuals and every lead candidate. This is CPU/contract/scene-graph verification, not shader compilation or LIVE FPS acceptance.

## Current integration hold

Transport3 confirmed `vehicle_crash_mechanics.mjs` is clean, free of conflicting ownership and belongs to this vehicle-physics scope. Coordinator20 explicitly placed canonical/GPU changes on HOLD only until its current NPC checkpoint and LIVE reload finish; there is no vehicle-file conflict. The next authorized production change is the behavior-identical structural-force scratch optimization. Exact base identity and an `apply_patch`-ready hunk are saved in `outputs/vehicle_crash_noalloc_e33212e_apply_patch.txt`; recheck HEAD/blob immediately before applying.

## Published checkpoint — main/origin `4d4cd84` (2026-09-23)

Coordinator20 authorized, verified and published the first production integration on main/origin. `assets/maps/city_rebuild_v1/vehicle_crash_mechanics.mjs` now reuses one `Float64Array(135)` structural-force buffer per crash state through a `WeakMap`, and clears settled velocity components in place. The production Git blob is `67574722dbf5bd32714e272a915450d4371ffd04`; its raw-file SHA-1 is `c44ef17154953743d2100dc12a5570700a3383d6`.

`outputs/test_vehicle_crash_step_gitbase_parity.mjs` reconstructs the exact original Git blob `f3ade1304ff48f6b0e5ed9e37dd5501ace0fd993`, verifies that identity with Git's blob hash, then compares the old and integrated solvers for 1,400 frames with repeated impacts, long frames, settling and thermal damage. Serialized states and return values are exactly equal.

Fresh post-apply verification: 123 checks PASS across vehicle dynamics, crash mechanics/visuals/drive, contact damage/motion, pair impulse, tyre tracks, wreck idle, damage, fire/fade, occupant impact reaction and integration, plus the isolated no-allocation, drive-cache, surface, pulse/snapshot, fire batching/staging and occupant-plan candidates. This is CPU/contract/real-GLB test coverage, not a LIVE FPS or GPU result.

The deterministic performance result is allocation removal: a fully active 72-car structural frame no longer creates the estimated 13,248 transient force objects and instead keeps 77,760 bytes of fixed scratch storage. Wall-clock Node timings remain noisy: the latest 72-car run measured old/candidate p95 4.9737/5.1552 ms, while earlier repeated runs showed materially lower candidate p95; therefore no stable time-speedup claim is made until the single-tab LIVE gate. The latest run did reduce the worst sampled frame from 14.8651 to 8.0869 ms, but that is not yet an acceptance metric.

## Safety hold — server occupant death

Do not attach lethal occupant damage directly to `gta_crash`. That message accepts client-reported crash damage without a server-verified physical contact identity, dedupe window or authoritative collision proof. The server file is `mafiozi_bot.py` (not `mafiozy_bot.py`). Any future lethal integration requires a server-admitted detonation event, immutable authoritative seat snapshot, life-generation binding and durable per-occupant receipts/retry.

`test_vehicle_explosion_occupants_server.py` previously overwrote `.bot-token` because its import-time dummy token used the production module directory. It now copies `mafiozi_bot.py` into a unique temporary import directory and scopes `BOT_TOKEN`/`DB_DIR` with `patch.dict` only around that import, verifying both environment keys are restored immediately afterward. Seven focused tests PASS, and a before/after SHA-256 check confirmed the real `.bot-token` stayed unchanged. The token had already been restored from the existing backup and was never printed. Production additionally has `VEHICLE_EXPLOSION_OCCUPANT_LETHAL_ENABLED=False`; the delivery function returns `server-physical-admission-required` without applying damage unless a test explicitly opens the gate. This fixes test isolation and prevents accidental activation only; the isolated presentation/receipt candidates remain useful, but no server lethal path is production-ready.

## Astra continuation

- Astra 12 READY-2 was accepted; READY-3 now cross-reviews the local surface-grip/composition candidates against the current driving chain and must return an opt-in, legacy-exact, allocation-bounded patch proposal with 72-car measurements. Production and LIVE remain forbidden for the Astra thread.
- Astra 13 READY-2 was accepted; READY-3 is queued for stable fire event identity, real update-rate gating, finite smoke cleanup, external-blast suppression, 10 Hz far batching and bounded debris. It must not touch the unsafe server-lethal path.

Additional isolated visual candidate: `outputs/vehicle_tire_tracks_surface_candidate.mjs` with test/benchmark. It uses one shared bounded ring and ages TTL once per frame, then emits once per vehicle; calling the old pool update from every vehicle would incorrectly age tracks 72 times. It stores per-wheel surface/material identity for asphalt, wet asphalt, dirt and grass, uses explicit slip/service-brake/rear-handbrake intensity, and breaks continuity on teleport, airborne/missed frames, release and surface changes without hot-path allocations. Existing tyre-track tests plus 5 new tests PASS. At 72 cars/4,096 segments, Node p50 was 0.2024–0.2151 ms and p95 0.2708–0.2964 ms; fixed storage was 645,312 bytes. One draw is only an estimate contingent on a future palette shader; GPU/LIVE remain unverified. Integration waits for Astra 12 READY-3 telemetry.

## Current integration review — main/origin `1d0fc45`

The no-allocation crash solver remains published and clean on current main. The `car_drive` cache candidate is file-level READY but Coordinator20 keeps it HOLD until the frozen GPU/checkpoint baseline is complete.

The old surface-traction patch must not be applied. Although its target blob still matched, it activated on the presence of finite longitudinal fields instead of an explicit `advancedTires` flag, could double-apply longitudinal grip, lacked load transfer and correct drive/brake/handbrake axle splits, and had no safe `car_drive` surface seam. Astra 12 READY-3 kept advanced mode opt-in and legacy exact, but its archive-only test still had 10/48 tolerance failures at 144 FPS, up to 0.954 m over eight seconds. Astra 12 is now assigned a bounded 120 Hz accumulator/host-clock READY-4 to close this before local integration.

Astra 13 READY-3 produced 76/76 isolated PASS for stable fire identity, finite smoke/burn deadlines, real update-rate gating, `externalBlast` suppression, a 10 Hz far upload contract and bounded debris leases. It could not read local candidates or compile the real shader. The proposed 24-float far packet also differed from the current 16-float layout and rollback retained 360 legacy fire mesh objects. Astra 13 is now assigned a versioned two-phase packet/shader migration with lazy/bounded legacy allocation. Its stated `1,241,128 B` proxy equals about `1.184 MiB`.

`outputs/vehicle_occupant_impact_4d4cd84_proposal.patch` now contains the exact tested event module, adapter and thin fleet seam. Exact AddFile extraction executes as ESM. Physical delta-V is immutable and strictly separate from bounded presentation intensity; damage receives only the original physical contact. Nineteen exact/runtime tests and five real-cabin suites PASS, including 13 cars, 40 seats and 160 directional applications. Transport3 opened the fleet ownership seam, but application awaits Coordinator20 approval and does not by itself animate source NPC/crew occupants.

The source NPC/crew gap is explicit: current `npc_vehicle_pose`/`npc_actor` does not read `impactReaction`. An isolated group candidate samples one existing per-vehicle reaction once and composes up to three persistent seat scratches without a second spring or hot allocations. Twenty-three combined tests PASS and the real cabin suite remains safe, but simple fire-pose suppression does not satisfy the user's requirement that aiming/leaning occupants also jerk. A second isolated stage is composing the existing fire/aim pose with the same impact sample while preserving grips and hull bounds, plus a bounded cold-certification scheduler.

The LOCAL-only explosion occupant candidate now uses a monotonic controller-owned generation independent of resettable `state.explosions`, high-water replay protection and full new-life cleanup. It snapshots crew before hero callbacks, applies crew receipts first, uses the actual local `_hurtLocal` armor/death path, and keeps online/server modes fail-closed. Extracted actual owner lifecycles and reset/re-explosion scenarios pass 21/21. Production is still HOLD pending owner/root review and LIVE QA.

An additional actual-GLB review found a death-presentation blocker: a dead crew member can remain source-bound to a moving seat while `npc_actor` switches to a ground death pose, placing the body under the chassis and dragging it with the car. A separate isolated candidate must keep an in-seat fatal/slump pose until authoritative removal/ejection; Transport3 separately owns ghost-seat/hospital release.

## Published fleet impact seam — main/origin `217075c3` (2026-09-23)

Coordinator20 published the five-path scoped integration after independent review. `vehicle_fleet.mjs` now emits one confirmed physical contact packet through `vehicle_occupant_crash_pulse_event.mjs`, `vehicle_occupant_impact_adapter.mjs` and `vehicle_occupant_impact_fleet_seam.mjs`; the portable production test is `test_vehicle_occupant_impact_runtime.mjs`. Main and origin both resolve to `217075c37c03cd20d37a3eb74eab11806de8fa18`.

The final boundary preserves physical damage even when a legal fleet car omits `yawRate` or presentation-only evidence is invalid. Missing `yawRate` normalizes to zero like the solver. Corrupt impulse/time/yaw suppresses only the cabin reaction; it cannot suppress pair A/B damage and cannot fall back to raw impact speed. Production runtime checks pass 8/8, related suites 29/29, independent boundary repro 19/19 and real-cabin safety 5/5 across 13 cars and 40 seats. This is a confirmed event/integration seam, not yet proof that every source NPC/crew body visibly jerks in LIVE.

The shared branch later advanced to `5661b28` for an unrelated street-lamp batching change; the fleet impact commit remains in its ancestry. Fresh checks on that newer HEAD pass 8/8 runtime, 12/12 fleet and the contact-damage suite.

The first seated-death candidate remains HOLD after a stricter actual-GLB review found two failures: an actor first streamed already dead has no prior live seat capture and can still appear under the chassis, and a warm seated corpse did not follow vertical/roll seat-root motion because the captured world pivot overwrote full car-relative pose. The next candidate must handle cold-dead construction and full six-degree-of-freedom car-relative transforms before any production integration.

## Fire-pose plus impact composition candidate — `5661b28` HOLD

`outputs/vehicle_fire_impact_composition_candidate.mjs` now composes one shared existing per-vehicle impact-reaction sample after the existing READY/FIRING/RETURN occupant fire pose, using three persistent seat caches and no second spring. Real-model coverage passes 405/405 combinations across 13 cars, 27 passenger seats, three fire phases and five impact directions. Legs do not drift, no new body/weapon/hull intersections appear, and maximum aim delta is about 0.065 rad under the 0.105 gate. Full gain is unsafe (76/405 violations), so any future integration must retain the hard 0.5 gain cap.

The hot 72-car/216-composition prototype measured p50 0.0232–0.0311 ms and p95 0.0784–0.0865 ms with 78,408 bytes fixed typed storage and no candidate hot-path allocations. Actual cold certification remains too expensive for an unguarded frame (p50 8.95 ms, p95 16.56 ms, max about 20 ms), and a simultaneous queue can take hundreds of frames. Production remains HOLD; the next isolated stage is a bounded incremental cold-certification scheduler with stale cancellation, fairness, previous-certified fallback and explicit backlog telemetry.

Current main/origin is `f4164be1a5a027a19daf99816967ee78f99261bb`; the published fleet-impact seam remains in its ancestry. Fresh current-HEAD verification passes vehicle dynamics 6/6, crash mechanics 19/19, real crash visuals 12/12, impact reaction/cabin 5/5, fleet impact runtime 8/8, legacy tyre tracks, surface candidate 5/5 and surface composition 4/4.

The shared surface-aware tyre-track pool was rebenchmarked at 72 cars/4,096 segments: p50 0.1956 ms, p95 0.2511 ms, max 0.411 ms, fixed 645,312 bytes. Coordinator20 keeps production promotion HOLD because a new module without its host and renderer would be dead production code. The isolated candidate stays ready; user-visible integration waits for Astra12's stable surface/clock contract and a real palette-render owner seam.

## Local occupant-lethal explosion root review — READY/HOLD

The current isolated proposal now passes 28/28 tests. It freezes an immutable roster, delivers crew receipts before hero callbacks so ambulance/seat cleanup cannot skip crew, includes real hero/crew exit-door occupants, excludes entry/board/reserved/exit-body/dead/hospital actors, deduplicates hero-versus-seat identity, creates no second FX and remains fail-closed online while the server gate stays false. A newly fixed replay edge keys generation high-water by canonical fleet vehicle ID, so replacing a record object with the same ID cannot restart at generation one and replay an old death.

Production remains HOLD for ownership rather than logic: `walk_preview.mjs` and `world.html` changed twice during the audit and remain active dirty owner files. The exact unblock is to wait for those owners to land/freeze, rerun the five proposal transforms and all 28 tests against final hashes, then apply without touching server/fire code. Artifacts include `outputs/walk_vehicle_explosion_patch_proposal_217075c3.mjs` and `outputs/WALK_VEHICLE_EXPLOSION_ROOT_REVIEW_217075C3.md`.

Coordinator review found that the first proposal's second nested dynamic import would break existing full-host VM fixtures, which intercept only the one `mercenary_core` import. Root tested the safer architecture in `outputs/test_walk_vehicle_explosion_full_host_core_export_candidate.mjs`: export `createMercenaryVehicleExplosionOwner` from the already-loaded `mercenary_core.mjs`, instantiate it from that module in `mercenary_world.js`, and keep the walk-local controller module separate. The transformed full host retains exactly one import. Two full-host regressions pass: hero plus three recruited crew receive 4/4 receipts once with replay suppressed, and a fatal crew receipt blocks auto-medic, reaches hospital, then clears fatal/death state and advances life generation at 300-second discharge. The exact non-writing proposal must be updated to this architecture after the active owner freeze.

The exact non-writing proposal is now updated on base `f8f1a6e` and passes 31/31 combined checks. Two further P1s were fixed: local preview's `combatVersion=-1` is replaced by an owner-controlled monotonic hero life epoch that advances on dead-to-alive transition, and crew fatal/death/life-generation markers are explicitly persisted/restored so reload cannot reopen an ordinary medic revive. Full-host tests now include fatal save/reload, continued revive blocking and authoritative discharge cleanup. Manifest: `outputs/walk_vehicle_explosion_core_owner_f8f1a6e_manifest.json`; proposal SHA-256 `e2a00ef9...`, candidate `9be52e59...`. Production/server/fire remain unchanged pending final independent owner review and scoped application.

## Impact cold-certification scheduler v2 — READY/HOLD

The cooperative scheduler passes 7/7 with exact final arithmetic parity, round-robin fairness and deterministic behavior at 7/15/30/60/120/144 Hz. It supports phase/sign/generation keys, soft deadlines, hard vertex budgets, per-job quantum, stale reset cancellation, pause/dispose, prior-certified fallback and backlog/latency telemetry. Synthetic 72-car/216-job runs at a 0.25 ms soft budget measured p50 about 0.230 ms, p95 about 0.259 ms and completed in 141–144 frames, with about 172 KB fixed scheduler storage excluding job snapshots.

Actual integration remains honestly blocked at the owner API: `createVehicleOccupantImpactPose.apply()` performs its skin bounds/stage/cache work atomically, a visible actor cannot remain in the temporary probe pose between frames, and a Three.js `SkinnedMesh` cannot be structured-cloned to a worker. Thus the real 8–20 ms certificate cannot be claimed as incrementally fixed from outside. The next valid solution is an owner-exposed pure serializable certification kernel or exact resumable API; idle/loading-only execution merely moves the spike.

## Astra 12 READY-4 — fixed-clock blocker closed in isolation

Astra 12 reproduced the prior 10/48 144-FPS failures and 0.954361 m drift, then eliminated them on archive base `e33212e` with an opt-in shared 120 Hz clock. Across 192 regular plus 480 adversarial runs and 9,624,960 `Object.is` comparisons, equal physical tick traces had zero position/angle/speed drift. Jitter, 144↔30 switching, a 250 ms stall and pause/resume passed 11/11 new groups; the earlier 22/22 regression groups also pass. Feature OFF remains bit-exact through 33,984 frame comparisons, and advanced mode without the new host gate remains unchanged through 135,936 comparisons.

The clock uses one 9-float buffer (72 bytes) per synchronized group, fixed 1/120 ticks, 0–12 ticks per callback and remainder below one tick. A 250 ms frame admits 100 ms and discards 150 ms without later catch-up. Archive 72-car callback measurements for fixed advanced were p50/p95 0.290/0.512 ms at 60 FPS, 0.131/0.238 ms at 144 FPS and 1.758/2.085 ms for the 250 ms stall; these are Node/open-ground results, not current-city FPS. Current production integration remains unproven because the whole `stepCar`/contact/fleet chain must share the clock and zero-tick render callbacks must not replay contact events. READY-5 is assigned specifically to tick-indexed input, pair/contact idempotency and current-host seam evidence.

## Astra 13 READY-4 — versioned fire packet migration

Astra 13 reports 72/72 Node tests plus 18/18 real WebGL2 compile/reflection/sentinel checks PASS, with a byte-identical clean reapply in isolation. The contract correctly rejects blind padding of the old 16-float packet and also rejects the semantically different V3 24-float packet. The accepted `V4_SLOT_MASK` layout is versioned at 24 floats/96 bytes and uses a canonical 0–71 slot; full fire event IDs and revisions remain CPU metadata.

Feature OFF returns the exact legacy factory and allocates no migration resources. PREPARE validates the manifest, actual shader compile/link, reflected attributes, VAO stride/offset/divisor, a sentinel draw and both buffer banks while the current presentation remains live. COMMIT rechecks context epoch, cancellation token, event identity, revision and far cohort before one synchronous ownership swap; constructors, destructors and callbacks stay outside publication. Layout/NaN/compile/upload/stale failures retain the last valid presentation without extending smoke deadlines. A per-slot `uEnabled[72]` mask handles repair/reset and far↔near transitions without dropping the other 71 cars. The corrected fixed-memory unit is 1,241,128 bytes ≈ 1.184 MiB. Production still needs current-renderer seam review and one real LIVE/GPU visual gate. READY-5 is assigned to bounded high-quality fire/smoke shader presentation without adding far draw calls.

## Surface-aware tyre-track palette renderer — READY/HOLD

The isolated renderer now uses one mesh, one shader material and one estimated draw for 4,096 segments/8,192 triangles. Attributes cover position, opacity, material, surface, wheel and edge; the shader supports asphalt/wet/dirt/grass and rubber/wet-rubber/dirt-rut/grass-rut palettes with edge feathering, tone/color-space chunks, depth test, no depth write and negative polygon offset. Geometry/material/surface/wheel uploads occur only when dirty; normal ring writes use one range, wrap uses exactly two, and TTL updates only the populated alpha range. The host ages once per frame token, deduplicates active versus fleet records and has bounded stable slots with reset/deactivate/dispose.

Twelve combined tests pass while the production `tire_tracks.mjs` and legacy `createTireTracks` remain unchanged. A 72-car/4,096-active CPU run measured p50 0.229–0.234 ms, p95 0.324–0.350 ms and max 0.636–0.722 ms with 841,920 bytes fixed arrays; steady dirty ranges total 139,776 bytes/frame versus 688,128 for a full rewrite. This is not a GPU result. LIVE remains blocked on the actual fleet lifecycle/slot seam, Astra12 per-wheel surface state, real WebGL upload/overdraw measurement and art tuning of height/polygon offset/palette. An exact current-host non-applied adapter is assigned next.

## Real pooled debris renderer proposal — READY/HOLD

`outputs/vehicle_crash_debris_renderer_f4164be_proposal.patch` (SHA-256 `3e74311f...`) now adds an optional fleet/world singleton with two shared instanced meshes: 144 glass shards and 216 chips, 288 global active fragments, five per car and 72-car admission. Fixed combined storage is 74,592 bytes and active rendering is capped at two draws. Authored persistent doors/hood/wheels stay with the existing owner; the pool is cosmetic only, repair clears it, explosion panes hide once, and no second `glass_breakage` path is called. Feature OFF preserves legacy state/API identity and adds no scene node.

Forty-eight overlay and existing tests pass, and `git apply --check` passes on current clean scoped blobs. In the 72-car CPU stand, dynamic update p50/p95 was 0.0665/0.1127 ms, dirty sync 0.0499/0.0845 ms and clean frame 0.0133/0.0389 ms. GPU/full-city cost remains unmeasured. Production waits only for the crash/damage/fleet owner window and later feature-flagged LIVE acceptance.

## Applied local explosion package — HOLD_TO_CHECKPOINT on Transport3 ghost-seat

Coordinator20 applied the seven-path local occupant-lethal explosion proposal on the shared worktree, including `walk_vehicle_explosion_local_authority.mjs`, without enabling the server lethal path or adding a second fireball. Exact production hashes match `outputs/walk_vehicle_explosion_core_owner_f8f1a6e_manifest.json`. Fresh root verification passes the deployed portable suite 3/3, `test_vehicle_damage.mjs`, and `test_vehicle_fleet.mjs` 12/12. Independent review also passes the transformed candidate 14/14 and the existing mercenary persistence/recruit/revive/hospital overlay 74/74.

The first checkpoint attempt was held by an exact-host lifecycle repro, `outputs/run_walk_vehicle_explosion_seat_lifecycle_review.mjs` (SHA-256 `ac84b901b32886f3a10ad786a5f504fc38d833dfe24de9c73d30e25e689a47bd`), which proved a pre-existing Transport3 ownership defect: after fatal explosion, hospitalize and same-session discharge, the crew member retained `_mercenaryVehicleSeat='rear_left'`; `snapshotVehicleExplosionOccupants('fleet:red')` still returned that remote actor, so a later explosion of the repaired car could kill the new life at the hospital door. Reload cleared the non-persisted seat and therefore disagreed with the live session.

The repair correctly landed through the squad-transport owner rather than the explosion controller. Authoritative hospitalize now releases the `squadTransport` reservation and clears seat/id/phase/exit/reserved fields, with a discharge fail-safe. `outputs/test_vehicle_explosion_ghost_occupant_transport3_acceptance.mjs` (SHA-256 `8be7dd94888a825f9c93bae3685b529a096a6690aa69cf33b724321917a3a854`) now passes 2/2 for fatal→hospitalize→discharge→repair→second explosion and reload parity. Fresh post-apply root verification also passes deployed explosion 3/3, mercenary world 48/48 and rally/actions 36/36. The ghost-seat P1 is cleared.

The first hero-epoch follow-up artifact directly toggled `myDead`/`myHp` in a VM without calling the real death or recovery owners. It is useful only as an abstract contract and must not be used as an integration blocker: a read-only getter cannot detect arbitrary unobserved variable writes. Actual acceptance must exercise `_hurtLocal`, death dispatch, `_completePlayerAmbulanceRecovery` and the real reset path, with generation publication at those authoritative lifecycle boundaries. The targeted explosion recovery path already passes. Two proposal source-contract checks are pre-apply-only and double-patch an already transformed `effect`; their post-apply failures are harness defects, not runtime regressions.

The corrected seated-death v2 was separately applied by its owner to `npc_death_entry20.mjs` (SHA-256 `56bebab9056949f0964b47f2ba24e174d55163e82e22156384f8135a65a1f23f`) plus four scoped lines in `npc_actor.mjs`. Actual production tests pass origins 62, integration 26, continuity 6, portable 3/6 scenes and legacy 24. This keeps a fatal occupant visually seated until authoritative removal and does not itself own Transport3 reservation cleanup.

The full-quaternion seat binding was later applied independently to `npc_vehicle_pose.mjs`; the current Git blob is `abeb1e631405fa986beec499a68b1590a97c474e` (raw SHA-256 `e721d29f42c0b169518220d214e3a523ae65cfca1f114c4f96810ea50b918ea7`). It replaces the yaw-only temporary actor root with a world-space seat point and car quaternion converted through the actor parent, while restoring source authority afterward. The isolated owner run reported 1,189 checks, drift reduction from about 0.4012 m to `3.6e-13`, zero root error and endpoint jump about `1.14e-6` m. An independent current-tree review is still required before claiming full combined acceptance with seated death and explosion cleanup.

The independent current-tree review then confirmed full-quaternion correctness across 1,640 live checks, 1,625 independent checks, cold/warm seated death, save/release/re-entry, explosion 3/3 and impact 8/8, but found five temporary objects per seated occupant per frame (two vectors and three quaternions). At 40 seats this was structurally 200 allocations/frame, so the owner replaced all nine pose scratch objects, including the pre-existing source-root and matrix clones, with private per-walker `WeakMap` scratch. The owner reports the same maximum bone error `5.4e-8` with the actual 1,640 and full-host death/continuity suites passing. A separate post-apply allocation/correctness audit is assigned; do not reapply the earlier `abeb1e6` diff over the rewritten file.

## Current-host fixed 120 Hz audit — scheduler READY, integration HOLD

`outputs/vehicle_fixed_120_host_candidate.mjs`, its portable test/benchmark, the non-applied skeleton patch and `outputs/VEHICLE_FIXED_120_HOST_F8F1A6E_HOLD.md` now document the actual current host. Twenty-five combined candidate and production tests pass. The candidate proves zero-tick/duplicate-token callbacks do not move or contact, 1–12 admitted ticks use one input snapshot, actual `stepCar(1/120)` has exact 30/60/120/144 and jitter traces, active/parked/source records share tick identity, pair impulse/damage emits one event ID, long frames cap at 12 steps, and pause/reset do not catch up.

Direct integration remains HOLD because current `vehicle_fleet.update` mixes passive physics and render presentation and still executes a physical loop for `dt=0`; the walk host runs parked substeps before active and then source; pair cooldown suppresses repeat callbacks but not repeat impulse and derives identity from float time; source update mixes physics, pose, visual and bridge work without an authoritative source↔fleet pair seam. The required promotion order is: split fleet fixed physics from once-per-render presentation, add one bounded enter/stay/leave ledger spanning active and passive records, split source physics from presentation, decide source↔fleet authority, then sample input once before admitted ticks. The reported CPU numbers are Node/current-function measurements, not LIVE FPS.

## Astra 13 READY-5 — bounded richer fire/smoke, integration HOLD

Astra 13 reports 110/110 Node tests and 27/27 real WebGL2 compile/link/reflection/sentinel/draw/readback checks PASS for the isolated V4 24-float/96-byte slot contract. The shader adds a hot core, orange turbulent shell, soot smoke, bounded wind-minus-vehicle bend and small billboard-only shimmer without a postprocess or extra far core draw. Ordinary stages end at 16 seconds, wreck fire at 5 seconds and smoke-only at 8 seconds; `externalBlast` still creates no second fireball. Repair/reset, far↔near, NaN/extreme inputs and actual context loss are covered, with structural far uploads at most 10 Hz.

This is not yet a production seam. Current `vehicle_fire_fx.mjs` owns five per-car `InstancedBufferGeometry` pools using a four-float particle attribute; it has no near/mid/far owner, no V4 packet and no context-loss migration hook. The exact integration therefore stays HOLD behind an explicit adapter/API gate and two-phase prepare/commit; no parallel owner may be introduced. At 72 far fires, flame and smoke are two draws, but 72 legacy ember modes still make 74 estimated draws. Astra 13 READY-6 is assigned a shared bounded far-ember batch targeting one ember draw while preserving the existing 32-per-car ceiling, stable seeds, deadlines and rollback.

## Published vehicle occupant lifecycle checkpoint — main/origin `f30d6dc`

Coordinator20 published the curated vehicle/NPC checkpoint as `0bec159` (`npc: integrate vehicle combat, road access and occupant lifecycle`), followed by unrelated traffic door batching `f30d6dc`; local main and origin/main both resolve to `f30d6dcf747896154cb66a567f5ba2fbcc55030e`. The vehicle checkpoint includes local lethal explosion ownership, actual hero life-boundary hooks, mercenary ghost-seat cleanup, seated-death presentation, full-quaternion seat binding with depth-two per-walker scratch, occupant sight/incoming/surface seams and permanent production regressions.

Fresh root post-commit verification on the published tree passes: hero life 9/9, ghost lifecycle 3/3, actual ghost-seat visual removal/reuse, pose scratch 4/4, tilt 1,640 checks, deployed explosion 3/3 and occupant impact runtime 8/8. The pose scratch test warms 40 occupied seats and then runs 5,760 calls at a 144-frame schedule with exactly zero candidate-created `Vector3`, `Quaternion` or `Matrix4`; the full 40-pose frame measured about 0.136/0.179 ms p50/p95 in that Node run. Same-walker nested calls use separate depth slots and restore both temporary and authoritative roots; deeper-than-two reentry uses safe temporary storage.

The first same-tab LIVE check also passed: an Easton containing the hero plus three crew was exploded through the local QA path; the controller accepted one event, selected four targets, delivered four receipts, suppressed the duplicate, set hero HP to zero and reached confirmed source-world death with no JavaScript errors. This validates the local preview path including its `combatVersion=-1` input, not online/server authority. Corpse visual inspection and hospital removal/reuse remain the final visual observations. The shared branch has since advanced through unrelated shadow fixes to main/origin `06a8035cb99f1e01f7b92688cd4cbbfcf2230c6e`; `0bec159` remains in ancestry.

## Astra 12 READY-5 and current-host translation

Astra 12 READY-5 reports 20/20 isolated host groups, 10,706,136 exact comparisons and zero physical drift for equal fixed ticks. It freezes tick-indexed input, runs complete `stepCar` plus contact admission and pair resolution on one 120 Hz clock, commits authority effects after every physical tick and proves 187,523 zero-tick render callbacks do not move, query contacts, resolve pairs or repeat frame distance. Its archive storage is 503,880 bytes for 72 cars, including a 512-transition FIFO, 32-tick history, pair dedupe and a bounded 2,592-event outbox. This remains isolated and makes no current production claim.

The separate exact current-host translation is under `outputs/vehicle_shared_120_*` and passes 34/34 candidate+production tests. It defines a 512-entry enter/stay/leave pair ledger with at most one impulse/damage/event ID per pair/tick and 20,480 bytes fixed state. Promotion still waits for a real fleet fixed-physics/presentation split, authoritative source↔fleet collision ownership, separation of damage/fire timers from physical ticks and the walk owner window. Astra 12 READY-6 is assigned bounded suspension/load-transfer and body pitch/roll on the fixed clock; production remains unchanged.

## Fire canonical episode seam — explicit HOLD

The exact production audit confirms `vehicle_fire_fx.mjs` exposes only `{object, update, reset, dispose, stats}` and does not publish stable fire event identity, revision, absolute start/deadlines or reset generation. Damage `recentHits` and resettable explosion counters are not valid substitutes. `outputs/vehicle_fire_episode_extractor_candidate.mjs` and its tests pass 9/9, including 72 slots, 100,000 stable reads, reset/replay and 30/60/120/144, but intentionally fail closed without one allocation-free owner method `readVehicleFireEpisode()`. The next non-applied stage is a minimal owner hook only; no shader, mesh or second `onExplosion` may be added before that contract is reviewed.
