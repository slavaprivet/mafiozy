# Мафиози — миникарта (автономный модуль)

This is an independent Godot project and reusable map component ported from
`assets/maps/city_rebuild_v1/exploration_minimap.mjs`. Its authored demonstration
uses metres, +X east and +Z south, with negative world coordinates. It does not
load the game, a city roster, navigation, or a reconstructed current286 scene.
Exact upstream hashes and delivered file hashes are in `SOURCE_MANIFEST.json`.

## Run

Open this `project.godot` with Godot 4.7.2, then press F5. From a repository root:

```powershell
& $env:GODOT_EXE --path godot/minimap_demo res://scenes/demo.tscn
```

The repository launcher is [tools/godot/launch_minimap_demo.ps1](../../tools/godot/launch_minimap_demo.ps1).
It opens this project in a separate editor and verifies the installed engine
against `docs/godot/ENGINE_LOCK.json`. It accepts `-GodotPath`, the alias
`-GodotExe`, or `GODOT_EXE`; `-CheckOnly` verifies files without starting an editor.
Wait for initial resource import, press F5 to run, and F8 to stop the demo.
The launcher is delivered by the portability owner and installed by BUILD.

WASD moves the demonstration character. M opens/closes the map; Esc closes an
expanded map. Left click/release places a bounded waypoint; right click removes
it only within 12 pixels of the displayed marker, including its clipped edge
position. The clear button also removes it. Expanded mode supports drag, arrows,
cursor-anchored wheel zoom, +/−, player recenter, world fit and Enter to mark the
center. Demo movement polling is gated while expanded and its held input is
cleared on mode changes.

Tab and Shift+Tab cycle only through visible, enabled map controls while the map
is expanded. Invalid train positions do not consume an ID belonging to another
valid train marker in the supplied actor snapshot.

## Component contract

Instantiate `addons/walk_minimap/minimap_control.gd` under a CanvasLayer/Control.
The three scripts require no additional plugins or absolute filesystem paths.

```gdscript
const Map = preload("res://addons/walk_minimap/minimap_control.gd")
var map = Map.new()
add_child(map)
map.set_world({
    "bounds": {"minX": -120, "maxX": 120, "minZ": -90, "maxZ": 90},
    "objects": [{"id": "shop", "name": "Магазин", "kind": "shop", "x": 80, "z": 40}]
})
map.update_state({"position": {"x": 0, "z": 0}, "yaw": 0.0})
map.waypoint_changed.connect(on_waypoint_changed)
map.expanded_changed.connect(on_expanded_changed)
```

- `set_world(Dictionary) -> bool` requires finite, strictly increasing bounds.
  Optional arrays: buildings, objects, districts, regions, water, roads, trails,
  railways. Polygon vertices accept `{x,z}` or `[x,z]`, already in metres.
- `set_providers(position: Callable, bounds: Callable, objects: Callable) -> bool`
  initializes the world; position returns an update-state dictionary and is
  polled at most once every 80 ms. Bounds and objects are fetched on initialization
  or explicit `refresh_world()`, without scanning the city every render frame.
- `update_state(Dictionary, now_ms=-1)` accepts position, yaw, actors, vehicles
  and trains. Optional time is for deterministic native cadence checks.
- `set_waypoint(Variant)` accepts null or a dictionary, clamps x/z and preserves
  name plus scalar/null id, kind, buildingId and lotId. Every replacement,
  including an equal waypoint, clears the route and emits `waypoint_changed`.
  `get_waypoint()` returns a defensive copy. Hovering does not select or teleport.
- `set_route(Variant)` accepts null, pending, blocked or ready. Ready routes
  require 1–4096 finite x/z points. An invalid segment blocks the entire route.
  An optional nonnegative finite distance overrides the measured length.
  The normalized setter result is recursively read-only. `get_route()` returns
  a defensive copy. Equal routes reuse normalized state and do not force redraw.
  There is no path planner. A dashed line without a route is a bearing indicator;
  ready road geometry is supplied by the host. Demo buttons use an authored road
  polyline and explicit ready/pending/blocked states.
- `set_expanded(bool)`, `set_visible_map(bool)`; signal `expanded_changed(bool)`.
  Host must release held gameplay input, gate Input polling and manage cursor
  mode itself. Consuming map events alone does not stop global Input polling.
- `get_projection()`, `handle_map_event(InputEvent)` (map-surface coordinates),
  `handle_key_event(InputEventKey)`, `draw_stats()` expose native QA seams.
  Set `auto_layout=false` to use a host-supplied Control position/size.

Small mode follows the character with a 180 m horizontal span. Expanded fit is
`max(bounds width / canvas width, bounds height / canvas height) * 1.08 / zoom`.
Zoom is clamped to 0.6–12; dragging beyond 5 px suppresses placement in both modes.
Marker clipping uses 13 px horizontally and 16 px vertically. District polygons
precede large regions; polygon boundaries count as inside.

`waypoint_state.info()` reports distance, bearing, relativeBearing and
`arrived = distance < 5`. This informational state never removes a waypoint.
The separate pure helpers `reached_waypoint()` and `can_auto_remove()` preserve
the Walk physical threshold (horizontal <=1.15 m, height difference <=0.9 m,
walking, no occupied seat/transition/jump). The host must supply real ground Y
and call removal; this demo does not infer height or auto-remove markers.

## Rendering, costs and scope

Ordinary changes are capped at one draw request per 80 ms. An unchanged snapshot
causes no request. User interactions and world/route changes force an immediate
request, matching the source exception to the cadence. Queued rendering occurs
on the next engine frame. A throttled dirty state retains the newest position.

Route normalization/distance scans occur at set_route, never in draw. Cached
world geometry and a reusable screen buffer avoid route dictionary copies and
polyline allocation on every paint. Repeated equal routes retain geometry and
skip forced redraw. Train markers rebuild only when actor/train snapshots change.
Public getters remain isolated from mutation. `draw_stats()` exposes requests,
actual draw callbacks, route normalizations, distance scans and geometry builds.

Stage01 includes map math, waypoint/route state, input, ordinary cadence,
simple polygons/roads, object hover names, actor/vehicle/train marker rendering
and this standalone demo. Rendering currently uses simple colored object marks
and labels. Full semantic building icons, measured collision-free label layout,
POI index/filter panel, grid adapter, atlas/spatial object index, detailed squad
hover text, roster-to-marker authority adapter, 3D pin, terrain and real host
input/city integration remain for subsequent stages. A supplied ownSquad flag is
trusted host data; a profession/candidate badge does not establish membership.

No 4.1 scale is assumed. No quality-reducing city-object cap is applied. The
current286 scene is NOT_RECEIVED. Full-city/GPU/frame-budget performance, physical
arrival in the real city, actual roster authority and existing game launch
integration are NOT_RUN. Native demo/component evidence is recorded separately
from those missing integration checks; this is not full Walk map parity.

## Native author smoke

```powershell
& $env:GODOT_EXE --headless --path godot/minimap_demo --script res://tests/smoke_minimap.gd
```

In the shared workspace use `tools/godot/test_scheduler.py` with a read lease,
the locked GUI engine executable and a bounded timeout. Native import/staging
uses a write lease on the exact isolated project. Frozen author evidence and
independent QA evidence belong outside this source subtree. Headless CPU timings
are bounded component measurements, not a full-city performance acceptance.
