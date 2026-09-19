# District detention service entries — 19 September 2026

All three service suffixes are ready against the current road dressing and prepared graph, including the Old Town one-way passage and the 0.78 m waterfront lane inset. `city_service_access_plan.mjs` required no production change: it selects current edges using semantic incoming/outgoing lane identities and resolves current numeric IDs at construction time.

## Integration contract

`planCityServiceAccess({trafficPlan, instances, topology, extraBodies, roadSupportRects, metresPerCell:4.1})` returns clone-safe `{routes, issues}`. Pass the final prepared plan, all authored instances, final road/parking/decor collision bodies and the actual parking plan's road-support rectangles. Build once in the environment worker after road/parking placement and lane preparation. Do not reconstruct this in a frame update or treat an issue as a ready destination.

Each route provides `id`, `buildingId`, `kind:'service_entry'`, `points`, `gear`, `laneAnchor`, `lengthM`, `distance`, `minRadiusM`, `speedLimitKmh`, `requiresStopBeforeReverse`, `retainedApproachId`, `retainedTurnId`, `retainedConflictTurnIds` and `actualConflictTurnIds`. All coordinates and lengths are native metres. `laneAnchor` includes the resolved edge ID, semantic lane IDs, exact point index, cumulative progress and exact body-facing pose.

Route the city prefix to this exact `laneAnchor`; retain its canonical controls and append the suffix. Never perform a generic near-street snap instead. The suffix yaws describe body facing. Southside has negative gear throughout, so its travel tangent points backwards: the vehicle must stop before changing gear at the join. Do not discard this boundary when removing coincident points. The suffix does not replace the canonical signal/priority rules on the prefix.

| Site | Length | Minimum radius | Gear | Speed cap | Retained control |
|---|---:|---:|---:|---:|---|
| Southside | 7.815 m | 5.915 m | -1 | 4 km/h | Right-hand priority on junction 456 |
| Iron Harbor | 10.759 m | 5.177 m | +1 | 6 km/h | `road-traffic_signal-21` on junction 65 |
| Chinatown | 4.693 m | 5.997 m | +1 | 6 km/h | Upstream lane controls; no new conflict crossing |

The root-owned `detention_road_stop_pose.mjs` provides corrected body orientation and the measured kerb insets. Intake, release and pedestrian handoff positions remain independent.

## Validation

`node --test assets/maps/city_rebuild_v1/test_city_service_access_plan.mjs`: **6 tests passed**. The suite now rebuilds current road dressing and a prepared graph, rather than accepting the stored old road graph. Existing placement/parking/decor come from the integration snapshot.

- All three real city prefixes are ready, with Southside priority and Iron Harbor signal 21 retained before the suffix.
- 1,620 dense poses, at most 2.5 cm / 0.5 degree spacing, pass complete CAR rectangle/asphalt and static-body clearance. Minimum radius exceeds 4.3 m; heading, tangency and gear agree.
- New obstacles, lost asphalt, new stop lines and unretained crossing-turn conflicts fail closed.
- Renumbering every TURN still resolves the same physical entry using semantic lane identities.
- Missing edges or road support cannot create a neighbouring-street shortcut.
- The stored integration snapshot remains unchanged.

Construction took 139 ms for all three suffixes in this run against 3,224 final static bodies. This is a one-time CPU cost, not a frame-time/FPS acceptance. No GPU tab was opened. **Performance of the shared game scene is unverified.** Root must still run the combined final worker and wrapper integration, then coordinate one-tab LIVE validation.

Reports: `outputs/roads_logical_20260912/service_access_plan_audit.json` and `service_access_fresh_audit.json`; diagnostic recipe `audit_service_access_fresh.mjs` rebuilds only roads, not a full worker/grass plan.
