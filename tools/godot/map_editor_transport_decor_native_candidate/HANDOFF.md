# Native transport/decor consumer — isolated, not integrated

Frozen companion input manifest SHA256:
`69ecbd14108fd151b504a41dc3d00ab5dbeca98b8c5ccd6251553fb60189546b`.
The exporter and its independent original-generator test remain unchanged.
This package is outside production `res://`; do not auto-install it.

## Verified CPU result

Godot 4.7.2 official `ed1daf0bf`: `test_transport_decor_factory.gd`
**232229 checks, 0 failures**, clean exit, approximately 1.38 seconds including
source admission and actual GLB import. No GPU, live FPS, lighting, shadow,
alpha/depth parity or gameplay acceptance is claimed.

All 265 semantic IDs are admitted without rewriting their original data:
39 parking lots, 59 bays, 78 surfaces, 57 signs, 1 rail alignment, 2 stations,
12 crossings and 17 explicit signals. The original railway additionally has
24 actual lamp parts, including 7 crossing-owned fallback lamps; these are
not invented extra editable IDs.

36 exact source ArrayMeshes are shared; buffers retain original positions,
normals, UVs and linear vertex/instance colors. Only triangle winding changes
CCW to Godot CW. 42 original untextured materials are shared; the other two
station-label materials await actual pixels. The actual Godot GLTF importer
was used as a CPU oracle for albedo and emission linear→sRGB conversion.

Parking builds 42 MultiMesh nodes and 856 exact source parts, one bulk upload
per batch, active count rather than larger backing capacity. Source metre
scale is retained (4.1 is not applied twice); the supplied origin is subtracted
once on the dataset root. Editing four bay parts changes only those indices,
with CPU-side transforms and updated conservative native custom AABBs.
Far-away moves, deletion, undo/redo, adapter failure restoration, source ID,
metadata and history preservation are checked.

## Host API and authority

`configure(source_dir, expected_manifest_sha, trusted_hooks)` verifies manifest
admission and every SHA-addressed buffer before constructing resources.
It loads no script, scene or arbitrary resource named by imported JSON.

`build_parking()` returns an unattached root. `build_railway()` returns HOLD
until both station capture and actual train factory gates pass. Neither
function starts traffic, collisions, train motion, ownership or AI.

`transform_object(key, native_transform)`, `delete_object(key)`, `undo()` and
`redo()` require `edit_lease()` returning true **after the owning runtime jobs
have been paused**. `edit_adapter(request)` must explicitly approve the exact
source SHA/record and provide `commit()` and `rollback()` Callables. It owns
all parking route/collider/ownership and rail route/nav/signal rebuilding.
No user boolean unlock exists. On owner commit failure, native source state
and history are restored. Failed owner rollback blocks further edits.

`source_metadata(dataset)` and `source_record(key)` return deep copies.
Walking routes, entry/exit rules, source colliders and rail route metadata are
not automatically activated or silently changed by geometric edits.

`update_parking_culling(native_focus)` keeps the original 300 m source filter
and conservatively admits edited parts; only CPU shadow data is read.
`update_railway(dt, context)` needs an explicit `motion_adapter` returning
three source-root-space car poses and all 24 lamp intensities. It receives
read-only original metadata, never self-enables the original runtime logic.
The owner must not resume motion until its edited routing is rebuilt.

## Train and station gates — HOLD

`required_station_captures()` returns the exact original canvas recipe,
1024×192 dimensions, original 600 66px Arial font and source identity for both
labels. The host must obtain pixels from the actual original browser canvas
with its font/rendering environment, verify live capture, and bind the exact
recipe and RGBA image SHA. No locally rendered font, invented image, blank
texture or placeholder is supplied. The captured pixels are currently absent.

The trusted `train_factory` receives the source GLB asset SHA, 27 exact merged
source mesh batches/materials, and the three original car frames. It must
return three unattached roots containing exactly their admitted MeshInstance3D
children, each with `source_train_batch` metadata, exact shared source mesh,
material and original car-local transform. Nested offset parents, empty
roots and placeholder geometry are rejected. Original GLB byte SHA and its
three authored car roots are checked by native GLTFDocument in the test.

Because station pixels remain HOLD, successful combined railway construction,
trusted railway edit/motion callbacks and live visual parity are **not yet
accepted**. The consumer contains those guarded paths but their final host
integration and positive combined scene test require the real pixel capture
and real runtime owner. Default HOLD leaves no partially attached railway.

## Run

Use the approved console executable with
`--headless --path outputs/map_editor_transport_decor_native --script res://test_transport_decor_factory.gd`.
Keep one existing game open; do not launch another GPU instance for this test.
