# Exact protected-record admission — source-only variant

`variant.mjs` reads the SHA-pinned frozen `editor_controller.gd` and returns an in-memory controller source variant. It does not write the frozen candidate, paged receipt, actual game or staged project. It inserts one guard in `prepare_install_document`: every non-editable baseline ID must be present and match its full trusted record exactly (including JSON-transport representation). Editable IDs continue to use the existing admission path.

Run `node tools/godot/map_editor_protected_exact_variant/test_variant.mjs`. The Node negative test covers a sub-epsilon protected transform, protected deletion, and allowed ordinary transform/deletion. This is only a source/static test; no Godot script or transaction has executed.

Integration sequence for the owner: review generated source/diff against frozen SHA `d1812cb...`; add native negative import tests asserting protected document/scene/history remain exact and an ordinary edit succeeds; run Godot tests in a disposable staged project; then issue new paged-controller baseline receipt and update the corresponding hash pin in `stage_map_editor_assembly.mjs:125-132`. Do not weaken or silently bypass the existing pinned receipt. Only after the full host/asset/pause gates pass may the new variant be considered for actual main.
