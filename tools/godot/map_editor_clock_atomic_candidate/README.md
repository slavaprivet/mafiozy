# Actual-K clock two-phase release — tools-only HOLD

This derives two outputs from pinned source without modifying production:

- `diagnostic/gameplay_clock.gd` is derived from `map_editor_native_clock_candidate/gameplay_clock.gd`, SHA-256 `842d7d811490a993248e22c7f6844afd41d0d58a184b868188abf9aa8505e160`.
- `diagnostic/pause_workspace.gd` is derived from `map_editor_actual_k_composition_candidate/build_candidate.mjs`.

The clock keeps `now_ms`, pause accounting, and the exact first-read resume boundary. The original one-step `resume` still works for non-editor callers, but refuses to bypass a prepared editor ticket. Editor handoff becomes `prepare_resume` while the tree is paused; population prepare/commit/finalize; `commit_resume` as the last owner mutation; tree unpause; held navigation callback flush. A population finalizer failure aborts the clock ticket and leaves the clock paused. The clock commit does only private arithmetic/state mutation and has no owner callback or yield.

Integration seam for a *new isolated* actual-K stage: import `buildSource` from `../map_editor_clock_atomic_candidate/build_candidate.mjs`, then use its returned `clock` and `workspace` bytes for the two existing overrides in `map_editor_actual_k_composition_candidate/stage.mjs`. Do **not** change the 192-file checkpoint, main, project or visible game. Replace the old `test_source.mjs` ordering assertion (`clock.resume` before population finalizer) with assertions for finalizer → `clock.commit_resume` → tree unpause. There must be no `clock.resume(_clock_receipt)` in the derived workspace. Existing `stage.mjs` is intentionally unchanged and still produces the older HOLD candidate until the integrator makes this explicit choice.

Source check: `node tools/godot/map_editor_clock_atomic_candidate/test_source.mjs` (43 checks at authoring). No Godot import, native fixture, GPU, or LIVE run has been performed. This is **not engine-level atomicity or editor readiness**. Native fault injection must cover finalizer refusal and ticket mismatch; inspect whether navigation callback flush can fail after tree unpause and leave an active clock in terminal HOLD. That late callback/flush boundary is a remaining separate risk. The moving production weapon/NPC scene also needs a deliberate rebase and owner review before use.
