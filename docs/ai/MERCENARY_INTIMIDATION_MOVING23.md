# Moving NPC intimidation — production fix and regression

2026-09-23. **IMPLEMENTED / CPU TESTED: production regression 27 PASS.**
Root reviewed the isolated candidate and authorized the narrow production fix.
Changed `mercenary_core.mjs`, `mercenary_pose.mjs`, and one existing
`mercenaryPose.apply` call in `npc_actor.mjs`. `mercenary_world.js` was not edited.
New files: `test_mercenary_intimidation_moving23.mjs` and this document.

Run from repository root:

```text
node --test test_mercenary_intimidation_moving23.mjs
```

Observed: 27 passed, 0 failed, total test-run duration 646.309 ms (Node 26.1.0).
This duration is not a per-frame performance result or an FPS improvement claim.
Adjacent core/moving-C4/witness tests also passed (34 combined cases before the
gait test was added). Existing pose/bruiser/visual tests plus the final gameplay
and gait regression passed 37 combined cases.

## Confirmed failure

The previous actual core used range 2 m and duration 2.5 seconds for an untrained
bruiser. Entering `working` unconditionally issued `moveMember(..., null, stop)`.
The walking target leaves range; the next update re-enters `approach` and clears
progress. Catching the target repeats this cycle instead of maintaining contact.

Deterministic actual-core reproduction, target 1.2 m/s and member 3 m/s:

| Update frequency | Working → approach resets | Highest work progress | Effects | Terminal result |
|---|---:|---:|---:|---|
| 7 Hz | 139 | 0 | 0 | path_timeout at 40.00 s |
| 15 Hz | 239 | 0.0267 | 0 | path_timeout at 40.07 s |
| 60 Hz | 957 | 0.06 | 0 | path_timeout at 40.05 s |

The actual `mercenary_world.js` adapter was also executed in a bounded VM using
the existing rally-actions fixture. Its normal source clock, movement, route
adapter, command admission and effect dispatch reproduce zero effects over
five seconds at all three update rates. This is stronger than a handwritten
standalone movement model, but still not a browser scene.

## Implemented behavior

The final test imports the **real production core directly**. Only the broken
historical baseline is reconstructed by reversing the exact work-block change
in memory. Removing the production fix fails the regression; the test never
adds a hidden candidate patch to the module under test.

- For `intimidate` only, the working phase continues ordinary physical
  `moveMember` navigation toward the target with stopping radius
  `sqrt(range² - heightDelta²) * 0.6` (1.2 m on level ground).
- The existing full 3D `d > range` check still runs before work progression.
  Leaving range resets progress and starts pursuit exactly as before. Returning
  requires a new full 2.5-second interval; no earlier partial credit survives.
- The movement request keeps phase `approach`, so the existing adapter retains
  its normal route behavior. Published gameplay/animation phase stays `working`.
- Movement stops **before** `performEffect`, including asynchronous receipts.
  The existing once-only authority, success/failed receipt, XP, cooldown and
  cancellation machinery is unchanged.
- The implementation never writes target position, speed, HP or behavior. The target
  is free to walk or escape. Member movement follows existing speed/collision
  code; there is no teleport, target freeze, expanded effect radius or remote
  effect. The test asserts target immutability before every core update.
- No `plant_bomb` branch is changed. Moving-target stationary-work requirements,
  arming, safety retreat, fuse and once-only detonation remain intact.

The complete runtime block is recorded by the `replacement` literal in the
new test for inverse historical reconstruction. Its changes are confined to:

```js
if(a.phase==='approach'){
  a.phase='working';
  a.phaseStartedAt=time;
  if(a.kind!=='intimidate')moveMember(a.memberId,null,{phase:'stop',stopDistance:0});
}
if(a.kind==='intimidate'){
  const heightDelta=(m.position.y||0)-(t.position.y||0);
  const horizontalRange=Math.sqrt(Math.max(0,a.range*a.range-heightDelta*heightDelta));
  moveMember(a.memberId,t,{phase:'approach',stopDistance:horizontalRange*.6});
}
// Existing progress/duration/plant_bomb branches remain unchanged here.
// Immediately before the existing apply(a,t):
if(a.kind==='intimidate')moveMember(a.memberId,null,{phase:'stop',stopDistance:0});
```

The tighter stopping radius provides a reserve for target movement between
updates. The existing 0.85 approach radius remains unchanged outside `working`.
A stationary target is also approached from the initial 1.8 m to 1.2 m.
This small ordinary movement is a visible behavior change to observe LIVE;
it is not a teleport or a change to the allowed effect radius.

## Results and boundaries

