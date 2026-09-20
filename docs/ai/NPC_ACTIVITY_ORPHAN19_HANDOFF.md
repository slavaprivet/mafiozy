# Civilian orphan activity/bench cleanup — Artist19

2026-09-20. Approved bounded patch. READY for root's next shared LIVE reload; agent performed no reload/push/GPU run.

Production scope: only `npc_civilian_activity_source.js::_npcPurposefulSocialTick`, on its existing 1,400-ms cadence.

- Removed NPCs no longer hold their bench reservation until the 120-second route lease expires. A Set of currently present NPC IDs controls absent-owner cleanup.
- Detached/replaced activity records release their entry in the shared activity set. Cleanup checks each member's current `_civilianActivity.record` identity. The existing release handler preserves any replacement activity and cancels only participants still owning the old record.
- Present pending, walking and seated owners retain their bench claims. No path-completion requirement was introduced. Full valid activity sets remain full; this is not forced eviction or an activity-density change.
- Membership uses Sets built once per rare cleanup, only when the relevant resource set is nonempty. No per-frame NPC×bench scan; no animation/agenda/navigation authority changes.

Verification:

- `test_npc_activity_orphan19.mjs` PASS: reproduces both old failures, then checks absent owner, cleared/replaced record, unchanged replacement owner, pending/walking/rest controls, talk/jog/smoke/read removal, dead reader bench release, full active set and cleanup cadence. Actual source lifecycle functions; route creation boundary stubbed.
- Existing `test_npc_civilian_activities.mjs`, `test_npc_outdoor_activities.mjs`, `test_npc_activity_elapsed19.mjs`, `test_npc_bench_pending_reservation18.mjs`, `test_npc_activity_agenda.mjs` PASS.
- `node --check` helper PASS.

CPU-only comparison with 288 NPCs, 20 active records, 100 seat claims: rare cleanup p50/p95 before 0.016/0.034 ms, after 0.099/0.207 ms in the observed run. Additional bounded cleanup work occurs once per 1.4 seconds. This is not a full-scene FPS measurement. **Performance of the loaded shared scene has not been measured by this agent.**

These edge cases are demonstrated resource-lifecycle failures, not a claim that they explain widespread LIVE idling. Ordinary completion, threat and death paths were already passing their relevant regressions.
