# Resident initial intent — source audit, 27 September 2026

Status: **source initial-choice oracle PASS; runtime intent/agenda OPEN**. This package does not add a substitute wander controller. No main, resident host, visual, policy, source packet or production test was changed. `preview_resident_intent.gd` was deliberately not created: the requested general decision cannot yet be supplied by a row, clock and nearby-candidate callback without replacing source owners.

All three raw rows remain `_npcInitialPlacementPending: true`. Coordinator's actual native policy check reports their raw positions on roads. **They are not admitted actors.** No resolved coordinate is produced here. Initial safe placement must complete before road egress, agenda or wander; hypothetical admitted-copy oracle results below are not permission to move them.

## Reproduction and immutable evidence

From repository root:

```powershell
node outputs/coordinator21_resident_intent/build_initial_intent_oracle.mjs
```

Exit 0; assertions verify all three pending gates leave their rows unchanged, exact rotated agendas and outcomes, zero unexpected RNG draws, native arrival idle clock, and unchanged packet bytes. Output: `outputs/coordinator21_resident_intent/initial_intent_oracle.json`. The generator executes the actual unchanged agenda module, four source eligibility functions and the actual calm-arrival fragment from `world.html` in a Node VM. External owners are throwing capability seams: no fake `false`/unavailable response is supplied. It does not execute the full world loop, placement, navigation, cars, commerce or LIVE.

| Input | SHA256 |
| --- | --- |
| `world.html` | `9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5` |
| `assets/maps/city_rebuild_v1/npc_activity_agenda_source.js` | `acf8a3a5a83bd85203cd47fcccfe9460592c45eb775dfefae95dd8ec1de3ef5c` |
| `assets/maps/city_rebuild_v1/npc_initial_placement_source.js` | `65a4fe4736f9b31e037da760b26b86150de0e303cf7496924488c4dbd2db3b60` |
| `assets/npc_visual/session/e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096.json` | `e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096` |

Source clock at packet boundary: 0 ms, game minutes 720. Shared RNG receipt: mulberry32/v1, seed 20260927, draw_count 6356, `BEFORE_ORDINARY_INIT_LOOP`. This is a shared continuation, not an instruction to reseed every resident independently. Other source owners can consume later draws.

## Actual initial choices, conditional on accepted placement

| Identity / role | Exact initial agenda queue | First decision after hypothetical admission |
| --- | --- | --- |
| resident_72 / housewife | walk, bench, walk, drive, walk, shop | walk: requests source wander selection; no destination selected by this oracle |
| resident_169 / student | drive, walk, shop, walk, bench, walk | calls `_npcAgendaTryDrive(n, now)`; unresolved trip/car owner, not a walk fallback |
| resident_252 / pensioner | walk, drive, walk, shop, walk, bench | walk: requests source wander selection; no destination selected by this oracle |

For each unadmitted raw row `_npcAgendaPick` returns null and makes no mutation. Initial queue rotation uses FNV identity hashing, **zero Math.random draws**. The hypothetical admitted native healthy arrival sets `idleUntil = now`, `walking = false`, then calls `pickNpcWaypoint`; it does not add a random idle interval. Source idleMult values remain 2 / .25 / 2.8; they do not activate legacy random idle in this branch.

The raw speed fields are .7716332539566793 / 1.3573183923843315 / .565774921728298. They are not already native metres/second. Existing `resident_speed_oracle.json` and host own the healthy effective-speed mapping (1.3118482738187358 / 1.8 / .912652391870984 m/s at this receipt). No new speed, pace, role or identity was assigned.

## Prerequisite: source initial placement ownership

Actual source is `npc_initial_placement_source.js` and `world.html:9382` onward. It collects NPCS, cityCops, worldCops in that order, deduplicating object identity. The spacing pool contains collected rows even when a row is excluded from relocation. Police may use x/y rather than r/c. A cropped three-row packet alone is insufficient to reproduce spacing.

The source first tests the current point with the correct resident/police body-pass function. On failure it scans rings starting at .25 tile, index 0; candidate angle = index × 2π / min(64, max(8, ceil(radius × 10))). Radius increases by .25 below 6, .5 below 24, then 1, bounded by the map diagonal. Each row gets at most 16 local attempts before returning to the shared FIFO. Initial step admits at most 128 checks / 4 ms; later default steps 96 checks / 2 ms, both using actual monotonic CPU time. No random draw is used.

Candidate acceptance requires body pass and distance at least .55 source tile (2.255 native metres) from every other collected non-dead row's **current** position. Current-point success does not run the relocation spacing test. Accepted relocation updates r/c/tr/tc (or police x/y/tx/ty), clears owned routes and water-escape state, sets walking false / walkPhase 0, and deletes the pending flag. Exhaustion retains pending rather than displaying a blocked actor.

Required native bridge: same-session full spacing roster with order, kind, coordinate convention, identity aliases and lifecycle updates; exact current policy/body queries; retained ring cursor/FIFO across bounded slices. Artist21 supplies the roster/placement package. This audit must not fabricate its result.