| Update frequency | Production completion, 1.2 m/s target | Distance at effect | Actual source-adapter effects before → after |
|---|---:|---:|---:|
| 7 Hz | 2.714 s | 1.371 m | 0 → 1 |
| 15 Hz | 2.600 s | 1.280 m | 0 → 1 |
| 60 Hz | 2.533 s | 1.220 m | 0 → 1 |

Stationary and 2.1 m/s targets also complete exactly once, within 2.53–2.86 s
and 1.2–1.5 m. A 4.4 m/s escaping target receives no effect and the original
approach timeout ends the chase. Those speeds are controlled fixtures, not
measurements of all native NPC routes.

Also verified at 7/15/60 Hz:

- A target jumping 20 m horizontally or vertically interrupts work; after
  returning, the full work interval is required again.
- Explicit cancel, damage, death, downing, unavailable/missing member, dead,
  invalid, immune or missing target prevent later effects and clear movement.
- A physically blocked approach expires without an effect. Losing contact
  after movement becomes blocked also expires instead of hanging indefinitely.
- Rejected effects grant no XP; pending effects stop movement, issue once and
  retain existing source-receipt authority even if the target later moves.
- Moving-vehicle planting produces **deep-equal full baseline/production traces**
  of motion requests, phases, positions, progress, arm state, effect and final
  snapshot. Continuous stationary work and safe retreat remain required.
- Actual source adapter uses normal `route_moving` during intimidation work;
  target source coordinates and speed remain unchanged by the adapter.
- Production core hash is checked again at the end to prove the test itself
  did not edit it.

## Walking gesture correction

Read-only examination and actual male/female GLB sampling found a second defect:
the intimidation pose overwrote both thigh rotations with an absolute stance.
Ordinary walker thigh-matrix variation over 80 moving frames was 1.06224;
after the old gesture it was exactly zero. Knees kept moving, so the whole
gait was not disabled, but the thighs were frozen.

The authorized narrow fix adds `moving=false` as a primitive third argument to
`mercenaryPose.apply`, forwarded from the existing actor `moving` flag. Moving
intimidation now applies only the relative ±0.12-radian stance spread on top of
the already authored thigh quaternion. Stationary intimidation retains its old
absolute silhouette. Reusable private vectors/quaternions avoid new allocations
per overlay update; no `walker.diagnostics()` query is added to the hot path.

Actual male/female regression verifies:

- Production thigh variation matches ordinary authored gait (1.06177 over the
  paired sample), with the intended relative spread.
- Both shin and foot local matrices are unchanged by the intimidation overlay.
- Stationary whole-bone matrices and pivot position remain exactly equal to the
  historical pose at progress .02/.4/.97.
- Seven other specialist poses retain exact bone matrices.
- Actual `npc_actor.update` produces thigh variation 1.06224, proving that the
  movement argument reaches the real overlay call rather than only a test call.

Interleaved CPU-only pose measurement, same GLBs and 300 warm samples per side:

| Rig | Before p50/p95 | After p50/p95 |
|---|---|---|
| Male | 0.0263 / 0.0469 ms | 0.0271 / 0.0485 ms |
| Female | 0.0228 / 0.0451 ms | 0.0238 / 0.0443 ms |

This is a bounded additional pose cost with sampling noise, not a performance
gain. It excludes the actor pipeline, route geometry, renderer and loaded FPS.

## Integration and remaining acceptance

The production patch is applied and the regression exercises it directly.
Root owns the one-tab LIVE acceptance and checkpoint. No commit or push was
made in this task. The inverse baseline anchor intentionally fails clearly if
future edits change this block, requiring a reviewed baseline refresh.

The module's existing definition of contact is 3D range. This implementation does
not introduce a new line-of-sight predicate for a target already within 2 m
across a wall. Movement remains collision-checked by the adapter. The source
fixture here uses passable open ground, so crowded/walled/corner routes and
upper-body gesture quality need the one authorized browser LIVE check.

The fix adds one ordinary movement request per working update; it also
avoids repeated stop/reset cycles. Their loaded-scene cost is **not measured**
by this functional fixture. Do not present the short CPU test duration as a
performance gain. Before acceptance measure the actual core/route update cost
and frame p50/p95 in the same loaded scene, and observe the bruiser's gesture
while following a normal walking NPC. No extra GPU tab was opened.

Historical core SHA-256:

```text
7a2412f6216ae7dad98d6557ef13aeb910916aa2d7a48bc1af476640d62a96df
```

Integrated core SHA-256:

```text
cec698dd010e5fe47762de4e696587b5280dfeeeaadaff6d95537359f966fbf1
```
