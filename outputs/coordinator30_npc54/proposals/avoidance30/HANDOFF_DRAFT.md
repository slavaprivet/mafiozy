# navigation29 avoidance — isolated candidate

Do not integrate yet. Current source has 23 source/patch/grammar checks; the final native run is pending because the shared scheduler reports unrelated unregistered shop-test engine processes. Historical native passes do not validate the latest source.

## Scope and integration

Two new scripts: `scripts/navigation/npc_local_avoidance29.gd` and `scripts/navigation/npc_avoidance_world29.gd`. Apply `patches/simple_avoidance29.patch` against integration29 Simple SHA `2a95ca719fd7b7353cb18526af5d988f2cebb3cd09517e9f7506f70d25e4867d`, and `patches/population_snapshot29.patch` against population SHA `0f10997488db61226a08cfa86bbd415d83be91fc1bc0d8ca4280430fce685b44`. Later root edits require a three-way merge of these narrow hunks, not replacing root files with this full Simple copy.

Population refresh precedes `daily.step`. The adapter uses the existing scene population records, then a stable snapshot is reused for every actor in that physics frame. Simple keeps its complete capsule, live collision, water/support, gravity, cancellation, attention pause/resume and path-search guards. No physical planner source is changed. Local steering can hold or request the existing safe replan; it cannot teleport or move a body independently.

Venue interaction is readonly `doorway_state29(body)`: crossing owner gets priority 100; a client already at its queue/service slot holds. Avoidance never requests/releases/touches capacity, portal, service or emergency claims. The separately frozen venues29_staff seam is required for these hints. Without the method all actors receive ordinary priority.

## Cost and hard bounds

A single O(N) snapshot; at most 384 actors. At most 16 new steering decisions per physics frame, each checks at most 75 grid cells, scans 64 candidates, selects the first 8 local candidates, and evaluates at most 24 pairs. There is no global actor sort or per-actor traversal of the whole crowd. Dense one-cell buckets use a rotating offset and early caps, not a 286-entry sort. Selection is bounded local sampling, not exact nearest-neighbor ranking.

Small populations reconsider at most every 6 frames (10 Hz at 60 Hz). All stable 286 participants receive their first decision by frame 18 and then approximately every 18 frames (300 ms). For 384 the bound is 24 frames. This latency is a stated cost tradeoff, not a reduction in population. Cached decisions store a relative turn, so each caller's current waypoint direction takes effect immediately. A lone actor follows its input directly. First admission waits if the decision cap has been consumed.

Costs must include all 286 calls, snapshot and input refresh. Earlier component run09 measured core + 286 calls: ordinary spaced median 1.616 ms / p95 2.364 ms; dense moving 1.934/2.307; dense stopped 1.865/2.125; adversarial all-in-one-cell 1.808/2.112. These are historical, before the latest relative-heading fix, and exclude native adapter gathering, native collision, world movement, animation and rendering. They ran under the functional scheduler while the user's game stayed open. The requested 1–2 ms full cost and full 286 FPS are NOT accepted. The earlier 16.6 ms candidate and all failed runs remain preserved.

## Lifetime and behavior

Core rows contain numeric values only. Adapter body/shape caches are weak and bounded by the current snapshot; keys include source, generation and body instance. Missing/dead/queued-for-free bodies leave the next snapshot and cache. No body/controller/scene ownership cycle is introduced. Pauses, FIFO waiting and time before the first movement attempt cannot trigger the 3.5-second no-progress replan. Deterministic right-side preference uses 1.2-second side dwell and 0.6-second yield dwell to avoid rapid left/right switching. Persistent physical obstruction requests a normal full-capsule route replan.

The hard caps ensure bounded work, not mathematical collision-free planning in arbitrary crowds. Omitted neighbors still meet live native capsule collision. A permanently blocked narrow corridor cannot be solved by local steering alone. In an earlier 2.2 m corridor, a stationary .72 m-diameter body on the center line left only .02 m extra lateral clearance; the .4 m physical grid found no route. Final fixtures therefore model the actual venue contract: queue slots outside the center line and a room wider than the doorway. Infeasible spawn overlaps, blocked exits and hostile geometry remain explicit limitations; collision or water guards are never relaxed.

## Native validation plan and evidence

`run_fixtures29.py <fresh-run>` stages a private tiny project under scheduler write lease, imports, then acquires read leases for zero-body 286-proxy tests and native collision tests with at most three actual bodies. No main game, F5, frozen previous proposal or Git is modified.

Proxy tests cover ordinary, dense moving, dense stopped and one-cell adversarial cases; bounds, all first admissions, repeated service, retirement, overflow rejection, backward clock/frame rejection, FIFO resume, replacement generation, idle/paused time and current-waypoint heading. They are component tests, not gameplay performance.

Native tests: two opposing walkers, three-way merge, FIFO queue behind an actually closed door opening after two seconds and actual Simple driver versus driver. The queue fixture begins its service drive only when the FIFO owns passage; no route job is submitted on behalf of a held queue client. It checks real door-plane crossing and off-axis room slots. A separate adapter test disables/deletes a real fixture body and checks weak-cache cleanup.

Historical runs09 two-way, merge, actual Simple two-way passed; queue crossed all three but its third actor took an old prequeued detour. The fixture/controller timing and idle timer were corrected in current source, which needs a new native run. Earlier grammar failures and scheduler blocks are retained and are not evidence of PASS.
