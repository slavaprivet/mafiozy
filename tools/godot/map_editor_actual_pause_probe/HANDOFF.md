# Actual main pause-clock CPU diagnostic

Source-only package; no production hooks, no GPU or browser. Load the actual main scene with original scripts/raw assets/data. Stage is unique, rejects symbolic links/escape/overwrite, pins all copied source SHA/bytes, skips source UID/cache/tests. Original `.import` configuration files are copied; isolated headless importer regenerates derived `.godot` outputs. Project configuration is diagnostic-only, no editor plugin and unique user directory. Source project hash retained, no game save read/write requested.

Commands from repository root:

1. `node tools/godot/map_editor_actual_pause_probe/stage.mjs`
2. Godot4.7.2 console `--headless --path <explicit returned stage> --editor --import --quit`
3. Same executable `--headless --path <stage> --script res://probe.gd`
4. `node tools/godot/map_editor_actual_pause_probe/finalize.mjs <stage>`

Bounded bootstrap240physicsframes; actual source data8buildings8decor27colliders, original printshop/water/vehicle/melee. Stable grounded ON_FOOT required. Original melee press/release owner creates source cooldown_release300ms, no cancellation/reset before diagnostic snapshots. Global Input.action_press is scoped to this process and released before resume and cleanup. Wait650ms via explicit process-always SceneTreeTimer. Report original body's integration tick/transform/velocity, player transform, main runtime, actual melee snapshot. Synthetic RefCounted deferred marker demonstrates engine semantics only; it does not attest a real navigation continuation.

Observed stage `outputs/actual-main-pause-probe-qAWF1V`, source revision `s01-20260927-melee21`, main SHA `0916381441df9a9d111006aed2b34e4e1c2ec195ee24609757a552b388017571`. Import9.9s CPU; diagnostic4.0s CPU. Actual live exported melee21b was NOT inspected; source revision and compiled live package are distinct. First diagnostic refused due incorrect expected melee status `ready`; corrected to actual `ground_practice_no_combat_targets` plus owner snapshot.ready, final test source hash is in FINAL_DIAGNOSTIC_RECEIPT (source_snapshot pins first probe revision). Original source files unchanged; finalizer reverifies every raw source except generated project/probe and importer-owned `.import` config outputs.

Final diagnostic: elapsed647864µs, actual body tick91→91, exact body transform/velocity, player transform/main runtime unchanged. Held Input true and deferred marker ran. Source cooldown true/timers1 remained unserviced during pause; after resume cooldownfalse/timers0 and bodytick92. Cleanup invokes original melee.cancel only after reports/snapshots, releases input, unpauses isolated tree and frees actualscene. Original body was naturally active (nonzero velocity); no impulse or fake body was inserted. No timing rewrite, owner booleans, fake nav approvals or save changes.

Finalizer refuses any modified staged raw source; concurrent production source changes are listed separately as currentSourceDrift and invalidate currentSourceMatchesSnapshot, not the historical stage proof. Final proof source closure is the exact snapshot, not automatically today's production.

This is NOT an editor pause lease, full owner quiescence, resource immutability, preservation of combat state, full-map editor, GPU visual equivalence or FPS acceptance. Residents disabled by original scene default: no actual navigation callback was pending/tested. Always editor Node processing was not mounted, only explicit always timer/SceneTree script diagnostic. Focus/session/door/traversal/reentry/rollback contracts remain required. Stage can be reused read-only by separately owned actual terrain/building inventory scripts to avoid duplicate import; those scripts cannot modify original staged owners.
