# S01 OFF/ON/ON/OFF protocol — prepared 26 September 2026

Harness: `tools/godot/preview_perf_qa.gd`.
SHA-256: `618acfad44ae2383ff9acf52dbdc79b1c5f4992a92ad97da6e520dd77ef4c125`.

Only the coordinator launches the native run after arranging a sequential
replacement of the current single game. This author ran **headless protocol
selftests only**. PID 43332 / session 9305 were not touched. No production file,
existing motion QA, export or renderer setting was changed by this work.

## Run modes

Headless protocol verification (actual main scene/player/adapter, shortened
windows; never LIVE/performance acceptance):

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:/Users/Слава/Desktop/Мафиози/godot/mafiozi_walk' --script 'C:/Users/Слава/Desktop/Мафиози/tools/godot/preview_perf_qa.gd' -- --protocol-selftest
```

**Observed release-template limitation:** the Windows review05 release EXE
ignores external `--script`: it starts its default main scene instead. Root
observed nonterminating headless default-main processes and stopped those exact
processes. Do **not** invoke this harness or claim its results through that
release EXE. This supersedes the original proposed release command.

Root verified that the console **engine** with `--main-pack <exported.pck>` and
the absolute external `--script` actually runs the requested smoke harness.
For the coordinator's native harness run, use that engine/main-pack combination,
omit `--headless` and `--protocol-selftest`, and first validate its headless
protocol mode. This measures a **debug engine with exported content**, not a
release executable benchmark. Native release gameplay must be observed
separately. Do not start a second game alongside the existing visible game.

Optional user arguments after `--`:

- `--perf-output-dir=<absolute directory>`; default
  `outputs/godot_perf_qa` relative to the source project. Supply an explicit
  absolute directory for exported runs whose resource base may differ.
- `--perf-capture-after=<absolute PNG file>` captures the viewport **after all
  four windows, collector worker drain and per-window reporting**. The parent
  directory must already exist. No screenshot is taken without this option.
  Headless selftest records a skipped capture and creates no PNG.

Native finish, including failure, releases scripted inputs and leaves that same
game interactive. No automatic quit, physics shutdown or scene teardown occurs.
Headless finish returns exit 0 only for four completed windows, successful
protocol checks and saved final output. Rejected headless invocations exit 1.
`--fixed-fps`, `--preview-capture`, pre-enabled `--preview-perf`, time scale other
than 1 or physics other than 60 Hz are refused rather than silently overridden.
Do not touch keyboard, mouse or controller during native windows: a device
event or lost window focus invalidates the measurement and releases inputs.

## Reproducible scene and route

The actual `main.tscn` loads first, with the default-OFF `main.preview_perf`.
No alternate geometry or synthetic player is used. At the existing settled
spawn, a read-only scan considers forward/right/left/back relative to the
current camera yaw. The first accepted straight corridor has:

- 13 m of source-map dry cells, rejecting water, out-of-crop and nonsolid cells;
- physical floor within 0.1 m of initial feet height and floor normal dot UP
  at least 0.98, sampled every 0.25 m;
- the **actual** `PlayerCapsule` shape, overlap queries and continuous capsule
  sweeps through each segment, plus a 1.5 m upward sweep for jump headroom.

No corridor means failure before any measured route. No teleport is used to
find a more convenient corridor. Reset to the original accepted transform is
allowed only between windows. Velocity, initial heading/camera yaw/pitch and
pose lifetime are reset there, then the body must settle for 12 physics frames.
Every window gets a fresh full **5 seconds of wall-clock warmup** after setup.
The collector's ON allocation/begin happens before that warmup. Any previous
worker is consumed before the next reset/warmup.

The four assignments are exactly **OFF, ON, ON, OFF**. A driver with physics
priority −100 sends real `Input.action_press/release` before the existing
player's physics tick. Native route, fixed at 60 Hz:

| Physics tick | Action |
| --- | --- |
| 0–29 | Idle |
| 30 | Press selected movement direction |
| 120 | Press run |
| 180 | Release movement and run |
| 210 | Grounded jump press |
| 211 | Jump release |
| 600 | End window after final observed process callback |

Actual ground loss before the scheduled jump, falling below the dry floor,
failed ascent/landing, peak under 1 m or incomplete route invalidates the run.
Endpoint and observed jump height must match the first window within 2 cm.
Headless selftest uses 0.25-second warmups and ticks 6/21/33/42/43/150, retaining
all four modes, real motion/jump/landing and the same safety checks. These
shortened windows test protocol correctness, not performance.

Renderer, viewport, anti-aliasing/scaling, vsync, cap, physics rate, time scale,
camera yaw/pitch/FOV/near/far/distance, scene counts, printshop state and current
population must match at all boundaries. Focus is retained per measured frame;
native unfocused frames fail rather than being removed. Source SHA-256 values
are saved at start/end and must stay unchanged. Hash entries are null when an
exported resource source is unavailable; the coordinator must retain the build
manifest/PCK receipt rather than treat null as a verified source hash.

Current population is explicitly **0 NPC and 0 vehicles** in the small main
preview. This is not a full-city test. Future dynamic populations require a
new reproducible scenario/reset contract; this harness must not be reused to
claim equivalent crowded scenes merely by changing those metadata labels.

## Measurement and observer cost

An independent observer runs with process priority +100 in **every** window.
It reads the same wall clock, physics tick, player position, floor/focus bits
and safety state whether the production collector is OFF or ON. The first
callback anchors time; a partial initial frame is excluded. Every subsequent
full callback interval, including stalls, is retained without clamping.

Raw arrays are preallocated before warmup to 60,000 rows. Reaching capacity
fails closed without overwriting an old row. ON production capture has the
same 60,000 capacity and 32 event slots; retained/overwritten counts are checked
after finish, and exactly five scheduled input markers must remain. OFF
production adapter must report both `is_processing=false` and
`is_capturing=false` on every observed frame. It has no process callbacks.
No OFF samples are sent into the production collector.

No harness JSON, report, sort, file access, screenshot, scene scan, console
output or worker launch runs within the measured interval. The bounded
independent observer and input driver themselves have cost in **both** modes;
these are instrumented wall-loop intervals, not an uninstrumented game FPS
measurement. ON additionally includes the intended production timestamp
callback and five event-marker calls. There is no claimed 4 ms wall budget,
GPU duration, presentation latency or enforced FPS result.

Use independent window traces for all OFF/ON percentiles. Collector and
observer execute at different intra-frame positions: collector raw reports
can include extra boundary intervals after warmup/before finish. They must
not be assumed to have identical timestamp endpoints/sample counts. This
boundary distinction is retained in the output. Last-frame render draw-call
and primitive counters are sampled only after windows; they can lag and are
not whole-run peaks. Unique triangles and GPU frame time remain null.

## Post-window operations and output schema

After measurement ends, inputs are released and the ON adapter invokes
`finish_capture_json_async()`. Its main-thread **finish/report/dispatch** cost
is recorded separately. The already-running worker is polled without a spin
loop, then its completed result is consumed and the queue checked empty.
`worker_ready_observed_wait_us` is wall polling latency, including scheduling
and frame pacing; it is **not** exact worker serialization CPU time.

Independent report/sort time, JSON encoding time and file flush/rename time
are measured separately outside the windows. Each window file is written to
a same-directory `.tmp`, flushed, closed, then renamed. A final result file
lists all window paths and file-operation timings. Unique UTC/PID names avoid
replacing previous run outputs. The final file's own encoding/IO timings are
shown in the single completion console record, since they cannot be embedded
inside the file before that operation completes. Interrupted writes may leave
a `.tmp`; such a file is not a completed result.

Schema `mafiozi.s01.perf-off-on-on-off/v1`:

- `<run>-result.json`: mode/status, source receipts, clearance, engine,
  population, four window summaries/paths, checks/errors, optional capture.
- `<run>-window-N.json`: metadata start/end, warmup and route schedule/results,
  independent raw timestamps/intervals/physics ticks/positions/floor-focus
  flags/event times, nearest-rank p50/p95/p99 and count of intervals >50 ms;
  ON also contains the full production collector report and deferred timings.

Both `live_acceptance` and `performance_acceptance` are always false. Native
successful status is `measurement_completed_review_required`; selftest status
is `protocol_selftest_completed`. The coordinator must compare both ON windows
with both OFF windows, including OFF-to-OFF drift, raw spike locations and
metadata. No automatic threshold converts protocol completion into acceptance.

## Actual verification

Godot `4.7.2.stable.official.ed1daf0bf`, headless, current actual main with
printshop `ready`:

- Final harness run: **20 protocol checks, four windows, zero errors, exit 0**.
  Result: `outputs/godot_perf_qa/2026-09-26T20-41-37-28032-result.json`.
  Includes the optional capture argument: correctly skipped under headless.
- Previous equivalent positive run recorded 362/361/363/362 independent
  intervals; both ON windows retained all samples, zero overwritten records,
  exactly five markers. All four actual routes completed 150 physics ticks and
  observed physical ascent/landing. These counts are execution evidence, not
  performance scores; individual runs may have different process counts.
- Embedded tests: bounded two-slot trace accepts two rows then refuses a third
  without changing its first row; independent nearest-rank percentiles; full
  route completion; same endpoint/jump height; collector events/capacity;
  OFF/drained state before each next reset/warmup; unchanged source hashes.
- Negative invocation with `--protocol-selftest --fixed-fps=60`: rejected
  before scene launch, zero windows, exit 1; no synthetic-clock acceptance.

**Remaining:** coordinator engine/main-pack headless harness check, one native
five-second-warmup debug-engine/exported-content run in the sole visible game,
separate native release gameplay observation, visual motion/contact review,
source/build provenance review and interpretation of actual wall traces.
Производительность общей сцены не проверена этим headless selftest.
