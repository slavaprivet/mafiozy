# NPC → hero contact: read-only audit / proposed bounded patch

No production change. Root review required before implementation. Fixture: `node test_npc_incoming_melee_audit19.mjs` (PASS).

## Proven current behavior

`world.html::updateNpcs`, ordinary `_fightingMelee` branch near line18790:

- Chase stops at1.18 source cells (4.838m), route goal radius1.2 (4.92m), attack admission≤1.6 (6.56m), heavy rush0.48 (1.968m).
- Actual extracted branch in the fixture walks on open ground from12.3m and stops at4.51m. Every visible authored melee pose misses at this distance.
- Pending impact uses only source range1.24/1.48/1.68 cells for punch/kick/heavy and `_meleeLineClear`. Fixture accepts4.92m with player standing/crouched/prone and attacker facing away.
- Actual GLB fixture: male/female punch/kick/backfist hit standing target0.7m ahead; all miss prone target and target at old stopping distance. Punch/kick miss0.7m behind attacker; spinning backfist genuinely contacts behind during its circular arc. Thus **do not add a universal forward-cone check that cancels real backfist contact**.
- Separate `_hostile` business-guard branch immediately above stops at1.2cells and damages immediately inside1.5cells. Do not quietly claim the civilian patch fixes guards/cops/bosses/server-owned actors.
- `_localHostileCanResolveHit` is local preview/direct-demo only. `_hurtLocal` keeps authenticated player HP server-owned. Preserve this boundary.
- Existing `_hurtLocal` front blocking reduces ordinary damage90%; heavy currently passes `blockPiercing:true`. Heavy stochastic knockdown is applied outside `_hurtLocal`, so “blocked heavy must not fall” is another real source-resolution policy issue to explicitly settle in this patch rather than infer from animation.

## Existing usable hooks

- `npc_population.mjs::normalizeNpcSnapshot` already maps `_shotAt` + `meleeType` + `meleeKickSide` to Artist14 authored action at source clock.
- `npcPopulation.getActors()` returns stable snapshot id/object/source; `getActor(id)` returns actor including `.walker`. `npc_actor.mjs` requires no changes.
- Walker already exposes `sampleMeleeContactPose`; shared hero sampler handles windows/low-FPS contact without advancing animation.
- `walk_preview.mjs` creates outgoing melee host near502 and calls it after `artistUpdate` and `updateNpcPopulation` near1992. Incoming host can run there against the actual displayed hero and NPC roots.
- `npc_melee_contact.mjs` can test hero object as sole target with one target skin cache per incoming host frame shared across all attackers. Bone-derived capsules can reject far limbs cheaply before exact triangles. A capsules-only replacement needs calibration against the actual GLB fixture to avoid enlarged invisible hits.
- Physical hit shape must remain independent of camera-driven head visibility. Current generic mesh contact ignores invisible meshes; an incoming player wrapper needs an explicit physical visibility policy, not re-enabling render meshes globally.

## Proposed first patch: ordinary local civilian counterattack only

1. **Walk distance contract in the existing branch.** Metres converted once via4.1: chase arrival≈0.70–0.75m, attack admission≈0.85–0.9m. Keep existing2D thresholds outside Walk. Route goal radius must match physical arrival. Clamp last-step distance to arrival and use `_npcPathPassable` (full sweep), including fallback detours and heavy rush; endpoint `_npcBodyPassable` alone is not enough. Clamp heavy rush to remaining separation rather than retaining1.97m teleport. Recalculate distance after movement before admission. Test open ground, wall interruption, moving player, lowFPS and no root overlap.
2. **Source attack ticket.** On accepted unarmed attack store monotonically increasing per-NPC sequence, source start clock, type/side, fixed facing, accepted original contact window and expiry. Do not apply old timed radius damage for that Walk ticket. Snapshot exports only those explicit fields alongside stable existing id. Pending ticket naturally expires/cancels on death, stun, weapon acquisition, changed target/scene or source ownership; no actor index as identity and no queued duplicate attack. Freeze strike facing during the short action so turning the player behind can produce an honest dodge; do not continuously retarget the visible strike after admission.
3. **Small incoming render host module.** Iterate only ticketed, nearby living unarmed actors via existing population; retrieve their walker; use bounded authored pose samples with root interpolation and full obstacle LOS. Hero posed capsules first for cheap rejection; current hero posed triangles for exact final contact where needed. One shared target revision/skin cache per frame, no per-NPC hero reskinning. Stable token resolves hit or miss exactly once; late sampled contact allowed only within original window plus existing bounded delivery grace. No pose/network/HP mutations inside contact helper.
4. **Source `resolveWalkNpcMelee` bridge.** Validate current source actor identity/ticket/generation, local damage authority, target player alive/unlocked, unarmed source, finite surface contact/time, conservative world-space range and pending expiry. Source alone invokes its existing damage/bruise/block/knockdown effects. Consume token before damage. Preserve server-owned paths; do not submit an invented server protocol. Pass actual point/normal/body region into the player presentation contract in cooperation with root blood owner.

Scope: `world.html` ordinary branch + ticket snapshot/bridge; new incoming-host module; one initialization/update hook in `walk_preview.mjs`; contact helper only if physical visibility/broadphase option required. No `npc_actor.mjs`, police custody, boss AI, death, activity or server combat rewrite.

## Acceptance before LIVE

- Actual ordinary branch approaches from5m to physical reach without teleport/overlap; blocked route remains blocked and full sweeps are used.
- Same male/female and5/8/15/60FPS contact matrix as outgoing host; standing/prone/crouch, behind punch/kick miss and genuine spinning backfist contact retained; old4.92m admission rejected.
- Actual source damage once per token; stale seq/dead/armed/expired/server-owned reject; no damage while waiting for or failing visual actor creation.
- Directional block policy, heavy/drop knockdown policy explicitly tested; separate unsupported guards/cops remain listed, not silently reported complete.
- Bounded active-attacker count/sample work plus one hero skin per frame. Compare update p50/p95 in same loaded scene through root; isolated CPU fixture alone is not FPS acceptance.

This is not a safe one-line radius change: approach thresholds and damage admission must move together. The scoped bridge can be implemented independently without rewriting the wider AI, but needs root approval and LIVE staging.
