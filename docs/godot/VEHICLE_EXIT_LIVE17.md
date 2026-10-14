# Exit timing correction — 27 September 2026

User observation: character appears to stop, then rolls. Actual-drive native02
confirmed this: physical planar motion stopped around .333 seconds, while the
canonical 1.7-second recovery kept rotating afterward. Tests that merely checked
for a roll and successful completion had missed the visible timing defect.

## Applied behavior

- Transport transition c9ed1ad7205c74d1131cfda0588f8c862fb1ae6cf64d7b42c83b25f1b0df4c6f
  adopted byte-for-byte after independent 168 checks. Planar inherited velocity,
  bounded swept sliding, uninterrupted recovery clock, physical falling, actual
  floor contact before release and no yaw reset after planar motion stops.
- Pure presentation helper 5acd95e835b3779847a9518cca3a0ab8aef266ce362547021343a1f5e04be1cb
  finishes canonical rotation within the planned physical deceleration window.
  Remaining recovery unfolds the pose. This is an explicit user-requested timing
  change; canonical source geometry and the authority clock remain separate.
- Additive pose adapter 8e1350680b10511e88c75df70be887b9ac3bc40041575a7578362d07589ecad3
  blends the last release portion into the tucked pose, grounding the actual
  mixed skin. It removes the source release's upright-then-tuck seam.
- Source .28 m / .3 s visual hop restored without writing physical root position.
- Root keeps a single pose writer and resets presentation progress per exit token.
  Revision roll17 and compact five-item in-game notes updated.

## Verification

Physical candidate independent 168 PASS; actual main drive/exit cycle 14 PASS;
timing helper 545 PASS; source geometry at remapped times 40 PASS; blended actual
occupant skin 677 PASS. Full scripted headless drive selftest17 passed, then sole
native GPU drive native03 passed with real E/W input, no injected speed, stable
source hashes and a fresh interactive scene restored. Speed at exit 5.737392 m/s.
Late-release, mid-tumble and settled screenshots inspected: grouped before roll,
airborne tucked rotation and standing afterward; vehicle continues moving.

Native03 performance requires follow-up: frame p95 during roll 16.618 ms versus
11.396 ms in native02. Seven stale headless transport test processes were found;
their owner cleaned them after confirming ownership. Do not attribute the entire
timing difference to those processes without a new measurement. Native04 repeats
the same actual drive after cleanup and adds per-phase pose-cost telemetry.

Evidence: outputs/coordinator21_vehicle_liveqa/native02, native03, native04;
outputs/coordinator21_moving_exit_review.md; VEHICLE_EXIT_PRESENTATION_HANDOFF.md.

## Limits

This is a controlled animated roll with swept character physics, not ragdoll or
exact no-slip rolling. At low launch speed it completes quickly. Source surface
gravity18 differs from the native project's9.8; source water exit support remains
unported. The live test covers one car and a small quarter, not full-city FPS.
The independent deep-fall review caught and corrected an airborne grounded
receipt, but water/whole-city behavior is not inferred from that result.
