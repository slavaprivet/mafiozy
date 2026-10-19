# Missing editor GLBs — byte-preserving outputs package

`stage.mjs` checked the verified 196-resource catalog and existing adoption
audit, then staged **exactly 188 missing GLBs** (25,601,564 raw bytes) at
`outputs/map-editor-missing-assets-aE6EyN/assets/map_editor/<SHA>.glb`.
The eight byte-identical assets already in `godot/mafiozi_walk/assets` are
manifest **references**, not copied files. Nothing was installed in the
production project, and Godot/GPU was not run.

The [package manifest](../../../outputs/map-editor-missing-assets-aE6EyN/package_manifest.json)
has all 196 resource SHA/size/source paths, current catalog `resPath`, 8
production paths or 188 proposed SHA-addressed package paths, placed-object
counts, and exact GLB material, mesh and embedded-image counts. All image and
buffer payloads are internal to the original GLBs; there are no external URI
dependencies. The manifest SHA-256 is
`50fe3ca72c5b7a6956495e870c0c2f618019abf62c92b5eaca4f7a1cddf9fa27`.
Catalog SHA-256 is
`ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e`;
adoption-audit SHA-256 is
`48d9806e512e02b5ff53e67a7289d18fcd91cfc44cecbf2f7235009c7d20e13d`.

Run `node tools/godot/map_editor_missing_assets_package/stage.mjs --check`
for a read-only preflight, `--stage` for a new unique outputs-only directory,
or `--verify <absolute-package-dir>` for a complete package/path-set and
current-source verification. Staging uses exclusive copies and post-copy
hash/structure checks; it never overwrites an existing file. On 30 September,
`--check`, `--stage`, and `--verify` all returned success for the path above.

Coordinator22 subsequently authorized **one isolated headless import and
verification**. `stage_import.mjs` copied the stable checkpoint without its
`.godot` cache, added the verified catalog and 188 package GLBs, plus the
**three** exact catalog references absent from that checkpoint (the other five
were retained). It preflighted all 196 catalog target paths by SHA. Stage:
`outputs/map-editor-188-import-WictKB`. Godot 4.7.2 headless import exited 0;
the native resource fixture exited 0 with **785 checks, 0 failures, 196
PackedScene resources loaded**. `inspect_import.mjs` then verified all 196
`.glb.import` sidecars and nonempty generated `.scn` caches (18,418,154
bytes). Both logs have zero detected engine errors, script errors or warnings.
The [import receipt](../../../outputs/map-editor-188-import-WictKB/import_verification.json)
SHA-256 is
`23b466c83500a042ce06466ac158e437a31d0d8ff8e125ce902422d98d9419be`.
No second import, GPU scene or production adoption occurred. Current missing
catalog `resPath` values still require owner-controlled activation; full-world
visual, collision, navigation, draw-call and FPS proof remains open.
