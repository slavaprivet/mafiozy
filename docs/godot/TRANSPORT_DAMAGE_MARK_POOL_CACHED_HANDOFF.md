# Cached damage-mark reconcile candidate

Date: 2026-09-27. Status: **PERFORMANCE REJECTED / DO NOT ADOPT**. This is an
additive transport candidate. The frozen mark pool was not edited.

## Frozen files

- Base `transport_damage_mark_pool.gd`:
  `b8b095037f80867f8ec168b75d8a76e0458b1b32b750d9e5e06bb3cc6cc7af0b`.
- Candidate `candidates/transport_damage_mark_pool_cached.gd`:
  `775dadce790a49536e0f5a005d26541c79585ac6d437f41cddfd7d488a9ed122`.
- Test `test_transport_damage_mark_pool_cached.gd`:
  `fb2184eca6c79b195d1c9657b025f706570f57e8c7ea298823eca9fd00746eb9`.

## Candidate behavior

The candidate preserves the base public API. Its `reconcile_targets()` result
adds diagnostic counts: `unique_targets`, `transform_writes`, and
`exact_transform_skips`.

Every call still validates all 32 nodes, the two mesh/material resources,
overrides, layout, generation, external hierarchy, source visibility and target
hierarchy before mutation. It retains all 32 physical marks and their raw local
poses. A reusable dictionary maps exact `StringName` source IDs to a per-call
target transform cache; one bound target is therefore validated and read once
even if many marks use it. Reusable packed/typed scratch arrays stage all
visibility and transforms before the first node write. A transform write is
skipped only when Godot's exact `Transform3D ==` succeeds; no epsilon or
approximate comparison is used. Moving marks are never skipped.

The initial linear cache lookup was rejected because its worst case performed
496 ID comparisons. Its 32-distinct-target moving block mean regressed from
`165.6 us` to `191.84 us`. The frozen candidate uses the bounded reusable
dictionary instead.

## Verification and cost

Safe headless results: **155/155 author PASS, 155/155 parent PASS, and 155/155
independent PASS**. No correctness blocker was found. The test covers:

- all 32 active marks with two repeated targets;
- all 32 active marks with 32 distinct targets;
- exact baseline/candidate node transforms, visibility, mesh/material sharing
  and physical slot layout;
- static exact-write skips and writes for all moving marks;
- hidden, reparented and freed weak targets with multiple marks;
- nonfinite failure atomicity, reset/generation, slot override validation,
  prepared-resource signals and dispose cleanup.

Timings are 24 alternating-order blocks of 25 calls. The reported p50/p95 are
percentiles of block mean microseconds per call, not individual event tails,
frame time, FPS, or full-scene measurements.

| Scenario | Base p50/p95 | Candidate p50/p95 |
|---|---:|---:|
| 2 targets, 32 static marks | 162.16 / 179.56 us | 76.92 / 84.20 us |
| 2 targets, 32 moving marks | 161.92 / 167.96 us | 82.52 / 89.84 us |
| 32 targets, 32 static marks | 166.80 / 190.08 us | 177.20 / 211.00 us |
| 32 targets, 32 moving marks | 176.56 / 201.72 us | 198.20 / 229.60 us |

Parent's sequential joined confirmation used the same 24-by-25 alternating
blocks:

| Scenario | Base p50/p95 | Candidate p50/p95 |
|---|---:|---:|
| 2 targets, 32 static marks | 168.48 / 200.16 us | 79.72 / 95.56 us |
| 2 targets, 32 moving marks | 183.28 / 270.76 us | 90.28 / 134.48 us |
| 32 targets, 32 static marks | 172.52 / 259.36 us | 187.76 / 277.12 us |
| 32 targets, 32 moving marks | 168.12 / 199.20 us | 182.88 / 219.12 us |

The independent run reproduced the same tradeoff without finding a correctness
failure.

Repeated-target cases improve substantially, but the supported 32-distinct
distribution regresses by roughly 7–14% in the author run and about 9% in the
parent confirmation. The actual game distribution of the
32 persistent marks across unique target meshes has not been measured. The
candidate therefore cannot replace the base without a proven source workload
or an algorithm that avoids the worst-case regression.

No content, authority, hit planning, TTL, resource, main, GPU, LIVE or Git state
was changed.
