# Native route point cost: read-only audit

Production was not changed. CPU profiling used the real hospital/source/geometry fixture with 96 simultaneous visit jobs. This is not the loaded city and does not reproduce the observed 110-second LIVE queue delay.

The point cache in `npc_native_navigation.mjs` resets every render frame. A native A* edge can call eight samples, each invoking five footprint points. `npcPassable` and `npcPassableForSnitch` query the resolver twice per accepted point (collision/depth, then native surface). The second query hits the frame cache, but resumed jobs in later frames recompute previously visited geometry.

Instrumented baseline: 264,128 uncached point calls, 406,316 cache hits, 6,612 sweeps and 1,010,135 polygon containment callbacks. Timed callbacks cost ground96ms, polygon90ms, terrain35ms, static index32ms, one actual car32ms, water22ms and surface21ms. Total route CPU was1,448ms. Callback counts also include final returned-route collision validation, outside the route-loop CPU total. Timing wrappers add overhead: compare only against the equally instrumented prototype.

An experimental static polygon result cache in `outputs/prototype_npc_static_point_cache_20260919.mjs` keys exact position, current sampled floor and current candidate-array identity. Floor, water, terrain and dynamic vehicles remain live. It reduced polygon containment calls to55,873 and route CPU to1,284ms (about11%). Both runs resolved88 jobs and rejected8, with no pending jobs. Queue completionp95 went15.95→14.70s in50ms simulated frames. It helps, but this scale of savings does not explain or solve the110s LIVE delay by itself.

The prototype is NOT suitable as an unconditional production change. The generic navigation API currently allows callers to mutate a body's height in place while returning the same array; an existing test uses that contract. Safe integration needs an explicit opt-in geometry revision provider or an indexed-host contract with all mutations published through `replaceGroup(...,{force:true/revision})`. Incremental bucket identity already changes after ordinary door replacement and dirty-group updates. Cache entries must be bounded and invalidated on scene/index replacement. Do not retain final `blocked`, because a vehicle or train can arrive after the static result was cached.

Prototype tests pass for changed/open/removed door groups, forced in-place height changes, current support height, water depth, terrain and a moving vehicle. They also verify ground sampling still occurs across frames. Files: `outputs/profile_npc_native_route_20260919.mjs`, `outputs/profile_npc_cached_route_20260919.mjs`, `outputs/test_npc_static_point_cache_20260919.mjs`.

LIVE host differences that the fixture does not measure: multiple candidate building-floor samplers, parked fleet scans, railway and logical traffic. In the current railway code, `exploration_railway.mjs` exports `plan.floorHeight` (static rail bed/stations); moving trains are `motion.blocks`, a separate callback. Nevertheless support caching must remain explicit/revision-aware rather than assuming every future host floor is immutable. The rail nearest query is already spatially bucketed.

Recommendation: investigate scheduling/frame throughput and per-job progress alongside measured LIVE callback costs. Static narrowphase caching is a bounded secondary optimization; do not claim it resolves queue starvation or loaded-game FPS.

## Follow-up: actual railway support divergence

The actual railway plan has1,021 samples. Its spatial buckets still hold enough nearby segments to make western support checks substantially more expensive than hospital/eastern checks. `outputs/profile_npc_rail_floor_20260919.mjs` measured30 batches of1,600 exact point queries with the real topology/rail plan. Latest warmed p50/p95 milliseconds per batch:

| Area | Rail floor | Exact-value memo replay p50 |
| --- | ---: | ---: |
| Hospital (675,40) | .225/.751 | .569 |
| Centre (369,410) | .213/.322 | .596 |
| West rail (35,365) | 7.049/7.317 | .573 |
| West forest (-190,200) | 6.528/7.036 | .587 |

The west rail samples all return null yet still search nearby spline segments. Therefore the one-hospital fixture substantially understates support cost for western routes. This is a real callback discrepancy, not a full LIVE route diagnosis. The naive string-key memo is slower where the existing callback already returns null cheaply; reuse the navigation query key or use numeric maps rather than blindly wrapping all hero/host support calls.

Exact current support inspection: NPC ground queries use referenceY0. `building_entry`, `building_entry_profiles`, `building_storeys`, `hospital_public_approach` and detention floors depend on fixed transforms and static floor/stair/platform data. Door leaves change collision bodies, not support. Railway support is static plan geometry; moving trains remain a separate live `motion.blocks` check. Water and landscape support derive from current static topology/plan. An opt-in NPC support cache is viable for this host with explicit invalidation on content/building sample index, rail plan, landscape/topology generation and entry floor-sampler replacement. Scene rebuild clears/recreates these providers. Do not apply this assumption to the generic navigation API or hero floor sampling with variable referenceY. A future mutable floor implementation requires a revision hook.
