# Extended functional QA31

This new adapter observes exact frozen release57 for1200 seconds after30 seconds
warmup, using ten original residents and twelve staff. It uses the current
scheduler read Lease, immediately registers its own child, bounds that child to
measurement+warmup+120 seconds, and never terminates external/user processes.
The running user's game is preserved. Headless frame timings are descriptive
telemetry only; there is no graphical performance claim.

Small copied QA scripts total55KB. PREPARE.json records each original SHA and the
limited changes:600→1200 duration cap,512→4096 inactivity intervals, new relative
QA inheritance paths, exact release57 source-pin check, disk caps, and actual
measurement duration/physical ticks. No production scripts or game are copied.
All actor/motion/queue/RNG/HP/needs behavior remains ordinary. Gates stay10s of
required-motion inactivity and30s of queue inactivity; phase/retry changes do not
reset physical progress.

Expected ordinary native output is≈22MiB. Historic slow-planner records average
3.1KB each; even12000 such records plus normal telemetry is≈65MiB. Runtime output
is capped at100MiB and disk reserve128MiB, checked every second; before launch at
least256MiB must be free. Existing600 evidence occupied10,640,102 bytes and free
space before preparation was1,244,860,416 bytes. No thick evidence bundle or game
duplicate is created. HARNESS.zip contains only the actual pinned small scripts
and metadata, verified before engine launch.

Run:

```powershell
python -B outputs/coordinator31_npc57/proposals/qa31_extended/run_extended31.py release57_1200_01 --seconds 1200 --warmup 30 --mode headless
```

The final RUN/MASS30/SOAK31/SLOW_PLANNER31 reports retain unchanged gate results,
all per-ID1Hz samples, per-render physical tick counts, exact observed elapsed
time, service/queue states, native memory/objects and OS memory. Failures remain
terminal evidence; no automatic retry is configured. stdout emits live behavior
highlights every30 measured seconds. A finite natural run does not guarantee
every service is selected, and memory growth includes bounded observer records.

Historical qa31_resume evidence and release57 files are never rewritten by this
adapter. F5/Git/production remain root-owned.
