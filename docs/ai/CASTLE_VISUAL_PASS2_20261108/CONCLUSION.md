# Castle visual pass 2

## Outcome

The second pass improves the existing entrance and tower language without adding castle cells or render classes. Entrance piers now read as base, shaft, and capital; the seven machicolations have a defensive rhythm; four tower crowns have distinct silhouettes while retaining their original support edge. Coarse repaired masonry, sheltered courses, gate wear, and tower exposure use the existing build-time `MultiMesh` colour channel.

## Fixed budgets

- 61,886 bricks
- 361 `MultiMesh`
- 211 `MeshInstance`
- 46 shadow casters
- 12 lights
- 3,969 `StaticBody`
- 150 `RigidBody`
- final renderer sample: 1,811 draw calls / 2,242 objects for both baseline and candidate

No `_add_brick`, material, light, physics body, shader, texture, transparency, or runtime update was added.

## Destruction and regression

The first projected keystone geometry changed one arch cascade and was rejected. The accepted version keeps arch support geometry unchanged and uses colour for that accent. In the final baseline-matched fixture, removing one existing cell from each of four changed families produces exactly the same result in baseline and candidate: 204 collapsed cells, zero pending support work, and identical remaining group counts.

Material, pass-2 profile, pass-2 support, architecture support, single-brick support, support budget, castle structural, gate breach, graphical capture, and performance runs pass with empty stderr.

## Performance

Exact `3921c692` baseline and candidate used matched imports and the exclusive scheduler. Closest final pair:

| View | Baseline FPS | Candidate FPS | Delta |
| --- | ---: | ---: | ---: |
| Courtyard | 184.58 | 184.36 | -0.12% |
| Gate | 155.60 | 156.15 | +0.35% |
| Whole castle | 151.82 | 151.94 | +0.08% |

One earlier candidate sample fell to about 104 FPS without a draw-call change; immediate and subsequent repeats returned to the normal range. It is retained as anomalous raw evidence and is not hidden from the result.
