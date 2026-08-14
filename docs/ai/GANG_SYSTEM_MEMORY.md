# Mafiozi gang-system memory

Last reconciled with GitHub `main` at `1be90e35e013d280701e62af331a580ab24ba5df`
on 2026-08-14.

This is the canonical hand-off for work involving gangs, bosses, criminal
empires, diplomacy, properties, guards or raids. It records contracts that are
easy to break when looking at only one file. Confirm details against current
source before editing and update this document whenever a contract changes.

## Read order and ownership

1. Read this document for gang gameplay and server invariants.
2. For any 3D or `world.html` visual change, also read
   `docs/ai/OPTIMIZATION_MEMORY.md` completely.
3. Treat `npc_empire.py` and SQLite as authoritative for the 19 NPC families,
   their economy, diplomacy, holdings, guard assignments and raid sessions.
4. `mafiozi_bot.py` owns API/WebSocket integration and the broader shared-world
   simulation. `world.html` owns the main client and `three_preview.js` the 3D
   presentation bridge. Do not create a parallel client truth.
5. Publish only with the repository's safe `github_upload_*.py` scripts. Never
   use `git push` for this project.

## System map

There are three related but distinct layers:

- Player gang: hired `gang_members`, district assignments and concrete property
  guard assignments. One living member cannot occupy several assignments.
- Nineteen NPC empires: persistent bosses with profiles, treasury, members,
  strength, HQ, holdings, diplomacy, memory, actions and comeback lifecycle.
- Street gangs: bounded city encounters with their own fighters, morale,
  surrender, reinforcement and police response. Do not silently merge street
  gang actors with an empire roster.

The server advances strategic state in bounded ticks. The client visualizes
snapshots with capped pools and throttled reconciliation. Strategic decisions
must never be evaluated per render frame.

## Principal files

- `npc_empire.py`: profiles, schema, economy tick, diplomacy, ownership,
  recruitment, guard assignment, target intelligence and raid resolution.
- `mafiozi_bot.py`: routes/endpoints, player business snapshots and shared city
  combat services.
- `world.html`: primary game client, 2D/DOM state, routes, business interiors,
  combat state and preview fixtures.
- `three_preview.js`: 3D actors, family appearance, labels, projectiles and
  alert/marker rendering.
- `docs/ai/OPTIMIZATION_MEMORY.md`: 3D allocation, pooling and validation rules.

## Core database ownership

Important tables include:

- `npc_empires`: one row per boss; treasury, members, strength, status, HQ,
  recovery and action clocks.
- `npc_empire_holdings`: NPC HQ, legacy businesses and converted buildings.
- `npc_empire_relations`: player-to-boss score and pact.
- `npc_empire_diplomacy`: symmetric NPC-to-NPC score, pact and tension.
- `npc_empire_player_wars`: persistent player-war phase and next attack time.
- `npc_empire_interior_raids`: authoritative pending indoor assault session.
- `npc_empire_guard_assignments`: aggregate living assignment per holding.
- `npc_empire_player_guard_members`: concrete player `gang_members.id` assigned
  to a property.
- `npc_empire_building_closures`: CLOSED intervals for sabotaged/attacked
  converted buildings.
- `npc_empire_events`: bounded persistent memory/event log.

Every ownership, treasury, roster, casualty or raid transition that belongs
together must occur inside one `BEGIN IMMEDIATE` transaction. Repeated polling,
reconnect and duplicate resolve requests must be idempotent.

## Nineteen-empires lifecycle

- Families can be active, rebuilding, vassalized or ruined. Ruin removes their
  political capital and holdings; comeback uses a real available HQ building.
- While `hospital_until` is active, the boss has one stable treatment activity
  and cannot personally recruit, expand, acquire, fortify or start an NPC war.
  The family still receives income, pays wages and advances its bounded server
  tick; player-war and NPC-war activity must not overwrite the hospital state.
- Persistent boss memory writes hospitalization as canonical `hospitalized`.
  Readers normalize legacy `hospital` events so old saves retain the same
  negative importance, wound count and defensive adaptation.
- A returning family starts small and has a finite recovery stipend. It does
  not receive endless free fighters or cash.
- The fighter cap is 20. Paid recruitment changes treasury, members and
  strength atomically. Street recruitment and scheduled recruitment share the
  same cost policy.
