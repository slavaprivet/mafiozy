# Static water query for the current preview crop

Root22, 29 September 2026. Component only, not connected to main or exports.
`scripts/preview_static_water_query.gd` reuses the existing reviewed landscape
sampler; it does not infer gameplay water from rendered vertex depths.

The exact active block1523f52e and terrain d744b99a are required. Root verified
the full original topology pin11f256f2, all crop cells/masks and303 rendered
water cells:6,739 checks PASS in outputs/coordinator22_water_binding/RESULT.json.
The wrapper repeats crop equality at configuration and retains scalar JSON
origins instead of rounding them through Vector3. Queries outside the half-open
visible crop return UNKNOWN. Source topology still includes neighbours outside
that crop for the original shoreline calculation.

The source proof remains the historical static a05ad context and original
static phase/session. It is never renamed to a current gameplay frame. Results
explicitly retain combined_ground:false and physical_admission:false. Known dry
is value:null; an unknown result must not be unwrapped as dry. Water level/floor
are local metres; source_world_value preserves original values separately.

Owner tree exit retires the instance permanently, including remove/re-add
between queries. Manual disposal disconnects its exit signal. No world scans,
source hashing, terrain loading or new physics queries occur per sample.
The host must create a new instance for a replacement static scene.

Root6,121 headless checks cover every crop cell at three positions, scalar
reference equality, output independence, boundaries, changed bytes and lifetime.
Independent5,970 checks identified two issues now repaired: an owner could leave
and re-enter between polling queries, and empty input emitted an engine hashing
error despite rejection. Final targeted independent17 checks PASS, clean log,
including immediate remove/re-add, sticky retirement, empty inputs, manual signal
disconnect and released RefCounted instances. Final source SHA:
`b0df5afce8d22598f3fae708c6cbf73220c85ad89070e5f41cf72a02a494cb5c`.
Evidence: outputs/coordinator22_static_water_review/REVIEW.md.

Observed cold configuration75–83ms; warm source-water query p50/p95 approximately
17/18–19/20us under ordinary background CPU load. These are component costs,
not a comparable loaded-scene improvement, allocation measurement or city FPS.
Configuration belongs at load time, never in the movement loop.

Before runtime adoption: ship reviewed terrain bytes/provider dependency in a
verified export, bind the actual main lifetime, preserve separate building/rail
ground and posture collision owners, and measure the entire water movement path.
The data still lives in the received outputs package. The API alone does not
enable submerged car exits, swimming, floor colliders, NPC placement or progress.
