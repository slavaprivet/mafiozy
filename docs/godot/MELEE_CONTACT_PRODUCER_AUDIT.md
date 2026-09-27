# Walk melee producers: source audit and next native slice

Read-only source audit, 27 September 2026. No production changes, GPU runs, or implementation-mirroring tests. Line references below refer to the inspected working files, not historical extracts in `outputs`.

**Finding:** Walk already has a connected, surface-accurate **player → NPC** melee pipeline. Its **NPC → player** pipeline is different: local source attacks use delayed range/LOS checks, authenticated attacks use server damage transactions. The accurate incoming-contact prototype is explicitly unconnected. None of these producers supplies physical impulse in N·s, segment mass/inertia, or contact-point velocity. A damage notification alone cannot populate the native physical-impact host.

## Inspected source identity

| File | SHA-256 |
| --- | --- |
| `world.html` | `9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5` |
| `mafiozi_bot.py` | `76d5f192fa42fc16a9980adefcf9fd016f125f8606bb2b5bd517a2cd2dbebcb9` |
| `assets/maps/city_rebuild_v1/world_walk_melee_host.mjs` | `561d0157dffe51f3b47408f2ed520c41d89cffa28165bb87a61489eac0df0441` |
| `assets/maps/city_rebuild_v1/npc_incoming_melee_host19.mjs` | `d17091f0e28e92374c83a4d8c2529a1862ae68bc774863cace6337863eb51a09` |

`server.py` is merely the local static HTTP server. Actual gameplay authority is in `mafiozi_bot.py` and the appropriate local branches of `world.html`.

## Connected player → NPC path

| Source entry | Actual responsibility / port boundary |
| --- | --- |
| `walk_preview.mjs:64`, `:529`, `:556` | Imports/constructs `world_walk_melee_input` and `world_walk_melee_host`; feeds real hero, current NPC actors and world/car obstacles. Confirmed events are delivered through a microtask to avoid consuming a receipt before its contact anchor is stored. |
| `world_walk_melee_input.mjs:2–58` | Projects input to source-owned charge/block/begin. Source chooses the attack; local button timing cannot authorize damage. Holds charge for 1.2 s; cancellation and reserved heavy state remain part of the contract. |
| `world.html:38598–38604`, `:38755–39019` | `punch` admission: PvE observer cannot fight; incapacitation/weapon/stance locks, 300 ms cadence, charge admission, alternating hands, source random kick/critical decision. Local authored HP values: punch12, kick21, heavy18. These are damage values, **not force magnitudes**. Preserves witnesses, police, NPC response and other source consequences. |
| `world.html:71934–71949` | `beginWalkMelee`: admitted sequence, type, side, source time, duration and contact window. Punch `.34s / [35,190]ms`; kick `.62 / [180,340]`; heavy `.50 / [70,360]`; dropkick `1.25 / [160,380]`. Stores one pending source context. |
| `hero_walk.mjs:533–554`; `hero_artist14_melee.mjs:48–115` | Samples the authored limb pose without advancing the animation clock or leaving the sampled pose displayed; restores all saved transforms. This supplies the actual hand/foot trajectory, not a standing proxy's root speed. |
| `world_walk_melee_host.mjs:14–58` | Sweeps one hand/foot, or both dropkick feet. Radius `.10m` hand / `.14m` foot. Low-frame-rate catchup is clipped to the accepted window, samples at most 12 subdivisions with ~32 ms spacing, interpolates actual root position/rotation, and has at most 250 ms delivery grace. Resolves once per admitted attack. |
| `npc_melee_contact.mjs:4–95` | Contact against current posed skinned triangles, cached by explicit pose revision; broadphase, finite/radius checks, closest swept-limb point, limb→surface and torso→surface obstacle occlusion, surface normal and head/body zone. Returns a **candidate**, not damage authority. |
| `world.html:71951–71993` | `resolveWalkMelee`: validates sequence/window, consumes pending context before resolution, rechecks current action locks, live native ref, finite point/normal and source-space ranges. Dispatches only actual whitelisted collections. No handler means rejection. |
| `world.html:38912–39019` | Local `applyImpact`: rechecks current target position/range and source LOS; applies block rules; calls the existing target-specific owner. The 3D branch does not perform the legacy non-Walk scripted heavy dash. |
| `world.html:8885–8955` | Ordinary `hitNpc`: role/empire/invulnerable branches, HP, source 0.09-tile collision-checked displacement, flinch, aggression, rumor, panic, surrender, medical downing, final death and replacement scheduling. Copying just `hp -= damage` would lose gameplay. |
| `world.html:70003–70025` | `_walkConfirmDamage` emits `artist14:confirmed-hit` only for the matching pending ref/contact and positive accepted damage; `_walkConfirmServerHit` verifies reply kind, target, attacker and fresh request before confirming. |
| `world_walk_melee_host.mjs:60–66`; `npc_contact_anchor.mjs:27–53` | Pending source sequence/target plus 15 s lifetime; exact actor UUID, mesh path/UUID, geometry UUID/counts and barycentric triangle anchor must still match. Replaced rigs do not inherit the old wound/contact. |

