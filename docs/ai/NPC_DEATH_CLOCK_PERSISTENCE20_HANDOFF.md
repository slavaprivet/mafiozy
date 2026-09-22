# NPC death clock persistence20 — production READY, 2026-09-20

Approved by Coordinator20. Actor released after this patch. Only `npc_actor.mjs` save/validate/restore changed; deathPresentation, pose, source health/clocks and mixed expired-stun logic were not edited.

## Defect and result

The population can sync a death at time15 while a culled actor's last rendered time is10. Saving before its first death update previously lost absolute sourceDeathAt: saved raw age0 plus private time10 restored as a death at10. Actual population cull/reentry reproduced raw age5.01 instead of0.01, skipping the fall.

New optional version1 field `sourceDeathClock:{at:sourceDeathAt,snapshotAt:time}` preserves this information. Null means no authoritative source death clock. Restore uses `at + (restoredTime - snapshotAt) - elapsedSeconds`, handling both the original timeline and a rebased local timeline. Missing/null metadata uses the exact legacy restore path. Existing old saves cannot recover information already lost; no guessed correction was added.

The optional field is validated before state mutation: finite timestamps and difference, matching saved surface time, dead reaction, nonempty source key, and consistency of `max(0,snapshotAt-at)` with saved raw age. Invalid or overflow projections fail atomically. Source death time later than the last displayed snapshot is intentionally valid.

## Tests

`test_npc_death_clock_persistence_prototype20.mjs` retains its historical name but is now a production regression (`integrated:true`), with baseline reconstructed by reversing exactly the three new substitutions in memory.

- Actual male/female: six restore clock variants each, JSON roundtrip, zero bone matrix difference against uninterrupted reference; root and weapon retained.
- Repeated external sync without update; new death epoch without an intermediate update; death/respawn/reuse; receipt-only death; legacy saves at elapsed0/30; malformed metadata rejected atomically: PASS.
- Actual population hide/sync/reentry: raw age5.01 →0.01000000000000156; headY0.368437 →1.493108, the correct fresh death frame.
- Surface serialization suite: PASS.
- Death integration suite:24 PASS.
- Recovery production regression: PASS; original recovery audit:8/8 PASS. Updated only two baseline rollback anchors to preserve the newly integrated death renderer and deathPresentation restore.
- Existing `test_npc_lifecycle.mjs`: FAIL at line28 medical downed/sourceDown expectation. Exact in-memory rollback of this persistence patch fails identically. This is a pre-existing current-tree issue, outside this patch; reported to root. Earlier stun/recovery assertions in that suite pass.

## Cost and limits

No new per-frame work or meshes. Save adds one small two-number record; restore validates it. No isolated save/restore CPU benchmark was taken, and performance of the complete scene is not checked. Recovery regression's incidental parallel-run CPU numbers are not a persistence cost measurement. No GPU/browser run; LIVE acceptance remains with Artist19.

Separate mixed expired-stun/fresh-death prototype remains unintegrated. Next vehicle-pose/death continuity work is isolated pending a separate approval.
