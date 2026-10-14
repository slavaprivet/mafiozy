# Isolated native melee geometry candidate

This is a prototype, **not installed in the live Godot project**. It owns no actor,
pose, life, damage, hit admission, occlusion, attack clocks, or source authority.
The parent host must still validate current pose revision/life and perform its
real contact/occlusion/consequence checks. A geometry hit alone is not admission.

## Build provenance and reproduction

Windows x64, official Godot **4.7.2**, standard single-real build, current engine
commit `ed1daf0bf001b61586d9930840f2f1394092c079`. `gdextension_interface.h` and
`abi_manifest.json` were produced from that actual engine's
`--dump-gdextension-interface --dump-extension-api`; no godot-cpp dependency.
The full generated API is in `outputs/coordinator21_melee_native/extension_api.json`.

Portable compiler: official llvm-mingw release **20260616**, clang **22.1.8**,
`llvm-mingw-20260616-ucrt-x86_64.zip`, 187,504,083 bytes. Published GitHub release
asset SHA256, checked before extraction/execution:
`b9b68a4d276e16fa25802aaba458e4638f64b3884c290aaccdc2d87083b6ca35`.

Official metadata: <https://api.github.com/repos/mstorsjo/llvm-mingw/releases/tags/20260616>.
Official archive: <https://github.com/mstorsjo/llvm-mingw/releases/download/20260616/llvm-mingw-20260616-ucrt-x86_64.zip>.
`acquire.ps1` verifies both the pinned official digest and downloaded bytes. It only
uses `outputs/tools`; no global install or PATH modification. `build.ps1` verifies
the archive again and invokes the absolute compiler path. Build flags:
`-std=c11 -O2 -fno-fast-math -ffp-contract=off -shared -static`.
Source arithmetic order remains explicit; no fast-math or contracted FMA.

From repository root, PowerShell:

```powershell
& tools/godot/melee_native_candidate/acquire.ps1
& tools/godot/melee_native_candidate/build.ps1
$engine = 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$repo = (Get-Location).Path
& $engine --headless --path "$repo/godot/mafiozi_walk" --script "$repo/tools/godot/melee_native_candidate/capture.gd"
& $engine --headless --path "$repo/outputs/coordinator21_melee_native/project" --script "$repo/tools/godot/melee_native_candidate/verify.gd"
```

Capture only instantiates the existing real hero and reads actual skinned geometry.
It does not load this DLL into the main project. The isolated test manually loads
`candidate.gdextension`. No native/GPU test, export, Git action, or live autoload
has been performed. Re-run only outside the coordinator's GPU measurement window.

## ABI and ownership

`MeleeNativeGeometry` extends `Object`; instantiate with `ClassDB.instantiate` and
**call `.free()`** when retiring that host. It deliberately has no gameplay lifetime.
Each instance owns copied vertices, immutable indices, BVH nodes, and hit storage.
No borrowed PackedArray pointer survives its call. Every accepted refit invalidates
old queries, and every failed refit makes the old geometry unavailable. Valid newer
refit can recover the same topology. Use a new instance to replace topology.

Generated `float_64` means float32 native real and 64-bit pointers, NOT double-real.
Vector3 is exactly **12 bytes**, PackedVector3Array/PackedFloat64Array are opaque
16-byte handles, StringName/String are 8 bytes. Startup checks exact 4.7.2 and
constructs Vector3 into an oversized scratch buffer to verify precisely 12 bytes
are written, rejecting a double-real build before reading any vertex buffer.
Compile-time checks enforce 64-bit pointers and IEEE-sized float/double.
Methods reject calls outside the captured engine initialization thread.

Topology bounds: 1..65,536 vertices, 1..131,072 triangles; all indices integral and
in bounds; all positions finite and within +/-10,000,000. Radius finite `(0,.5]`.
Revisions are externally supplied exact integers `0..2^53-1`, strictly increasing
on refit. Sweeps 1..4, result pages 1..256. All counts and complete payload lengths
are validated before indexing/allocating. Output allocation failure yields an
empty PackedArray: the caller must treat **every unexpected shape as failure**.
No native pointer, engine resource, or asynchronous callback escapes.

`run(payload: PackedFloat64Array) -> PackedFloat64Array`:

| Operation | Payload | Success |
|---|---|---|
| Kernel | `[0, fromXYZ, toXYZ, radius, aXYZ, bXYZ, cXYZ]` (17 numbers) | 16-number kernel row below |
| Configure | `[1, revision, V, T, verticesXYZ..., indices...]` | `[1,V,T]` |
| Refit doubles | `[2,newRevision,V,verticesXYZ...]` | `[1,revision,nodeCount]` |
| Begin query | `[3,revision,sweeps,pageSize,(fromXYZ,toXYZ,radius)*sweeps]` | page |
| Next page | `[4,revision,queryID,pageSize]` | page |
| Cancel | `[5]` | `[1,revision,newQueryID]` |

Use **`refit_vertices(vertices: PackedVector3Array, revision: int)`** for the hot
path. This widens each real float32 component directly to scalar double in C,
copies/refits once, and avoids per-vertex GDScript float64 repacking. Return shape
is the same as the double refit. Configure remains a one-time float64 payload.

Kernel row: `[valid,hit,pointXYZ,lineXYZ,normalXYZ,weightsXYZ,score,distanceSquared]`.
To reproduce GDScript Vector3 semantics, convert XYZ/weights to native Vector3;
score/distance remain double. Degenerate faces return `valid=1,hit=0`.