After placement authority accepts coordinates and the host has actually created and bound the physical/visual actor, host may create a **separate mutable logic copy** in its runtime record, apply accepted coordinates/reset patches and delete `_npcInitialPlacementPending` there. The success point is `_admit_record` after body insertion and gait binding, immediately before returning IDLE. A failing policy, physical, visual or gait stage must not publish that copy as admitted. Do not alter `record.row.source_raw`, descriptor/session hashes or source bytes. Bind the copy to session, source ID and owner generation; discard it on owner death/replacement/disposal. This requires the future placement-result bridge; the current host's raw-position admission alone is not sufficient.

## Dependencies before a real goal can be published

The source order in `pickNpcWaypoint` (`world.html:11006`) is road egress → retained agenda/owner → retained native wander search. The main update loop also runs higher-priority health, activity, trip, visit, threat and conversation owners before calm walking. Their absence cannot be encoded as always-false source state.

| Owner | Required semantics / next implementation |
| --- | --- |
| Road egress | Execute `npc_road_egress_source.js` against actual centre/corner surface state and directed body sweeps. Preserve retained target, shared route admission and retry; do not declare no egress needed merely because placement happened earlier. |
| Agenda state | Port the exact finite queue and adoption/completion rules, retaining `started`, current/index, lastResult and existing plan/search ownership. Effect calls must distinguish READY, PENDING, definitive UNAVAILABLE and missing provider. A missing drive/shop/bench owner leaves migration pending; it must not advance the agenda as source-unavailable. |
| Drive, first needed by resident_169 | `_npcAgendaTryDrive` → civilian parking/trip, source vehicles, reservations, access and shared attempt limits. An actual authoritative search may return unavailable; absent native vehicle AI cannot. |
| Shop/bench, next needed by 72/252 | `_maybePlanResidentBuildingVisit` / `_civilianPlanNext`, real doors/access, business and bench reservations, ordered places, retry timestamps, directed retained routes and completion hooks. Intent does not own commerce or seat occupation. |
| Wander goal owner | Port exact retained lazy DFS, deterministic direction order, fine-grid escape, goal reservation checks and RNG publication. A nearby-candidate list or native shortest-path endpoint cannot replace source expansion order. |
| Shared scheduler | `_npcReserveRouteWork`, `_npcRouteWorkExpired`, `_npcFinishRouteWork`: global oldest cohort/FIFO, current maximum 8 admissions and 4 ms route work per frame. Retained search keys and resolver/pass identity invalidation must survive yields. Use current source, not older docs describing 2 admissions or 8 choices. |
| Occupied goals | Full current NPCS, excluding only the source's dead/indoor/self checks, including both current cells and reserved goal cells. Three rendered residents are not the full reservation authority. |
| Clock/RNG | Inject source monotonic now and shared RNG continuation; preserve draw ordering across actors/owners and fresh `performance.now()` reads on idle-failure branches. CPU admission clock is a separate requirement from simulation delta. |

Source wander details: max depth 18 (22 for beach), 520 visited cells, early finish on the first eligible long candidate; long means depth >=8, distance >=6 tiles (24.6 m), and >5.5 tiles from previous outing origin when present. Only after exhausting the available search does fallback use depth >=6 then all candidates. Native direction shuffle is deterministic FNV/xorshift by ID, cell and previous origin, not Math.random. Point/sweep checks retain .18-tile five-point footprint and .14-tile edge sampling; exact-point dedup is local to one admitted slice, so changing doors/water/vehicles are rechecked later.

Source final choice consumes one Math.random draw even for a one-element pool. Empty pool consumes one draw for `now + 900 + random*1200`. All goals occupied consumes goal-choice draw plus one for `now + 500 + random*700`. Pending work consumes none. Route arrival completes walk before requesting the next agenda activity; ordinary blockage >900 ms clears/replans. Preserve these boundaries in the source oracle for the next package.

The host's present 8-metre request limit is a preview admission restriction, not source design. Root may permit a proved full source goal through bounded native navigation (backend supports up to 512 m), but must not shrink the goal to 8 m, segment it as new agenda outings or repeatedly choose nearby points. Native pathfinder owns physical motion; source goal selection and arrival/completion authority still need the above port.

## Concrete next delivery sequence

1. Artist21 placement package supplies same-session full roster, retained exact ring search and accepted per-owner patch, with actual JS trace and real policy queries. Root admits physical actors only from that result.
2. Port pure agenda transitions plus typed effect requests/continuations; keep unknown external authority distinct from definitive unavailable. Oracle covers pending placement, 72/169/252 initial queues, in-progress owners, interruptions, pending retries, successful arrival and rejected stale generation.
3. Port source wander selection and road-egress adapters with full reservation view and shared work leases. Compare ordered source query/RNG traces and complete goals, including dead ends, fine-grid escape and invalidation. Root then reviews full-distance host admission.
4. Supply real drive/shop/bench executors and completion/reservation bridges. Until then report AGENDA_PENDING explicitly; no fabricated local walk substitutes for resident_169's initial drive.
5. Measure logic update cost in the same loaded scene and coordinate one LIVE run through root. This audit launched no GPU and makes no whole-scene FPS or visible-NPC-behavior claim.
