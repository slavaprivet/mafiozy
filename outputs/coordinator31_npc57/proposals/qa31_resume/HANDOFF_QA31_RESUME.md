# QA31 resumed — final functional soak and matched perf gates passed

## Current state, 15 October 2026

Root requested one reverse performance pair after the first pair to investigate
the8% difference. This is now complete with unchanged V4/source/camera/window.
`merged57_perf1080_04` PASS:112.46385FPS/p9515.242/p9916.617ms.
`baseline56_perf1080_04` FAIL for required-motion inactivity25.147s in resident2:
107.49849FPS/p9516.069/p9917.465ms. Both clean exclusive with stderr/drift0.
The reverse pair comparison is therefore FAIL on liveness, with other11 gates
passing. All original03 evidence remains unchanged. Full four-run cost evidence
and limitations: `PERF_FOUR_RUNS31.json`, readable `PERF_FOUR_RUNS31.md`.

The first pair candidate/baseline difference was−8.011%; the reverse is+4.619%.
Candidate repeats vary+6.909%, baseline repeats−5.998%. A reproducible fixed8%
regression is not established, and this does not close the user's FPS complaint.
Physical daily mean costs track the variation:2.575/3.203/2.724/3.300ms in run
order. Process monitor means7.282/7.566/7.292/7.435ms; required-motion actor
fractions72.8/87.1/82.7/86.1%. Natural workload differs substantially.
Passage-only cost is unavailable because the frozen harness did not export it.

Baseline04 resident2 was at[152.5699,−.00024,12.9976], outside TownClone_4's
envelope x127.5..145.5,z−11..11, but entered=true and OUTBOUND following
inbound_blocked_inside before purchase (cash1000). Three exit_blocked/work-limit
retries occurred. Native physical lag0; planner colliders include Cornice39 and
resident6. The21 slow snapshots include full geometry/target/shared budget.
Exact participant2/6 histories and26 transitions are preserved in
`runs/baseline56_perf1080_04/VENUE_1465691215855_TRACE.json`.
This is additional natural baseline evidence matching the fixed false-inside
mechanism, not a candidate failure. No further runs are active or planned by QA.

`merged600_02` is PASS on exact `INTEGRATION_merged02.json` candidate: 600s
measurement after 30s warmup, 599 actor samples, 86,893 frame records and 36,001
physical ticks. All ten residents moved, with twelve staff preserved. Native
stderr and all source/control/harness drift are zero. Maximum required-motion
inactivity is 4.029s, queue inactivity 9.011s; the unchanged gates are 10s/30s.
There are no exit_blocked retries. The two planning-work-limit interruptions
were followed by continued activity. Slow-planner snapshots are zero.

Natural measurement completed 51 purchases and 271 walks. Resident8 completed
a purchase and resumed activity, but no resident naturally selected the old
venue1559777848406 in this run. Therefore this soak does not independently
prove that exact geometry; services' targeted native fixture supplies that
coverage. Restaurant/bank/hospital were not naturally selected either.
The archived exact V3 harness SHA is
`5c1e1599cc803c1ee08f5b3734ca3f2a3e9b79fa448ee56a430d74a00778d176`.

Quarter-median memory changes in final600: RSS +40,960 bytes, private 0,
static +3,272,262 bytes, object count +417; nodes/resources stable, orphans0.
These include bounded observer allocations and do not prove absence of leaks.

Clean matched performance uses V4: `baseline56_perf1080_03` PASS,
114.3578 meanFPS, p95 15.007ms, p99 16.324ms. Candidate
`merged57_perf1080_03` PASS, 105.1962 meanFPS, p95 16.036ms, p99 18.094ms.
Both use 90s measurement after20s warmup, the same frozen harness and exact
baseline camera. PERF_COMPARISON passes all12 unchanged gates. The meanFPS
difference is -8.011%, p95 +6.857%, p99 +10.843%; no acceleration is claimed.
Candidate early/late-third p95 is15.532/16.373ms, baseline14.704/15.299ms.
Both have10/10 moving residents,12staff and clean exclusive scheduler receipts.
Candidate max required inactivity3.032s, queue0, stderr/drift0, with5,401
physical ticks and9,468 rendered frames. No engine test is currently active.

Candidate memory quarter deltas: RSS -716,800 bytes, private -32,768,
static +1,779,535, objects +251.5; nodes/resources stable, orphans0. Baseline:
RSS +36,864, private -28,672, static +1,807,864, objects +336. These small
finite-window changes do not establish a leak or its absence.

V4 forces only the
QA native window/root viewport to 1920x1080 before warmup, then verifies Window,
Display, root texture, logical viewport and content target all match, factor1.
Source/NPC state is unchanged. V4 adds WINDOW31.json; V3 final600 remains valid
against its own immutable archive.

`FINAL_QA31.json` ties the final functional/performance artifacts to their
hashes and confirms both final runs' complete1130 source pins equal
INTEGRATION_merged02. Final performance/release acceptance remains with root.

