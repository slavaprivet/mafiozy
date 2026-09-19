# Vehicle pair / fixed arch detail batches — 12 September 2026

Scope: `vehicle_render_batches.mjs`, its regression tests and the new CPU benchmark.
No wheel-model, simulation, fleet, traffic, NPC, world or walk hooks changed by this author.

## Change and A/B contract

- Existing material-UUID-compatible pairs now batch, preserving all original
  geometry, shadow/layer flags, materials, raycast sources and damage ownership.
- Four fixed painted wheel-arch lips are admitted by exact seat/name/parent
  ownership. Rolling wheels, tyres, liners and steering remain excluded.
- New arch groups stay separate from legacy groups. New pairs and arch groups
  are tagged `vehicleDetailRenderBatch`; legacy groups never toggle.
- `setVehicleRenderDetailOptimization(carRoot, enabled)` returns boolean or
  null for an absent/disposed manager. The factory API also exposes
  `setDetailOptimizationEnabled(enabled)`.
- Runtime disabling restores only active new source materials and hides new
  batches. Updates and re-enable validate geometry versions, transforms,
  material replacement, ownership, detachment, visibility and render flags;
  permanently fallen-back parts are never resurrected.
- Constructor `detailOptimization:false` allocates **no new detail batches**
  and cannot enable them later. Caller must pass this when
  `WEBGL_multi_draw` is unsupported. The factory has no renderer context.
  Unsupported Three fallback draws each member and therefore cannot provide
  the intended submission saving; automatic late render-callback switching is
  deliberately avoided. Supported construction defaults true for runtime A/B.

## Evidence and costs

`benchmark_vehicle_render_details.mjs` uses all 12 actual models, body/door
batching, a fixed full-car orthographic view and the production-sized sun
frustum. Capability-off construction has exactly legacy groups; runtime A/B
off matches its main/shadow eligibility on every model.

- 192 additional source meshes become 84 batches.
- Main submissions: **108 fewer** over 12 models (7–11 per car).
- Shadow submissions: **96 fewer** (6–10 per car).
- Totals assume working multi-draw and exclude a transmission prepass.
- Interleaved 600-sample CPU runs showed an additional roughly **0.25–0.30 ms
  p50 per update of all 12 helpers**, not a reduction in helper logic cost.
  Two source-eligibility benchmark runs: .888/1.187 → 1.144/1.492 ms and
  1.038/1.742 → 1.335/2.256 ms (p50/p95). These are CPU-only samples, not
  GPU times or a claim about overall FPS. The retained script uses the final
  public capability opt-out rather than the earlier in-memory source hook.
  Final capability-off vs enabled run: **.971/1.657 → 1.223/1.963 ms**
  (p50/p95 for all 12 helpers), an added **.252/.306 ms** respectively.

## Verification / limits

- Existing 12 GLBs × 3 modes: **6,011,010 vertex comparisons PASS**, including
  new pairs/arch lips, full car rotation and open doors; material/geometry
  mutation, reparenting, shadow/layer/order, source raycasts/anchors, disposal
  and real SUV crash/explosion debris pass.
- New detail tests pass runtime A/B, unchanged legacy batches, strict arch
  admission, capability opt-out, disabled-state mutations, material ownership,
  changed transforms and authored hidden state.
- Additional fleet, walk integration, damage, authored crash parts, crash
  mechanics/visuals, tyre damage and all 13 wheel-geometry fixtures: **62 PASS**.
- No GPU/browser scene opened. **Performance of the complete game is not
  verified here.** Main owns caller capability plumbing and queued fixed-scene
  LIVE A/B. Keep only if saved driver work outweighs the measured extra CPU.
