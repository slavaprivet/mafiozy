# Mafiozi gang-system memory

## Honest player-asset threat presentation (2026-08-21)

- The server's `target_kind` is the only asset-role authority for a boss raid.
  Never infer that a victim business is a headquarters by comparing its id to
  the attacking empire's `hq_key`; those independent ids may coincide.
- One pure client presentation maps `target_kind + objective` to the shared
  warning used by the HUD compass, 2D world marker, minimap and 3D bridge.
  `followup-capture` says `захватывают`; the first-close objective says
  `атакуют`. An explicit future `target_kind=hq` is supported without claiming
  that current production target selection already creates HQ sieges.
- Resolved, expired or tokenless raids hide every surface through the same
  lifecycle predicate. Preview fixtures and static string checks are not proof
  that the server can create a particular target kind.
- The exterior HUD owns the one persistent route arrow. Its pure compass helper
  projects the server target delta into isometric screen space, then reports the
  object name, rounded distance and literal approach/attack/capture state. The
  2D draw path refreshes it through a signature cache; the 3D bridge uses its
  existing 250 ms sample. Do not add a second edge arrow, target scan or timer.
- Missing or non-finite server target coordinates are inactive, never `(0,0)`.
  The red world ring, minimap point and retained 3D marker still identify the
  exact building when it is in view.

Last reconciled with GitHub `main` at `26abfdbfa1f051cea809b7a374a0a969bcbb5321`
on 2026-08-21.

This is the canonical hand-off for work involving gangs, bosses, criminal
empires, diplomacy, properties, guards or raids. It records contracts that are
easy to break when looking at only one file. Confirm details against current
source before editing and update this document whenever a contract changes.

## Concrete player guard ownership (2026-08-21)

- `npc_empire_player_guard_members` is owner-scoped truth for the exact living
  fighter IDs assigned to a converted property; `npc_empire_guard_assignments`
  is its bounded aggregate. A roster cleanup must filter by `owner_uid` before
  comparing IDs with that owner's living `gang_members`. Never globally prune
  concrete rows using one player's roster.
- `BEGIN IMMEDIATE` serializes assignments, including simultaneous changes by
  different owners. After every successful transition, each owner's aggregate
  living count must equal their concrete rows; reconnect must reconstruct the
  same defenders without stealing, cloning or reviving another player's IDs.
- The client only displays the server response and publishes one event-only
  `playerPropertyGuardAssignment` dataset for QA. It does not infer or repair
  guard ownership locally.
- A valid player assignment lazily reconciles only that owner's aggregates
  inside the existing `BEGIN IMMEDIATE`, before capacity is checked. Concrete
  rows joined to the owner's living `gang_members` are current truth: aggregate
  `living` converges to their count, missing aggregates are restored, and an
  aggregate-only legacy ghost becomes `living=0` without fabricating IDs.
  Historical `assigned` may remain above `living` after casualties and is only
  raised when concrete living count exceeds it. Never run this repair from a
  state poll, infer it from partial ownership reads, or touch NPC/other-owner
  rows, district guards or pending raid rosters.

## Player-to-boss diplomacy

- Diplomacy remains one `BEGIN IMMEDIATE` transaction. A paid `gift` or
  `compensation` debits `characters.cash` and credits the recipient
  `npc_empires.treasury` in that same transaction; a rejected or interrupted
  action changes neither balance. The empire version advances with the credit
  so the next authoritative state snapshot exposes the new treasury.
- Cooldowns are keyed by `(leader_id, telegram_id, action_kind)` in
  `npc_empire_relation_actions`. The legacy aggregate timestamp in
  `npc_empire_relations` remains for compatibility and general history, but
  must never decide a diplomacy cooldown: respect, apology, insult and threat
  each retain their own clock even when the player interleaves other actions.
- Empire collapse clears its per-action cooldown ledger together with political
  capital. A returning boss therefore starts neutral without inheriting action
  locks from the defeated incarnation.
- Legacy aggregate timestamps cannot be attributed to an action kind, so the
  migration intentionally starts the exact ledger empty once; subsequent
  `ensure_schema` calls preserve every clock. Paid zero-cooldown actions still
  have no request id/receipt and must not be described as HTTP retry-idempotent.

