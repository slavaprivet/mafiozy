# Combined native melee kernels — staged source, inactive descriptor

**Not activated in the shared game/editor.** This directory has source, build/test
scripts, licenses, and `melee_kernels.gdextension.cfg` as an **inactive template**.
There is no `.gdextension` file or DLL here. Build output goes only to
`outputs/coordinator21_melee_combined/project`. Root owns the final descriptor/DLL
placement, staging, loading, export presets and live integration approval.

## Accepted source composition

The numerical C and header files are byte-for-byte copies of independently
accepted isolated candidates. `build.ps1` checks their exact hashes before every
compile. They are compiled as separate translation units; their static globals,
class registration and lifecycle handlers remain separate. Only `src/combined.c`
is new composition code: it prepares both modules, initializes geometry then skin,
and deinitializes in reverse order. Both original engine/architecture/thread/ABI
guards remain active. Failed preparation registers no classes.

| Pinned input | SHA256 |
|---|---|
| `src/native.c` | `c6a4a21a8b328f4cde4579f43d57b836af1e5554aaa594e863f20c0dfed0c4ad` |
| `src/kernel.h` | `34bcdaa050cd186ea00b5b407d332f46421bc7e48c1a01afd406469ab21a8090` |
| `src/bulk_skin/native_skin.c` | `485a28d5117254d0d377fda495500ef48e0283f9638873589ba8e596e9a05b25` |
| Generated ABI header | `640b48188708ba0016f8d7ace9e0e1d3279a41fa1226c59ff3193b15538bd254` |

The DLL exports **exactly one entry symbol**, `melee_kernels_init`. To retain the
accepted C bytes while removing their former individual exported entrypoints,
the build inspects each object using `llvm-readobj --coff-directives`: the entire
directive must be precisely its expected `-export:melee_native_init` or
`-export:melee_skin_init`. It then removes only that `.drectve` linker metadata
section with `llvm-objcopy`. Unexpected metadata fails the build. Numerical code,
data and symbol definitions are not rewritten. The combined unit exports the
single entry and links with automatic exports disabled.

## Reproducible build and ABI

PowerShell from repository root:

```powershell
& godot/mafiozi_walk/native/melee/build.ps1
& godot/mafiozi_walk/native/melee/run-tests.ps1 -SkipBuild
```

The existing portable official llvm-mingw **20260616 UCRT x86_64** cache is required
at `outputs/tools/llvm-mingw-20260616-ucrt-x86_64`; no global installation or PATH
change. Before invoking its tools the build verifies the official archive SHA256
`b9b68a4d276e16fa25802aaba458e4638f64b3884c290aaccdc2d87083b6ca35`.
Official release metadata: <https://api.github.com/repos/mstorsjo/llvm-mingw/releases/tags/20260616>.
Archive: <https://github.com/mstorsjo/llvm-mingw/releases/download/20260616/llvm-mingw-20260616-ucrt-x86_64.zip>.
The existing `tools/godot/melee_native_candidate/acquire.ps1` supplies this cache
with published-digest verification; it is build tooling, not a shipped dependency.

Compiler is clang **22.1.8**. Both kernels use `-std=c11 -O2 -fno-fast-math
-ffp-contract=off`; the link uses static compiler support, no PE timestamp, and
no automatic exports. **Two complete builds produced identical DLL bytes**, SHA256
`a5695c0b117e42a4847d10cdef0f7b71485f6243a7f412b6d6cb0eb5924c2add`.
Receipt: `outputs/coordinator21_melee_combined/reproducibility.json`.
This is reproducibility with the pinned toolchain/inputs; other compilers/platforms
are not claimed equivalent. Initial debug/release descriptor branches intentionally
select the same tested optimized DLL, not an untested alternate binary.

ABI is the header/API dumped from official Godot **4.7.2**, commit
`ed1daf0bf001b61586d9930840f2f1394092c079`, standard float32 real, 64-bit pointers.
Runtime checks reject a different engine version or a Vector3 representation that
does not write exactly 12 bytes. Compile-time checks enforce the expected scalar,
pointer and packed-handle sizes. `abi_manifest.json` records generated API sizes.
There is no godot-cpp, CLR, compiler DLL or C++ runtime dependency. PE import/export
receipt shows only KERNEL32 and Windows UCRT API sets and the one combined export.