Earlier `baseline56_perf1080_01` remains FAIL: actual texture2778x1563 despite
the CLI request. `_02` remains FAIL: fixed actual dimensions but a readiness
type-comparison guard timed out before measurement. Neither is accepted as
1080 evidence. Their original harness ZIPs and native reports are preserved.

All sections below describe historical states, not the current handoff.

## Latest result: merged600_01 FAIL

Exact merged6-file INTEGRATION_merged01 sources were observed for600 seconds
after30s warmup. The1130 source pins matched the integration receipt before
launch; after-run source/control/harness drift0, stderr0. There are598 native
one-second samples,86,821 frame samples and36,000 physics steps (60Hz).

At venue1559777848406, resident_8 marked leaving with
`inbound_blocked_inside` before purchase (cash1000, serial1), then stood at
`[18.2766418457031,0.000591035699471831,203.823150634766]` in OUTBOUND/door approach
for263.95s. Forty `exit_blocked` log lines record planning-budget retries.
Residents3/4/5 waited at that venue's portal for141.365/270.962/260.921s.
The threat owner remainedIDLE. Actual per-ID physics lag was0 at the terminal
stall, so this is not evidence that the physical dispatcher stopped ticking.

A separate threshold failure occurred for resident_1 at venue1511056810615:
10.048s during SERVICE_APPROACH, searching with476,604us accumulated planning.
That resident subsequently moved. Do not present it as the persistent8 stall.

`runs/merged600_01/VENUE_1559777848406_TRACE.json` preserves exact native histories
for all six venue participants and402 state transitions. `SOAK31.json` retains
every actor; `ANALYSIS.json` contains maxima, phase/queue states and memory.
Planner collider/target/leg and venue geometry were not instrumented; no values
are inferred. Services agent was notified and is testing a false-inside doorway
plane hypothesis in an isolated fixture. Running source was never changed.

Natural activity completed35 purchases and232 walks; bank/food/hospital were not
selected. Memory quarter medians: RSS−14,602,240 bytes, private0, static+3,514,092
bytes, objects+364; nodes/resources steady, orphans0. This remains finite-window
telemetry with bounded observer allocations, not a leak diagnosis.

The read lease is released. Root explicitly deferred perf until the service fix.
No performance acceptance is claimed. All older evidence below is preserved.

Only `outputs/coordinator31_npc57/proposals/qa31_resume` was written. No game
source, frozen release, F5, project control, Git, or user process was changed.
The runner uses current pinned scheduler read leases, exact source/controls and
owned-child cleanup. No full project copy was created.

## Completed evidence

- `runs/native_smoke01`: V1 native load succeeded, stderr0/drift0,5 samples and
 726 aligned frames. Only9/10 moved in the5-second window; overall gate correctly
 failed. This is retained evidence, never relabeled PASS.
- `runs/baseline180_01`: PASS, exact unmodified game57 baseline (see1129 source
 pins),180 measured seconds after15s warmup,10/10 residents moving,12 staff.
 26,070 rendered frames and10,800 physics steps, exactly60 physics Hz. Native
 stderr0, source/control/harness drift0. This was functional headless, so it
 establishes no graphical-performance acceptance.
- `runs/native_v2_smoke01`: PASS on exact frozen release56,5 samples and726
 aligned frames,10/10 movement, stderr0/drift0. The added threat fields parse and
 run; no threat encounter was forced, so behavior coverage remains separate.

Baseline180 maximum required-motion inactivity4.022s, queue inactivity1.0s.
Longest raw stationary interval27.124s belonged to resident_7 in RESTING, with
no route, queue or attention. Raw stillness is preserved. Eight natural shopping
cycles and63 walks completed during measurement. Bank, restaurant and hospital
were not selected in the observed window. No exit_blocked/retry log lines arose;
this short ordinary window cannot refute the263 historical blocked exits.

Baseline180 first-to-last quarter median trends: RSS+532,480 bytes, private
+434,176 bytes, native static+3,124,208 bytes and objects+323. Nodes/resources
were steady; orphans0. Observer records and ordinary activity contribute bounded
allocations. This is descriptive finite-window evidence, not a leak diagnosis.

## Current runner

Use `run_soak31_v2.py`, `entry_soak31_v2.gd`, `observer_soak31_v2.gd` together.
V1 files and native evidence remain intact. V2 adds threat phase/age/quiet,
observed contiguous RECOVER duration, physics lag and raw-stillness live flags.
FLEE is required motion; the existing PHONE call animation is stationary4s.

`analyze_soak31.py` creates derived ANALYSIS.json with per-ID summaries and
evidence hashes. `compare_perf31.py` compares completed exclusive pairs and
retains final acceptance for root. Detailed commands are in README.md.

## Pending root integration

Root plans a corrected merged600s+30s warmup after the real stall fix. The initial
merged600 already failed as described above. After functional success, clean
1920x1080 baseline56/candidate57 pair90s+20s warmup with exact baseline camera.
Run perf only after probe eligibility; preserve any reopened user game.
Root has deferred additional1280x720 pair if1080 passes. No new run is active.