Source units matter: `world` r/c are tiles, browser points are `(x=4.1*c,z=4.1*r)` in metres. Current Godot crop subtracts its actual scene origin (see `preview_resident_world_policy.gd:127`). Do not pass browser coordinates straight into a cropped Godot scene, or multiply an already-native metre-space impulse by 4.1.

The local target branches are ordinary NPC, bank guard, city cop, beachgoer and decor collections. Role-specific damage owners remain distinct; in particular decor's one-hit death behavior is not interchangeable with resident medical downing. `_walkShotNativeRef` (`world.html:69938–69951`) explicitly refuses static catalogue actors without gameplay authority.

### Server-owned NPC targets

`resolveWalkMelee` routes actual world cops, Michael guards, convoy/event actors, aggro/nest actors through `melee_hit {attack_id,kind,id,heavy}` (`world.html:71978–71989`). It does **not** send client damage, point, momentum, critical choice or airborne authority. Pending is not a hit.

`mafiozi_bot.py:20036–20130`, `WorldSim.apply_npc_melee`, validates a real runtime target collection, shooter state/location, target life/HP/custody, finite authoritative positions, 1.38/1.75-tile range, LOS, shared .30 s cadence and server heavy charge age1.17–4s. Server owns critical/block/damage and delegates to the existing cop/guard/aggro/event damage path. Its replay key `(uid,attack_id)` binds `(kind,target_id,heavy)`; conflicting reuse rejects. Ledger lifetime is this WorldSim, bounded to4096 receipts/300s, not durable across server restart.

The WebSocket handler at `mafiozi_bot.py:31448` invokes that method. `_deliver_world_melee_packet` at `:3459` sends replay receipts only to the requester and fresh ones to the current connections. Client `_walkConfirmServerHit` ignores replay. Preserve both layers; the native sink's64-entry local ledger cannot replace server replay authority.

## NPC → player: current producers, not presumed symmetry

| Producer | Confirmed source behavior | Available contact / authority limitation |
| --- | --- | --- |
| Ordinary local hostile, `world.html:19084–19138` | Source chase/defense/charge, one `_pendingMeleeImpactAt`, explicit one-shot heavy token. Rechecks range (punch1.24/kick1.48/heavy1.68 tiles) and `_meleeLineClear`; calls `_hurtLocal`; source heavy stun remains a separate authored state. | No limb-surface point/normal/velocity or stable receipt ID. `_localHostileCanResolveHit` (`:24851`) is true only for local preview or explicit direct combat demo. Cannot extend this permission to authenticated play. |
| Local guard, `world.html:18994–19000` | Existing proximity/cooldown and local-hit permission; `_hurtLocal(...,{kind:'melee',source:n})`. | No real hand contact. Not the precise outgoing contact pipeline. |
| Local empire combat, `world.html:12129`, `:12173–12190` | Existing tactical/profile owner; delayed melee application and current combat-state guards. | Must retain empire authority; not an ordinary-resident generic attack. |
| Server aggro boss, `mafiozi_bot.py:21918–21940` | Authoritative target/range/LOS/cadence, `_directional_npc_melee_kind`, durable `apply_authoritative_damage`. Sends `aggro_melee` visual packet. | Packet has bot/target IDs, rounded source/target2D coordinates, damage and killed. It does **not** carry the generated durable damage event ID, exact contact, velocity, or impulse. Do not synthesize physical event identity from damage+position. |
| Hired specialist, `mercenary_melee_source.js:16–59`, called `world.html:24125` | Companion→whitelisted local NPC only, source path/LOS, delayed180ms one-shot target object, .8s cooldown, source stats damage/XP. Explicitly rejects remote actor paths. | Separate third direction, not NPC→player; source movement is3.2m/s and reach1.65m, not the local hostile's tile-unit reach. No physical impulse. |