## Factory and unchanged APIs

Root-controlled explicit loading of the descriptor registers both classes:

```gdscript
var geometry: Object = ClassDB.instantiate("MeleeNativeGeometry")
var skin: Object = ClassDB.instantiate("MeleeNativeSkin")
# Supply either object or a Callable factory to the real owner/provider.
# Each owner frees its own Object when retired.
```

`MeleeNativeSkin.skin(vertices: PackedVector3Array, joints: PackedInt32Array,
weights: PackedFloat32Array, frames: PackedVector3Array) -> PackedVector3Array`:
four joints/weights per vertex; four vectors per bind frame (basis x, y, z, origin).
It performs original slot-order float32 transform/weight/add arithmetic, keeps all
vertices, and returns an independent array. No configure step or actor lifetime is
stored. Empty means failure, so the host must require the expected full vertex
count. Bind-name/explicit-index resolution, mesh bind offsets, queued/free/replaced
owners, current frame/revision capture and real source admission are host-owned.

`MeleeNativeGeometry.run(PackedFloat64Array)` retains operations 0 kernel, 1
configure, 2 double refit, 3 query, 4 page, 5 cancel. Its direct hot input is
`refit_vertices(PackedVector3Array, revision: int)`. Output pages retain every
candidate in exact score/triangle/limb order. Errors are not misses; invalid refit
invalidates old ready state; wrong-thread calls never mutate owner state. Geometry
owns copied topology/current vertices and must be freed at host retirement.
The bulk-skin output feeds direct refit without a per-vertex GDScript repack.

This packaging adds no source attack/contact/HP authority. Query construction is
still synchronous; paging bounds output, not native compute time. Host scheduling,
pose revisions, cancellation policy, actual occlusion and consequences remain
mandatory integration work. The kernels do not authenticate anonymous arrays.

## Combined isolated validation

All tests use headless isolated projects, never the shared editor/GPU. Tests are
adapted from accepted candidate harnesses only for descriptor/DLL/report/output
paths; numerical oracles/assertions remain intact. Capture scripts read the actual
existing hero and source fixtures, producing all 8,338 vertices / 13,034 triangles.
Run-tests aborts on logged engine/script errors as well as exit codes, and applies
a bounded frame timeout to avoid leaving failed test processes alive.

- Geometry: **11,832 PASS**, original JS oracle 288, thin/parallel/epsilon cases,
  all actual hero candidates, ties/pages, malformed input, failed refit/stale query,
  cancellation, copied storage and worker/lifetime checks.
- Skin: **183,599 PASS**, all 22×8,338 outputs byte-identical to original scalar
  float32 results; original twelve JS skin canaries preserve their prior precision
  bound. No geometry/support subset replaces full skin.
- Combined lifecycle: **30 PASS**, three load/instantiate/free/unload cycles,
  both classes coexisting, skin → direct refit → real triangle query, failure
  isolation, and both class registrations absent after each unload.

Reports: `outputs/coordinator21_melee_combined/{geometry_report,skin_report,
lifecycle_report}.json`. Independent original-kernel evidence is recorded in
`outputs/coordinator21_melee_native_review` and
`outputs/coordinator21_melee_native_skin_review` (reviewer-owned paths).
The accepted isolated source/DLL files were not changed by packaging.

These checks establish packaged CPU behavior, not final exported-game loading,
live host ownership or loaded-scene FPS. Root must separately review/activate the
real descriptor, include the DLL/notices in export, and measure the actual scene.

## License materials

Godot's generated C header retains its MIT notice. `licenses/` carries the unchanged
LLVM Apache-2.0-with-exceptions and MinGW-w64/runtime notices. Keep these with any
binary distribution, including the MinGW binary notice requirements. Do not ship
the whole compiler bundle using only this subset of its component notices. Project
numerical sources retain their existing project ownership; no new third-party
license or permission to drop original attribution is inferred.
