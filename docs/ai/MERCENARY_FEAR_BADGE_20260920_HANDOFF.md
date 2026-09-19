# Fear marker — 20 September 2026

Presentation owner `/root/safe_operator_clearance18`; source state owner `/root/crew_follow_routes18`. Source contract: [MERCENARY_INTIMIDATION_WITNESS_20260920_HANDOFF.md](MERCENARY_INTIMIDATION_WITNESS_20260920_HANDOFF.md).

`mercenary_badges.mjs` now shows a compact warm-colored **Страх** marker over frightened ordinary NPCs as well as specialists. It does not require squad membership or current aim. It reads only actual renderer snapshot fields: `actor.source.fearActive === true` and finite `fearExpiresAt > Date.now()`. HP/death/downed guards suppress the marker. Generic `_fear`, panic flags or a recent intimidation animation do not invent fear state.

An ordinary frightened character gets the compact fear-only card, not an extra large citizen/profession panel. Existing squad labels remain intact. Labels use the existing head anchors, first-frame camera projection, HUD masks and wall-occlusion policy. Expiry hides immediately during projection even before the next card-registry pass. Actor removal and death remove the card normally.

At most 12 frightened nearby actors are retained, within the existing 32 m display radius; the currently selected frightened actor receives priority. Nodes are retained while active and reuse existing cards. Fear does not create a new fullscreen overlay, meshes, lights or a separate raycast loop: all badges share the existing global 10 Hz occlusion budget. With many labels, refreshing wall occlusion can therefore take more than one second; camera/offscreen and expiry hiding remain immediate.

**25/25 PASS** in badge and overhead-speech suites. New cases cover ordinary off-aim frightened NPC, compact label, actual epoch expiry, ignored generic panic flags, wall and camera hiding, retained node, 12-label cap, source death and unchanged global ray budget. Source owner's actual snapshot and witness tests are documented separately.

**LIVE and shared-scene performance not measured here.** Root can reload the combined package, intimidate an ordinary NPC, then turn away/return and observe “Страх” only during its real fear memory. Presentation adds no 3D draw calls; no extra per-frame scene rays were introduced.
