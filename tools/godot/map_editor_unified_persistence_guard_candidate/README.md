# Unified file-action guard — source-only candidate

`node tools/godot/map_editor_unified_persistence_guard_candidate/patch.mjs --check`
pins the frozen controller/workspace source and builds a two-file derivative in
memory. It composes the independently checked exact protected-row guard from
`map_editor_protected_exact_variant` with the unified file-action guard.
`--stage` writes that derivative to a new `outputs/` folder only.
No production or frozen assembly file is edited.

After the workspace is configured, its one-way handoff makes direct
`editor_controller.handle_action(save/load/import/export)` return a refusal.
The derived controller also refuses direct legacy `install_document` (and its
`install_versioned_patch` caller) after handoff; atomic combined import uses
`prepare_install_document` plus guarded model commits, not that legacy loader.
The workspace still routes those four actions through its existing combined
object+ground persistence callback; object edit/undo actions remain delegated.
The workspace variant preflights the required panel, brush and renderer APIs
before flipping the irreversible handoff. This closes the known direct
object-only routes, not arbitrary host-injected callbacks: the owner must bind
`persistence` to the configured combined `EditorPersistence.handle_action`, not
an object-only or synthetic callback. A native negative test must prove setup
failure leaves the controller route unchanged, then prove the successful
handoff blocks direct object-only file/install calls while combined I/O works.
Host admission rule: do not deliver K, panel input or any direct controller file
action between `controller.setup` and successful `workspace.setup`/one-way
handoff. Before that handoff, the frozen controller's legacy object-only route
still exists by design. A failed workspace setup must leave the editor closed
until a corrected setup succeeds; do not treat a callable's mere validity as
proof that it is the configured combined persistence owner.

`atomic_map_import.gd:102` calls `prepare_install_document`; its guarded commit
at `:141-144` does not call public `install_document`, so blocking that legacy
method after handoff does not block the intended combined import path.

Independent source/static check after the added guards: `patch.mjs --check`
PASS; final staged derivative `outputs/map-editor-unified-persistence-KKEd3m`
has controller SHA-256 `4878b8b9c9d8b5f4594f3c5858ada9d799f80239e6426eab18369797ac808e97`
and workspace SHA-256 `681fd1a7f5971634260eca69f96f831072fc6e5e47f0e62eebb4551f2547116a`.
`node tools/godot/map_editor_unified_persistence_guard_candidate/test_patch.mjs outputs/map-editor-unified-persistence-KKEd3m`
reports 16 static checks PASS. Earlier stages `QYFy3G` and `9rDo1A` are
superseded and must not be used for native admission.

The opt-in `native_fixture/test_unified_guard.gd` and
`stage_native_fixture.mjs` are prepared for a later, separately authorised CPU
Godot run. `--check` only reads SHA-pinned sources; `--stage` creates a fresh
minimal project under `outputs/`, with no imported assets and no Godot launch.
The fixture exercises failed setup, successful handoff, all four direct file
refusals, legacy object-only install refusal, protected sub-epsilon rejection,
ordinary object movement, and a real combined bundle save through the workspace
callback. Its pause/terrain owners remain synthetic; it is not full editor or
LIVE acceptance. Run Godot only after a new owner GO and record a native receipt.

The existing assembly stager pins the original controller SHA, so this variant
must receive a reviewed new receipt and native negative tests before adoption.
Production K, terrain ownership, disk durability and LIVE behavior remain HOLD.
