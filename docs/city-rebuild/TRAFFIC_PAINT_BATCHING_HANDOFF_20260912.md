# Traffic paint invalidated vehicle batching — 12 September 2026

## Observed in the actual populated game

Loaded local integrated world, 72 NPC / 27 visible, 27 traffic cars,
GTX980/DPR1/multi-draw supported. `npcWorld.traffic.renderBatches` reported:
492 batches / 2532 members / 1485 active / **1047 fallback members**.
This demonstrated that earlier structural batching savings were not all retained
in actual traffic. GPU timing was not a controlled acceptance: a separate owner's
hidden test renderer remained active, and the render-only hold was interrupted
by the 15-second placement poll. No FPS improvement is inferred from this capture.

## Cause and narrow production fix

`world_traffic_presentation.mjs` painted each `*_LowerBody` mesh's current
material. For batched sources that current material is an invisible proxy shared
by many members. Mutating the proxy correctly triggers the batch manager's safety
fallback, disabling dozens of otherwise healthy members on every colored car.

The paint operation now obtains `getVehicleRenderSourceMaterial(mesh)` first.
It updates the real material used by the batch instead of corrupting its hidden
proxy. If a part has genuinely acquired a replacement material, the accessor
returns that actual replacement, preserving damage/ownership semantics. No
batch-manager safety checks were removed and no models were simplified.

## Red / green checks

`test_world_traffic_paint_batches.mjs`: 12 actual GLBs plus one duplicate instance.

- Initial paint fallback members: **557 before → 0 after** over thirteen cars.
- Structural one-pass mesh/batch submissions: **1879 → 1435** (not GPU timing).
- Sedan: 156 → 116; SUV: 153 → 112; coupe: 134 → 102.
- Runtime stationary paint updates preserve batching; two instances keep private
  colors. Detail A/B, steering, brakes and doors remain valid.
- A genuine per-part material replacement still falls back exactly that one part.
- Existing `test_world_traffic_presentation.mjs` also passes.

Already fallen-back runtime actors are deliberately not repaired automatically:
reload/recreation is required. A late bulk re-enable could resurrect genuinely
damaged/deformed parts. Coordinator was asked to inspect fallbackMembers after
the next ordinary demo reload, without opening an additional GPU scene.

## Testing infrastructure corrections

The loaded A/B hold was being cancelled by placement refresh's transient `busy`
flag every 15 seconds, even with unchanged files. `refresh()` now skips work only
during an explicit local render-only QA hold; ordinary gameplay refresh is intact.
QA diagnostics now record the stop reason. New regression assertions pass.

Hiding the in-app browser is **not** sufficient GPU isolation: our temporary
test tab still reported `document.hidden=false`, `visibilityState='visible'` and
kept rendering after visibility.set(false). Only our own temporary test tab was
closed; the user's/coordinator's game was not touched. The other owner confirmed
their old hidden baseline tab also remained active. Previous multi-scene timing
comparisons are invalid. Future tests require actual temporary-scene cleanup or
explicit rendering suspension, not merely stopping automation calls.
# Fresh populated LIVE confirmation

Coordinator16 read the user-refreshed demo DOM after `first-populated-frame`:
`traffic.renderBatches = {activeMembers:2583,batches:500,fallbackMembers:0,members:2583}`.
This confirms the paint fix retains all traffic batch members on a fresh load.
No FPS measurement accompanied this check; do not report a measured FPS gain.
