# Trip17 test-only checkpoint — paused by new squad transport priority

23 September 2026. Coordinator20 relayed the user's direct priority change:
squad boarding/free seats/ride/exit/fire from vehicle. Further trip17 work stops.

New test-only file: `assets/maps/city_rebuild_v1/test_transport_trip17_lifecycle23.mjs`.
Result: `outputs/transport_trip17_lifecycle23.json`.
No runtime files edited; no GPU tab.

Pinned authored snapshot SHA256
`7cc0043339615a3fecf74eb0c3c0ebc46b75a76c78cf82f133952f891bd8f8d9`, topology
`11f256f20ea5f8f5387fa4829173e84cf688aa2ba554aa5b6aacdb85301d67b6`.
Actual source producer, agenda, async worker, car hull, door access, and registry
run from the recorded car17/resident2 coordinates to the actual pine_ridge001
building. Uses actual compact fixture profile, NOT the still-missing LIVE shape.

First real lane result **READY1763points**, allowed lot
`parking:REBUILD-VISUAL-old_town_narrow_townhouse_v1-006`.
No lane-rejection/forwardfallback occurred in this fixed scene. The next
source approach tick released the trip with `approach-blocked`; neither car nor
NPC moved. Source IDs were preserved, registry returned0, destination slot was
released, origin bay reservation remained with the parked car. NPC agenda moved
drive→walk, completed1. This is NOT proof of a successful full trip or a replay
of the original LIVE lane failure. The approach refusal needs its own audit if
this task is resumed; no reason is invented here.

Existing assertions cover per-step travel bounds, source registry identity and
actual swept car movement if reached. Owner-interruption/slot cleanup matrix
and the requested first lane-rejection scenario are **not yet completed**.
The report's `pass:true` means the bounded scenario reached a release without
an assertion failure, not that every gameplay phase succeeded.

The earlier QA first-lane-failure candidate remains unintegrated and is still
the planned way to capture the missing original LIVE profile/reason/lot subset.