Page: `[1,revision,queryID,totalHits,cursorBefore,count,16,rows...]`.
Each row: `[triangleIndex,limbIndex,pointXYZ,lineXYZ,normalXYZ,weightsXYZ,score,distanceSquared]`.
Rows are ordered by exact score, then original triangle index, then original sweep
index. Thus ties preserve the source winner, irrespective of BVH traversal order.
All later candidates remain available if the nearest is rejected. An exhausted
page is `count=0`; `totalHits=0` is a geometry miss only for a successful valid
query. Errors are `[-1,code]`, never a miss or successful empty page.

Codes: 1 context/thread/op; 2 length; 3 finite/range/radius; 4 already configured;
5 topology/revision/count; 6 index; 7 native allocation; 8 refit; 9 stale/page;
10 query; 11 unrepresentable kernel arithmetic; 12 Variant argument type/count.

This prototype computes and sorts the **complete query synchronously** before
returning its first page; paging bounds output copies, not native compute time.
There is no `PENDING` state yet and no resumable mid-query cancellation. Worst
allowed topology/sweep input is bounded but has **not** been latency-qualified.
Do not use it as a time-budgeted drop-in replacement without that host review.
Candidate storage is capped at `T*sweeps` (128-byte candidates, at most 64 MiB),
plus mesh/BVH buffers. It does not silently discard candidates to meet a budget.
The result order is geometric winner order, not permission/effect callback order:
side-effecting source callbacks must remain host-owned and must not be dispatched
automatically for every returned candidate.

## Evidence, CPU scope, and remaining gates

`outputs/coordinator21_melee_native/report.json` final author test: **11,832 PASS**.
Includes original executed-JS oracle **288** rows, thin/parallel/degenerate cases,
all returned contacts for the real **8,338 vertices / 13,034 triangles**, exact
score and native Vector3 equality to current GDScript kernel, tied triangles and
limbs, complete paging, cancellation/stale revisions, invalid direct refit,
borrowed-input mutation, malformed Variant/shape/index, 100 create/query/free
cycles, and worker-thread rejection. Maximum compared double scalar error **0**.
This is author evidence, not independent acceptance or an adversarial memory-safety
proof. Different animations/very large topologies still need review.

Final isolated CPU sample: 16 warmup + 64 measured calls, microseconds:

| Work | p50 | p95 |
|---|---:|---:|
| Direct PackedVector3 refit, including Godot boundary | 182 | 270 |
| Old diagnostic GDScript float64 packing alone | 4701 | 5998 |
| Already-packed float64 refit, including boundary | 232 | 350 |
| Head radius .14, complete native query + all 1074 results | 485 | 599 |
| Chest radius .10, complete query + all 361 results | 130 | 142 |
| Shin radius .10, complete query + all 72 results | 34 | 59 |

One-time topology build 11.915 ms. Separate real skin capture 4.624 ms **single
sample**, not a warmed skin benchmark. Upstream deformation, real owner checks,
visibility queries, and damage are **not included** in native timings. Single
linear-reference timings in JSON are correctness work, not a paired p50/p95
performance claim. Concurrent other CPU work was not globally stopped. Loaded
scene FPS/GPU performance remains unmeasured; no content was removed.

Before adoption: independent C/ABI/lifecycle review; source/runtime owner seam;
current-pose refit scheduling; final package DLL loading/licensing receipts;
target hardware worst-case/cancellation budget; actual loaded-scene timing.

## Distribution

The compiler is portable build tooling in outputs, not a shipped dependency.
Included `licenses/LLVM-LICENSE.TXT` preserves Apache-2.0 with LLVM exceptions;
`COPYING.MinGW-w64-runtime.txt` and `COPYING.MinGW-w64.txt` preserve bundled
runtime notices. The latter explicitly requires binary distributions to include
the runtime copyright/license notices. Godot's MIT header notice is retained.
Keep these notices with any candidate DLL distribution; do not redistribute the
whole compiler bundle as though these few notices cover every bundled program.

`pe_imports.txt` shows only Windows KERNEL32/UCRT API-set imports, no LLVM,
libc++, libwinpthread, or Godot-cpp runtime DLL. Load already passed with no PATH
edits and no compiler directory in the isolated project. Final release/export
packaging and independent review remain separate gates.

Independent review found malformed Variant/count direct refits previously left old
geometry ready. Fixed in vertices_call: owner-thread validation failures clear query
and ready state; wrong-thread attempts are rejected before touching owner state.
Author adds 12 malformed call forms, old-page/old-geometry rejection, valid recovery,
and malformed foreign-thread non-mutation (50 additional checks). Prior report is
retained as report_before_invalid_type_fix.json. Independent final rerun: 31,197 / 31,197 PASS on DLL 2e7427c8; both findings corrected.

The independent epsilon-boundary review also found tight radius-only broadphase
boxes could discard contacts admitted by the kernel's squared-distance tolerance.
Both BVH and triangle overlap now use nextafter(sqrt(r*r+1e-10), +infinity), with
each minimum/maximum endpoint rounded outward using nextafter. Narrowphase radius
and source math are unchanged. Added transformed boundary hit and definite-miss
checks (42 assertions); all real-hero candidate sets stay identical.

Independent receipt: outputs/coordinator21_melee_native_review/report.json and
REVIEW.md. Covers maximum legal topology, revision limits, worker malformed calls,
all four actual hero zones, 288 original oracle rows, and 1204 ordered tie pages.
Independent CPU refit p50/p95 .185/.293 ms; head all1074 .440/.584 ms. These remain
isolated CPU receipts, not release packaging or live combat/FPS acceptance.
