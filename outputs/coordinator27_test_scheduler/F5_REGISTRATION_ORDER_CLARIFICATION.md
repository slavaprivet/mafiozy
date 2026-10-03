# F5 registration ordering clarification — source review, 2026-10-03

The final paragraph of frozen `registration_guard/README.md` described an analogous F5 registration window. That inference omitted the shared prelaunch mutex. **No equivalent F5 race has been demonstrated in the supported scheduler/launcher flow, and no launcher change is justified by the legacy guard failure.** This separate note corrects that limitation; the frozen helper, README, tests and manifest are unchanged.

Reviewed source pins:

- `tools/godot/test_scheduler.py`: `6f86204fdb510a9f3d850792891fc9902301ad68b5a67688080d0ac888c3cad9`.
- `tools/godot/launch_current_game.ps1`: `3c35014e251a614641082cdc97fa8f6e0a458c7424f40328975f4fcb3764f629`.
- Unchanged `registration_guard/MANIFEST.json`: `1653979112994fb5e5e07ef0570cbf17d9e9a5a5ad524d9e6dddfadc452aaef0`.

Ordering proof from these exact sources:

1. Actual F5 launch acquires `Local\MafioziUnifiedPreviewLaunch` at launcher lines 66–73 before inventory (94), scheduler coexist snapshot (95), and engine start (111). `CheckOnly` skips the mutex but exits at 92 before inventory or launch.
2. Scheduler `Lease.__enter__()` uses the same name (208), acquires the bridge at 224–225, and retains its context at 228 when admitting a child. It does not release the bridge on returning from `__enter__()`.
3. `register_child()` verifies the actual child and appends its identity inside `state_lock` at 263–277. Leaving that block writes the temporary registry and atomically replaces `state.json` at 118–120. Only afterward does the functional lane release the bridge at 279–280. Thus F5 cannot observe this normal prepublication interval after acquiring its mutex.
4. Conversely, if F5 acquires first and no stable user game exists, the scheduler's unavailable bridge is not bypassed (226–227). The explicit functional coexistence exception requires an observed stable user game, not merely an editor. In the supported user-game flow the original launcher retains the same mutex while waiting for that game to exit (131, then 137); another F5 invocation cannot enter its inventory step during that ownership.

This is a source-level concurrency ordering proof, not an assertion that every possible process-exit/crash transition is race-free. It adds no engine or GPU run. The demonstrated C4 private legacy guard race remains valid: that running guard polls inventory without holding the prelaunch bridge, so it can meet another owner's child before registration. Its bounded registration adapter remains applicable. Existing CPU 11/11 evidence and all frozen files remain unchanged.
