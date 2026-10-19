# Native Godot RVO prototype, not integrated

The user explicitly requested testing the engine's existing navigation tools.
`rvo31.gd` uses NavigationServer3D agent RIDs and real avoidance callbacks behind
the current `snapshot`/`steer` interface. It does not add a NavigationAgent node or
replace the already-existing navigation mesh/path queries. Exact accepted57
Physical/Surface/Passage sources still own all floor, capsule, wall, player, debris,
door and symmetric NPC-passage collision rules. No frozen source, F5 or Git writes.

Official facts: avoidance runs separately from physics and navigation meshes;
the engine warns about perfectly symmetric head-on encounters. Agent nodes are
optional, so this prototype uses the server API directly. These facts motivate
keeping native collision checks and explicitly testing symmetric encounters.
[Godot agent guide](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html)

The API provides desired velocity submission, safe-velocity callbacks, map/layer/
mask control and explicit RID cleanup. Callback cleanup is necessary even if the
scene stops processing. Forced velocity is used only at initial admission, never
every frame. The prototype measures callback timing in the actual locked engine.
[NavigationServer3D API](https://docs.godotengine.org/en/stable/classes/class_navigationserver3d.html)

Prototype choices, not documentation claims:

- Same eight-neighbor/3.2m/1s bounds as custom avoidance; body radius+.06 represents
  half of the current.12m pair gap. Physics capsule size is unchanged.
- Horizontal avoidance with the real actor height; all ten inputs update each
  physics frame. The current algorithm makes decisions on a minimum six-frame
  cadence; comparison reports that asymmetry rather than pretending both run the
  same work schedule.
- Current native passage members receive one avoidance bit per occupied zone.
  Each ignores only its own zone bit and sees outside/other-zone actors. At most31
  simultaneous zone groups; excess is an explicit rejected snapshot, not silent
  global ignore. This prototype does not remove the accepted32-member zone cap.
- Safe callbacks are cached and consumed only by the fixture's actual physics
  movement step, never by a second body move in the callback. Missing/stale output
  holds the body. Lifecycle cleanup removes callback, disables and frees each RID.
- The controlled fixture uses exactly ten active residents; staff are not newly
  introduced as avoidance inputs because the accepted custom adapter currently
  does not include them. Actual-city comparison, if earned, retains10+12 bodies.

The ten-body fixture runs open parallel paths, five exactly symmetric head-on
pairs, a ten-way crossing, a real compact doorway with opposing streams, then
native wall/player/debris/closed-door and death cleanup checks. All bodies use
native movement. Initial placement occurs only before each measured case. Actual
physics context,60Hz delta, maximum displacement, progress, wait duration, callback
counts, queries and source/harness/control pins are saved. A FAIL remains a FAIL;
only a complete functional result permits an actual-city overlay.

Timing limitation: adapter_us includes our snapshot/submission work; Godot's RVO
solver runs elsewhere and is NOT included. Those numbers must not be called total
avoidance cost or an FPS improvement. These concurrent functional runs are not
comparable full-city performance runs. Headless workers receive the scheduler's
normal CPU affinity limits.

Godot's profiler distinguishes inclusive time from self time, and its documented
workflow uses an editor Profiler session. A separate profiler session may be used
only when available without touching the user's editor; this package has not
opened one. In its absence, scoped counters honestly identify included work,
while complete engine/RVO cost remains unmeasured.
[Godot profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html)

Initial custom_smoke01 is preserved as an invalid fixture setup: it did not create
registry entries and its incomplete resident adapter allowed automatic door
closure. The corrected harness explicitly discovers the real door and provides
resident occupancy. That failed setup is not evidence against either algorithm.
