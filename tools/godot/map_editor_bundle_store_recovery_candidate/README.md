# Combined bundle recovery candidate — source-only

The frozen combined store and production game are unchanged. `patch.mjs`
SHA-pins the original `map_bundle_store.gd` and builds a compatible raw-JSON
derivative at `outputs/map-editor-bundle-recovery-4Ib6yD` (derived SHA-256
`f19da51b2f9953a394bb747c61cf6874c6f25a39c701183c00cd7301791f5254`).
It retains the public `.json` path and existing `.bak` behavior.

Before removing a valid primary, the derivative copies it to `.bak`, reads
that backup through the full trusted bundle/resource/ground validator and
requires exact canonical equality with the former primary. If primary and
backup are both unavailable but a previous `.tmp` validates, it first copies
that sole recoverable version to `.bak` and verifies it before reopening the
temp path for WRITE. `load_bundle` can recover a fully validated temp only if
both primary and backup fail. No incomplete temp is admitted. A post-rename
readback validates the promoted bundle.

Six deterministic test-only failpoints exist: `before_temp_write`,
`after_temp_verified`, `after_backup_verified`, `after_primary_removed`,
`before_promote`, `after_promote`. For an already validated old map, a refused
step should leave an old or new complete admitted bundle at primary, backup,
or temp. A first-ever save interrupted before any complete temp exists cannot
preserve a map that never existed. The primary path can still be absent between
remove and rename; this candidate is **recovery hardening**, not atomic
primary replacement, OS crash durability, `fsync`, or proof against external
disk corruption. Promotion remains HOLD until native failpoint and separate
real-platform crash tests establish the intended claims.

`node tools/godot/map_editor_bundle_store_recovery_candidate/patch.mjs --check`
checks the frozen source pin and derives the variant in memory; `--stage` writes
only a fresh source-only copy under `outputs/`. The opt-in
`native_fixture/test_recovery.gd` covers all six failpoints, first-save temp
recovery and subsequent temp preservation. `stage_native_fixture.mjs --check`
only verifies SHA-pinned bytes; `--stage` makes a minimal project for a later
explicit CPU Godot GO. Neither stager launches Godot or imports resources.
`test_patch.mjs` checks the source ordering and all six failpoint seams; it is
static evidence only, not a replacement for the native fixture.
