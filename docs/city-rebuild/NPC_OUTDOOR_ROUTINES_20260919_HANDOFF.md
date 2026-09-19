# Outdoor resident routines — 19 September 2026

Existing source residents now occasionally jog a short circuit, stretch, squat or look around between their normal tasks. Shopping, bench reading, conversations and smoking remain in place. NPC identity, health, original civilian plan and economy are not replaced.

## Source and animation

- `npc_civilian_activity_source.js`: existing social scheduler distributes starts every 1.4 seconds, examines at most 12 outdoor candidates and starts at most one action. Caps: three jogging residents, two stretching, two squatting, two looking around; existing total activity cap 20 is retained. Choices use the resident's deterministic key and changing time bucket. Sports require healthy nonelderly residents without a carried gun; looking around is also available to elderly residents.
- Jogging copies up to four points from an already completed ordinary walking route. No BFS/A* job is added. The resident physically jogs out and back at 2.6 m/s, turns using actual movement direction, then resumes their original plan. No coordinate teleport or reversed gait. An absent/pending/short route safely postpones the activity.
- Accumulated distant-update time is consumed up to 0.5 seconds, including waypoint corners, with a bounded loop over at most eight copied points. Each traversed segment is swept separately. Five 0.05-second updates and one 0.25-second update produce equal positions and heading throughout the route and turnaround; far cadence does not slow the jog or create waypoint pauses.
- Admission and movement use full footprint dry-land checks and the existing native exact sweep. Roads, water, solid geometry and dynamic vehicle checks are retained. Stationary exercises repeatedly validate their available space. Existing indoor, visit, vehicle and threat exclusions remain authoritative.
- Panic, combat, death, emergency calls and armed state interrupt these routines. Cleanup clears only the owned `_civilianJogRunning` flag, preserving common panic running. The `world.html` snapshot now ORs that flag into existing `running` presentation.
- `npc_activity_pose.mjs`: both hands reach upward during stretching; squats lower the visual hips by up to 24 cm at 1.9 m height while IK keeps both feet planted. Looking around turns head and chest. A 0.7-second envelope eases pose entry and exit. Source coordinates and bone lengths do not change. No new geometry or props are introduced by these activities; warmed overlay creates no THREE instances.

## Checks

PASS `test_npc_outdoor_activities.mjs`: physical out/back movement, speed bound, genuine heading reversal, body terrain and continuous solid checks, absent route, original task/ID/HP preservation, panic/death/phone/weapon interruption, common running flag preservation, elderly exclusion, bounded scheduling across 288 residents with all action types represented.

The coordinator caught a WIP runtime exception after reloading the shared game: a walk-kind resident could have a null route. This is now guarded with `Array.isArray` before `slice`; null, undefined, empty array, object and string route regressions all pass. A fresh live reload must confirm that the shared game has this fixed source before declaring live readiness.

PASS `test_npc_outdoor_pose.mjs`: actual male and female GLBs, unchanged root and bone lengths, finite poses, smooth entry/exit, expired/blocked/armed overlay, no new geometry or warmed THREE construction. Stretch hand excursion 0.67–0.69 m; squat hips 0.24 m; foot error approximately 0.000001 m. Largest successive 50 ms hand movement is 0.073 m.

Existing `test_npc_civilian_activities.mjs`, `test_npc_social_pose.mjs` and `test_npc_shop_pose.mjs` pass. Existing reading/smoking/talking and checkout animations remain covered.

## Cost and limits

Source active stationary sport CPU p50/p95 approximately 0.0035/0.0039 ms per resident in a warmed source-only test. Compared on the same actual rig with alternating warmed updates: idle actor about 0.05/0.06 ms p50/p95, sports about 0.21/0.24 ms (four simultaneous athletes capped). No additional render meshes or route searches. These are isolated CPU measurements, not city FPS acceptance. Performance and appearance in the complete GPU scene remain for the coordinator's single live game tab; no competing browser/GPU run was opened.
