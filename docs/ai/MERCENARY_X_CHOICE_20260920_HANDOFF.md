# X action choice, car numbers and chatter binding — 20 September 2026

Owner `/root/safe_operator_clearance18`; code/tests READY, LIVE belongs to Coordinator18.

- One enabled unique X action dispatches directly. Multiple eligible action kinds open a compact choice at screen center: unlocking, physical breach, demolition, etc., according to actual source eligibility. Duplicate same-kind choices from several specialists are collapsed. Source `host.command` still chooses the matching eligible specialist.
- The menu captures the original target, re-resolves it and action eligibility on button selection, guards repeated input while pending, and honors source rejection. Queue actions say “В очередь”. Escape or X closes without issuing a command. Pointer events stay in the UI; existing control-release hook and `walk.isOpen` block movement/fire. Current target keeps its marker while the menu is open. Completed/removed targets close the menu.
- The red overhead X on an aimed car is removed completely. The ordinary center X prompt remains. Only assigned/current/queued job numbers remain above vehicles; their anchor uses cached actual mesh roof bounds plus 18 cm in world coordinates, so model scale does not send numbers high above the car. No source geometry bounds are mutated, no car outline is added, and roof geometry is scanned only when a task target object first enters the cache.
- `createMercenaryChatter` is created only after a real host arrives, updated through the walk update loop, and disposed/rebound on host replacement. It never captures the initial null host. `walk.chatter.stats()` is available for LIVE checks. Chatter source/director/audio behavior is owned by `crew_follow_routes18`.

Files: new `mercenary_action_menu.mjs`; changes to `mercenary_walk.mjs` and `mercenary_task_markers.mjs`. Tests: new `test_mercenary_action_menu.mjs`; extended walk and marker suites.

Focused run **10/10 PASS**: exact chosen kick/bomb through actual QA door adapter, direct single-action behavior, queued choice, fixed-target/stale eligibility, rejected command, double-click guard, Escape/input isolation, car without aim icon, scaled roof anchor without geometry mutation, and late/replaced chatter host with one caption/subscription. Existing persistent marker/occlusion/wreck regressions also pass in this run.

Menu refresh is bounded to 5 Hz while open and rechecks source only at selection. Closed menus do no target work. Roof calculation is once per object; car markers add no draw calls. The existing ten-object marker CPU fixture is approximately p50 .0062 / p95 .0118 ms, excluding the shared scene spatial index. **No LIVE visual acceptance or shared-scene performance measurement was performed by this agent.**
