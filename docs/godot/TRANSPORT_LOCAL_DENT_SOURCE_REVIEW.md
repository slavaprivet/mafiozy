# Transport local damage source review

This is a source contract and implementation research note. It does not grant
damage authority and does not claim a Godot integration.

## Pinned source

| File | SHA-256 | Relevant lines |
|---|---|---|
| `assets/maps/city_rebuild_v1/vehicle_damage.mjs` | `e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92` | 55-66 state/pools; 92-100 scratch state; 161-188 dent/mark; 189-245 bullet/contact/scratch; 276 glass-at-wreck; 306 reset |
| `assets/maps/city_rebuild_v1/vehicle_crash.mjs` | `cceffb5b6e65a1d180e8860d471351bf04340439ad605a66d6143daf53b20e44` | 7-28 shared subdivision; 45-121 cage deformation |
| `assets/maps/city_rebuild_v1/glass_breakage.mjs` | `d5b8f7380eb716067203395808e7c94ed45cc44ff4d7cfc4bb1d278b24cecf3a` | 4-36 admission/panels; 39-44 hull/RNG; 46-67 pools/ownership; 69-107 decoration/fracture/shards; 109-128 hit/shatter; 130-153 lifetime/reset |

The existing deformation oracle pins Three.js revision 180. Any new oracle
must pin that revision and all source hashes again.

## Local dent buffer contract

`dent()` is presentation-only and rejects a missing position attribute,
transparent material, and every mesh below a `vehicleWheelId` ancestor
(`vehicle_damage.mjs:170-173`). The tyre adapter owns wheel deformation.

On the first accepted hit, the source selects the geometry that is already on
the mesh. Unless it has `vehicleCrashSubdivided`, it calls the shared exact
subdivider with `maxEdge=.15` and `maxTriangles=9000`. It stores:

- `original`: the authored geometry captured when `createVehicleDamage()` ran;
- `geometry`: the current tessellated geometry object;
- `base`: a typed-array slice of the current position buffer;
- `offset`: a same-length `Float32Array`, initially zero.

The nearby private `deformableGeometry()` at lines 161-169 is not called by
`dent()` in this revision. A port must follow the imported
`subdivideVehicleGeometry()` path at line 173, not that historical helper.

Bullet dents set the cumulative displacement cap to at least `0.18 m`;
collision dents set it to at least `0.40 m`. The larger cap persists.

Before **every** dent, including the first one after a cage update, the source
rebases every coordinate exactly as:

```text
base_f32[i] = f32(current_position_f32[i] - old_dent_offset_f32[i])
```

This is the essential composition rule. The current mesh can contain a newer
cage deformation. Subtracting only the prior local dent recovers that changing
cage result as the new baseline. If the geometry object changed, the source
instead adopts all current positions as a new base and clears the dent offset
(`vehicle_damage.mjs:175-180`). A native consumer therefore needs an explicit
topology/geometry revision and must clear or rebuild offsets when vertex order
or count changes. After an in-place dent it must notify the cage adapter that
positions changed before the next structural snapshot.

The world hit point becomes mesh-local through `mesh.worldToLocal()`. The
world normal is transformed with `Vector3.transformDirection(inverse(
mesh.matrixWorld))`, which applies the inverse linear basis and normalizes it.
This exact operation must be retained, including under roll and non-uniform
scale. It must not be silently replaced by a normal-matrix conversion.

The radius and depth are:

| Hit | Radius | Depth | Total displacement cap |
|---|---|---|---|
| Bullet | `0.10 + min(0.20, sqrt(damage)*0.014)` | `min(0.10, 0.008 + damage*0.00055)` | `0.18 m` |
| Collision | `min(1.10, 0.30 + impactSpeed*0.035)` | `min(0.30, 0.012 + impactSpeed^2*0.0028)` | `0.40 m` |

For each base vertex, the source computes Euclidean distance `d` to the local
hit. Vertices with `d >= radius` do not change. The accepted displacement is
`amount = depth*(1-d/radius)^2` and is accumulated on the **current** position
along `-localNormal`. The resulting vector from the rebased `base` is clamped
to the persistent cap. Position writes and all stored base/offset values land
in Float32 buffers; intermediate JavaScript arithmetic is binary64. That
rounding order is observable over repeated hits:

1. read `base_f32`, `current_f32`, and `offset_f32` into binary64 arithmetic;
2. calculate the new point and cap in binary64;
3. `setXYZ` rounds the position to Float32;
4. `offset[j] = x-base[j]` separately rounds the new offset to Float32;
5. the next rebase subtraction is calculated from those two Float32 values and
   assigned back to a Float32 base.

After any accepted call the source marks positions dirty and recomputes every
vertex normal, bounding box, and bounding sphere, even if no vertex fell inside
the radius (`vehicle_damage.mjs:181-182`). A port may avoid a GPU upload only
after proving the source output is byte-identical for the no-change case; it
must still preserve the observable cached bounds/normals contract.

