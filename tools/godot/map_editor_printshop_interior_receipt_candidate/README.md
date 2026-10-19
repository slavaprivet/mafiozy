# Printshop interior owner receipt — diagnostic HOLD

This is a separate, read-only tools-only package for the immutable Coordinator22
actual-main checkpoint at `outputs/coordinator22_residents_checkpoint/godot/mafiozi_walk`.
It does not edit the current main, Printshop adapter, the existing
`map_editor_live_authored_receipt_candidate`, production assets, or any frozen
receipt. The current working main differs from checkpoint SHA
`faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53`;
the checkpoint is intentional. `block.json` SHA is `1523f52e...`, source
package SHA `958a2c2d...`, imported Printshop GLB SHA `ad7b8ef7...`, Printshop
adapter SHA `f6f08258...`, and finish adapter SHA `666bb280...`.

`printshop_interior_owner.gd` checks the exact main/block/catalog/package/model
bytes and actual source ID/placement, then captures the live root/visual,
Printshop adapter and imported scene identity. It records weak lifetime IDs and
byte-exact transforms for all descendants; generated mesh cache and active
material identities; original GLB mesh restoration identities; both door
pivots/base/fraction/target/bounds; and the 111 expected interior static-body
identities plus collision shape resources. Unlike the 15 ordinary roots, the
Printshop visual is **not** compared to a raw GLB tree: `attach_existing`
replaces meshes, hides one imported mesh and builds new geometry and doors
(`preview_printshop_interior.gd:53-136`).

The source-to-owner gap is not resolvable by a read-only observer. The pinned
adapter exposes mutable `_mesh_cache`, `_material_cache`, `_doors` and `_restores`
(`:15-19`); `request_door` changes target (`:158-170`), `advance` changes door
fraction and pivot transform (`:173-185`), and `restore_original` mutates
imported meshes/visibility and clears ownership (`:192-207`). There is no
monotonic revision, writer seal, or transaction callback in that source. A
mesh/material/door/shape could be changed and restored between two snapshots;
identical later instance IDs/bytes would not prove that no game or owner writer
ran. Consequently `begin` and `verify` return
`printshop-owner-revision-or-seal-required` even when the captured identities
match, and `verified_root()` always returns `null`. This package grants **0/1
Printshop**, not 16/16 authored root approval, and does not authorize editing,
save/load, physics, doors, or gameplay resume.

`node tools/godot/map_editor_printshop_interior_receipt_candidate/test_source_gap.mjs`
checks pinned source/package/model identities and the missing revision seam
without Godot. `stage.mjs --check` checks seven pins and lists the checkpoint
project source without writing. `stage.mjs --stage` is opt-in: it copies the
checkpoint to a new outputs directory, excludes `.godot`/`.import`/UID caches,
adds the current pinned editor catalog and this diagnostic owner/fixture, and
uses a distinct test user-data directory. It never launches Godot. Only after
an explicit CPU GO should the owner import that returned project and run
`res://test_printshop_receipt.gd`; the fixture expects HOLD and zero verified
roots, not a positive integration. GPU/LIVE remain untested.

To turn this into a positive receipt, the Printshop owner must supply a
monotonic revision or sealed writer lease covering mesh/material resources,
door target/fraction/pivots, collision resources, restore/rebuild and owner
lifetime; the actual main must expose a pause-safe admission/verify boundary.
Then a new native negative suite must prove mutation, mutation-restore,
callback reentry and owner deletion invalidate the receipt before any 16/16
root-map handoff. The existing live-authored owner stays fail-closed meanwhile.
