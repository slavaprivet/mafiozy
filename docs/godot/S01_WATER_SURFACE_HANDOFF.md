# S01 native water surface handoff — Artist21, 26 September 2026

## Status

READY for root21 integration review. Author actual Godot4.7.2 headless **44 checks PASS**, exit0/no errors. Receiver Python deterministic export `--check` PASS and independent actual-source JS oracle **1818/1818 depths exact, max error0**. Full native water crop303 cells /1818 source vertices /606 triangles assembled into one ArrayMesh/MeshInstance3D. No main/project/collisions/physics/source Walk edits. GPU shader compile, visual parity, same-scene before/after frame metrics and inclusion in visible release remain OPEN until root hooks and tests in its single window.

Latest confirmed visible game is root release05 PID2868, `exports/win64/s01-20260926-jump-interior05/MafioziPreview.exe`, lifetime session67057 owned by root. It includes jump/interior progress, **not this unhooked water surface**. Screenshot `outputs/godot_release05_live.png` reviewed: HUD says typographer opens through E. Do not close or start a second game.

## Files / exact bytes

| File | SHA256 |
| --- | --- |
| `tools/godot/export_preview_water.py` | `bc66c7a1f419dd12a87e3e26fb4b595ed87f020a3fedb2e73514578afa2caa05` |
| `godot/mafiozi_walk/data/preview_water.json` | `ac70f924e1beef0f8501c48d09535a89d47effff014bf0f32b8abc72b3e3b824` |
| `godot/mafiozi_walk/scripts/preview_water_surface.gd` | `7d89235d93f31dd565aadf37f549a05074bec5534acfb120543228f1dba2655c` |
| `godot/mafiozi_walk/scripts/tests/test_preview_water_surface.gd` | `a79411f07df6f21026d0643f9e5e9ff9768f6ecef27b96ec2c4dab57ee453dae` |

Factory/shader remains exactly `preview_water_material.gd` SHA `51f3d2d5f6c744cc98b0131a62d2acb1e97b8327f2235702b9b1896615952d88`; its47 CPU tests and source limits are in `S01_WATER_MATERIAL_HANDOFF.md`. No factory changes during this surface scope.

## Source geometry and coverage

Exporter verifies current `block.json` topology receipt, cropped grid/protected mask and exact source formula guard, source metre scale4.1, and native-city precedence. Receipts for block, topology, Walk source, landscape plan, material source, and exporter itself are embedded with paths/byte sizes/SHA. Current block SHA1523f52e…; topology11f256f2…; Walk working sourcee80ebf4b…; landscape planede2c9a1…; source material6598e763…. SourceStatus candidate/pending host remains unchanged.

Crop rows0≤r<31 and cols76≤c<107 contains303 unprotected water cells. Source coordinates Float32(c×4.1,-.18,r×4.1) before preview recentering; originM=[395.65,0,45.099999999999994]. Exact six-corner source triangle order comes from terrain(). Source waterAt samples native unprotected tile16 then3×3 shore neighbourhood, floor=-min(2.4,shore×.9), depth=max(0,-.18-floor); source factory stores Float32 depth. Data keeps231 zero-depth shoreline corners,1587 wet corners, max2.2200000286102295; no epsilon or default2.5 coastline substitution.

Source total10799 unprotected native water cells; outside this crop10496 explicitly NOT_EXPORTED_OPEN. Landscape clipped lakes are distinct and NOT_EXPORTED_OPEN. Exporter fails if a future crop samples landscape precedence, requiring exact clipped geometry/depth implementation; no guessed lake plane. This package preserves all native water in the current excerpt, not complete city water.

## Host API / integration

```gdscript
const WaterSurface = preload("res://scripts/preview_water_surface.gd")
var water_host = WaterSurface.new()
# data is parsed once from res://data/preview_water.json
var receipt = water_host.build(data, identity_world_parent)
# Root main-loop only. Absolute monotonic seconds, optional source-world FX events.
water_host.advance(float(Time.get_ticks_usec()) / 1000000.0, events_or_null)
# At scene-generation removal:
water_host.dispose()
```

