# Isolated incoming melee prototype — 20 September 2026

**Not integrated and not production READY.** Only new prototype/test/docs files were written. No edits to shared world, hero, NPC actor or Walk files; no reload/Git/GPU. Outgoing melee patch remains separately READY.

Files:

- `assets/maps/city_rebuild_v1/npc_incoming_melee_host19.mjs`
- `test_npc_incoming_melee_host19.mjs`
- `test_npc_incoming_melee_cost19.mjs`
- Source/approach audit: `NPC_INCOMING_MELEE19_DESIGN.md` and `test_npc_incoming_melee_audit19.mjs`.

## Prototype contract

Constructor inputs: `THREE`, `getHero`, `getTickets`, `getNpcActor`, `resolve`, `obstacles`, source `now`; optional work clock /4ms soft budget /16 samples /4 attackers per frame. `getHero` returns walker with optional `dead`; `getNpcActor(id)` returns existing population actor exposing `.walker` and `.weapon`.

Ticket shape:

```js
{
  npcId, generation, seq, startAt, type, side, yaw,
  contactWindow: [beginMs, endMs],
  kind: 'civilian', local: true, alive: true, armed: false
}
```

Only original windows are accepted: punch35–190, kick180–340, heavy70–360, dropkick160–380. Fixed source attack yaw is in native Three.js radians. Prototype supports dropkick geometry for parity; it does not give civilians a new dropkick behavior.

Result callback:

```js
resolve({npcId, generation, seq, type, contactAge,
         contact: null || {npcId:'player', point, normal, zone, ...},
         reason: 'contact' | 'miss' | 'expired'});
```

No HP, block or knockdown mutation inside host. Source must validate and resolve those. Cancelled tokens retain tombstones until expiry; removed/reappearing or armed/unarmed cannot resume the same token. Source still must reject replay across host replacement/reload.

Authored attacker pose is sampled at32ms spacing; exact hero skinned triangles confirm contact. No enlarged capsule approximation was added. One hero posed-vertex cache revision is shared across all attackers per frame. Existing body-origin/limb obstacle tests remain. Temporary synchronous physical visibility wrapper ignores camera hiding, restores every flag before return, and never changes the final rendered pose. Only nearby visible civilian attackers are serviced. Standing/prone geometry is the actual displayed hero skin.

The4ms budget is checked between indivisible pose/contact queries, not inside a vertex pass. A single query can exceed it. Round robin prevents one attacker consuming all samples. Deferred work continues until window end+250ms, then expires without damage. Current target pose is used, not historical player rewind. Moving attack roots use recent interpolation; movement/turn/large-stall parity needs separate tests before integration. Maximum simultaneous pressure still loses some contacts; see measurements below.

## Actual fixtures

`test_npc_incoming_melee_host19.mjs` PASS:

-32 positive combinations: male/female × punch/kick/backfist/dropkick ×5/8/15/60FPS.
-Prone and4.92m targets miss. Walls block every attack. Elevated high kick hits standing and passes above crouching hero. Ordinary punch/kick miss behind; actual spinning backfist can contact behind.
-Camera-hidden hero remains physically hittable; all visibility flags and attacker bone matrices/phase restored.
-Four attackers share one hero skin pass:8338 vertices +4 winning anchors×3 =8350 vertex calls.
-One resolution per token; armed cancellation/reappearance, invalid/nonlocal/guard/dead/future ticket rejection.
-Forced one-pose-per-frame continuation still hits with each attack at5FPS, one attacker.
-Block fixture checks the injected authority boundary: reducer applies reduced damage/no knockdown while host still reports physical contact. **This is not an actual world block integration test.** Existing source-heavy block policy still needs the design's explicit correction/review.

## CPU pressure result / remaining blocker

`test_npc_incoming_melee_cost19.mjs`: warm JIT, fresh hero/attackers, same GLBs,3 repetitions per model/attack,4ms soft budget. CPU host update only, not FPS or a before/after live comparison:

| FPS | attackers | valid hits | p50 ms | p95 ms | max ms |
|---|---:|---:|---:|---:|---:|
|5|1|24/24|0.019|3.623|6.882|
|5|4|**93/96**|0.041|4.558|13.575|
|60|1|24/24|0.003|0.027|9.704|
|60|4|96/96|0.004|2.433|4.825|

Three contacts expired under simultaneous5FPS pressure. Do not report incoming melee complete or silently increase budget/grace. Identical simultaneous tickets have equal deadlines, so simple deadline sorting does not solve that fixture; requires cheaper query work or more deliberate scheduling, with validation. Combined game performance has **not been verified**.

## Exact attachment points (not applied)

1. `world.html::updateNpcs`, ordinary `_fightingMelee` branch near18790: add per-source-NPC generation/sequence ticket on accepted attack. Preserve old2D behavior outside `_walkRendererActive()`. In Walk, remove old radius-based damage for ticketed attacks only. Cancel on dead/stun/weapon/ownership change. Change chase stop, route goal radius, attack trigger and heavy-rush final displacement together per design; full `_npcPathPassable` sweep, no endpoint-only rush. Source angle must stay latched during the attack; otherwise sampled ticket yaw and visible NPC can disagree.
2. `world.html::getDynamicEntities`, row construction near70960: export an immutable `incomingMelee` copy only for ordinary source-owned civilian counterattack. Include `npcId` matching the row's stable id, exact source generation/seq/time/type/side/window, `yaw: Math.PI/2-latchedSourceAngle`, local/armed/alive flags. No bosses/guards/cops/server-owned ticket promotion.
3. Same bridge near `resolveWalkMelee`: implement `resolveWalkNpcMelee(request)`. Validate actor reference/generation/seq, pending ticket/window/time, local authority, source alive/unarmed, player alive/state, finite physical contact and conservative native-space range. Consume ticket before effects. Source alone calls existing `_hurtLocal` and block/bruise/knockdown logic; source explicitly prevents blocked knockdown. Root blood owner must attach actual `point/normal/zone` to player hit presentation. This prototype does not supply a server protocol.
4. `walk_preview.mjs`, imports near outgoing melee host:

```js
import {createNpcIncomingMeleeHost19} from './npc_incoming_melee_host19.mjs';
```

Initialization alongside outgoing host near502, after source bridge method exists:

```js
incomingMelee = createNpcIncomingMeleeHost19({
  THREE,
  getHero: () => /* walker plus current source player-dead guard */ hero,
  getTickets: () => (npcPopulation?.getActors() || [])
    .map(row => row.source?.incomingMelee).filter(Boolean),
  getNpcActor: id => npcPopulation?.getActor(id),
  resolve: request => npcBridge.resolveWalkNpcMelee(request),
  obstacles: () => [content, ...(fleet?.records.map(r => r.car.object) || [])],
  now: () => { const c=npcBridge.getWorldClock(); return Number.isFinite(c)?c:c.now; }
});
```

The dead-state adapter must use source health, not infer death from camera visibility. Avoid temporary comments/placeholder adapter in production.

5. Main frame near1992: call `incomingMelee?.update()` **after** `artistUpdate`, `updateNpcPopulation` and source custody pose, alongside outgoing host. Dispose during the existing Walk teardown; clear on host/bridge replacement. Add a profiler bucket and LIVE comparison through root.

Before applying these points, resolve the budget-pressure failures and complete source approach/HP/block/identity tests. Current file is intentionally not imported anywhere.
