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

## Component contract

Instantiate `addons/walk_minimap/minimap_control.gd` under a CanvasLayer/Control.
The five component scripts require no additional plugins or absolute filesystem paths.

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

The expanded sidebar preserves the source POI selection and priority rules,
duplicate-id handling, distinct same-name places, Russian legend, object count
and hover names. A POI button sets its metadata-bearing waypoint, centers the
map and raises zoom to at least 2; it never teleports the character.

## Object filters (additive improvement)

The compact `Фильтры` button beside the place-list heading opens the optional
category controls. All 27 actual source categories are enabled by default, and
`Показать все` restores them. Long category lists stay within the sidebar scroll
area. The map and original legend remain available. No NPC or vehicle authority
is inferred by filtering.

- `set_kind_enabled(kind: String, enabled: bool) -> bool` returns whether a
  filter changed. `is_kind_enabled(kind)` reads it; `reset_filters()` restores all.
- `visible_pois()` and `object_at(map_surface_pointer)` use the same filtered
  snapshot as the object glyphs. Hidden objects cannot leave stale hover/hits.
  Unknown supplied kinds use the source `object` color/category rather than vanish.
- Filters affect object glyphs, POI list and hover/hit consumers. Base geography,
  roads and building polygons remain. The player and selected waypoint stay
  visible; hiding the selected category does not clear the waypoint or its route.
  Actor, vehicle and train markers remain governed by the supplied host snapshots.
- The object spatial index is built on dataset changes; filtered object and POI
  caches rebuild on dataset/filter changes. Equal filter settings, query calls,
  movement and idle updates do not rebuild the list or index.

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

The base map uses the source 64-pixel overscan atlas, rebuilt on world/filter,
scale/size changes or movement beyond 56 pixels. It retains the source color
palette, metre-scale footprints, all 13 semantic building icon geometries, grid
colors (when explicit cellSize is supplied), water outlines, dashed trails and
double-stroke railways. Rounded brass framing, collapsed/expanded layout,
responsive widths, place-list/legend/help and system UI font follow the source.
The native text engine and widgets are an adaptation of browser CSS rather than
an assertion of identical pixels. The exported but unused source layoutMapLabels
helper is not injected into runtime: default object names remain hover-only.

Route normalization/distance scans occur at set_route, never in draw. Cached
world geometry and a reusable screen buffer avoid route dictionary copies and
polyline allocation on every paint. Repeated equal routes retain geometry and
skip forced redraw. Train markers rebuild only when actor/train snapshots change.
Public getters remain isolated from mutation. `draw_stats()` exposes requests,
actual draw callbacks, route normalizations, distance scans, geometry builds,
atlas rebuilds, POI rebuilds and spatial/filter index counters.

Stage02 adds the source visual structure and semantic icons, POI list/legend,
spatial/atlas caches and opt-in object filters to the frozen Stage01 core. It also
renders the source expanded-only squad hover text from supplied ownSquad,
profession/status marker fields. A supplied ownSquad flag is trusted host data;
a profession/candidate badge does not establish membership. The roster-to-marker
authority adapter, 3D pin, terrain and real host input/city integration remain
outside this standalone project. Real-city authority/physical-arrival verification
requires the authentic scene; none is substituted by the demonstration.

No 4.1 scale is assumed. No quality-reducing city-object cap is applied. The
current286 scene is NOT_RECEIVED. Full-city/GPU/frame-budget performance, physical
arrival in the real city, actual roster authority and existing game launch
integration are NOT_RUN. Native demo/component evidence is recorded separately
from those missing integration checks. Full game parity is not established by
the standalone map fixture.

## Native author smoke

```powershell
& $env:GODOT_EXE --headless --path godot/minimap_demo --script res://tests/smoke_minimap.gd
& $env:GODOT_EXE --headless --path godot/minimap_demo --script res://tests/test_filters.gd
```

In the shared workspace use `tools/godot/test_scheduler.py` with a read lease,
the locked GUI engine executable and a bounded timeout. Native import/staging
uses a write lease on the exact isolated project. Frozen author evidence and
independent QA evidence belong outside this source subtree. Headless CPU timings
are bounded component measurements, not a full-city performance acceptance.

## Stage02 R2 responsive correction

The frozen R1 failed independent graphical QA at 640x480: sidebar content
minimum widths pushed its place buttons and filters outside the map. R2 keeps
the source 135/210 pixel sidebar widths and 8/12 pixel responsive padding.
The title and filter toggle stack at narrow widths. All 27 filter names wrap
beside their keyboard-focusable CheckBoxes; clicking a name also toggles and
focuses its CheckBox. No category, legend item or object is removed.

Long place buttons retain their full text and expose it, plus the category, in
their tooltip. Ellipsis confines the displayed row to the sidebar. The complete
source help paragraph wraps into measured height, using its source 10/11 pixel
responsive font size. Collapsed outer widths include both borders (192/232),
so the actual canvas remains 190/230 pixels wide as in Walk.

`tests/regression_responsive.gd` exercises the rendered component at 640x480,
1100x720 and 1920x1080, long visible place rows, filter keyboard/name toggling,
route preservation and full help height. Author R2 evidence is separate from
independent QA; R1's failed receipt and immutable archive remain preserved.