`validate(data)->PackedStringArray` is pure structural admission: supported schema, finite bounded origin/cell size/depths, source height and vertex sequence, max4096 cells, integer coordinates, duplicate rejection. Host accepts **trusted exported data** whose provenance/protected-mask/crop is independently established by exporter and oracle; host does not pretend to recalculate whole-source topology or verify unavailable external source files at runtime. Root admission should run exporter `--check` before package/export; coordinate origin and bounds with root block to prevent stale excerpts.

`build(data,parent)->Dictionary` returns `{ok,errors}` or counts. Requires identity-world Node3D parent; in-tree global transform checked (detached parent local identity only, attach under identity world as documented). Validates before creating any nodes. Duplicate build rejects without resource growth until explicit dispose. Empty dry input creates zero nodes/resources. Current input creates exactly one ArrayMesh with one ShaderMaterial and one MeshInstance3D, no physics children. Reserve CUSTOM0 R_FLOAT for depths; normals UP, no authored UV invention. Reversal is **indices** [0,2,1,3,5,4], leaving all source vertices/depths paired. Godot front winding is clockwise (official ArrayMesh4.7 documentation); Three source is CCW. Normal encoding can introduce ≤1e-4 engine compression error, tested.

`advance(time,ripples=null)` has no auto_process/timer, no scene scans or I/O. One root call updates explicit epoch time. No events and no prior active ripple avoids resetting the eight-slot array/uniform; null after active events clears once. Actual events are passed in source world x/z with provided age, not local recentered positions; host does not own FX spawning/aging. Cached shader/material/mesh references reused throughout. Dispose frees only its owned node, clears factory references and permits rebuild. Root must dispose before removing the parent; parent otherwise owns water node lifetime.

Mesh casts no shadows; default lit shader receives shadows. Material render_priority1. **Omit prior `Surface_water` BoxMesh group in root `_build_surface()` when enabling this host**, otherwise two transparent water surfaces overlap. Keep existing dry-strip collision logic and all physical water rules. Shader/environment intensity mapping, transparency sorting and whole-scene lighting stay root acceptance concerns from material handoff.

## Verification and optimization

Commands:

```text
python tools/godot/export_preview_water.py --check
node outputs/astra21_water_geometry_oracle/verify.mjs
Godot_v4.7.2-stable_win64_console.exe --headless --path godot/mafiozi_walk --script res://scripts/tests/test_preview_water_surface.gd
```

Python standard library only; JS oracle needs installed Node and existing Three180 vendor (THREE_MODULE_PATH override supported). Test preloads actual factory/material. Exporter’s source hash/receipt change requires reviewed regeneration even with same303 count.

44 Godot assertions include current data admission, all1818 actual mesh vertex/depth pairs, wet/zero shoreline counts, all606 triangles, CW winding, UP normals, noUV/collision/auto_process, one mesh/material reuse, ripple clear optimization, explicit epoch, double-build failure, disposal/rebuild, empty dry input, malformed/schema/origin/parent/depth/coordinate/source-order/oversize inputs and no partial nodes on rejection.

Independent source evidence/receipts: `outputs/astra21_water_geometry_oracle/HANDOFF.md`, `verify.mjs`, `result.json`. Read-only independent host review: `HOST_REVIEW.md` (same final SHA after freeze).

Static geometry shrinks current preview water from303 six-sided boxes to303 exact source planes in one batch: expected triangle topology3636→606 for default boxes, while preserving original Walk plane geometry. This topology comparison is **not a measured rendered frame gain**. Per-frame no-event advance CPU batch mean reduced from2.0223µs to0.7754µs in10000-call synthetic runs by avoiding redundant ripple reset; actual current303 mesh one-time build2716µs. Single runs/batch means are not framep50/p95 or LIVE GPU measurements. No textures or additional passes. Whole-scene matching camera/settings/population/warmup before/after p50/p95, GPU/draw-call/triangle counters and shoreline visual/swimming behavior remain OPEN for root’s sole updated scene.