`npc_incoming_melee_host19.mjs:1` expressly says **isolated prototype, not imported by Walk and not connected to world HP**. Its tickets (`npcId/generation/seq/startAt/type/window`), ≤4 attackers, ≤16 samples and4ms round-robin budget are useful design evidence, but no current production provider emits these tickets. Do not relabel this proposal as an existing admitted producer or assign ordinary residents aggression from it.

`_hurtLocal` (`world.html:24890–24960`) performs directional melee block and local health behavior. Its `impact.power` is clamped from applied damage and `bodyPart` may be inferred from text. Authenticated live HP exits to the server-owned combat state. Those telemetry fields are not a physical point or impulse. `world_walk_health.mjs:74–88` explicitly refuses a surface impact receipt without independently confirmed finite contact.

Server `apply_authoritative_damage` (`mafiozi_bot.py:17297–17369`) owns directional blocking, armor, durable damage transaction and current mirrored health. Its damage transaction has life-aware machinery, but this melee caller does not pass `expected_life_generation`. Preserve that fact; a native consumer still needs current life binding rather than pretending every old event is explicitly life-bound.

## Identity, life, replay and death

- Render ID is not a universal authority key. `_threeNpcEntityId` (`world.html:69693`) prefixes explicit source IDs, otherwise uses object-identity WeakMap IDs. `_walkShotNativeRef` maps collection-specific render IDs back to the actual living object. A changing array offset is not a life identifier.
- Outgoing local `walk-melee:<seq>` is scoped to the current world and one pending context; it contains no native session/life generation. Surface anchors bind exact rig instances, not network identity. A native adapter must additionally bind source session, target life, current pose epoch and geometry revision and reject retired rigs/owners.
- Player canonical state exposes `life_generation` (`mafiozi_bot.py:2964`); restore increments it (`:2987–2999`). Existing local vehicle life counter increments on dead→alive (`world.html:69780–69784`), but is not automatically the authenticated player generation. Never silently equate these counters with Godot's current preview life1.
- Residents leave a corpse and schedule a distinct new object; `_respawnResidentImmediately` (`world.html:10926`) delegates stationary service separately and queues ordinary replacement/appearance generation. Old resident receipts must not target replacement identities.
- Online player→player is another separate path: `apply_player_melee` (`mafiozi_bot.py:20132–20294`) checks actual PvP/arena/territory/business/police/family rules and writes durable `(attacker_uid,attack_id)` receipts (`:3428–3456`). Its result includes current combat state, attack ID and replay flag, not exact physical contact/J. Do not substitute server NPC melee's shorter ledger or local preview permission.
- **Ordering caveat in existing source:** ordinary `hitNpc` calls `_walkConfirmDamage` at `world.html:8915` before medical-survival/final-death decisions at `:8942–8955`. Therefore that particular contact's `fatal` flag is not a definitive post-transaction death receipt. Native `final_dead` must be derived from the completed authoritative lifecycle, preserving medical downing/surrender/custody. The current sink requires dead/recovery suppression to be confirmed; do not bypass it to match an early visual event.

## What physical input actually exists

