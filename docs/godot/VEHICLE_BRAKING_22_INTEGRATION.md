# Braking22 — native integration and single-window acceptance

29 September 2026, Coordinator22. Current source body and visible build use exact
`ae4d67e7f931e33e3cf65404af665579498986cb307418a45989dba5e0dfe5d5`.
Physics owner confirmed the frozen candidate and kept the shared body unchanged
until root adoption. Previous body was `a3825379…`.

## Behavior

Handbrake and service braking suppress propulsion, including W held together with
Space. Opposite pedal first applies service braking and then changes direction.
Rear handbrake uses separate longitudinal/lateral traction limits. Wheel support
rejects vertical walls; source planar coasting applies on support. Unsupported
vehicles no longer lose linear momentum through the former all-axis damping.
Existing 3D suspension/steering and IDs/lifetimes remain; this is not numerical
2D source trajectory parity. Surface coefficients/crash authority are still open.

## Verification and cost

- Candidate30 + independent107 PASS; independent actual-main injection15 PASS.
- Adopted production: body131, twelve profiles138, visual25, signed steering8
  scenarios, actual main boarding/driving/exit14 PASS. New production braking
  regression33 PASS; isolated reintroduction of old defects caused6 failures.
- Callback microbenchmark, four alternating epochs: ground p50 increased about
  8–15 microseconds; airborne about1.5 microseconds. This extra work is disclosed,
  not presented as an optimization. See outputs/coordinator22_braking_review.
- Existing root player pose receipt33/writer346/physical handoff20/practice21
  passed before this integration. That late21 player writer is included in BOTH
  comparison builds, so it is not a hidden baseline difference.

## Immutable exports and actual GPU scenario

Baseline PCK: `exports/win64/s01-20260929-braking22-baseline/MafioziPreview.pck`,
SHA `9fcde74fb4860deb5ff4b20799399b201b46a4f604e10da3ba75636d2c0a867e`.
After PCK: `exports/win64/s01-20260929-braking22/MafioziPreview.pck`,
SHA `14a1e0de4fac67034e27670bdaa9860b7c075bb60d09c81a2d7bb03c5d8f4236`.
Only source inputs differing: native body, main revision, update notes. Export
inputs remained stable, dependency/inventory checks and after actual-main smoke PASS.

The exact frozen helper in VEHICLE_BRAKING_LIVEQA.md ran both real PCKs sequentially.
No concurrent GPU game, no fixed-fps native override, no injected velocity/pose.
External launch.json records actual --main-pack, build receipt and source inputs;
compiled script byte hashes are unavailable, so whole-pack stability is used.
Both runs passed, cancelled=false, zero engine errors, and restored a fresh main.
Current single interactive game PID43120 is the AFTER pack, responding.

Physical E boards from original spawn, W1.5s, W+Space3.2s, releaseSpace+.6s.
Baseline brake entry5.042m/s, end3.001m/s, stopped=false. After entry8.999m/s,
end0.039m/s, final-quarter-second max0.056m/s, stopped=true; release→3.565m/s.
These identical input sequences produce different entry speeds, so stopping
distances are not an equal-initial-speed comparison. No chassis obstacle collision
occurred during acceleration/braking; wall collision did not impersonate stopping.
Separate fresh-spawn episode: W2s→E→actual articulated fall→GETTING_UP→ON_FOOT,
driver released and grounded. After exit entry12.044m/s; baseline5.738m/s.

Root visually reviewed seated, brake episode end, mid-fall and recovered PNGs.
The visible update panel describes the running braking22 revision. No NPC, HP,
debris, tyre marks or extra combat target capability is claimed by this build.

## Comparable loaded-quarter measurements

GTX980, Forward+,1280×720,144Hz cap, same original camera/settings,8buildings,
1vehicle,0NPC. Same warmup/input/scenario; changed physics causes different paths.
Readback/PNG plus3following frames excluded; process memory sampled outside phases.

| Phase | Baseline frame p50/p95 ms | After frame p50/p95 ms |
| --- | ---: | ---: |
| Acceleration | 6.989 /8.161 | 6.858 /8.182 |
| W+Space | 6.951 /8.290 | 6.920 /8.191 |
| Reacceleration | 6.868 /8.183 | 6.927 /8.087 |
| Moving exit /recovery | 6.973 /9.712 | 6.963 /9.447 |
| Recovered | 6.940 /8.121 | 6.989 /8.095 |

Brake draw-call p95:577→576; primitive p95:320136→320112 (renderer primitives,
not asserted exact triangles). Process working set before scene339947520→340365312
bytes; after two episodes649027584→633405440. No memory improvement claim from
two short samples, no long-session leak guarantee. These results show no material
regression in this measured quarter, NOT full-city/crowd performance.

Evidence: outputs/coordinator22_braking_liveqa/{baseline-native,after-native}/
report.json, launch.json, engine.log and reviewed PNGs. User play is restored;
all owners received CPU RELEASED after the measurement window.

## Clean checkpoint closure

Root exported the scoped Git index into a fresh directory with no shared WIP or
Godot cache. Cold headless import exited0; production braking33, pose receipt33,
actual-main melee21 and physical transport cycle14 passed. The melee test uses
real time: its first invocation with fixed-fps60 failed four timer assertions
because that mode advances simulation faster than its original wall clock.
The ordinary-time rerun passed without code changes. Both logs are retained in
outputs/coordinator22_braking_checkpoint. Physics-only braking uses fixed-fps60.
The current native extension proposals are absent from this checkpoint.
