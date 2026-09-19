# Applied eight-admission queue checks — 20 September 2026

Test-only update for root's production change `_npcRouteWorkCount >= 2` → `>= 8`. Production files were not changed by this audit.

Passed:
- `test_npc_route_cpu_budget18.mjs`: eight 0.25 ms jobs accepted, ninth denied with CPU still available; four 1 ms jobs exhaust 4 ms before slot cap; FIFO and one grant per owner; expensive search exhaustion, next-frame reset, exception cleanup and all five production callers closing their slices.
- `test_npc_route_fairness.mjs`: twelve fixed-order mixed police/residents all receive turns, eight exact door searches finish. An abandoned-head setup now consumes a measured 4 ms instead of assuming two zero-work reservations exhaust the frame.
- `test_npc_route_work_budget.mjs`: two hundred simultaneous expensive requests preserve shared CPU bound and retained frontier.
- `test_npc_wander_first_slice_starvation.mjs`: background jobs cost 0.5 ms each and consume at most eight admissions / 4 ms. Distant first wander obtains a persistent slice at frame 29 versus frame 26 with full cadence; historical missing-frontier mode remains starved for 1,200 frames.
- `test_npc_actual_visit_queue18.mjs`: all 38 requests terminate, 33 physically reach the authored print-shop door in both short-approach baseline and current versions; exact swept paths checked. Peak admissions remain at or below eight. Actual timing is noisy and is not a full-scene performance measurement.
- `test_npc_route_admission_cap_audit18.mjs --contracts-only` and `test_npc_route_admission_v4_10hz18.mjs --contracts-only`: applied max 8 compared with reconstructed historical max 2; all 288 short/mixed/heavy jobs finish under unchanged CPU budget, allowing one final atomic 0.05 ms quantum. Full physical AB/BA measurements were already run by root; audit mode does not overwrite those output reports.

Additional observation: `test_npc_queue_clock_audit18.mjs` retains an older `< 4.3 ms` synthetic wander bound. Current five-point swept wander expands an entire four-neighbor node between deadline checks; at 0.02 ms per point it performs 5.74 ms for the first slice. This is distinct from the slot-cap change and was reported to root for a separate explicit decision, not hidden by claiming every test passed.

Resolved afterward: root applied the separately checked resumable-neighbor patch (`NPC_WANDER_NEIGHBOR_SLICE18.md`). The original queue-clock assertion now passes at 4.10 ms search CPU / 10.10 ms including preparation; its threshold was not relaxed.

No GPU or current game-tab checks were performed. Static navigation cache remains **not applied**, as documented in `NPC_STATIC_QUERY_CACHE18_AUDIT.md`.
