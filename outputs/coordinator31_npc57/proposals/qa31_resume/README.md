# QA31 resumed observer

Current functional evidence is `runs/merged600_02` PASS on merged02, using the
immutable V3 harness archive. Current performance adapter is V4; the matched
pair is `baseline56_perf1080_03` and `merged57_perf1080_03`, 90s/20s: both PASS,
with all12 comparison gates PASS. FINAL_QA31.json provides the complete final
handoff, exact source-match verification and explicit coverage limitations.
Root also requested one reverse repeat: candidate04 PASS, baseline04 FAIL for
a25.147s resident2 OUTBOUND stall. This new evidence is in PERF_FOUR_RUNS31.json
and PERF_FOUR_RUNS31.md, with all four timing/cost/workload distributions.
The original03 pair is preserved; reverse04 is not relabeled PASS.
V4 stabilizes an actual native 1920x1080 root viewport before warmup and records
all physical/logical sizes in WINDOW31.json. It changes QA presentation only.
Always keep paired cameras and archived harness pins identical. Historical
V1/V2/V3 runs and failed sizing attempts are retained, never relabeled.

All V3/V4 launches archive and verify exact harness source files in HARNESS.zip
before starting the engine; HARNESS_ARCHIVE.json records its SHA. Slow route
diagnostics are read-only and appear in SLOW_PLANNER31.json after 5s of required
motion inactivity or15s of queue inactivity. The liveness gates remain10s/30s.

This is a new adapter. Historical qa31 and batch56 files remain unchanged.
Only this directory is owned by QA. The runner reads the shared game under a
scheduler read lease and creates no full game copy. It never stops user processes.

Native smoke uses the real city, not a mock. Five seconds only validates script
loading, the telemetry and the frame alignment; the ten-resident movement gate
may legitimately fail in such a short window.

```powershell
python -B outputs/coordinator31_npc57/proposals/qa31_resume/run_soak31.py baseline180_01 --seconds 180 --warmup 15 --mode headless
python -B outputs/coordinator31_npc57/proposals/qa31_resume/analyze_soak31.py outputs/coordinator31_npc57/proposals/qa31_resume/runs/baseline180_01
```

After root integrates services and attention into the shared candidate, choose
a new unused run name and use `--seconds 600 --warmup 30 --mode headless`.
Allow roughly 40 additional seconds for native startup. At most 600 seconds of
measurement are supported by the inherited fixed-capacity observer.

`--project <absolute-project-path>` can select another imported city. No import or
source mutation is performed. `--mode graphical` uses the single functional
graphical scheduler slot. `--mode perf` probes eligibility before obtaining a
lease and refuses to wait on a user game. Headless or shared functional timing
never establishes clean rendered FPS.

Run outputs:

- `RUN.json`, `SOURCE*.json`, `CONTROL_PINS*.json`, `HARNESS.json`: verified child,
  pinned complete source/harness/engine, drift checks and gates.
- `SOAK31.json`: all original IDs and life generations; one-second positions,
  real route/queue/door state, 10cm-anchor inactivity, maxima, bounded intervals,
  and physics ticks aligned with the inherited frame samples.
- `MASS30.json`: composition, original IDs, travel, raw frame timing, native
  objects/memory/navigation and fixed camera.
- `OS_MEMORY.json`: real child RSS/private memory at approximately 1Hz.
- `ANALYSIS.json`: derived per-ID behavior, completion deltas, memory quarters,
  physics/render distribution, evidence hashes and explicit limitations.
- `stdout.log`: `SOAK31_LIVE` highlights every30 measurement seconds, including
  any required-motion inactivity over5s or queue inactivity over10s.

Default diagnostic liveness gates are required-motion inactivity <=10s and queue
inactivity <=30s per ID/generation. Retry/phase changes do not reset the position
anchor. Raw stillness remains visible even during legitimate activities or player
attention. These are diagnostic gates, not previously approved product limits.

Natural RNG is retained and no actor positions, routes, needs, HP, queues or
states are written. A finite run does not guarantee all four services are
selected or opposing portal traffic occurs; targeted fixtures complement it.
Observer memory is bounded but recorded intervals and inherited samples still
contribute allocations. Memory trends alone are not a leak diagnosis.

## V2 and matched performance preparation

V1 files and baseline180_01 pins remain unchanged. V2 adds threat phase, quiet
deadline and remaining time, phase age, observed contiguous RECOVER duration,
per-ID physics lag, and raw-stillness highlights. FLEE requires motion; PHONE
is the existing four-second stationary call animation. ALERT/RECOVER raw holds
remain recorded rather than excluded from evidence.

The following runs are prepared but must be started after root finishes source
integration. Each perf invocation probes first and refuses a user-game conflict.
Use matching90s measurement /20s warmup, both with ten original residents and
twelve staff. V2 native smoke on exact release56 completed successfully in
`runs/native_v2_smoke01`: source/control drift0, stderr0, ten residents moved,
five complete samples and726 aligned frame/physics entries. This short smoke
does not establish long-run behavior or threat encounter coverage.

```powershell
python -B outputs/coordinator31_npc57/proposals/qa31_resume/run_soak31_v2.py baseline56_perf1080_01 --project outputs/coordinator30_release56/game --seconds 90 --warmup 20 --mode perf --resolution 1920x1080
python -B outputs/coordinator31_npc57/proposals/qa31_resume/run_soak31_v2.py merged57_perf1080_01 --seconds 90 --warmup 20 --mode perf --resolution 1920x1080 --fixed-camera-from outputs/coordinator31_npc57/proposals/qa31_resume/runs/baseline56_perf1080_01/MASS30.json
python -B outputs/coordinator31_npc57/proposals/qa31_resume/compare_perf31.py outputs/coordinator31_npc57/proposals/qa31_resume/runs/baseline56_perf1080_01 outputs/coordinator31_npc57/proposals/qa31_resume/runs/merged57_perf1080_01
```

Optional720 follow-up uses new names ending `perf720_01` and
`--resolution 1280x720`, selecting the720 baseline MASS30 camera. Root currently
requests only the1080 pair if it passes. Analyze each run with `analyze_soak31.py`.
The comparison verifies both exclusive receipts, full camera/viewport, harness,
editor environment, count/content, relative frame regression, 60fps budget and
early-to-late behavior. It never grants final performance acceptance by itself.
