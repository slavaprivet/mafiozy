# Release57 tools — prepared for root review

`freeze57.py`, `startup57.py` and `check_tools57.py` are ready for review. Neither freeze nor startup has been executed. No engine, F5, Git, production source or previous release was changed by this preparation.

## Required evidence

Every run argument is a completed receipt directory, not RUN.json. Required CLI arguments:

| Argument | Required result |
| --- | --- |
| `--soak` | Final V3 ordinary 600-second run; planned `qa31_resume/runs/merged600_02` |
| `--services` | Four physical service cycles on the final merged source, graphical mode |
| `--threat` | Completed actual-city threat cycle on the final merged source |
| `--visual` | Graphical visible-turn cycle on the final merged source, with successful PNG photographs |
| `--perf-baseline` | Exclusive V4 native 1920×1080 baseline release56, at least 90 seconds; planned `baseline56_perf1080_03` |
| `--perf-candidate` | Matched V4 exclusive measurement of the final merged source; planned `merged57_perf1080_03` |
| `--perf-comparison` | The candidate's completed `PERF_COMPARISON.json` |
| `--integration` | `outputs/coordinator31_npc57/INTEGRATION_final02.json`, cumulative seven-file delta plus all 1130 source pins |

The four future service/threat/visual/performance paths are intentionally explicit arguments. An older PASS on merged01 is rejected because its exact source pins differ from the current candidate. The failed `merged600_01` cannot satisfy the gate. Any new implementation change requires evidence for the new exact source.

## Validation and archive behavior

The freeze validator requires clean exit, empty errors/stderr, zero source/harness/control drift during the run, exact registered native child and project/entry, ordinary launch flags, all 287 catalogue entries and the original ten active IDs plus 12 staff. Runtime overlays and seeded/global QA initialization are refused. The service checker uses its exact tested archived Python bytes; its documented local service setup remains permitted.

V3 requires at least 597 observation samples, aligned native frame/sample counts, no errors, per-resident required-motion inactivity at most 10 seconds and queue inactivity at most 30 seconds. `SLOW_PLANNER31.json` must be the read-only V3 schema with matching sample counts and thresholds at most 5 seconds for motion and 15 for queues. Its diagnostic cost is recorded rather than treated as an invented performance threshold.

Performance acceptance recomputes the existing comparison gates from native timings: same camera, 1920×1080, harness, editor environment and timing; all ten moving; p95 within 60 FPS and no material baseline regression or late slowdown. It is scoped to this batch and finite measured interval.

Performance additionally permits the V4 entry and requires `WINDOW31.json` with the native window protocol. RUN must contain the identical receipt, requested resolution and the explicit `--qa-render-resolution=1920x1080` protocol flag. Window.size, DisplayServer window size, root texture, logical viewport, content scale target and both start/final camera sizes must all be 1920×1080, with content scale factor1.0 and matching stable before-measurement/final metadata. A command-line resolution alone cannot pass. The old V3 trial rendering2778×1563 and V4 startup-not-ready trial remain invalid evidence. The final600-second behavioral soak still uses V3, with its exact archived harness; no liveness/FPS threshold has changed.

For each HARNESS pin the validator first reads the run's `HARNESS.zip` or `HARNESS_SOURCES.zip`. It verifies each actual archived byte sequence. Later changes to unrelated or archived live harness files do not invalidate the historical run. For an older run lacking an archived member, the current exact file must still match the tested SHA; otherwise freeze fails. The final EVIDENCE.zip includes all raw run files, comparison/integration, release scripts and recovered tested gd/py/control bytes under `tested_harness/<role>/`. Archive inventory and bytes are verified after writing.

## Execution sequence for root

Use `python -B` and supply all eight evidence arguments. Omitting `--go` validates and prints a plan only. After reviewing a successful plan, root may repeat the same command with `--go`.

Freeze makes one new cache-inclusive copy, excluding shader_cache, after checking free space for the copy, complete evidence and at least 128 MiB reserve. It uses scheduler leases, retains partial failures for inspection and refuses any existing release57 target. Only `scripts/main.gd` revision and `data/preview_updates.json` title/news may differ from the tested game. The news panel contains exactly five short Russian release57 items, replacing the old item list: narrow-doorway passage with walls/doors preserved, false exterior exit and shop queue fix, threat-facing and return to ordinary activity, four services with physical entry/exit, and the active 10 residents plus 12 staff with later batches checked separately. No claim about FPS independence from elapsed time is added. It derives the release bootstrap from frozen56, verifies all other source pins and writes `PROPOSED_CURRENT.json`. It never activates the actual pointer.

After freeze exists, root can review a startup plan:

```powershell
python -B outputs/coordinator31_npc57/proposals/services31_resume/release_tools/startup57.py startup57_01 --mode graphical
```

Add `--go` only when ready to run that exact plan. Startup uses a read lease and a directly registered child with a 150-second watchdog. It terminates only its own child if necessary, saves source/control before-and-after pins and checks exact revision, original roster 10/287, 12 staff, eight new venues, 18 ambient actions and active behavior. Graphical mode also requires the bootstrap screenshot. The bootstrap exits after readiness because `--city-play-check=1` is added. This is a bounded startup check, not the persistent delivery launch or performance acceptance. F5 activation and the persistent ordinary launch remain root's work.

Startup RUN.json exposes `ordinary_ready`, `resident_count`, `staff_count` and `revision` for root's delivery contract. `ordinary_ready` is true only if the complete startup receipt passes. The script never writes release DELIVERY.json; root records the persistent launch/activation and final delivery separately.

## Verification performed

`python -B .../check_tools57.py` passed 16 CPU checks: syntax; exactly five news items with no appended historical list; exact archived harness recovery despite later live edits; invalid SHA, traversal, unpinned entry and seeded flags rejected; real historical service archive/checker accepted; real failed 600-second soak rejected; and six window-protocol validator checks. The latter use synthetic validator inputs explicitly, never acceptance receipts, and reject scaled physical output, wrong logical size, final-window drift, incomplete startup and missing V4 flag. `REVIEW_CHECKS.json` pins the reviewed scripts. Separately, read-only verification confirmed the final integration's 1130 pins, complete seven-file delta against release56 and all three revision/title template anchors. No final successful receipts have been invented; full freeze validation awaits the actual finished runs.
