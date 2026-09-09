# Server NPC melee — 2026-09-09

The former client `t:melee_hit` had no server handler. It now resolves real damage against the existing server-owned cop, territory/city/district/nest gang, convoy and Michael-guard collections. No new AI population, NPC health model or database schema was introduced.

## Protocol and authority

Request: `{t:'melee_hit',d:{attack_id,kind,id,heavy}}`. Kinds are `cop`, `aggro`, `event` (`convoy` alias), `mg`. Unknown IDs are rejected; client `dmg`, coordinates, critical and airborne fields are ignored. Attack identity is a bounded ASCII string; target IDs bind to existing runtime objects.

`WorldSim.apply_npc_melee` validates existing unarmed/stance/incapacitation state, observer/jail/interior restrictions, target death/custody, finite actual server positions, range and world LOS. It shares `_melee_attack_t` and its 0.30-second cadence with PvP. Heavy requires the existing server-recorded charge of 1.17–4 seconds; successful strikes consume it. Damage matches existing PvP: punch 12, server-selected 20% kick 21, charged heavy 18. Actual frontal `_melee_block` reduces damage to 10%; a blocked strike never emits knockdown.

An internal server-generated melee profile enters existing target damage functions, preserving cop wanted, gang hostility, convoy death outcome and other source behavior. The city-gang function gained an optional internal `shot_profile`; no request supplies it. The WS preprocessor routes the already validated result through the existing cop/aggro/event/Michael delivery and reward tails. No firearm claim, ownership grant, ammunition spending or duplicate reward implementation is involved.

Runtime receipts bind `(uid,attack_id)` to `(kind,id,heavy)`, keep at most 4096 entries for 5 minutes, and replay only to the requester without damage or rewards. They reset with `WorldSim`, matching ephemeral NPC HP. This is intentionally not the durable PvP receipt ledger. No NPC IDs are coerced into fake player UIDs.

## Source client integration

`resolveWalkMelee` recognizes actual remote references and sends a unique network `attack_id` only after physical contact. It returns `pending:true`, without optimistic HP or blood. Success keeps the existing source event kind (`cop_hit`, `aggro_hit`, `mg_hit`, `player_shot`) and adds `melee:true`, attack identity/type, damage, block and death metadata. `_walkConfirmServerHit` requires matching own shooter, native target and pending attack; repeats are rejected.

The visual `shotId` remains `walk-melee:<seq>` so `world_walk_melee_host` can resolve the previously captured skin anchor. The network identity is independently unique across reloads. Existing source state/death/reward UI continues to run, while firearm-only visual effects are excluded from melee events.

Accepted heavy charge is held until contact resolution sends the attack packet, then released. `setWalkMeleeCharge(false)` cannot cancel that already accepted heavy early; invalid/missed/expired resolution and a short deadline release it. This fixes the previous ordering where server charge was cancelled before its melee request arrived.

## Explicit remaining limits

Server input has no authoritative jump/elevation admission window. Airborne dropkick currently retains its local authored pose but requests ordinary server melee damage, never free heavy damage or fabricated server knockdown. `stunned:false` is deliberate: no unsupported server NPC motion freeze is claimed. A later authoritative jump/fall state must be added before promising remote-NPC dropkick knockdown.

Static catalogue NPCs and empire HTTP encounters outside these existing server collections are not newly damage-authoritative through this protocol. Local source NPC damage remains its separate existing route. Gang capture/AI redesign was not performed.

## Checks

- `python -B test_npc_melee_authority.py`: all six real target routes and actual extracted WS delivery tails, spoof fields ignored, no firearm/ammo authorization, repeat/conflict/cadence, distance/LOS, charge, weapon/custody/observer locks, frontal block, convoy kill reward object retained.
- `node test_world_walk_melee.mjs`: physical local contact plus remote pending/ACK matching, no optimistic HP/blood, stable visual identity, unique network identity, charge packet ordering, no client-airborne promotion.
- `node test_world_walk_shots.mjs`, `python -B test_world_hit_shot_receipts.py`, `python -B test_world_weapon_authority.py` pass after integration.

Restart the actual Python server before live testing the new protocol. Parent owns final live rollout.
