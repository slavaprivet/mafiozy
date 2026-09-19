# Own-member E dialogue and queue label occlusion — 20 September 2026

UI owner `/root/safe_operator_clearance18`; source conversation owner `/root/crew_follow_routes18`. Single LIVE tab remains with Coordinator18.

## Behavior

E in front of a living visible squad member within 2.5 m opens the personal conversation. It wins over candidate recruitment and ordinary building/vehicle input when that own member is eligible; money-bag pickup keeps its existing priority. The choice is recomputed at key press and requires line of sight, a visible rendered actor, the same vertical level, and a living source member. Downed/hospital members remain rescue/medical targets. A missing/behind-wall/far own member does not consume E.

The conversation shows name/profession and a clear **Уволить бойца** button, retaining the explanation-of-skills option. It calls only `host.dismiss`; pending UI blocks repeated clicks, source rejection remains visible, and accepted dismissal closes the dialogue. Source owns removal, civilian return, and exactly-once return of issued inventory. Existing badge/card `openMember` and roster dismissal remain available. Dialogue pointer/mouse events stop propagation and opening uses the existing `onOpenChange` control release, so clicks do not fire weapons.

Candidate recruitment remains unchanged apart from correctly respecting an object `{ok:false}` conversation receipt; previously the walk adapter only rejected literal `false`.

## Queue number visibility

Persistent number labels now use the same opaque-material / ignored actor / hero / mercenary-decoration policy as friendly badges. An indexed `getPickRoots` ray hides labels behind walls. Work is bounded to one ray per 50 ms, at most ten label targets, oldest-check-first. Camera projection still follows every rendered frame; new targets start hidden until checked. Invisible/detached/behind-camera targets hide immediately. Opaque cover visibility may take one bounded scan cycle (roughly 0.5–0.7 s for ten targets) to refresh. 3D arcs retain depth testing.

## Verification

Dialogue, task markers and walk integration suites: **11/11 PASS**. Existing command UI and source-world regression: **59/59 PASS**, including issued-gun reconciliation/return and original roster dismissal. New cases cover own-member E priority, 2.5 m cutoff, wall LOS, downed exclusion, rejected source receipt, single dismissal despite repeated click, disappearance during conversation, and DOM weapon-event isolation. Occlusion tests cover opaque walls, transparent decoration, hero ignore, cover removal, ray cap and retained geometry.

Existing ten-marker CPU fixture remains approximately p50 0.0057 / p95 0.0110 ms without obstacle-query work. This does not establish the cost of the game's spatial index or shared scene. **LIVE and shared-scene performance remain unverified in this agent.** Source member conversation integration is delivered separately by the source owner; root should verify movement hold/release and real inventory after dismissal in the one active game tab.
