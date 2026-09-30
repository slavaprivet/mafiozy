# 23d AK outlier: cause unresolved

Actual loaded_23c_to_23d_01 evidence: candidate active AK maximum42.721ms at zero-based frame126. That frame begins432.589ms and ends475.310ms into the measured phase. The next frame is8.595ms. Baseline maximum7.675ms. Candidate active p50/p95 3.090/5.818ms versus baseline3.042/5.560ms; other candidate outliers reach9.251ms. Idle/cargo maxima5.775/8.597ms show no comparable42ms event.

The2-second weapon warmup holds aim only; it does not shoot. The spike is near the second scheduled click (~400ms), not the phase boundary. The report has no actual shot/impact timestamps, so it cannot establish whether this was the first visible mark, second impact, or unrelated stall. GPU timestamps were sampled every12frames:126 lies between119 and131, so the reported GPU maximum3.034ms does not cover the42.721ms wall stall. Do not use it to rule out rendering/compilation.

Source candidate new normal marks change mesh and enable rim material vertex_color_use_as_albedo on first hit. Four tiny mesh variants are built at configure, so no runtime art generation is present. A first-use material/pipeline stall is plausible, not proved. CPU scheduling/driver upload/other processing remain possibilities. Ordinary camera cargo caches are not a strong explanation for this phase, but absence of per-frame attribution prevents excluding everything.

Actual accepted shots differed: baseline10, candidate9. Both met the old workload admission threshold5, so comparable:true denotes fixed fixture/export checks; it does not establish equal shot work. Any regression conclusion must disclose this. A fixed-duration window can legitimately admit fewer shots due to frame scheduling; new targeted capture holds each native input until shot receipt, records trigger/emission/mark times, and reports counts alongside per-shot timing. A count failure is diagnostic, not an excuse to erase a sample.

## Minimal candidate patch

surface_preassign_minimal.patch changes only pool configure after preserving source_meshes. It assigns normal art[i%4] and rim vertex-color feature ahead of first real impact. No fake hits, added warmup draw, removed content, changed lifetimes, reduced pools or different actual shooting behavior.303 small headless pool-contract assertions PASS. Original glass/explosion art restores correctly. This avoids first-hit feature mutation; hidden material assignment may still leave native pipeline creation until first visibility. No claim that it fixes the stall without GPU evidence.

## Targeted capture prepared, not run

cold_warm_capture.gd preserves full3NPC/8building/377body/377shape scene and comparable draw camera. Cold=first10real AK shots in this process; warm=next10same-process shots. No persistent driver/Godot cache deletion. Per-frame wall/GPU/process/physics/memory, pipeline monitor counts if exposed, actual shot signal timestamps, observed mark-count changes. GPU timestamps can be delayed relative CPU, so inspect neighboring frames/counter transitions before causal claims. Mark times are explicitly after-draw observations, not physics timestamps.

run_cold_warm_pair.py uses the same GUI direct/offscreen/NO_FOCUS/receipt guards. Root outer stop/restore wrapper still required. Two runs max76sec; optional exact current23d between baseline23c and updated candidate adds max38sec (114sec total). No GPU executed during preparation.

```powershell
python outputs/coordinator23_quality_perf23d/run_cold_warm_pair.py --candidate-pck "ABS_UPDATED_PCK/MafioziPreview.pck" --include-current --tag cold_current_updated_01
```

Without --include-current it captures baseline23c and updated candidate only. Current23d identity is pinned to the exact PCK and receipt in loaded_23c_to_23d_01/MANIFEST.json. Output COLD_WARM_ANALYSIS.json annotates top5 slow frames with nearby shots/marks and compilation-counter deltas. Native camera behavioral acceptance remains separate.