- HQ fronts provide a modest `$24/min` bootstrap. Mature spendable liquidity is
  capped; excess becomes non-spendable `distributed_profit`.
- Every five-minute tick pays fighter payroll, property-guard upkeep and active
  war logistics before expansion. Purchases retain twelve future operating
  ticks as reserve.
- Insolvency progresses by ticks; desertion is bounded. Recovery reverses it
  gradually, never by spawning a free full roster.

## Diplomacy and wars

- Player and NPC relations use explicit scores and pacts. A UI status must name
  the exact enemy boss and gang, not merely say “at war”.
- NPC holding defence includes the concrete living guard assignment for the
  exact namespaced target. A resolved NPC war applies bounded permanent member
  and strength losses to both sides, updates both win/loss counters and records
  both perspectives without charging a captured guard twice.
- Reload each acting empire row inside the shared war transaction so losses
  inflicted earlier in the same tick cannot be overwritten by the opening
  snapshot. Retain at most 80 persistent events per family; one noisy family
  must never evict the useful memory of another boss.
- NPC wars can exhaust into truce, then cool toward peace; alliances form only
  through the existing diplomacy cadence.
- Third-party reactions, ally defence and territorial penalties reuse the
  persistent diplomacy table and event log.
- A war without a valid target must not fabricate a capture, free squad or
  client-only march.

## Holdings and business identity

- Legacy POI businesses use `business:<id>`. Converted buildings use
  `building:<key>`. Always persist namespaced references where both kinds are
  possible.
- Converted buildings support eight operation types. Owner, operation, area,
  derived income and CLOSED state are authoritative and must survive reload.
- Exterior and interior cache signatures include owner, operation and CLOSED
  state. Capture therefore changes both skins on the next authoritative entry.
- A converted building's stored income is per minute; the five-minute empire
  tick credits five minutes. CLOSED overlap suppresses each intersecting income
  interval, including after reconnect. Never back-pay downtime.

## Concrete property guards

- The property action “Поставить охрану” assigns actual living player
  `gang_members.id` values. Assigned district guards and guards at other
  properties are unavailable.
- Businesses may have 0–12 assigned defenders. The UI must use authoritative
  `holding_guards`, `assigned` and `free`, including an explicit `free=0`.
- Only assigned guards defend an indoor raid. Free mobile fighters do not
  teleport into the property and no synthetic second guard layer is allowed.
- Casualties set the participating member's health to zero and remove the exact
  assignment. Dead slots do not respawn after polling or reconnect.
- Sale, capture, NPC transfer, ownership loss and empire collapse atomically
  clear obsolete assignments and invalidate pending sessions. Never leave a
  ghost guard consuming roster capacity.
- NPC guard allocation is threat-first, then income/value, while preserving a
  mobile reserve of at least two and a larger reserve during wars. Rebalance in
  the same transaction after casualties or roster shrink.

## Smart player-business targeting

The old selector was round-robin and could send two fighters against twelve
guards. The current server scorer must preserve these rules:

- Evaluate business income, Euclidean logistics distance from the boss's HQ or
  nearest holding, concrete living assigned guards, paid free assault force,
  attacker quality, relationship hostility and boss aggression.
- Estimate attack/defence power and expected casualties separately from target
  value. A high-income property is not feasible merely because it is valuable.
- Assigned NPC guards and already committed pending attackers are excluded from
  the free attack roster. Force remains bounded to 2–8 and is paid from the
  boss treasury.
- If no feasible target exists, move `next_attack_at` forward without charging
  treasury, increasing the attack counter, changing ownership, emitting a raid
  event or showing a fake client march.
- A follow-up may keep `last_business_id` only while that target remains
  feasible and reasonably close to the best score. It may switch when new
  guards make the old target irrational.
- Load all player property guard counts with one player-scoped grouped query.
  Do not issue a guard query per target, per family or per frame.

## Indoor assault session

- A due feasible attack creates one persisted `npc_empire_interior_raids`
  session before any ownership mutation. The session stores token, target,
  coordinates, operation label, concrete attacker/defender rosters, combat
  quality, cost, start, hold and expiry.
- Creating a pending session moves the war deadline beyond its expiry. Legacy
  hot due rows self-heal. Reconnect must not repeatedly traverse or emit the due
  path.
