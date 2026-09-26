# Godot city excerpt, version 1

`tools/godot/export_preview_block.py` exports a deterministic excerpt from the
existing Walk placements, centered on `REBUILD-VISUAL-print_shop-001`. It reads
the real building, decor, topology and hero manifests. Run from any directory:

```powershell
python tools/godot/export_preview_block.py
python tools/godot/export_preview_block.py --check
```

The default selects the eight nearest authored building centers (stable ID
breaks distance ties). The surface crop covers their actual footprints plus
three existing grid cells on each side, clamped to the real source grid.
All decor whose authored center falls inside that crop is included. No map
outside the crop is inferred. `--count` accepts six through ten buildings.

## Consumer contract

Read `res://data/block.json`, schema `mafiozi.godot.preview-block/v1`.

- `originM`: original print-shop placement position in world metres. Every
  original source position remains in its original record. Subtract this
  origin only when placing nodes in the local preview scene.
- `buildings[]`, `decor[]`: stable source `id`, `assetId`, original `binding`,
  `transform`, original `collision.worldBodies`, and Godot resource `path`.
- A placement parent uses `positionLocalM`, positive Y rotation
  `deg_to_rad(transform.yawDegrees)`, and scale
  `[uniformScale*horizontalScale[0], uniformScale,
  uniformScale*horizontalScale[1]]`. The imported GLB is its child, translated
  by `modelLocalOffsetM` **before parent scale and rotation**. Both systems use
  right-handed Y-up coordinates. Do not independently flip Z or yaw.
- Hide the exact placement `hideNodeNames`. `effectiveHiddenNodeNames` also
  contains actual GLB node names matching the existing Walk loader's helper
  regex (collision, collider, clearance, socket, anchor, keepout, nav, proxy,
  datum and the matching prefixes). Hide these subtrees, preserving normal
  visual geometry and source GLB bytes. Importer name sanitization may require
  matching the original name metadata. No arbitrary mesh filtering is allowed.
- `collisionBodiesM[]` is a derived convenience view. `polygonXZ` has local
  metre X/Z points; `minY`/`maxY` are already local vertical coordinates.
  `sourceIndex` points to the original `collision.worldBodies` entry.
  Build extrusion collisions at the **scene origin**, not under the scaled
  building parent: these polygons already include world placement and scale.
  Do not turn the whole visual bounding box into an extra blocking body.
- `surface.grid[row][col]` is an unchanged rectangular source crop.
  Actual grid indices are `startRow+row`, `startCol+col`.
  A cell corner in preview metres is
  `[(startCol+col)*cellSize-originM[0], y,
  (startRow+row)*cellSize-originM[2]]`. The tile covers one full `cellSize`
  square. The cell center therefore adds half a cell in X and Z.
- `surface.masks` preserves the corresponding source masks. `palette`
  preserves Walk tile IDs, colours and native mesh heights: road 0, grass 8,
  sidewalk 9, sand 14, water 16, bridge 19. Water has height -0.18 m and no
  solid floor. Other native tiles have height 0. Protected cell colour is
  separate. `materialDescriptors` preserves original asphalt/material data;
  its `baseColorFactor` is **linear sRGB**, while palette hex values are sRGB.
- `hero.path` points at the exact hash-verified existing male hero GLB.
  Use `targetHeightM=1.9` divided by actual rest-pose height, not a guessed
  model scale. `spawnLocalM` has a dry, statically clear 0.45 m radius near the
  authored print-shop road approach. It is only preview staging; it does not
  certify dynamic NPC, vehicle or multiplayer teleport authority.

## Provenance and checks

Each source JSON has raw-byte SHA-256 and length in `sources`. Every GLB is
read, compared with its source binding length and SHA-256, and checked as a
self-contained glTF 2 binary **before any outputs are written**. External GLB
dependencies currently fail closed. Duplicate assets share one destination.
Copied bytes are unchanged. The generated manifest has no wall-clock fields.
`--check` rebuilds the result in memory and compares every expected output
byte-for-byte without modifying it. It never removes stale or unrelated files.

The exporter refuses unknown tile IDs, invalid body heights, missing binding
hashes and a missing safe spawn. `counts` reports actual exported records,
unique GLBs, collision bodies and cells. Source placement/topology readiness
flags are retained; this excerpt does not upgrade their acceptance status.

## Explicit stage boundary

This is a real asset/placement preview for the first visible Godot scene.
Building collisions remain the authored **conservative exterior proxies**;
they do not prove a migrated working interior or door system. Authored source
`gameplayId` is retained, while `gameplayActive` is false in this consumer
contract. Businesses, ownership, police, NPCs, cars, damage, missions,
multiplayer authority, swimming and the outside landscape are separate
migration tasks. A successful exporter check is neither a GPU benchmark nor
visual acceptance of the application. The root coordinator owns Godot scene
assembly and the single live application run.
