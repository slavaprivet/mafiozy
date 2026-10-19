# Registered native placement bridge — dependency proposal

Status: dependency audit/proposal, not a running implementation. Artist21 owns NPC bridge/source exporters/tests; navigation implementation, main, host, export and LIVE belong to Root21 and its navigation owner.

## Why the existing packet cannot start the population

Source world9f5cc5 `_npcInitialSafePlacement` returns before setting attempted/done while `_walkNpcNavigationResolver` is absent; `_npcInitialPlacementStep` also returns before advancing the queue. `walk_preview.mjs` creates the actual `createNpcNativeNavigation` instance and registers its `query` at lines532–533. Thus pre-native BODY320pass/6reject and abstract solver7450 are useful predicate/algorithm tests, not source placement execution. All326 actors must remain private until the actual registered solve completes and Root validates current physical admission. Named/otherwise ineligible actors still participate in source spacing as the source requires.

The frozen a05ad context is the immutable birth/state baseline. Its boundary is not a registration receipt and must not be renamed. A new evaluation phase needs its own explicit transition receipt while retaining exact original baseline bytes/IDs. Old helper provenance must not be mistaken for current post-registration state.

## Proposed integration boundary

Root/navigation owner supplies a coherent complete provider bundle and current lease to a new `scripts/npc_visual/npc_registered_navigation_bridge.gd`. The bridge wraps the real `npc_native_navigation.gd.Geometry.query`; it does not replace geometry or provide default-clear callbacks. BODY consumes its `native_nav(r,c,query_context)` through the existing strict known/defined/value/provenance envelope. Root owns resolver installation and the source registration transition. Bridge coverage/version verification is necessary but cannot establish source provenance by labels alone.

Required callback bundle (actual complete source-equivalent implementations): `ground_height(x,z)`, `water_at(x,z)`, `terrain_allows(x,z)`, `bodies_at(c,r)`, `contains_body(body,r,c)`, `blocks_dynamic(x,z,context)` and `surface_at(x,z,r,c)`. Initial placement uses point requests; route sweeps additionally require `bodies_in_bounds`. The current native adapter's optional defaults0/null/true/[]/false are not acceptable proof for this bridge. Unknown dependencies must stop publication instead of masquerading as an empty world.

Exact source semantics: world scale4.1; ground/water heights and depth in metres; body bottom/top fields map source minYM/maxYM to native min_y/max_y; body polygons use source [c,r] cell pairs and identity; ground support filters bodies at floor+.05 and floor+1.9. Water depth threshold .025 metres. Fullworld terrain uses landscape.contains/canWalk, otherwise nativePedestrianLand(topology.walkableMask plus tile9 policeMask) OR actual water. Surface is topology.roadMask sampled at floor(r/c). Dynamic collision uses railway, fleet with ignoreVehicleId, and logical source vehicles. Support is the actual building/rail/water/landscape ground closure, not generic ground0.

Lease must bind source/baseline SHA, registration receipt, evaluation phase, session/snapshot/revision, each provider identity/version, fullworld coverage and dynamic snapshots. Provider failure, freed callback, reentrant query, generation/revision drift or partial coverage yields UNKNOWN and permanently faults the pending batch. Validate lease before and after querying; the geometry cache must be cleared whenever the source provider snapshot changes. A reported `blocked:true` is not equivalent to an unknown provider failure: the wrapper must distinguish these outcomes before allowing the radial search to continue.

## Needed changes after concrete provider audit and Root agreement

1. Keep current immutable context boundary untouched; add an independently verified registered evaluation transition to solver/BODY provenance and test actual source guard behavior.
2. Supply complete fullworld source terrain/support/static solids and current rail/fleet/logical state. Cropped preview_block, 303-cell visual water and the separate ordinary_outdoor preview policy are insufficient replacements.
3. Bridge real Geometry.query into source BODY, preserving role order, water depth units, visited dynamic gates and coherent provenance. Fallback6bac only supports its proven before-native snapshot and cannot simply be reused after registration with toggled fields.
4. Compare original JavaScript registered closure and native bridge for initial positions and all actual radial search requests with all326 spacing; verify resident_72/169/252 against final positions and current policy. Publish only a COMPLETE batch, then Root revalidates support/life/access/collision.
5. Measure bounded CPU query/slice cost; Root alone runs comparable LIVE/FPS and refreshes the user's sole game. No content reduction for performance.

No new production bridge is created by this proposal. Complete source/native audits and specific available/missing dependency paths are being gathered separately; no fake resolver-present flag or invented birth/HP/authority is permitted.