## Player-business raid objective

- One player holding generation can have only one successful terminal raid,
  including a defence that creates no ownership-phase event. Legacy duplicate
  pending tokens serialize under `BEGIN IMMEDIATE`: the first fully validated
  resolver wins and atomically marks exact `(telegram_id,target_ref)` siblings
  `superseded`; later retries cannot repeat NPC, defender or guard casualties.
  Invalid payloads never terminalize a valid sibling, and another owner or
  holding is outside the cleanup scope.

- Pending raid sessions persist only irreversible casualty sets: attacker
  slots, assigned-defender member IDs and legacy guard IDs plus a monotonic
  version. Reports are validated against the server-authored roster and merged
  by set union in `BEGIN IMMEDIATE`; a retry or smaller report cannot revive.
- State snapshots publish persisted deaths as `dead:true, hp:0`; surviving
  nonlethal HP is deliberately not server-persisted. Terminal resolve unions
  its final payload with the checkpoint before outcome validation and permanent
  losses. The client sends full current death sets only on a death event through
  one coalesced `keepalive` request and exposes pending/ACK/error telemetry.
- Player-business target selection is doctrine-aware on the server. Existing
  profile commerce plus the doctrine mindset produce bounded value, distance,
  defence, risk and follow-up-stickiness weights; they never invent fighters or
  bypass the paid roster/feasibility gate.
- A pending target remains immutable, while activity and interior snapshots
  expose the policy id, target reason and value/distance/defence metrics that
  actually scored it. Target switching still resets an odd attack to
  `first-close`; doctrine does not alter authoritative resolve or ownership.
- Exterior and interior raid HUDs format that same server evaluation through
  one bounded decision helper. Treat it as the current server evaluation, not
  a persisted decision-time explanation: reconnect may refresh the metrics,
  and a policy/doctrine mismatch must fall back to a generic server label and
  explicit telemetry instead of inventing an explanation.
- Both HUDs publish the same authoritative objective and a minimum 20-second
  cashier hold. Interior phase labels are literal (`approach`, first breach,
  fight, advance, contested, hold or terminal); never advertise
  doctrine-specific room tactics that the generic interior thinker does not
  execute.
- Interior admission is roster-backed and breach-gated. During `approach` the
  defence may already be staged, but attackers remain at zero until the exact
  session token breaches. Thereafter admit at most one existing roster row per
  update: first attacker after 650 ms, chained attackers after 420 ms, later
  replacements after 900 ms; defender replacements wait 1100 ms. Concurrent
  caps are four attackers and six defenders, and dead reserve rows are skipped.
- One module-local checkpoint preserves a single active interior raid across
  same-page exit/re-entry. Its exact identity is `token + apt_key + target_id`;
  it restores bounded roster HP/casualties and pauses cashier-hold elapsed time
  while outside. Restore happens before admission so dead actors stay dead and
  wounded actors keep their HP.
- Restored active survivors lead the normal bounded admission queue; they are
  not mass-spawned. Saved hold progress resumes only after the exact previous
  live roster reaches the cashier again, and a saved approach never overrides
  a breach that occurred while the player was outside.
- Terminal outcomes spawn no replacement actors and retry the authoritative,
  idempotent resolve request. Successful/duplicate resolve or disappearance
  from the active server snapshot clears the checkpoint. It is intentionally
  not full-refresh persistence and does not support two abandoned interiors.

- The authoritative raid objective is `first-close` unless the attack number
  is odd and the war's namespaced `last_business_id` still matches the pending
  session target. Only that exact `followup-capture` objective may transfer
  ownership after a successful cashier hold.
- Smart scoring may switch away from the previous target when its defence
  changes. Such a switched target must return to `first-close`; never infer a
  capture from attack parity alone.
- Publish the objective with the pending session and boss activity. Client HUD
  may explain the boss doctrine, plan, stakes and counter-play, but SQLite
  resolution remains the only path that closes or transfers the business.
