# Castle visual pass 3 — 2026-11-11

## Outcome

- Round tower masonry now uses the correct radial/tangential dimensions and one
  stone bucket. A restrained four-course belt remains in build-time instance
  colour, removing the earlier high-contrast checkerboard.
- Two tall heraldic standards make the keep the courtyard focal point. They are
  additional transforms in the existing three banner MultiMeshes.
- Existing keep bricks receive broad centre/wing/crown colour hierarchy.
- Existing courtyard paving receives a darker perimeter, brighter gate-to-keep
  axis and warmer keep apron.

No brick, physics body, collision shape, light, material, shader, shadow caster
or render node was added. Brick count remains 61,886. Banner instance counts are
13 bars, 13 cloth panels and 52 device pieces inside the same three draw calls.

## Verification

- Visual pass 3 regression: PASS, stderr 0.
- Previous pass 2 regression and support cascade: PASS, stderr 0.
- Castle structural check and gate breach: PASS, stderr 0.
- Fixed graphical views and breached-gate view: PASS, stderr 0.
- DeepSeek review: no critical finding.

Two clean exclusive performance runs:

| View | Run 1 | Run 2 |
| --- | ---: | ---: |
| Courtyard | 186.90 FPS | 186.68 FPS |
| Gate | 157.14 FPS | 158.42 FPS |
| Whole castle | 152.10 FPS | 152.28 FPS |

Gate samples reported 1,778 and 1,776 draw calls, down from the accepted pass-2
reference of 1,811. Objects also fell from 2,242 to 2,209/2,207. The visual pass
therefore does not consume the previous frame budget.

Early regression receipts are retained: they record test-fixture assertions being
refined before the final `pass3_regression5` acceptance run.
