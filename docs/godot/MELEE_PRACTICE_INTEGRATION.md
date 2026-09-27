# Ground melee practice — 27 September 2026

Revision `s01-20260927-melee21` enables ground practice in the actual migration
scene. LMB admits the original source-selected punch/kick; holding LMB for 1.2
seconds selects the source heavy action; RMB raises the guard. The first click
after releasing the cursor only recaptures it. Mouse orbit remains independent
of facing. The numbered in-game update panel describes these controls.

This is currently practice with an explicitly empty combat target registry.
It does not damage NPCs, authorize a network hit, or implement a playable fight.
The incoming-impulse tests below use TEST_ONLY events on the real player.

## Integration and physical presentation

`combat/preview_melee.gd` owns the offline practice state, original input/admission
ports, source sampler and canonical physical presentation adapter. Main installs
it after the real player/transport. Player calls it before the existing local-hit
decorator; the existing player remains the sole skeleton writer.

Attacks use fixed rig lengths before any physical takeover. This intentionally
changes the source's stretched visual poses, while preserving source action
selection, timing and metadata. Guard/charge transitions settle smoothly into
ordinary locomotion. Fully settled walking/running/strafe samples pass through
exactly. Focus loss, cursor release, jumping, vehicle authority and a new player
epoch cancel practice; no old action is restored after physical recovery.

The requested future combat rule is stable controlled locomotion with physical
reactions to actual impacts. Variation should follow contact position/direction,
momentum, posture, support and nearby obstacles. It must not be simulated by
randomly throwing characters or permanently wobbling their gait. Weak reactions
should preserve control; sufficiently disruptive impacts can yield to articulated
physics, then recover only when support and clearance permit. Bullet/explosion
and melee producers still need their real damage/authority integration. An authored
gameplay force is not a measured source impulse and must be identified as such.

## Verification

- Actual-main practice: 21 checks; independent host review: 35 checks, including
  210 ordinary locomotion frames with exactly unchanged bases.
- Canonical adapter: 85,298 checks over 2,424 real-rig action/side/gait samples.
- Actual-main punch/kick to weak/strong physical handoff: 20 checks. First physical
  joint origins differ by at most 0.238 micrometres. These cases recovered, but do
  not cover the additional repeated-impact failure below.
- Existing affine writer: 346 checks; physical endpoints: 253 checks.
- Original-source admission: 9,363 checks against both current source and committed
  HEAD source. Four executed slices are pinned after CRLF-to-LF normalization;
  unrelated changes elsewhere in world.html are not a dependency. One broken callback
  fixture emits an expected script error; that log is not described as error-free.

Native evidence: `outputs/coordinator21_melee_liveqa/native01/report.json` and
baseline/punch/kick/guard/heavy/recovered PNGs. Actual Godot input-event routing,
GPU rendering and source hashes passed; screenshots were reviewed. The harness
restored an interactive scene. No OS-level manual playthrough is claimed.

Same warmed 1280×720 Forward+ quarter, GTX980, 144 FPS cap, one car, zero NPCs:

| Phase | Frame time p50 / p95 (ms) |
| --- | --- |
| Practice disabled | 6.972 / 7.894 |
| Enabled, idle | 6.952 / 8.046 |
| Ordinary actions | 6.961 / 8.254 |
| Guard | 6.963 / 8.345 |
| Charged action | 6.979 / 8.294 |
| Ordinary after action | 6.981 / 8.001 |

These short runs qualify this small scene only, not populated-city performance.

## Recovery defect and verified correction

`outputs/coordinator21_melee_liveqa/impact01/report.json` failed with
`recovery_timeout:FALLING:recovery_skin_blocked` after a weak, strong and repeated
TEST_ONLY impulse during a kick. That scene was restored interactively, PID35668.
A phase named `recovered` in this failed report does not prove
recovery. Keep the failure and its captures as regression evidence.

Exact headless traces identify both false positives from the conservative whole
skin bounding box near the rotated car and a real 1.299 mm skin penetration in
another proposed step. The adopted helper `23b78c72` proves the continuous full-skin
path outside actual box planes, with bounded subdivision and the original margin.
Driver `5499d0e1` removes a body from a temporary broad query only after proving
separation from EVERY actual shape and checking exact native/node geometry identity.
It reruns the unchanged remaining-world guard and restores exclusions. Unknown
geometry, caps, compound obstruction and insufficient clearance still reject.
Snapshots/refinement run only on the rejected broad-phase path. Disposal disconnects
geometry-lifetime signals. There is no unconditional car or floor exemption.

Helper 71, independent 29, root actual-server integration 36 and existing impact
endpoints 253 checks passed. Six captured false obstructions pass; one 44 micrometre
gap remains rejected by the 1 mm margin. Independently verified 1.299 mm penetration
and continuous crossing remain rejected. Two exact actual-main headless impact
sequences passed; final self02 includes the helper among stable source hashes.

Final LIVE: `outputs/coordinator21_melee_liveqa/impact_refined_native01/report.json`
PASS, all hashes stable. Real rendered kick, weak reaction, strong/repeated fall,
getup and ordinary stance were captured and reviewed. Inputs/events in this harness
remain TEST_ONLY, not enemy damage. One fresh interactive scene was restored and
left open as PID43848. Same small-scene qualification as above:

| Phase | Frame time p50 / p95 (ms) |
| --- | --- |
| Baseline | 6.951 / 8.128 |
| Fall | 6.959 / 8.188 |
| Getup | 6.942 / 9.600 |
| Recovered | 6.965 / 8.097 |

This verifies the reported scenario, not all possible poses, moving obstacles or
crowds. The original failed run is retained. Author helper cost and conditional
limits are in `RECOVERY_SURFACE_BOUNDS_HANDOFF.md`.

The isolated native triangle-query extension and GDScript index candidates are
not loaded by this scene. Their component benchmarks do not establish combat
frame cost or authorize target hits.

## Packaging

The first `melee21` export failed its actual-pack launch: selected-resource export
omitted `player_impact_host.gd` and `preview_melee.gd` and their dependencies.
That failed artifact is retained as evidence and is not the release to use.
The preset now explicitly includes all ten missing runtime scripts; the export
helper rejects omitted literal script dependencies before building.

Corrected `exports/win64/melee21b` built with unchanged recorded input hashes.
Its actual PCK main loaded and completed the TEST_ONLY kick/weak/strong/repeat/
recovery pipeline headlessly (`outputs/coordinator21_melee_liveqa/impact_pack21b_pinned`).
The package SHA was pinned before and after that run. Raw script hashes are absent
in this compiled pack and are correctly reported as unavailable, not stable empty
hashes.
The source LIVE result above is the GPU qualification; no separate release GPU
benchmark is claimed.

A fresh archive of the staged Git tree imported without errors, independent of
the shared `.godot` cache. Actual-main practice 21, source-slice admission 9,363
and recovery-world integration 36 checks passed in that clean archive.
Evidence: `outputs/melee21_staged_validation/`. Unrelated world.html edits,
NPC candidates, native DLL prototypes and other owners' WIP are not part of this
checkpoint.
