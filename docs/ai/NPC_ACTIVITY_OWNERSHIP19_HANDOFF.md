# Optional activity ownership — Artist19, 20 September 2026

## Applied patch

`assets/maps/city_rebuild_v1/npc_civilian_activity_source.js` only. Optional conversations, smoking and exercise no longer preempt a published `building_entry` or `civilian_bench` journey. The unfinished `civilian_road_exit` safety route is also protected. Guards require an actual nonempty route; ordinary walking remains eligible for optional leisure. Existing visit, seat, vehicle and threat ownership guards remain unchanged.

The old conversation path accepted shop and bench walkers, cleared both prepared routes, and retained their destination/reservation IDs. Conversation has no route-resumption snapshot because it changes physical position. Consequently both residents needed fresh route searches afterwards. The new regression reconstructs the prior admission guard and reproduces this exact loss before checking the correction.

The existing elderly exercise exclusion now recognizes the real `pensioner` archetype in `world.html`, as well as the legacy `oldman`/`oldwoman` keys. Looking around remains allowed. No animation, actor population, transport, police or route scheduler code changed in this patch.

## Checks

- `node test_npc_activity_ownership19.mjs`: PASS, actual activity module and actual source eligibility/route helpers; baseline route-loss reproduction; protected shop, bench and road-exit movement; ordinary walk conversation/smoke/sport retained; pensioner policy; native visit/seat ownership.
- `node test_npc_activity_route_resume18.mjs`: PASS. Fixture now covers ordinary walk pauses, because shop journeys intentionally no longer pause for optional leisure. Same route/plan identity, collision, threat and stale-resumption checks retained.
- `node test_npc_outdoor_activities.mjs`: PASS.
- `node assets/maps/city_rebuild_v1/test_npc_activity_agenda.mjs`: PASS.
- `node --check assets/maps/city_rebuild_v1/npc_civilian_activity_source.js`: PASS.

The new guard is constant work per eligibility check and avoids discarded route planning. Full-scene FPS and gameplay behavior are not verified by these CPU checks. Root owns the single existing browser and the next reload/observation. This helper opened no GPU/browser.
