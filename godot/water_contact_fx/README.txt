Hero water contact effects: isolated native Godot stage 1

Revision R2 supersedes rejected R1. Equal-priority ripple exports preserve the
source JavaScript stable ring-pool order by explicitly sorting ties by pool index.
Actual-source regression creates a valid simultaneous returning-droplet fan with
distinct XZ and equal-age/strength waves. 22 source cases/2101 frames include this
regression plus four seeded real trajectories. Frozen R1 remains diagnostic history.

Repository target: godot/water_contact_fx. Godot 4.7.2 standard; GL compatibility.
Source: assets/maps/city_rebuild_v1/water_interaction_fx.mjs HERO BRANCH ONLY.
No vehicle wheel effects, whole-city gameplay, swimming or collision/solver changes.

Caller API
  const Fx = preload("res://water_contact_fx.gd")
  var fx = Fx.new()
  identity_world_parent.add_child(fx)
  assert(fx.setup({"waterAt":water_at_callback}))
  # Published godot/water_hero_inputs sampler R2 returns the inner hero dictionary:
  var hero_input = sampler.sample(hero_feet_node, delta, state)
  fx.advance(delta, {"hero":hero_input,"focus":hero_feet_node.global_position})
  existing_water_material.set_water_ripples(fx.get_ripples())
  # Teardown: dispose detaches, frees GPU batch resources and releases callbacks.
  fx.dispose()
  fx.free()

Position and velocity accept source {x,y,z} dictionaries or native Vector3.
All coordinates are source metres, +Y up; actor origin represents feet.
Use an identity world parent and identity effect transform. Do not translate or
rotate the effect node later; instance positions are world/source coordinates.
waterAt(x,z) returns null or {level,depth?,floor?}. Only depth > .012 is wet.
The effect borrows callback dictionaries for immediate read; it never modifies
them and never retains them as contact history. Callbacks must be synchronous.
Optional groundHeight(x,z), random(), gravity=9.81, drag=.65, maxDistance=100.
Original capacity defaults retained: 240 drops,24 rings,72 foam,96 emission budget.
Capacity overrides are available for source-equivalent tests/config, not FPS fixes.
Hero-only: vehicles input is outside this stage and is ignored. One hero per call.
get_ripples() allocates its returned top-eight sorted snapshots, as source does.
The component has no automatic _process: advance exactly once from the host.
Missing, invalid, disabled or out-of-focus hero prunes history, preserving live
particles. First observation, teleport, excessive movement and raw delta > .25
reseed without impact; simulation time still caps at1/15 per source. Small dry-
endpoint ponds use the exact bounded sweep. Downward precontact velocity is
preserved when provided. Explicit dispose is final; use a fresh instance to reset.
External removal also disposes: reattaching the same removed component is unsupported.

Visual contract
Three MultiMeshes: source SphereGeometry(1,6,4) topology,12 RingGeometry(.97,1.03,3)
arcs per ring, CircleGeometry(1,7). Source sRGB colors b7e0e3/d6efeb/e1eee5,
material opacity .9/.55/.62, roughness .16/.6/.85, metallic .08, double sided,
no depth write, no shadow casting/receiving, render priority3, custom alpha.
Droplet stretch/velocity rotation, fading, foam flattening/growth and all six
shore/height checks per ring arc retain source formulas. Wavefront .08+age*1.35,
life4.5 seconds, independent of strength. Source batch counts/capacities retained.
Meshes create no physics bodies and cannot intercept gameplay physics rays.
Precomputed angles/bases reduce CPU work; they do not skip water samples or arcs.
Buffers have fixed capacities. Packed-array copy-on-write and GPU upload transient
allocations are NOT_INSTRUMENTED; bufferCapacityResizes counts explicit capacity
resizes only, not allocator events. Particle objects allocate once in setup.
Cross-engine pixel/lighting equivalence to Three is NOT_RUN; matching material
parameters/topology/formulas and native visible pixels are the evidence provided.

Demo and tests
Open project.godot in pinned Godot and run demo.tscn. The moving block is a feet
input marker, not a player asset or authentic city. Demo support water material
is a byte-exact copy of the existing Godot preview_water_material.gd; it is not
a rewrite of that shared material. Demo feeds exported ripple events to it.
Regenerate actual source traces:
  node tests/source_oracle.mjs <water_interaction_fx.mjs> tests/oracle.json
Run tests/native_fixture.tscn through the shared repository test scheduler:
  Godot --headless --path <this-directory> res://tests/native_fixture.tscn
This command is the child command, not a scheduler bypass. Import uses write
lease, tests read lease; pinned direct GUI executable, owned bounded cleanup.
Headless dummy renderer per-instance getters do not reflect bulk-buffer upload;
fixture checks actual buffer contents/geometry. Separate graphical capture checks
rendered pixels and added draw calls. tests/cost_fixture.tscn measures component
CPU in exclusive perf lease; it does not measure whole-city FPS or GPU time.
No engine/runtime is bundled or downloaded. Engine path comes from the caller.

Stage acceptance limits
Author source parity/native and graphical evidence are in the package evidence.
Independent QA, published-sampler joint host sequence, authentic current286/live
Walk view comparison, GPU timing and full-city baseline/candidate are separate gates.
Do not describe this standalone hero component as a completed city migration.
