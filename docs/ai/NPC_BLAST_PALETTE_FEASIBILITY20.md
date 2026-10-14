# Frozen GPU skin palette feasibility — 2026-09-20

Isolated prototype, **not imported by gameplay**. Files:

- `assets/maps/city_rebuild_v1/npc_blast_palette_prototype20.mjs`
- `assets/maps/city_rebuild_v1/test_npc_blast_palette20.mjs`

The existing `npc_blast_parts_prototype20.mjs` was not changed.

## Contract and proof

`prepareNpcBlastPalette20(THREE, actor.walker.artistContext().scene)` partitions immutable geometry into six regions in a loading-time pass. It owns cloned position/skin/normal/UV buffers and region indices. `prepared.freeze()` creates six independent world pivots, captures bone world matrices/inverses and both mesh bind matrices, clones materials/texture handles, and returns an independently disposable group. Shared prepared buffers remain leased until both victims release. There is no vertex bake during freeze: tests replace every source `getVertexPosition` with a throwing function while running 40 freezes.

Standard Three SkinnedMesh shaders perform deformation. **Plain detached bindMode is insufficient:** Three's update overwrites bindMatrixInverse with inverse(bindMatrix), whereas the source attached rig's current inverse can be different. The prototype overrides only fragment `updateMatrixWorld` to run the base Mesh method and preserve both exact admission bind matrices. No shader fork is needed. Frozen bones are not parented under the moving fragment pivots.

Actual male/female models, changed pose between prepare and freeze, translated/elevated/rotated roots:

| | Male | Female |
|---|---:|---:|
| Used region vertices | 8511 | 8248 |
| Frozen logical palette floats | 448 | 448 |
| Draw calls / one victim | 17 | 16 |
| Draw calls / two victims | 34 | 32 |
| Maximum Float32 palette position error versus CPU bake | 2.91e-7 m | 3.27e-7 m |
| Warm freeze CPU p50 / p95, 40 samples | .537 / 1.471 ms | .353 / .629 ms |
| Loading-time prepare CPU, one sample | 10.27 ms | 11.98 ms |

Double-precision frozen Bone-matrix vertex positions match the CPU reference within 1e-11 m. GPU numbers above are **CPU emulation of skinning with Three's actual Float32 boneMatrices**, not GPU readback. The renderer may pad the palette's texture storage beyond the logical 448 floats.

PASS: all used vertices, original actor movement and disposal, independent pivot translation/rotation, independent victim palettes/materials, bounded two-victim lease count, rejection of prepared disposal while leased, texture-backed skeleton disposal and idempotent victim disposal. Command: `node --test assets/maps/city_rebuild_v1/test_npc_blast_palette20.mjs` — 2/2 PASS.

## Integration still required

- This eliminates the 30–35 death-frame vertex-bake slices, but GPU geometry upload/shader compile must be warmed **before** death. Actual GPU warm-up and common-scene FPS have not been tested. First measured CPU freeze was 1.79/.57 ms in the final run; JIT/GC can vary.
- Per-region posed ground support bounds are not supplied. Prewarm per-bone local support boxes and transform/union them from the frozen palette for conservative bounds; do not reuse an unposed geometry box as exact ground support. Prototype disables frustum culling to prevent Three implicitly recomputing a skinned bounding sphere per frame. Host distance/TTL culling is still required.
- Source triangle partition/seam defects are unchanged; see `NPC_BLAST_SEAM_AUDIT20.md`. GPU feasibility does not constitute an approved final cut appearance.
- Material clones preserve standard material data and independent texture handles. Custom onBeforeCompile closures/uniforms (wet clothing/wounds) require their own explicit snapshot/clone contract; not tested here.
- Preparation is synchronous and tied to one actor's source mesh references; production needs its existing incremental preparation scheduler, geometry identity sharing and receipt/TTL/capacity lifecycle. Unsupported morph layouts are rejected. No gameplay receipt validation exists in this feasibility helper.
- No GPU browser run, ground integration or production hook was added. CPU normal/shading equality with the separately recomputed CPU-fragment normals is not claimed.
