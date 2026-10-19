CURRENT CORRECTION: helper3fbdf0259c909ee38c5d25cbe22ac627bc72a84b45af93da63f75979fa3132ca. See NPC_SOURCE_BODY_COERCION_HANDOFF.md. Production unique-depth comparison is exact public source predicate, not generic JavaScript Number conversion; unused private Number approximation is unqualified, NUL representation HOLD explicit. Historical frozen copies/receipts retained.
# NPC source BODY query contract

Scope: pure logical source access policy in scripts/npc_visual/npc_source_body_query.gd. Root21 owns current native primitives, candidate-position host integration, physical collision/admission, main and LIVE. Every result has physical_admission=false. No births, raw IDs, HP, jail timers, RNG or server authority change.

## API

configure(context_bytes:PackedByteArray, trust:Dictionary, source_snapshot:Dictionary, primitive_callbacks:Dictionary, static_geometry_bytes:PackedByteArray) -> {ok,error}

query(object_key:String, kind:String, raw:Dictionary, r:float, c:float) -> {known:bool,pass:bool,error:String,provenance:Dictionary,physical_admission:false,trace:Array,primitive_trace:Array}

body_pass(same arguments) -> strict bool only for a known decision, otherwise null. The placement solver must fault or hold on UNKNOWN; never coerce it to a blocked point and continue searching. snapshot() returns private diagnostic copies. Configure once per captured revision; rebuild after life/access/geometry changes. A lease receipt is trusted caller evidence, not a complete provider implementation.

Pins: context a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c; source world 9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5; static geometry c5f57678912a0c18b51430ea0ef69ea2c84572d32392fa036b84c53f4933724b. Approved session godot-preview-new-session-20260927-01 and phase AFTER_FULL_DEFERRED_POPULATION_CALLBACK_BEFORE_ANY_SERVER_SNAPSHOT_BEFORE_NATIVE_RESOLVER. This is an explicit offline new-session fixture, not a captured live/server session.

trust requires context_sha256, source_world_sha256, static_geometry_sha256, session_id, phase and primitives Dictionary. Each supplied primitive receipt has nonempty String id/version/semantics. Exact semantic labels: native_nav=_walkNpcNavigationResolver; water=_walkNpcWaterResolver; ped_blocked=isBlockedPed; city_surface=_cityV3NextSurfaceAt.

source_snapshot requires source_world_sha256,session_id,snapshot_id (Strings), revision (int>=0), native_nav_present,water_present,prison_enabled (bool), water_bypass (int>=0). Dynamic release_gate_progress in [0,1] is required only when the release-gate branch is visited; alarm_active bool is required on every visited island point. No gate state is inferred from alarm=false. Do not execute impure jail transition functions to obtain proof.

Each primitive receives (r,c,private_query_context) and returns {known:bool,defined:bool,value:Variant,provenance:{source_world_sha256,session_id,snapshot_id,revision,provider_id,provider_version}}, or known=false with optional error. Every field binds the captured revision and trusted provider. A missing/unavailable callback is UNKNOWN. Explicit proven absence/undefined is allowed for optional native/water resolvers; direct pedestrian/city calls require valid original return values, not absence of their functions. Values must be bounded private JSON-like containers; numeric NaN/Infinity remain supported for original finite/fallback predicates. Callback reentry/freed lifetimes fail closed.

## Exact source policy

Resident initial placement uses _npcBodyPassable with npcWaypointOk closure, not default npcPassable. Check five route points first at centre,--,-+,+-,++ offsets .18cells; then five waypoints in that order with original short circuit. Waypoint repeats route and applies bounds, prison exclusion .35, arena/lair, named unique policy, pit corridor, native land/road, beach flags and MAP fallback. Its fallback does not call isBlockedPed.

Police checks five points at .24cells. Route rejection precedes prison collision; a truthy prison collision overrides before bounds/arena/lair/snitch. Otherwise original snitch/native-surface/pedestrian fallback order applies. Preserve JS truthiness and strict blocked/depth predicates. Unique policy invokes native before bounds and uses BEACH_R0=150, distinct from waypoint beach rows138..168.

Source r/c, .18/.24 offsets and .55 spacing are cells and Float64. Original npc_native_navigation.mjs uses x=c*4.1,z=r*4.1 and depth=water.level-groundHeight in native metres; its .025 threshold is25mm. Do not divide that depth by4.1. MAP16 fallback1 is a nominal source sentinel, not measured water depth. Preserve actual producer raw depth and receipts.

Static arena/lair/pit/full prison layout come from exact original declarations and receipts; full MAP/raw rows come from a05ad. No crop substitution or fabricated clear geometry. Proven route failure may short circuit before later missing inputs. A required missing proof encountered earlier yields UNKNOWN. Root must provide full current ground/water/body/vehicle/train/access/interior and fallback cache evidence as needed; source hashes or TEST_ONLY booleans alone do not prove those.

## Acceptance and limits

Native tests compare all326 original rows and7902 source observations against original JS, plus short-circuit, dynamic prison, stale/freed/reentrant callbacks, input ownership, coercion and unknown placement handling. Synthetic primitive branch fixtures are explicitly TEST_ONLY. Body logic does not prove current floor support, overlap, native contacts, NPC behavior, calls, commerce, police/EMS or physical spawn admission. Root must validate those separately in the single actual game. CPU/headless results do not establish LIVE/full-city FPS.

Root integration seam: preload this helper and configure with the exact pinned context/static bytes and proven current leases. The existing npc_initial_placement.gd BODY Callable takes (object_key,kind,raw,r,c), matching body_pass. Its fixed source raw birth remains immutable; candidate placement is a separate host proposal. Root's existing preview_resident_host admission still needs an explicit candidate-position consumer and current floor/overlap/life checks. Never rewrite source_raw.r/c to consume a proposal.

This helper supports the approved pinned new-session actor table/static MAP, not arbitrary server snapshots or regenerated sessions. Source time, actor death/respawn/generation, current interior stockroom/door state, budgets, calls and police/EMS actions are external authority responsibilities. Current revision leases must genuinely capture those accessed primitives; changing only a receipt label does not implement them.

Hot-path diagnostics: query() records diagnostics_recorded=true and returns the full ordered traces. body_pass() evaluates the identical private core with trace construction disabled, returns only bool/null, and replaces last_report with diagnostics_recorded=false plus empty traces. snapshot() remains copied; it never exposes stale diagnostic traces after a body_pass call. Provider response containers are still privately captured for decision ownership, and every validation/call/unknown transition remains active.
