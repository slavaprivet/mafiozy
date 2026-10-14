Hero water inputs — independent Godot component, 09.10.2026
Port: assets/maps/city_rebuild_v1/water_interaction_inputs.mjs, hero branch only.
Caller owns world-feet origin and simulation updates. sample(Node3D,dt,state)->
Dictionary {id,kind,position:Vector3,yaw,contactOffsetY,enabled,teleport,
optional velocity:Vector3,massKg,footprint}. Empty dictionary means no valid hero.
No frame/physics/input hooks are installed automatically.

State keys: occupied_seat, transition, teleport (source JS truthiness preserved);
vertical_velocity (finite Y override including0); mass_kg or node meta massKg;
source_scale and diagnostics Callable returning sourceBounds min/max arrays;
hero_owner optional Object is source hero wrapper identity for dimension caching.
If wrapper is omitted, node is wrapper; when the same source wrapper replaces its
node, pass the same hero_owner. Node identity still resets movement independently.
Use immutable source bounds once; changing dimensions on a live wrapper requires
a new owner lifetime, matching source WeakMap. reset() clears velocity history only.
Read world feet, never use animated ankle/capsule centre. Metres, seconds, local yaw.
Teleport first frame, node replacement, enabled change, invalid dt, explicit reset,
or XYZ displacement>12. dt finite0<dt<=.25; teleport stores new position history.
Consumer must suppress impacts on teleport or disabled input.

Run: Godot4.7.2 --headless --path <this directory>, through project test scheduler.
Native fixture32 checks. Source parity: node tests/source_oracle.mjs <originalMJS>;
compare SOURCE_PARITY_TRACE in native stdout, numeric tolerance1e-4 for Godot float.
Oracle's tiny THREE vector seam models only getWorldPosition, not geometry/vehicles.

Optimisation: cached source bounds, no per-frame dimension callback/cache-wide sweep;
WeakRef reused for same node; dead width-cache owners pruned on new-wrapper admission.
10000 steady calls measure batch mean CPU us p50/p95, persistent Godot Object delta,
and bounds-callback delta. Dictionary/Variant transient allocations are not counted.
Functional/headless component measurement is not exclusive full-city/GPU perf.

Not implemented: vehicle branch, water detection/particles, swimming, damage,
scene input integration, current286 runtime/roster. Source water visual surface
already exists in baseline and is preserved. Integration target is isolated
godot/water_hero_inputs only; BUILD owns main and any future live host hook.
Fixtures use actual Node3D transforms; they never invoke movement solver.
