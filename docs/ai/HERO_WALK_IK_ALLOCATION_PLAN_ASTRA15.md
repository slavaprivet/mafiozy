# Astra15: narrow `hero_walk.mjs` IK allocation plan — 23 September 2026

This is a proposal for a separate production owner slot. The frozen traversal
pose package and `hero_walk.mjs` were not changed. The candidate must preserve
the public artist-context API and every matrix result.

## Exact production scope

Only five helpers inside `createHeroWalker` are in scope:

1. `rotateAdd` (current line 76): replace its per-call `Vector3`, `Quaternion`,
   `Vector3` and delta `Quaternion` with one closure-owned decompose tuple plus
   one delta quaternion. The existing shared `euler` remains reusable.
2. `worldPosition`: add an optional `out` parameter while preserving the old
   one-argument return behavior. Every hot IK caller passes a pooled `Vector3`.
3. `reachFoot` (lines 138-144): two hip/knee/foot world points, line, root
   quaternion, bend and knee become a left/right scratch record. Do not alias a
   target supplied by the caller.
4. `pointBone` (lines 338-345): origin, end, from, to, swing quaternion and
   current-world quaternion become one scratch record. It executes serially, so
   one record is enough for both bones.
5. `reachPalm` (lines 348-368): root quaternion, wrist offset, wrist, shoulder,
   forearm/hand points, line, bend and elbow become a left/right scratch record.
   Copy `rest[palm].p` into scratch; never mutate rest data.

Recommended allocation, once per `createHeroWalker`:

- `rotateScratch`: `p`, `q`, `s`, `deltaQ`.
- `pointScratch`: `origin`, `end`, `from`, `to`, `swingQ`, `worldQ`.
- `footScratch.l/r`: `hip`, `shin`, `foot`, `line`, `bend`, `knee`, `rootQ`.
- `palmScratch.l/r`: `rootQ`, `wristOffset`, `wrist`, `shoulder`, `forearm`,
  `hand`, `line`, `bend`, `elbow`.
- `worldScratch`: named temporaries passed through the optional `out` API; no
  single vector may be reused while an earlier result is still live.

Do not touch gait, posture, weapon grip, traversal admission, root/yaw,
`updateMatrixWorld` order or bone rotation math. Do not pool across heroes;
per-walker closure storage prevents male/female or replacement-character state
from leaking.

## Focused acceptance fixture

`benchmark_hero_walk_ik_allocations.mjs` is deliberately unimported by the game.
It loads both actual GLBs twice, drives identical warmed ladder IK through the
full `hero.update + orchestrator + applicator` path, and compares sampled skin
vertices every 15 frames with a `1e-7 m` maximum tolerance. It then uses the
Node inspector allocation sampler for 5,000 warmed frames and attributes bytes
whose stack passes through `hero_walk.mjs`.

Baseline:

```text
node --expose-gc assets/maps/city_rebuild_v1/benchmark_hero_walk_ik_allocations.mjs
```

Candidate gate:

```text
HERO_WALK_CANDIDATE=<absolute candidate path> HERO_WALK_ENFORCE_ZERO=1 \
node --expose-gc assets/maps/city_rebuild_v1/benchmark_hero_walk_ik_allocations.mjs
```

The inspector is sampled, so run the zero gate three times. Required result:
both models `maxSkinDelta < 1e-7`, stable applicator result identity, and
`heroWalkSampledBytes === 0` on all three runs. Also rerun `test_hero_walk`,
`test_hero_airborne_ladder_pose`, `test_hero_slope_motion_pose` and
`test_hero_motion_pose_orchestrator`.

Current unmodified-host baseline PASSed visual equivalence with zero skin delta.
The warmed 5,000-frame loop measured `0.3228 ms/frame` male and `0.3011
ms/frame` female. Inspector stacks attributed `110,691,880` sampled bytes male
and `112,411,080` sampled bytes female to `hero_walk.mjs`; retained heap deltas
were `+13.6 MB` and `-0.23 MB`. This confirms why retained heap alone is not an
allocation gate and provides the before-value for the future owner slot.

## Risk

Risk is medium despite the narrow diff. The main hazards are accidental aliasing
between live world positions, mutation of rest vectors, and reuse of a quaternion
before `worldRotation` consumes it. Those failures may keep root movement valid
while bending one limb incorrectly. Actual male/female skin equivalence is the
gate; CPU or unit-level quaternion comparisons alone are insufficient.

Retained heap delta is diagnostic only because GC timing varies. The inspector
stack-attributed sampled bytes are the allocation gate. Full-scene FPS remains a
separate LIVE check coordinated through the single existing game tab.
