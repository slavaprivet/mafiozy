# Candidate09 isolated marks pipeline preparation

Only `files/scripts/npc_visual/npc_bullet_marks.gd` changes. Require before SHA `20133717664f76f5d008060bd9238dda71da85d0c236505e23f56ac208c2e008`; proposed after `3235343d64754b5a2711ec43f49d9c992112e0b7ba852937903ea6d17db399b6`. No engine/GPU validation performed here.

The exact shader and real wound geometry are unchanged. An initial zero-area indexed/color/dynamic surface is attached during configure, using the same material and finite AABB. No marks, source receipts or damage are manufactured. First real `_rebuild` replaces it through the unchanged code path. Bounded idle overhead can be one extra degenerate draw per still-unhit resident; record actual draw counts and do not call it free.

Reason: exact candidate08 first-hit wall gap961.367 ms, later render-CPU measurement943.207 ms, GPU~2.4 ms. Marks material existed at setup but first actual surface attachment occurred only inside `_rebuild` on the hit. This is a narrow experiment for a strong first-use-pipeline hypothesis, not yet a proven diagnosis.

Root: copy08→09, apply guarded single-file overlay, run ordinary source/geometry/HP checks, export exact09. Re-run the actual GPU first-hit path with a fresh per-child APPDATA/project shader cache and retain driver-cache limitations. Verify no new gameplay stall, original appearance, bounded idle draw cost, and unchanged two-hit/foot behavior. Keep startup preparation latency separately visible. No global cache deletion or source material simplification.

Corrected raw comparison and full review: `../coordinator23_loaded_combat_pair/GPU_COMPARISON01_INTERVAL_FIXED.json` and `GPU_REVIEW01.md`.