- Treat the pending session as server authorization, not proof of exterior
  arrival. Interior attackers may become active only after the boss's ordinary
  action route reaches the persisted target and marks that session token as
  breached. Same-page snapshot rebinds must not replay the cue or recreate
  attackers. Full-page reload does not persist this presentation seam and may
  replay arrival until breach becomes a server field in a future schema.

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
  political capital, holdings and every player-war row; comeback uses a real
  available HQ building and discards pre-fix stale war rows before economy,
  guard or AI accounting.
- While `hospital_until` is active, the boss has one stable treatment activity
  and cannot personally recruit, expand, acquire, fortify or start an NPC war.
  The family still receives income, pays wages and advances its bounded server
  tick; player-war and NPC-war activity must not overwrite the hospital state.
- Persistent boss memory writes hospitalization as canonical `hospitalized`.
  Readers normalize legacy `hospital` events so old saves retain the same
  negative importance, wound count and defensive adaptation.
- Public hospitalization never accepts a client-owned `leader_id`.
  `npc_empire_field_encounters` owns one canonical HP/generation per physical
  boss; `field` rows in `npc_empire_assaults` are player-bound participant
  proofs attached to it. Every participant sees and damages the same HP, and
  only a token created before that generation's defeat may start treatment. HQ
  tokens cannot hospitalize, field tokens cannot resolve annex/loot/vassalize,
  and replay returns the persisted hospital result without another event,
  version bump or duration extension.
- A field encounter may be prepared only for a fresh, connected exterior
  player at the exact activity anchor published by the server; HTTP fallback
  coordinates are HQ-preview-only. Persist that anchor with the assault.
  Valid HQ and field sessions mutually conflict instead of abandoning each
  other. Street boss HP and defeat are applied from serialized server hit
  replies, and ambulance delivery submits only the proof token; a failed
  request must leave no locally hidden or dead boss.
- Shared field HP is event-driven: prepare joins/creates, a hit atomically
  subtracts canonical HP, and hospitalization resolves the generation and all
  participant tokens. `state_for` only reads the at-most-19 live encounter
  rows; polling must never repair, expire or otherwise write encounter state.
  Legacy independent field rows migrate idempotently using their minimum HP,
  so deployment cannot heal a boss already damaged by another client.
- New field generations use shot contract 2: the client submits an owned
  weapon, physical hit coordinates and a monotonically increasing participant
  `shot_seq`, never damage. The HTTP bridge derives damage through the shared
  `WorldSim` ownership/cadence/critical/falloff gate after fresh exterior,
  range, activity-anchor and world-LOS checks. `(token, shot_seq)` is a durable
  idempotency key; transport retry reuses the exact sequence and cannot consume
  cadence or damage twice. Existing contract-1 field generations and every HQ
  assault retain their old body until they naturally drain during deployment.
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

- A legacy landmark business has two non-interchangeable defence layers.
  `player_businesses.guards` is paid staff for the street-occupation system;
  it must never be converted into physical NPC-boss interior defenders.
  Interior raid authority is only the exact living owner rows in
  `npc_empire_player_guard_members`, exposed for `business:<id>` through the
  `/biz/{uid}/list` snapshot. The client labels and counts both layers
  separately and renders authoritative zero as zero.
- A missing table or malformed `district_control.guard_json` makes the complete
  player guard snapshot unavailable. Both assignment and UI fail closed; they
  must not reinterpret an unknown district fighter as free property capacity.
- The property action “Поставить охрану” assigns actual living player
  `gang_members.id` values. Assigned district guards and guards at other
  properties are unavailable.
- Businesses may have 0–12 assigned defenders. The UI must use authoritative
  `holding_guards`, `assigned` and `free`, including an explicit `free=0`.
- Guard roster writes expire overdue raid locks only for the exact player and
  holding inside their assignment transaction; a future sibling stays locked.
- Only assigned guards defend an indoor raid. Free mobile fighters do not
  teleport into the property and no synthetic second guard layer is allowed.
- An interior raid token is bound to the exact property acquisition generation
  and an active war. Ownership transfer, operation conversion, peace or
  vassalization terminalizes it before any casualty or property mutation;
  retries return the persisted terminal resolution.
