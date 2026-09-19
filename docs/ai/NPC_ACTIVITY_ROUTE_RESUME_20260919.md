# Activity lifecycle: keep an existing journey through a stationary pause

Status: small source patch ready; not yet visually accepted in the shared game.

## Reproduced defect and fix

Before this patch, smoking, stretching, squatting and looking around cleared an already published walking/shop route. The original shop plan survived, but completing the 4.5–13 second activity left the resident without a route. It had to rejoin the city route queue even though it had not moved.

`npc_civilian_activity_source.js` now saves the untravelled points for these four stationary activities. On ordinary completion it resumes only if the same plan, phase, destination, cycle and position remain, no other route has replaced it, and the first segment is still clear for the full NPC footprint. Normal movement still checks subsequent segments. Threats, player conversations, displaced actors and changed/blocked journeys do not restore the saved route. Conversations and jogging retain their existing physical movement and cleanup.

Optional activities also no longer begin while a directed or wander search is pending; previously attachment cancelled the resident's real queued journey.

No caps, population, route budget, vehicle code, server income or world ownership changed.

## Verification

- `test_npc_activity_route_resume18.mjs`: previous source behavior reproduced lost route; all four stationary activities restore only remaining points. Threat, displacement, changed plan/destination/cycle, dynamic blocker and player conversation reject stale restoration. Both pending-search types survive optional activity selection. 13 cases pass.
- `test_npc_civilian_activities.mjs`: approach/talk/finish, intent preservation, read/real bench release, death/panic/phone interruptions and smoke completion pass.
- `test_npc_outdoor_activities.mjs`: out-and-back jog, cadence, continuous obstacle sweep, original identity/HP/plan and interruptions pass. Fixture now imports the actual `_setNpcRoute` helper needed by route resumption; assertions unchanged.
- `test_civilian_purposeful_plan.mjs`: shop intent, entry, bench ownership and rest cycle pass.
- `test_npc_actual_shop_visit.mjs`: actual print-shop GLB collision, 9.03m physical entry/exit, newspaper purchase 55→52, next walk-to-bench phase pass. This is session NPC commerce, not server business income.
- Actual male/female GLB tests for social, outdoor, bench and phone poses pass.

CPU benchmark from a standalone run of the resume test: the matched small pause/finish fixture measured roughly 0.003/0.007ms p50/p95 before and 0.006/0.009ms after. Added work occurs on activity start/completion, with a single first-segment check on successful resumption. This fixture is not the full scene collision workload. **Performance of the shared rendered scene is not verified**; no GPU tab was opened.

Read-only animation contract audit: source `_npcCivilianActivitySnapshot` reaches `world` NPC snapshot `activity`, then `normalizeNpcSnapshot.life`, then actor social/activity poses. Read/talk/smoke use `npc_social_pose`; stretch/squat/lookaround and physical bench/phone use `npc_activity_pose`. Jog uses source moving/running state and the usual locomotion. This establishes wiring, not LIVE appearance acceptance.

## Separate defect sent to root

`test_npc_bench_retry_audit18.mjs` reproduces a definitive failed bench being retried twelve times over 60s while another reachable bench is never selected. `_civilianPlanNext` retains the failed `benchId` and prefers it every retry. Root owns the narrow world fix; this subagent did not edit world. That file initially asserts the defect, so root must convert it to the expected fixed behavior when applying the fix.

City activity is still not fully accepted. Queue admission, actual car departures and a warmed shared-scene run remain separate work owned by root/coordinator/roads.