The outgoing sampler has two authored limb positions at known sample times, root transforms and exact target triangle anchor. These permit a native producer to **measure** contact-point velocity over a bounded valid timestep, including limb motion, root translation and rotation. Current contact returns point/normal/zone/anchor, not velocity: this is additional measured data, not an existing source field. Defender point velocity must likewise come from current displayed bone motion, or from the already-running body's `v + ω × (point−COM)`. Reject zero/invalid dt, actor replacement, transform discontinuity, and stale geometry; do not add a nominal fist speed.

Source damage values, 0.09-tile knockback displacement, visual hit `power`, attack duration and root walking speed do not provide mass×velocity momentum. The newly present native `melee_impulse_profile.gd` is explicitly an **authored force proposal with balance_approved=false**, not a recovered source contract. It needs real contact/point velocities and separate accepted calibration. Avoid deriving J from HP or applying both its impulse and an extra knockback/torque. A solver-observed contact has already applied J; the sink must receive `solver_observed` rather than replaying it as `command_unapplied`.

## Smallest legitimate next integration

**Recommend the existing outgoing ordinary-unarmed player→ordinary-resident path as the first complete melee vertical slice**, because its actual pose-window contact and source confirmation already exist. Keep protected/service/empire/server targets behind their own unavailable handlers. This is a direction/scope choice, not permission to invent combat authority for the current static resident packet.

Required parts, in dependency order:

1. Bind one current, actually admitted resident instance and the current player to a source-owned session/life registry. The present `preview_resident_host.gd:40–56` accepts healthy initial rows/life1 and supplies navigation/appearance; it has no mutable HP/combat/lifecycle owner or incoming impact consumer. An immutable accepted spawn packet does not authorize new damage.
2. Add native attack input/pose sampling with the exact source admission decisions and accepted windows above, using engine skeletal transforms and collision queries where suitable. Preserve actual authored limb path/low-FPS window behavior; do not create a range-only hit or reuse standing arms. Current player status explicitly says combat animation is not migrated (`preview_player.gd:677`).
3. Resolve bounded real swept limb contact against the admitted actor and current world/door/car blockers. Hand off `attack ticket + exact actor life + candidate anchor + sample time` to the appropriate source damage owner. Native collision is contact evidence, not HP authority.
4. Port/connect the actual ordinary damage/lifecycle transaction and side-effect interfaces (`hitNpc` branches above) before calling this gameplay. Scope must explicitly account for panic/aggression, medical survival, witness/police reporting, death and replacement; unavailable consequences cannot be replaced by no-op success. Externally server-owned roles remain pending/rejected until their real protocol is present.
5. After completed authoritative resolution, the resolver exposes an accepted handle carrying current target/session/life/pose/geometry, source attack ID, actual contact and final lifecycle state. Measure physical velocities independently and use approved game-force calibration. The appropriate NPC physical owner consumes it once. The existing **player** impact host is not an NPC owner and must not be attached to residents unchanged.

Suggested narrow boundary for a later implementation proposal (not implemented here): `begin_attack(current_owner,input) -> source_ticket|rejection`; `sample_contact(ticket,previous/current_pose,geometry_revision) -> candidate|pending|miss`; `resolve_source(ticket,candidate) -> accepted_handle|pending|rejection`; `consume(accepted_handle,physical_input)` at the existing impact sink. The source callback controls HP/rights/replay. Every async reply must still match bound session/life and the original attack; no old reply is rebound to today's actor epoch.

If root wants the already-ready player consumer exercised first, the honest smaller groundwork is a native contact sampler shared by both directions plus a current **real** NPC attack-ticket provider. That is not yet incoming gameplay. The current incoming prototype and local HUD damage stamp cannot supply that missing authority. Authenticated incoming support additionally needs the backend's accepted event identity/life and contact association exposed to the receiver without changing server-owned HP decisions.

Completion gates for the actual gameplay slice: real attack misses through a wall or after target steps away; no hit outside the authored window; one source damage commit and at most one physical impulse; stale/replayed events cannot hit another life; weak contact leaves walking stable; actual strong contact can lose balance; get-up is interruptible; source medical/custody/final-death states stay distinct; no corpse/respawn ID reuse; and measured contact/pose work in the loaded scene stays bounded. This audit does not claim those future gates are already implemented.
