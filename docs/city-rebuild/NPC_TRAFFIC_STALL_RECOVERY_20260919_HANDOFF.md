# Traffic stall recovery — 19 September 2026

Owner: Artist17 / traffic_finish. Scope is limited to the civilian trip helper, its exact world marker, diagnostics and a CPU regression. No road-worker edits, new traffic features, increased cap or GPU sessions.

## Confirmed defect

Coordinator LIVE snapshot at source time 815717ms showed 16/16 occupied trip slots: ten planning and six drive. Several cars had essentially zero movement after over nine minutes, while three other cars really travelled 20–213m. The helper repeatedly replanned a blocked swept move after 1.5s (static) or 12s (vehicle/pedestrian), preserving the same destination and keeping the registry slot indefinitely. There was no lifetime physical-progress check. The shared planning queue itself serviced all pending cars in a controlled sixteen-trip reproduction; the text `shared-plan-budget` alone does not prove starvation.

The initial collision reason for the particular LIVE cars is not yet established. This patch fixes unbounded slot retention rather than claiming every original blocker is solved.

## Change

Each original trip tracks actual position progress. Walking/boarding tracks the resident; a seated driver tracks the car, so rotating the seated pose or changing drive→planning→drive does not fake movement. Genuine movement over 0.04 source tiles renews the clock. Sixty seconds with no progress before boarding, or ninety seconds while riding, starts recovery.

An unboarded resident releases the failed trip and returns to normal resident planning. A boarded resident stops the car and uses the existing physical door-exit path; the trip only releases after the resident really exits. If the doorway is blocked, the resident stays safely inside and retries the physical exit. This case deliberately retains its slot until there is an actual exit; no collision bypass, replacement driver or teleport is introduced. The failed goal is excluded for that resident for five minutes (bounded eight-entry history), and that car receives a two-minute retry cooldown. Other residents and progressing trips are unaffected; cap16 and planner budgets are unchanged.

`dataset.civilianTrip.active` now exposes `noProgressMs`, `blockReason`, `driverNotReady`, `roadWaitReason` and `recovering` per trip. Detailed opt-in driving diagnostics have the same blocker distinctions, allowing the next LIVE snapshot to distinguish geometry, driver presentation and signal waits.

## Checks

- `test_civilian_trip_stall_recovery.mjs`: 288 original residents, sixteen trips, eight pending route jobs, four physically blocked drivers and four continuing long drives. The prior code keeps all sixteen slots after110s. The fixed code has five at95s (four moving plus one occupied blocked doorway), then four after the last doorway becomes clear at100s and the resident physically exits. No blocked car moves. All eight pending original cars receive planning work. Failed residents retain identity and avoid the former task. Controlled full-loop CPU p50/p95 before 0.899/1.174ms, after 0.926/1.237ms in the final run; isolated CPU, not scene FPS.
- `test_native_parking_lifecycle.mjs --long --async`: actual worker/road graph/static bodies/vehicle and dynamic source blocker, **895.97m drive**, six-second obstruction wait, physical exit and actual hospital visit/exit still PASS (6926frames). A legitimate long journey does not trigger recovery. Latest CPU lifecycle p50/p95/max 0.0795/0.2035/7.188ms; timings vary with host load and are not a GPU or full-world benchmark.
- Native trip contracts, interdistrict policy/cooldowns/worker lease tests and all world inline syntax/melee checks pass.

Production source and world marker are synchronized and stable for the coordinator's combined reload. Remaining work: use the added LIVE diagnostics to identify the original sweep/driver/signal reason for the formerly immobile cars. A persistent physically blocked exit is still a real obstruction and is not hidden by these tests.
