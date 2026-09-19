# Custody source camera follow — 13 September 2026

LIVE root evidence: source convoy/hero position r98.8499164424,c153.3260940234 (native x628.6369855,z405.2846574), but camera remained x167,y2.74,z168 and displayed empty road.

Confirmed cause: `walk_preview.mjs` `updateNpcPopulation` applies a locked `syncWalkPlayer` receipt at the end of the frame by changing only hero.position. Camera/OrbitControls target and `surfaceMotion` floor state stayed at the previous source location. The following frame could restore stale support before ordinary camera following.

Scoped fix: validate finite source r/c, restore any temporary building camera clamp, apply source position, reset foot support at that new position, shift camera and controls.target by the actual displacement. Preserve camera orbit and source vehicle ownership/navigation. No vehicle motion, refresh, NPC AI, or HP changes.

`node assets/maps/city_rebuild_v1/test_npc_source_camera.mjs` extracts and executes actual production `updateNpcPopulation`; the exact LIVE coordinates failed RED before and pass GREEN after. Checks immediate camera/target follow, current floor state, unchanged orbit, no duplicate offset for repeated receipt, follow during later transport, unlocked path unchanged.

CPU callback with 200 warmup +1000 samples: previous branch p50/p95 .0039/.0052ms; fixed .0051/.0065ms. Not a GPU or loaded-scene frame measurement. No browser was opened. Root owns LIVE reload acceptance and queued GPU use.
