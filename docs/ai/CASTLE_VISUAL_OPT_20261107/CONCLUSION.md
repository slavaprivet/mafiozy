# Castle visual optimization — final review

## Result

The castle gained visible stone-course variation and a sharper medieval silhouette without adding castle cells, render batches, lights, shadow casters, or physics bodies. Existing merlons, tower crowns, gate relief, pediment, roofs, and pinnacles were reshaped in place. Existing `MultiMesh` instance colours are now consumed by the shared stone and paving materials; the deterministic tint is calculated only while filling the instance buffer.

## Structural budget

Baseline and candidate both report:

- 61,886 bricks
- 361 `MultiMesh`
- 211 `MeshInstance`
- 46 shadow casters
- 12 lights
- 3,969 `StaticBody`
- 150 `RigidBody`

No new material class, light, physics object, or `_add_brick` call was introduced. Renderer statistics from separate worktrees differ by four draw calls and four objects; castle-owned structural counters are identical, but the exact source of that renderer-level difference was not proven.

## Matched performance

Final consecutive clean scheduler pair, Godot 4.7.2:

| View | Baseline FPS | Candidate FPS | Delta |
| --- | ---: | ---: | ---: |
| Courtyard | 184.68 | 184.73 | +0.02% |
| Gate | 155.63 | 155.75 | +0.08% |
| Whole castle | 154.43 | 152.16 | -1.47% |

The whole-castle delta is inside the predefined strict 2% acceptance threshold and overlaps the observed run-to-run range. This supports “no demonstrated material FPS regression”, not a claim of zero overhead or a proven speedup.

## Regression coverage

All final runs completed with exit code 0 and empty stderr:

- castle visual material regression
- castle budget regression
- support work-budget regression
- single-brick support regression
- architecture support regression
- castle structural check
- gate breach regression
- repeated graphical performance runs

Visual captures were inspected from the entrance, whole-castle, and corner views. Earlier fixture failures and the failed scheduler start are retained as raw evidence rather than removed.

## DeepSeek review

DeepSeek found no confirmed release blocker under the stated 2% performance criterion. It correctly cautioned against claiming exact renderer parity, a proven speedup, or a proven cause for the four renderer-stat objects/draw calls. Its final answer is preserved in `deepseek_final_answer.txt`; conclusions above are based on the source and live Godot runs, not the consultation alone.
