# GPU pair 01 — rollout HOLD for first-hit stall

Exact compiled baseline `ec737f864181031e574bc4eb9e179a6d70cf3be6282a6068371b388b25167179`; candidate `710f2d40d852c4181d874494294ef236e6bc2d215ab216b4c016ad92e82c3c72`. Same capture `3b1d5f3f…`, normal visible 1280×720 Forward+ / TAA / 4×MSAA on GTX 980. Root ran sequentially and restored the accepted game. This review launched no engine.

Both behavior results pass and the geometric/camera comparator is comparable. **That does not constitute performance acceptance.** Candidate has a **961.367 ms** first-hit rendered-frame gap versus **8.230 ms** baseline. Candidate also has a following **24.035 ms** gap. These are visible stalls independent of whether the target is 60 Hz or 144 Hz.

| Measured phase | Baseline wall p95 / max ms | Candidate wall p95 / max ms | Candidate GPU p95 ms |
|---|---:|---:|---:|
| Three living residents, player walking | 3.776 / 6.237 | 3.287 / 5.842 | 2.376 |
| First hit / medical fall | 3.957 / 8.230 | 3.804 / **961.367** | 2.418 |
| Second hit / final fall | 4.365 / 6.013 | 4.141 / 9.234 | 2.400 |
| Natural settling | 4.161 / 10.293 | 3.942 / 6.453 | 2.404 |
| Rest, two other living residents | 3.589 / 5.115 | 3.634 / 5.955 | 2.404 |
| Actual walking contact / response | 3.857 / 4.841 | 4.058 / 6.403 | 2.389 |

Steady foot p95 adds **0.201 ms / 5.21%**, while candidate performs three admitted native point contacts and baseline performs none. Rest adds 0.045 ms / 1.25%. These small differences from one pair do not establish a systematic regression. Candidate has no foot-phase sample over the **6.944 ms arithmetic budget for 144 Hz**; max 6.403 leaves only 0.541 ms in this small fixture. This is a reference budget, not a newly authorized global acceptance threshold. No positive-headshot, 13-gun sequence, three-corpse saturation or full-city performance is established.

## First-hit timeline and comparator correction

Candidate first input is at 11,670,189 μs, shot commit 11,682,578, native impact 11,721,815. The frame interval **11,707,824 → 12,669,191 μs** spans the impact and lasts 961.367 ms. Observed completed HP occurs at 12,669,613: **999.424 ms after input**, versus **65.847 ms** baseline. This HP timestamp is the next driver observation, not proof that the HP transaction itself took one second.

The render CPU monitor subsequently reports **943.207 ms**; the GPU remains around 2.3–2.5 ms. The render CPU reading arrives later than the long wall interval, so it must not be attributed to that exact sample boundary. It nevertheless strongly points to CPU-side first-use render/pipeline work, not a one-second GPU draw or the ordinary millisecond mesh-query kernel. It is not a compiler stack trace: pipeline compilation is a strong inference pending the targeted prewarm experiment.

Original `compare.py` selected only frames whose **ending timestamp** was within input+500 ms; it excluded a stall that began inside the window and ended outside. The outputs-only comparator now tests **frame-interval overlap**. Raw evidence is untouched. `GPU_COMPARISON01_INTERVAL_FIXED.json` correctly includes 961.367 ms; historical `GPU_COMPARISON01.json` remains preserved. Its old first-use 5.948 ms figure is not valid for cold-hit acceptance.

Across all measured phases: baseline 7,257 frames, 3 over 6.944 ms and 0 over 16.667 ms; candidate 7,362 frames, 4 over 6.944 ms and 2 over 16.667 ms. The candidate's 961 ms outlier is <0.02% of samples, illustrating why p95 alone conceals it.

## Static cause and minimal isolated proposal

`npc_bullet_marks.gd` configure lines 65–77 creates the existing MeshInstance and custom ShaderMaterial but assigns **no mesh surface**. First accepted hit calls `_rebuild` lines 371–390, creating the first indexed vertex/color `ArrayMesh` with `ARRAY_FLAG_USE_DYNAMIC_UPDATE`, attaching this material and making that pipeline draw for the first time. Marks add a custom derivative-normal shader absent from the baseline. Blood changes only radius/opacity on an existing StandardMaterial path; head classification is CPU logic. These facts make the new marks pipeline the narrowest supported first hypothesis.

Prepared `../coordinator23_marks_prewarm09/` is a one-file outputs-only experiment: renderer **20133717… → 3235343d…**. Configure attaches an indexed vertex/color/dynamic **zero-area** triangle with the exact unchanged shader/material and finite AABB to the existing node. It admits no hit/HP/mark receipt. Real `_rebuild`, original source geometry and material flags are unchanged. There are no added nodes or script callbacks. At most one additional degenerate submitted draw per unhit resident can persist (three here), replaced by the real wound mesh on hit; that small idle cost must be measured rather than described as zero.

Do not claim this patch fixes the stall without the exact compiled09 rendered first-hit test. If attachment does not warm the necessary variant, use explicit loading-time preparation/render under the same Forward+ / MSAA / vertex format before ready. Shader creation alone, invisible/camera-culled dummy geometry, or simplifying the original shader is not an adequate demonstrated fix. Retain the original material, normals, colors, topology and quality.

Cold-cache experiment: use a new empty per-child APPDATA root and record it in the launch receipt; verify the Godot user/shader-cache directory is created there. This avoids mistaking reuse of the just-compiled08 project cache for a09 fix. OS/driver caches may be separate and still warm: record that limitation, do not delete the user's global caches. Compare first input→impact→observed HP and full overlapping rendered-frame intervals, including startup time so moving compilation into loading is reported honestly. Root should preserve08 and apply only the before-SHA-guarded patch into09.

## Memory, physical work and images

Candidate RAM is **+11.627 MiB before the living-walk phase**, growing to about **+12.04 MiB** by the final phase. Most of this exists before the first wound, consistent with new prepared query data; the pair does not isolate each allocation source. Resting draw calls are **715→716**, primitives **195,582→195,626**. VRAM at rest differs by only **2,208 bytes**. The approximately 0.4 MiB/s RAM growth on both sides largely follows retention of raw per-frame dictionary samples in the harness; it is **not evidence of a game memory leak**. A cap-filled marks / larger population memory bound remains separate work.

Baseline eventually sleeps all16 parts; candidate remains physically awake with low residual motion and receives three foot contacts. Both preserve16 bodies,15 joints and75 kg. Final candidate joint error is0.000134 m, with unchanged HP/blood damage revision. Different trajectories/sleeping work prevent treating these as identical solver workloads or interpreting the foot delta as exclusive sampler cost.

Viewed both medical and foot-response PNG pairs. Same buildings/ground/camera/player are visible; the corpse is present and repositioned after candidate contact. NPC and corpse poses differ modestly, as expected from the real physics/timing. The medical screenshot does **not** visually establish fine wound placement or blood quantity: the target is small and the hit side is partly hidden, and it is captured after transient particles expire. Renderer state reports two marks, but close visual wound acceptance remains separate. The HUD's instantaneous FPS is not used as the performance measurement.

**Recommendation:** keep rollout on HOLD until the first-use render stall is removed in an isolated cold-start compiled test. The steady one-corpse/foot workload is encouraging and does not justify removing geometry or effects; it also cannot excuse the first-hit pause.