## Bullet mark contract

The bounded pool has 32 entries. Physical indices divisible by three are thin
scratch planes (`.22 x .008`); the others are combined crater/rim meshes. A
bullet skips scratch indices. Reusing a slot reparents and overwrites that
pooled object; marks are not unbounded (`vehicle_damage.mjs:65-78,184-188`).

For a bullet mark:

1. transform the selected world point to the hit mesh's local frame;
2. transform the supplied world normal by the inverse world matrix through
   `transformDirection()`;
3. offset the local point by `0.007 m` along that local normal;
4. rotate local `+Z` onto the local normal;
5. use uniform scale `min(3.2, 0.75 + sqrt(max(0,damage))*0.16)`;
6. rotate around local Z by `markCursor*2.399` **after** incrementing the
   cursor.

There is no RNG consumption. The `2.399` rotation is deterministic.

Bullet admission derives a material index from the hit face or geometry groups.
An admitted breakable-glass hit returns `false` before HP, dent, or mark work.
The separate glass adapter owns it (`vehicle_damage.mjs:189-200`). For opaque
body hits the dent uses the supplied point/normal, then a short ray can replace
the mark point and normal with the actual current deformed surface.

One source edge case is observable: while the vehicle remains neither wrecked
nor destroying, a duplicate `eventId` can leave HP state unchanged yet still
enter the visual dent/mark branch; `impact()` then returns `false` after the
presentation mutation (`vehicle_damage.mjs:198-200`). A native authority layer
should deduplicate before calling a pure dent provider. The provider itself
must not infer a new authority grant from this presentation-side quirk.

## Collision dent and scratch contract

`contactImpact()` enforces the `.25 s` cooldown. Point, normal, impact speed,
and slide speed must be finite. Speeds clamp to non-negative values. A normal
with squared length below `1e-8` is rejected; otherwise it is normalized and
flipped to point from the vehicle centre toward the obstacle
(`vehicle_damage.mjs:202-220`).

The panel ray starts at `point + normal*0.8`, points along `-normal`, and uses
near/far `0/1.65`. Candidates must be visible, opaque, non-wheel geometry and
must not belong to damage effects. A gap or wheel contact can still reach the
mechanical crash system, but it creates no unrelated opposite-side dent.

For a hit panel, the face normal is transformed to world space with the normal
matrix and normalized. A collision dent uses the formulas above. The source
then raycasts the newly deformed panel again so the paint damage lies on the
new surface (`vehicle_damage.mjs:223-228`).

At `slideSpeed >= 1.5`, the source chooses a physical scratch slot even after
the 32-slot cursor wraps. The tangent is the supplied slide direction or
`UP cross surfaceNormal`, projected onto the surface and normalized. Degenerate
fallbacks are `(1,0,0)` projected onto the surface, then `(0,0,1)`. The scratch
first receives the normal mark transform and scale `2.2`, then its final basis
is:

```text
x = normalized world tangent transformed by inverse(mesh.matrixWorld)
z = local +Z transformed by the mark's normal-facing quaternion
y = normalize(z cross x)
```

The final local scale is:

```text
(min(5, 1 + slideSpeed*0.16),
 1 + min(2, impactSpeed*0.12),
 1)
```

There is no RNG in collision marks or scratches. With lower slide speed, a
round collision mark uses uniform scale `2.2`.

## Glass contract relevant to vehicle damage

`isBreakableGlass()` prioritizes explicit mesh/material `breakableGlass`
metadata. Otherwise it recognizes material labels containing glass/glazing/
windshield/windscreen, a non-array mesh name with those words, or a transmitting
non-zero-opacity material (`glass_breakage.mjs:4-12`). Mixed-material meshes
must opt in by material.

The vehicle damage adapter itself does two things:

- an ordinary bullet stopped by admitted breakable glass does not also damage
  or dent the body;
- the final vehicle explosion hides meshes collected as transparent when the
  adapter was created (`vehicle_damage.mjs:61-63,192-199,276`).

Actual pane fracture is owned by `glass_breakage.mjs`:

- panels connect only through shared **edges** within one material; authored
  UV/normal seams weld by position keys rounded to `1e-5`; corner contact alone
  does not connect panels;
- zero-area triangles with cross-product length squared below `1e-16` are
  excluded;
- each affected mesh or instance receives private index ownership; broken
  faces keep their face slots but become degenerate by setting indices 1 and 2
  to index 0;
- a decoration fractures after `0.085 s`; a failed decoration fractures the
  indices immediately;
- decoration/crack/rim positions are emitted as Float32 attributes;
- shard geometry and simulation use fixed bounded pools. Default limits are
  192 shard slots, 80 decorated panels, and 28 shards per hit.

