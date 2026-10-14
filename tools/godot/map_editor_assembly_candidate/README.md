# Source-only editor assembly

This preserves the reviewed native test fixtures outside disposable outputs.
Production main/player and the visible game are not modified.

1. Run `node tools/godot/stage_map_editor_assembly.mjs --stage`.
2. Use its returned destination as Godot `--path`.
3. Run Godot headless `--editor --import --quit` there, then headless
   `--quit-after 1200 --script res://test_editor_assembly.gd`.

Default `--check` only reads and verifies sources. Staging creates a unique
directory below repository outputs, admits every original GLB by SHA/byte count,
copies no `.godot`, `.import`, or UID files, and verifies every written file.
Imported resources are generated from original assets by Godot itself.
The fixture uses staged res paths, not machine-specific absolute paths.

Tests use real object/ground models, geometry, undo/redo, file storage, shared
persistence and atomic import. Game pause/navigation/water callbacks remain
test fixtures; GPU appearance, production K hookup, all procedural objects,
special-building owners and the full live game require separate acceptance.
No server upload is claimed by file export.

`--procedural` additionally admits the frozen original procedural manifest,
all982 original buffers, source dependencies and V3 factory/registry/policy.
It stages `test_unified_registry.gd`: actual242 GLB objects +9394 generated
objects in one composite/controller/history and real file storage. Root run
29910 checks PASS,9636 original/fresh9638 after one house and one tree copy.
Each loaded opaque record and native float32 frame is verified, no epsilon.
GPU/traffic/nav/collider callbacks remain explicit fixtures, not production.
The first timing (~15.48s) included the per-record verification, not pure load;
the current test now reports install and verification separately.

`--transport` (requires `--procedural`) adds the frozen original parking
registry and train/source resource bytes. Full source assembly:30718 checks,
9901 inventory records /9904 after trusted house/tree/parking clones.32 V1
railway records remain HOLD and must not be described as admitted visuals.

`test_combined_persistence.gd` intentionally reproduces the old non-atomic
sequential-loader failure as a negative regression. Its `atomicImportReady`
field describes that harness, not the newer atomic importer's readiness.
`test_atomic_import.gd` separately proves joint candidate rollback/admission.
Fresh196GLB native import after header-copy optimization: assembly12782,
atomic66599, sequential-negative1482, independent early-input-router14 PASS.
No real game navigation/water/authority callbacks are supplied by these tests.

`--registry-perf` additionally requires both family flags and admits the frozen
optimized registry subclasses by exact receipt/source/runtime hashes. Originals
remain available and unchanged. Run `test_exact_equal.gd` and
`test_full_registry_perf.gd`:30351+30718 PASS on fresh source import, current
MapDocument header optimization and exact original meshes/materials. Last
candidate install CPU12.891s; separate controlled original-model3pair benchmark
isolates registry gain15.431→13.792s(-10.6%). These are CPU import tests, not
user game startup/FPS or real gameplay-owner acceptance.

`--authored-perf` requires all three preceding family/performance flags. It
admits the frozen authored two-subclass package by receiptSHA74aa8c1ff506aaf…,
baseline and runtime hashes. `test_full_all_perf.gd` reuses the same full
9901-record assertions and explicitly selects all four optimized registry/
factory classes; no default source constructor changes. Fresh root first run
30718 PASS,9901→9904, install13278619us/verification580152us (single run, not
paired loading/FPS). Extended fresh run30767 PASS, original actual house/tree/
parking rotate/delete/undo/redo and top/fly actions before serialization;
exact rotated records restored on fresh load. Install13666523us/verification
592314us single run, not paired gain. Runtime gate callbacks
remain fixtures. Stager31 readonly checks include missing-dependency refusals.

`--paged-editor` requires all preceding flags. It admits reviewed initial-only
Controller adapter + frozen paged Panel by exact receiptSHA694b160720396dce…
and base/runtime pins, preserving originals at their base paths. New
`test_full_paged_editor.gd` uses genuine full Composite CatalogUI admission,
checks all pages/IDs, and catalog-selects original house/tree/parking IDs for
move/delete/undo before fresh mixed-owner load. Fresh independent root native
run after the coordinator's GPU window:80452 checks PASS,9901 originals /9904
after copies; all62 pages and38 protected owners. Actual house/tree/parking
undo restores exact native frame, collision/mesh or CPU MultiMesh shadow.
Stage `outputs/map_editor_source_assembly_z6tlla`, no SCRIPT ERROR. Install
CPU13018405us / verification583167us: single run, not paired FPS/startup.
Game-owner callbacks remain test fixtures, not actual main admission.
File-only stager43 checks PASS,1389 original/candidate files, no engine started.

Separate agent proof of genuine full catalog (not SyntheticSourceIndex):79711
PASS,9901 registry/document/UI IDs,0missing/availability/category mismatches,
9863 geometry-fixture available/38protected (6special+32rail). Root independent
pagedPanel9996PASS and actualfamily input73PASS are separate scopes. New
Controller adapter agent703PASS on actual242authored models/236available;
full combined paged integration/real game admission remains unverified.
