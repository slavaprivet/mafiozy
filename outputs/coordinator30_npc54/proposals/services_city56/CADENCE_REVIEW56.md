# Independent read-only cadence review — 15 October 2026

No engine was started; no shared/frozen source was edited. User then changed the
rollout to measured batches of 10, so this note records the completed diagnosis.

## Confirmed multiplier, including a GPU-free run

`cpu_perf56/runs/stage1_287_01/MASS30.json` reports 167 process frames over the
40s measurement, p50 **260.226ms**, p95 310.150ms. The measured first/last sampled
physics-frame difference over wall time gives **16.66246 physics ticks/s**.
167/40 = 4.175 process frames/s; their ratio is **3.991 physics ticks per process
frame**. Every render counter is zero (headless). The median NPC step is
54.169ms, approximately **216.676ms for four NPC steps alone**. The monitor's
median physics-step cost is 72.912ms and process-only cost is 8.8015ms.
These separately sampled medians must not be summed as an exact same-frame
decomposition, but they decisively establish the repeated-physics multiplier.

The instrumented headless baseline likewise has 62 frames/20s, p50 330.413ms,
11.97479 observed physics Hz, zero draw calls, 62.189ms median NPC step. This
earlier source includes instrumentation and differs from stage1; it is supporting
cadence evidence, not a clean optimization A/B.

The completed stage1 aggregate bucket means are daily38.481ms, resident host
5.958ms, health4.093ms, effects1.248ms, navigation0.106ms **per NPC step**, not
per rendered frame. They cover the recorded startup-ready period, including
warmup, so the p50 measured frame is not a direct sum of these bucket means.

## Source chain matching the runtime pins

The following current sources match both stage1/stage2 source pins:

- `project.godot` SHA `5e45528ade62ce0cb89aa53aa7f7d3e5f18aa1574c2555ae37cd5a972ae8bedf`:
  no physics tick/interpolation override; Forward+, MSAA enum2, TAA enabled,
  directional shadow filter enum3. These render settings cannot explain the
  headless 260ms frame.
- `scripts/main.gd` SHA `ee6f7eeff3fe946e680382d99b08e8a7b2046cf7e381c2ac17a80bd8130fa9ea`:
  `_dsh_physics_catchup` around line144 sets max catch-up **4**. `_dsh_apply_loadcap`
  around line832 caps at1 only before `city_ready`, then restores4. With launch
  `city-sim-stride=1` and `city-sim-one-per-frame=0`, `_physics_process` around
  line877 calls the complete `preview_population.step(delta)` every substep.
- Stage2 log confirms `DSH_WALKCHEAP catchup=4` and
  `DSH_LOADCAP cap=1 engine_default=4 city_ready=false`.

`TIME_PHYSICS_PROCESS` is a physics-frame monitor, not the wall interval between
rendered frames. Engine catch-up explicitly permits several physics steps per
render. The official Engine documentation also explains that saturation slows
simulation; this is not corrected by multiplying arbitrary actor deltas.
Sources: [Engine](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-max-physics-steps-per-frame),
[Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html).

## Remaining cost and limits

Stage2 rendered run has **no MASS30.json**. It was correctly stopped on the
`npc_simple_hospital.gd:538` missing `waiting` key. Rendered baseline55 was
stopped as `PERF_CONTAMINATED`. Their 3FPS observations cannot support an exact
GPU/render decomposition; do not invent the missing residual or report PASS.

The source still requests far-pose-cap512 in root's `run_city56.py` through old
ordinary53a flags, whereas Visual56's native default is48. It does not restore
the old physical-motion LOD bypass, but removes the hard cap when many far poses
become due together. Use matched explicit flags for each future pair.

69,780 nodes / ~158k objects are recorded in headless city samples, and source
model audit identified3,174 original MeshInstances /8,036 bones across287.
These counts make native transform/physics/render submission plausible residuals,
but no per-node or GPU timing exists in these interrupted rendered runs. Main's
ordinary process is a short water update, HUD positioning, and once-per-second
600-item percentile sort; it does not itself contain a 287-body daily loop.
Staff and lamp/sky callbacks cannot be called the dominant residual without
measured evidence. Current main uses100m sun shadow distance; the scene's renderer
cost must be measured after the CPU cadence is stable.

## Checkable correction, now through batches of10

1. Fix the waiting-key exception, then compare10→20→30 residents using the same
   camera, sources, staff12, flags and duration. Record both wall FPS and observed
   physics Hz. Stop at a measured failure; do not revive the287 run.
2. Add `physics_frames_since_previous_process` and `get_process_frames` to the
   observer, plus current Engine cap/tick rate. This measures the multiplier
   directly, including headless where `get_frames_drawn()` is0.
3. The existing `--city-physics-catchup=1` is a zero-code **diagnostic/temporary
   latency experiment**; compare it to4 at the same supported batch. It must not
   be advertised as restored real-time simulation. Track physicsHz/60 and native
   displacement per wall second, service timeout/dwell and input response.
4. Do not enable one-per-frame/stride scaling or globally lower tick rate as an
   unverified fix. The city clamps combined delta to.0499 and some owners reject
   delta>.05. A30Hz experiment would still be overloaded if a step costs50ms;
   the sustainable requirement at60Hz remains under16.67ms for all physics work.
5. Once supported batch CPU timing is below budget, measure actual render CPU/GPU
   using `RenderingServer.viewport_set_measure_render_time` plus
   `viewport_get_measured_render_time_cpu/gpu`, same view, and draw/primitives.
   Neither `TIME_PROCESS` alone nor a frame-minus-separately-sampled-median is a
   trustworthy GPU number. No such measurement has been run by this agent.

Services harness will now default to10 and refuse287. No cadence patch was
applied, and no full-population acceptance is claimed.
