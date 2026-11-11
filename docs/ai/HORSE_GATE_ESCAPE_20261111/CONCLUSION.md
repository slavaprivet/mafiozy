# Horse gate escape hardening — 2026-11-11

Follow-up audit found that the first four close dismount candidates still used
weaker validation than the rubble fallback, and that a floor up to eight metres
below the horse could be selected.

## Final behavior

- Close and fallback candidates now share ground, capsule and intact-route
  validation.
- A dismount floor may differ from horse height by at most 1.35 m.
- If all 36 bounded candidates are blocked, a startup-only recovery is allowed
  within 15 m of the saved safe spawn anchor. The anchor is revalidated before
  moving horse and rider, then normal dismount validation runs again.
- No recovery teleport is available away from the startup area.
- These physics queries run only on an F interaction, not per frame.

## Acceptance

- Horse regression: PASS, stderr 0. It covers the actual F handler, normal
  mount/dismount, close rubble fallback, a thin intact wall, a floor five metres
  below the horse, and dense rubble over all 36 candidates with startup recovery.
- Castle gate breach: PASS, stderr 0.
- Battlefield spawn guard: PASS, stderr 0.
- DeepSeek review: no critical finding and no sustained FPS concern.

Earlier `horse_input_f1/f2/f3` receipts are retained as raw fixture iterations.
They exposed the startup spawn guard in the test and led to the final isolated F
handler fixture. `horse_edges1` is the final acceptance receipt.