Glass RNG is isolated from shared gameplay randomness. It is the 32-bit LCG:

```text
state = (1664525*state + 1013904223) >>> 0
draw = state / 4294967296
seed = (panel.id+1)*7919 + (instanceId ?? 0)*113 + totalBroken*601
```

Decoration consumes two draws per rim segment, plus three more while fewer
than 42 spokes exist. Four crack rings consume two draws per spoke per ring.
Each emitted shard then consumes exactly 16 draws: two for hull interpolation,
one size, three velocity, three rotation, three spin, one lifetime, and three
colour components (`glass_breakage.mjs:79-107`). Hull length and rim step count
therefore affect the RNG position before shard emission. A port must reproduce
the whole earlier draw sequence rather than seed each shard independently.

## Exact oracle plan

Create two Node exporters that import the real modules through the existing
Three.js r180 hook. Do not copy their formulas into the exporter.

### Dent/mark oracle

Build a synthetic transformed, rolled, non-uniformly scaled opaque panel with
multiple material groups, then call the public `createVehicleDamage()` API.
Capture the Float32 position/normal buffers, bounding box/sphere, and pooled mark
local transforms after each step:

1. first bullet dent and mark;
2. repeated bullet at the same point;
3. external in-place cage edit followed by a dent, proving
   `base=current-oldOffset`;
4. geometry-object replacement followed by a dent, proving offset reset;
5. collision dent without slide;
6. collision dent with scratch and cursor wrap;
7. no-hit gap/wheel cases;
8. reset restoring authored geometry and hiding the pool.

Include points exactly at radius, one Float32 neighbour inside/outside, cap
saturation, large finite damage/speed, and reflected/rolled frames. Record the
input event stream and every resulting Float32 buffer byte-for-byte. Pin source
SHAs and Three revision in the fixture.

### Glass oracle

Use `createGlassBreakage()` on indexed synthetic panes containing shared-edge,
corner-only, UV-seam, mixed-material, instanced, and degenerate triangles.
Capture discovered panel membership, private indices before/after `.085 s`,
crack/rim Float32 buffers, seeded shard matrices/colours, pool wrap, and reset.
Run the exporter twice and require byte-identical fixtures. This separately
proves material admission and the complete LCG draw sequence.

## Native implementation and optimization guidance

The finished provider should accept an identity/generation-bound event and a
prepared mesh row containing authoritative Float32 `base`, `dent_offset`, and
current positions. It returns a fully staged replacement buffer, normals,
bounds, sphere, and the next offset. It grants no HP, collision, weapon, glass,
or ownership authority. Reject stale topology/geometry revisions before any
mutation and commit all affected surfaces atomically on the main thread.

Useful built-ins and bounded optimizations:

- use `WorkerThreadPool` jobs over private packed arrays, then commit resources
  on the main thread; the existing cage adapter already demonstrates this
  ownership pattern;
- transform the point and normal once per mesh. A custom/native packed loop is
  appropriate for the radial scan; Godot has no built-in cumulative dent
  operator;
- compare squared distance before taking a square root for accepted vertices
  only **after** an oracle proves boundary parity with `d >= radius`;
- combine changed-position, normal, AABB, and sphere work in a native pass only
  if its Float32 order matches Three.js `computeVertexNormals`, bounding box,
  and bounding sphere;
- keep a conservative spatial index only if cage motion and the persistent
  `0.40 m` displacement cap are included in its query expansion. It may not
  skip artist vertices to save time;
- use two `MultiMeshInstance3D` pools for crater marks and scratches. Their
  transforms can remain under the vehicle root, preserving the bounded pool
  while reducing per-mark nodes/draw submissions;
- use a `MultiMeshInstance3D` and fixed packed simulation records for glass
  shards, matching the source's bounded GPU pool.

Avoid `MeshDataTool`/`SurfaceTool` in the impact frame; both add conversion and
allocation. `ArrayMesh.surface_get_arrays()` returns copies, so a provider must
own authoritative CPU buffers. RenderingServer partial vertex updates may be a
render upload optimization only after verifying format/stride and keeping the
CPU buffer authoritative; they cannot replace the geometry used by collision,
evidence, reset, or later cage composition. Do not postpone the event, reduce
subdivision, omit normal/bounds work, or discard content to hide the cost.

The expected first integration seam is:

```text
prepare(mesh identity, topology revision, Float32 buffers)
apply_local_dent(event, expected revision) -> staged buffer result
commit(result) -> notify cage adapter positions changed
reset/dispose -> authored geometry and pooled effects restored
```

Performance acceptance requires the actual subdivided vehicle profile, repeated
cumulative hits, a simultaneous cage update, mark/scratch pool wrap, and glass
fracture. Report per-stage p50/p95/max and the loaded-scene frame impact. An
isolated source oracle or CPU microbenchmark is not integration acceptance.
