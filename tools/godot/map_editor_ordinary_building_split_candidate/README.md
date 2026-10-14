# Two-phase ordinary-building edit — isolated Godot candidate

This package links the actual Coordinator22 three-resident scene to a native
ordinary-building edit. It does **not** modify production `main.gd`, the visible
game, or the map-editor catalog. `stage.mjs` pins and copies the existing
ordinary-building, resident atomic-pause and navigation-shadow candidates into
a new `outputs/` project, then adds actual terrain and no-impact traffic owners.

For the actual `old_town_narrow_townhouse_v1-012`, the transaction now:

1. Requires a real, current population/policy/navigation pause receipt and
   prepares a second native navigation map while the scene stays paused.
2. Waits for a READY map without changing the live building or nav backend.
3. Mutates the source root and both sibling colliders under actual terrain,
   water and traffic receipts; records no undo entry yet.
4. Requires the root caller to atomically release resident/navigation leases,
   flush callbacks and re-pause in one stack; then swaps the READY map.
5. Finalizes the nav and traffic publication after resume and only then adds
   the undo-history entry. Failure before publication retains or restores the
   original scene rather than silently resuming with stale geometry.

The staged navigation inspector is broadened from the pinned townhouse `013`
to the same-geometry townhouse `012`; the original inspector is untouched.
The traffic no-impact owner gained a final release to break its owner/token
reference cycle. The final test stage was `outputs/map-editor-ordinary-building-tx-ZTA6PZ`.
Godot 4.7.2 headless import exited 0 with no parse errors. Separate native
checks passed **17/17 move** (`Vector3(1.5,0,-0.5)`) and **16/16 delete**, both
exit 0 without leak warnings. An injected traffic failure after its actual
publication restored building geometry, traffic revision and history, then
aborted the shadow map (**14/14**, exit 0, no leak warnings). Initial move
attempts were correctly rejected
by traffic for pre-existing parking-walk overlap and a road cell; no constraint
was relaxed to make the test pass.

Run a fresh isolated stage:

```powershell
node tools/godot/map_editor_ordinary_building_split_candidate/stage.mjs --stage
```

Import with Godot `--headless --editor --import --quit` at the returned path,
then run `--headless --script res://test_split_delete.gd -- --move`, the same
script without `-- --move`, and `-- --fault` for the rollback check. No GPU
preview is required.

This is **not production-ready**. The fixture's pause token verifies the real
population lease but is not the full K/editor workspace with gameplay clock,
vehicle freeze and teardown guards. The current production `npc23b` main is
newer than the pinned checkpoint, with weapon/HP time semantics still needing
rebasing. Navigation geometry is whitelisted to two ordinary houses, rotation
is unsupported, and the traffic owner refuses buildings tied to parking bays
until a source parking/route/vehicle publication API exists. Special buildings,
all 9901 catalog objects, terrain painting, save/load, published export and
LIVE FPS/visual parity remain separate acceptance work. The irreversible
finalization path still needs independent fault-injection/recovery review.
