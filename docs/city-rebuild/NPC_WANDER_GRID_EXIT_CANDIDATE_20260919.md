# Candidate: physical exit from an isolated coarse wander cell

**APPLIED root в world.html после прогретого снимка и снятия freeze.** Production helper `_npcFindWanderGridExit` и isolated-start hook в pickNpcWaypoint; точный origin guard включён. Название документа историческое. Новая игровая reload/LIVE пока не подтверждены.

Files:
- `npc_wander_grid_exit_candidate18.mjs` exports the bounded helper and a test-only insertion transform.
- `test_npc_wander_grid_exit_candidate18.mjs` exercises the current actual source with this candidate injected only into a VM.
- `outputs/npc_wander_grid_exit_candidate18.json` records actual geometry results.

The candidate runs only after the existing native coarse BFS has exhausted its sole origin node without finding any neighbour (`nodes.size===1 && queue.length===1`). It searches at .25 source-cell resolution, anchored at the exact actor position, within a three-source-cell square radius, up to 384 accepted nodes. It finds a physically reachable coarse cell centre and one additional clear coarse edge beyond that centre. The centre is thus an intermediate waypoint: existing .001 intermediate arrival requires physically traversing it before the unchanged .4 final arrival may finish the route. There is no teleport, collision-radius reduction, change to arrival logic, speed, FIFO or four-millisecond shared budget.

Each fine edge and final connection uses the original `npcWaypointOk`, full five-point .18 footprint sampled at .14 or less, and native continuous sweep. Both current actor locations and reserved coarse destinations are excluded as final endpoints using the original `occupiedGoals`. State is retained inside the existing `_npcWanderSearch`; its resolver/surface/plan invalidation and panic/death/cancel handling remain authoritative. The helper returns pending instead of creating a 1–2 second idle retry while reachable fine search is still in progress. Genuine closed geometry/water failure keeps the existing cooldown.

## CPU verification

`node test_npc_wander_grid_exit_candidate18.mjs`: PASS.

| Actual trapped origin | Physical connector travelled | Movement frames at 20 Hz | Next original coarse outing |
|---|---:|---:|---:|
| print_shop `(4.990913843951179,97.94314630350254)` | 6.86 m | 79 | 10 points |
| hospital `(6.469984627970292,165.137)` | 8.12 m | 94 | 10 points |

Every connector segment and every actual movement step passes native execution body/sweep collision. After each connector, the actor requests and receives a normal long route without invoking the fine helper again. Combined connector plus next normal search took 4–5 admitted slices / approximately 13–15 ms total CPU on the latest run; this is neither a frame-time claim nor a full AI update measurement.

Additional checks pass: slow retained search across admissions with stationary origin, resolver replacement, surface permission change, explicit cancellation, panic, death, truly enclosed land, blocked water, and reserved final goals. When `(6.5,98.5)` is occupied and `(7.5,98.5)` reserved, the print-shop connector selects the free `(4.5,98.5)` endpoint.

Root review added exact-origin protection: fine state stores `originR/originC`, and every generated node uses that immutable anchor. Any exact actor displacement invalidates/recreates the fine frontier even when `floor(r/c)` and the outer coarse key are unchanged. The actual print-shop regression shifts the actor by .02 source cells during a retained slice; the new path starts from the shifted position, every edge remains physically clear, and the actor is never restored/teleported to its earlier position. This change remains candidate-only.

Scope intentionally differs from the separate visit fallback: visits search toward a specific real door; this helper merely reconnects an otherwise isolated wander origin to the existing coarse graph. The two candidates share no production files. Bounded local escape does not guarantee a route for every city position. Full moving-city population cost, GPU/FPS and LIVE are not checked for this candidate.
