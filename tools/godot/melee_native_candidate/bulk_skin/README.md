# Full skin deformation — separate output-only candidate

This second prototype does **not** modify or replace the accepted geometry
candidate. Its C source, DLL, isolated project and fixtures have separate paths.
No production GDScript, scene, export, autoload or GPU run was changed/performed.
It supplies exact full vertex positions, not a bone envelope, sampled proxy,
deduplicated support hull, simplified geometry or new contact authority.

## API and exact arithmetic

The new class `MeleeNativeSkin` extends `Object`; call `.free()` after use.

```
skin(vertices: PackedVector3Array,
     joints: PackedInt32Array,
     weights: PackedFloat32Array,
     frames: PackedVector3Array) -> PackedVector3Array
```

There are four joint indices and four weights for every input vertex. Frames
contain four Vector3 values per bind slot: basis X column, Y column, Z column,
then origin. These are **already composed actual bind frames**, not a guessed
bone rotation or canonical rig substitute. Each vertex is evaluated in original
slot order using `point += (frame * vertex) * weight` for strictly positive
weights, with float32 rounding at every vector multiply/add. No preweighted
bindpoints, weight renormalization, combined weighted matrix, FMA contraction or
double intermediate changes the reference arithmetic. Zero influences reproduce
the source zero. Four influences and unnormalized sums preserve input order.

The implementation is stateless: each call validates and borrows packed input
storage only for that call, creates a fresh owned PackedVector3Array result, and
retains no array pointer, actor, skeleton, bind resource, revision or pose. Failed
calls return an **empty array**, never an earlier pose; callers must require the
complete expected vertex count before consuming the result. There is no hit/miss
or damage meaning in this result. Only the engine initialization thread is allowed.

Input bounds: 1..65,536 vertices; joint and weight counts exactly 4V; 1..1024 bind
frames, encoded by 4B vectors. Positions/frame components must be finite within
±10,000,000; weights finite in [0,1]. Active joint indices must reference an actual
supplied frame; inactive zero-weight slots are never read and may contain unused
indices. Negative/NaN weights fail closed rather than silently creating geometry.
Shear, nonuniform scale, reflection, and authored melee stretch are preserved;
this numerical kernel does not make those poses eligible for physical ragdoll.

## Bind mapping and host lifetime boundary

`capture_skin.gd` reads the existing hero's seven actual surfaces: **8,338 vertices,
13,034 triangles, 28 skeleton bones and 196 mesh-local bind slots**. It resolves
each mesh Skin bind with this exact rule:

1. Nonempty bind name uses `Skeleton3D.find_bone(name)`. Missing name rejects;
   it does not silently fall back to a different explicit index.
2. Empty bind name uses the explicit bind index, checked against actual bone count.
3. Vertex bone slots index their own mesh Skin table. When flattening surfaces,
   add that mesh's bind-table offset, not the skeleton bone index.
4. The host composes `actual world bone frame * actual bind pose` in original
   operation order, preserving full matrices and parent/motion frames.

The fixture uses the current source melee sampler and its exact full hierarchy,
with `visual * parent_frame * bone_global * bind_pose`, matching the existing
full-skin source oracle. Bind records, asset/source hashes, indices and all poses
are retained in the binary fixture. Name-priority, missing-name, valid explicit
index and invalid explicit index rules are tested against the actual rig API.

This fixture is an immutable snapshot, **not a live provider**. A future host must
own skeleton/mesh/Skin identity and lifetime, reject queued/freed/replaced owners,
rebuild immutable topology/bind mappings on resource changes, capture all frames
from one accepted current pose revision, then recheck that same owner/revision
before using the resulting vertices for the existing native geometry refit.
Changing actor life cannot be detected from four anonymous packed arrays; the DLL
does not pretend otherwise. No new authority framework or permission callback is
introduced. Bone/current-pose resolution, occlusion, contact and HP stay outside.

## Comparison and evidence

Author **183,599 PASS**, `outputs/coordinator21_melee_native_skin/report.json`.
All **183,436 tested actual vertices (22×8338)** match the current native scalar
reference **byte-for-byte**, not only within an approximate distance threshold.
The 22 poses include twelve original JS skin canaries, ordinary punch/heavy/
backfist endpoints and midpoints, and a translated/rotated/nonuniform world frame.
Twelve original executed-JS full-skin oracle cases also remain within the existing
native import/pose precision bound: max **0.081308 mm**, aggregate RMS **0.014507 mm**.
The new skin kernel adds **zero** error to the current native scalar result.

Additional coverage: four weighted influences without normalization, zero weights,
shear/reflection, malformed Variant/counts, bad weights/active indices/frame data,
array limits, result/input mutation isolation, worker rejection and fifty fresh
object create/call/free cycles. This is author evidence, not independent hostile
memory-safety review or completed release packaging.

The simpler built-in alternative was implemented and measured first: transform
rigid vertex groups using `Transform3D * PackedVector3Array`, scatter their results
back to original vertex order, and run the unchanged scalar loop for mixed skin.
It also matches all tested output bytes. This fixture has **6,259 rigid vertices
in 19 groups and 2,079 mixed vertices**. All repeated/duplicate surface vertices
are retained, unlike a grounding-only support cache.

Paired CPU measurements, same 22 actual poses, 16 warmups + 80 measured iterations,
alternating execution order, microseconds:

| Work | p50 | p95 | max |
|---|---:|---:|---:|
| Current scalar math, preallocated output | 2479 | 2901 | 3460 |
| Engine rigid bulk + original mixed loop + scatter | 1034 | 1354 | 1532 |
| New C kernel + Godot boundary + validation/allocation | 114 | 169 | 226 |
| Pack 196 existing bind frames | 25 | 42 | 78 |
| C kernel plus frame packing, measured together | 140 | 211 | 267 |

The earlier ~4.6 ms observation included fixture construction/bind setup; the
paired preallocated scalar baseline above is intentionally leaner. Do not compare
the new 0.14 ms against that old one-shot setup as a paired speedup claim.
These numbers exclude source pose sampling, bone hierarchy/bind composition,
live lifetime checks, downstream refit/query, physics, GPU and scene FPS. Other
project CPU work was not globally stopped. Independent live integration remains
open; no content or collision detail was removed to produce these timings.

## Reproduce and distribution

Use the already SHA-verified portable compiler cache documented in the parent
candidate README. From repository root: `& tools/godot/melee_native_candidate/bulk_skin/run.ps1`.
This builds only the new DLL, captures actual hero data headlessly, then runs the
isolated headless check. The runner treats logged script errors as failure and
uses a bounded frame timeout to avoid leaving a failed test process running.
Run only outside the coordinator's GPU measurement windows.

Godot ABI remains pinned to 4.7.2 standard float32 real / 64-bit pointer build,
with the same runtime Vector3 12-byte check and compile-time sizes. Compiler
flags retain `-fno-fast-math -ffp-contract=off`. `../gdextension_interface.h` and
`../licenses/` are read-only shared official ABI/licensing inputs. Keep the LLVM
and MinGW runtime notices if distributing this DLL. PE imports are recorded
separately in this prototype's outputs. No compiler PATH/global install or external
runtime dependency was added.

Frozen new C SHA:
`485a28d5117254d0d377fda495500ef48e0283f9638873589ba8e596e9a05b25`.
Frozen new DLL SHA:
`f9de67f74d31f994c0b90807b55282b30a4d3cafbf8f5397a502bfd636a0a111`.
Original accepted geometry C `c6a4a21a…` and DLL `2e7427c8…` were hash-checked
unchanged after this work. No changes to their accepted interface or implementation.
