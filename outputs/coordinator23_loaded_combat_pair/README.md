# Actual loaded combat pair — root owns GPU execution

This outputs-only harness measures the accepted point-only PCK **ec737f864181031e574bc4eb9e179a6d70cf3be6282a6068371b388b25167179** against a future exact combined PCK. It never launches another process automatically or stops/restores the user's game. Root must free the GPU slot, run each side sequentially, inspect the PNGs, and restore the accepted game outside this harness.

The older `coordinator23_corpse_perf/BASELINE_PIN.json` points to pre-point 023070 and is **not** this baseline. The correct baseline is `outputs/artist23_point23e/package/MafioziPreview.pck`.

## Fixed scope and workload

- Actual loaded main, original three residents and eight buildings. NPC walking remains enabled. No masks, shapes, bone transforms, HP, ammo or velocity edits; no disabled player physics, fake impacts, forced sleep or physics freeze. Player-only supported/clear placement happens outside measured phases and is logged.
- 1280×720, TAA, 4×MSAA, medium directional shadows, vsync off. A fixed 45° observer renders the same initial scene anchor throughout both runs. The actual player camera remains attached to its production spring arm; test aim sets its normal yaw/pitch and checks both its ray and the current presented muzzle ray. This is a fixed-view performance fixture, not acceptance of the user-facing camera composition.
- Explicit scripted control ownership renews logical mouse-look each physics tick and supplies real InputMap movement/LMB/RMB events. Production owner/input/pose/ammo/collision guards remain. This permits a normal unfocused window while the user works elsewhere. No topmost, NO_FOCUS, hidden/offscreen window, focus capture or native OS click injection.
- 3 s initial scene warmup; 2.5 s living walk; cold first revolver hit and 1.5 s medical fall; second real hit and 1.5 s final fall; fixed 10 s natural settling; 3 s rest; 2 s actual walking contact/response. Setup and bounded real-sight waits add time. Internal **58 s**, external **63 s** deadline.
- Target is resident_252. Two other residents keep their normal updates. Exactly two accepted inventory rounds/HP transactions are required. Shared source RNG seed selects the first medical survival; it does not set damage/HP/death. The second actual shot finishes the same fallen body. Candidate must show a persistent mark and actual admitted foot impulse. Baseline lacks the port and must report zero foot impulses.
- Natural rest may remain physically awake: sleeping counts, max speeds, kinetic energy and joint error are recorded. No sleep/wake claim is derived from this run. Separate root main07_02 covers sleep/wake acceptance. This is **one corpse plus two living residents**, not three-corpse saturation, all thirteen guns, a positive anatomical-headshot workload, medical getup or RPG blast HP.

## Evidence and measurements

`RESULT.json` includes raw per-render-frame wall cadence, measured viewport GPU/render CPU duration, RAM/VRAM, draw calls and primitives. Process/physics monitors are explicitly coarse values, not exclusive per-frame update timings. Scene object/resource/node and full collider/actor/body/joint snapshots occur at phase edges. Small event records timestamp LMB, accepted shot/ammo/pose, native impact, observed completed HP and accepted foot receipts. `compare.py` retains a first-use window around the first LMB so the mark/blood/activation stall is not hidden in a steady-state percentile. GPU timestamp return can lag the CPU submission; this window does not claim exact exclusive causality.

Snapshots/PNG readback are outside measured loops. `natural_settle` polls only the existing sixteen `sleeping` booleans; no per-frame deep ragdoll snapshot. The full scene still renders/updates all loaded content. Runtime resource creation from the new marks is a measured difference, not removed to make object counts identical.

Side reports require original counts and admitted work, positive measured GPU time and rendered samples. `compare.py` additionally checks harness/settings/fixed-camera/physics-Hz and physical content agreement. It reports p50/p95/max and p95 percentage differences without inventing a performance acceptance threshold. Root should check the exact before/after input trajectories and rendered framing; natural motion/physics need not be numerically identical when accepted foot impulses change the candidate.

## Root commands (one process at a time)

Use `run_capture.py --engine ABS_GODOT_CONSOLE --pack ABS_PCK --expected-sha EXACT_SHA --side baseline --out ABS_OUTPUT --run-gpu` for the accepted baseline; repeat separately with candidate and its reviewed exact SHA. The runner sets `--path` to the pack's directory, avoiding raw-project fallback, and pins the pack/harness/command before launch. It only terminates its own child if the 63 s bound expires. It does not manage the live user process.

For a non-GPU compiled behavior rehearsal replace `--run-gpu` with `--behavior-only`. Such results always have `performance_valid:false` and must not be described as FPS/GPU evidence.

Then run `python compare.py BEFORE/RESULT.json AFTER/RESULT.json OUTPUT_COMPARISON.json`. Root reviews `01_alive.png`, `02_medical.png`, `03_rest.png`, `04_foot_response.png`. Missing/offscreen target or materially different geometry/camera means the visual pair is incomplete even if behavior passes.

The candidate's real root contact binder is used if its sampler is not already installed; no harness force proxy or alternate NPC implementation is substituted. Final candidate head/foot modules still need their own exact compiled closure and behavior gates before this performance pair. The harness cannot turn an unreviewed owner implementation into an accepted one.