- Pending session state wins over fresh target scoring. HUD, route and world
  marker must point to the persisted token/target/coordinates even if guards or
  roster change after the raid started.
- Expired abandoned sessions resolve silently, remove their marker and become
  eligible for one bounded reschedule. Do not emit an event on every poll.
- Resolve validates `uid + token + apt_key` and exact casualty arrays. Duplicate
  resolve returns the stored result. Foreign slots or member IDs are rejected.
- Capture requires a continuous 20-second cashier hold. Any surviving attacker
  leaving the zone or a roster/casualty change resets progress. Defended status
  normally requires 45 seconds unless every attacker is already down.
- The first successful capture-phase result closes the property. The follow-up
  can transfer it. Ownership, closure, operation, income and assignments change
  atomically through the existing business-cycle path.

## Client and 3D presentation invariants

- One authoritative alert lifecycle: one-shot warning, persistent HUD, exact
  world/minimap/edge marker and one reused 3D marker group.
- HUD includes business name, owner, boss/family and actual roster counts. Text
  must be bounded/ellipsized at 1366×768 and 1920×1080.
- Family guards use family primary/accent colours and ordinary lean silhouettes;
  heavy bodies are rare high-tier variation, not the default security uniform.
- Indoor combat reuses existing LOS, cover, tracers, hit/death and blood paths.
  Furniture for all eight operations participates in collision and cover.
- A boss or empire fighter shooting the player applies damage and weapon
  effects only when the existing tracked projectile reaches the player. Keep
  the same capped `11.5..15.5` visual speed for flight timing, and reject the
  delayed hit if the shooter, player or street-combat context is no longer
  valid; never subtract HP in the trigger frame.
- Inter-gang and gang-to-police packets use their authoritative
  `bullet_speed`, stamp the shooter pose/sequence immediately, then reveal the
  server HP, impact and casualty only at tracer arrival. A bounded per-actor
  arrival gate prevents the ordinary world snapshot from exposing that result
  early, including when the server has already removed the last dead fighter.
- Corpse labels are short-lived and lowest priority. Screen-space decluttering
  preserves live/focused/HP labels without allocating new meshes or DOM nodes
  each frame.
- Empire movement reuses capped routes and actor pools. No raid-only pathfinder,
  actor pool, projectile system, renderer poll or unbounded history.

## Known traps

- Recomputing an activity target independently from a pending session makes the
  marker point to a different building after guard changes.
- Leaving a pending war row due creates repeated database work and event spam on
  every state poll.
- Treating deferred route planning as “no route” can starve A* retry forever.
- Resetting preview fixtures on each snapshot teleports bosses backward and
  revives dead slots.
- Using `value || fallback` for authoritative counts corrupts a valid zero.
- Pruning CLOSED rows before building the offline income schedule back-pays the
  closure interval.
- Counting aggregate guards without concrete living IDs creates clones after
  death, sale or reconnect.
- Broad automated replacement of `world.html` is unsafe. Make narrow edits and
  compile every embedded script.

## Required regression suite

Choose the relevant subset, but changes to target/guard/raid contracts should
normally run all of these:

```text
python -m py_compile npc_empire.py mafiozi_bot.py
python test_npc_player_target_scoring.py
python test_npc_empire_smart_raid_target.py
python test_npc_empire_interior_raid.py
python test_business_interior_raid.py
python test_npc_business_cycle.py
python test_npc_business_reload.py
python test_player_business_raid_alert.py
python test_property_guard_assignment_stress.py
python test_npc_guard_allocation_180d.py
python test_npc_empire_economy.py
python test_npc_empire_year.py
python test_npc_empire.py
python check_world.py
node --check three_preview.js
git diff --check
```

For a visual change, perform one live preview run in one browser tab, inspect
console/runtime telemetry, then close the tab. Never open several game tabs on
the user's machine.

## How to update this memory

- Update the “Last reconciled” commit after a verified publication that changes
  these contracts.
- Record durable invariants and failure modes, not a chronological chat log.
- Name authoritative functions/tables/tests only after confirming they exist in
  fresh `main`.
- Move deep 3D allocation details to `OPTIMIZATION_MEMORY.md` and link them here
  instead of duplicating hundreds of lines.
- If implementation and memory disagree, current tested code is authoritative;
  fix this document in the same task.
