# Horse gate escape fix — 2026-11-09

## Cause

The startup offset placed the horse at the castle gate plane. Dismounting tried
only four points at 2.15 m, so a rubble pile could reject every exit forever.

## Change

- Startup selects one of five courtyard-side positions after ground, slope and
  conservative horse-volume checks.
- Normal dismount keeps the original four close exits.
- When those are blocked, an F press performs a bounded 4-ring/8-direction
  search. The final player capsule and route must be clear.
- Route rays may skip only explicitly identified rubble/debris; intact walls
  remain blocking.
- No search was added to the per-frame update.

## Verification

- `test_horse_gate_escape_regression.gd`: PASS, stderr 0. Verified startup
  outside the gate corridor, normal mount/dismount, fallback through four
  blocked close exits, restored walking collision, and intact-wall rejection.
- `dsh_castle_gate_breach.gd`: PASS, stderr 0.
- `dsh_battlefield_spawn_guard31.gd`: PASS, stderr 0.
- DeepSeek review: no critical finding; noted only bounded, input-time cost and
  the deliberate no-spawn outcome if every safe startup candidate is occupied.

`dsh_castle_perf.gd` was also run in a clean scheduler lane. Gate and whole-scene
samples were about 144.8 FPS, but its courtyard sample reported the pre-existing
headless `courtyard_slow` failure (1.89 FPS), so this is not recorded as a full
performance acceptance. The changed code adds no per-frame query.

The first regression invocation passed its assertions but exposed a test-fixture
ordering error (`global_position` set before insertion into the tree). The fixture
was corrected and the clean second receipt is the acceptance run.