- Every event-driven casualty checkpoint revalidates that authority before
  merging its monotonic sets; a stale token keeps version zero and no deaths.
- Final resolve revalidates the same authority before expiry, casualty payload
  or physical-outcome checks, so an old client cannot keep a stale raid alive.
- A player diplomacy transition from `war` to a peaceful pact closes pending
  raids only for that exact `(leader_id, telegram_id)` pair, in the same
  `BEGIN IMMEDIATE` transaction and before its player-war row is deleted.
- Vassal status is global to one NPC family. Its winning transaction closes
  that leader's pending raids and player-war rows across every player, while
  leaving every other family's sessions untouched.
- Hostile diplomacy cannot restore that global war authority: declaration is
  rejected, while a street attack records score/event but keeps the player's
  prior non-war pact and creates no player-war row or guard reserve.
- HQ assault preparation obeys the same global authority: a vassal family is
  rejected before token, relation, player-war, guard-reserve or event writes.
- The winning vassalization transaction resolves every other active HQ assault
  token of that NPC family as `vassalized`; stale hit/resolve retries are
  terminal idempotent, while field encounter and hospital proofs stay isolated.
- Any global empire collapse likewise resolves exact-family active HQ assault
  tokens as `leader_ruined`; the winning token keeps its final `loot`/`annex`
  resolution and sibling retries cannot mutate the ruined generation.
- Raid creation must read the concrete defender roster successfully. A schema
  or SQLite read failure rolls back the complete raid transaction; it must not
  become an unguarded token or debit the attacking family's treasury.
- Casualties set the participating member's health to zero and remove the exact
  assignment. Dead slots do not respawn after polling or reconnect.
- Casualty HP writes, concrete-row removal, aggregate decrement, attacker
  losses and raid resolution are one transaction. Any casualty write failure
  rolls everything back; never resolve a fight while leaving its dead fighter
  alive in `gang_members`.
- Sale, capture, NPC transfer, ownership loss and empire collapse atomically
  clear obsolete assignments and invalidate pending sessions. Never leave a
  ghost guard consuming roster capacity.
- NPC guard allocation is threat-first, then income/value, while preserving a
  mobile reserve of at least two and a larger reserve during wars. Rebalance in
  the same transaction after casualties or roster shrink.
- `state_for` must only read NPC guard assignments. Reconcile them in the same
  authoritative transaction that changes a roster, holding, closure or war;
  an already exact plan is a strict no-op (no DELETE/INSERT churn). Keep the
  50-concurrent-poll regression proving zero guard writes and no SQLite lock.

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
  valid; never subtract HP in the trigger frame. Impact telemetry carries the
  firing-frame shot sequence and visual speed so live QA can correlate the
  tracer and damage without adding per-frame work.
- Inter-gang and gang-to-police packets use their authoritative
  `bullet_speed`, stamp the shooter pose/sequence immediately, then reveal the
  server HP, impact and casualty only at tracer arrival. A bounded per-actor
  arrival gate prevents the ordinary world snapshot from exposing that result
  early, including when the server has already removed the last dead fighter.
- Interior raid fire is symmetric at the presentation boundary. Player shots
  against business-raid or NPC-HQ assault actors defer HP, impact and critical
  effects until the existing tracer arrives. Business-raid NPC shots use the
  same capped tracer speed for their callback and reject arrival if the tracked
  target moved more than `0.72` tile from the visible endpoint, died, left the
  interior or lost line of sight.
- A living defending player inside the cashier radius contests the business
  objective, clears the accumulated hold and forces the surviving attackers to
  engage or approach through cover. Capture requires a fresh uninterrupted
  hold after the player leaves; a dead player cannot contest.
- Interior-raid resolve accepts only physically reachable terminal rosters:
  defence requires every paid attacker down, while capture requires at least
  one surviving attacker and every session defender down. Expiry is resolved
  atomically before outcome processing, so an expired token cannot mutate a
  business.
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
python test_landmark_business_empire_defense.py
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
