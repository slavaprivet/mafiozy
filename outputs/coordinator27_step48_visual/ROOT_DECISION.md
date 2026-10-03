# Step48: graphical review of the inherited foot-rise assertion

The accepted48 game and its 486 pinned source files remain unchanged. This is an
isolated graphical component using the original imported hero, exact step33
player, capsule and native movement on explicit artificial 106/120 mm lanes.
It does not establish traversal of current-world geometry or performance.

`visual03` executed cleanly in 10.717 s, stderr zero, 19 captures. All captures
have matching observed/rendered physics frames and focused test window. The
actual locomotion reports ready, changing pose revisions and running speed
5.727 m/s. A separate post-player physics observer recorded 514 consecutive
ticks and proved exactly one native movement and matching displacement per
tick, except the explicitly declared between-lane setup placements.

Root inspected `visual03/frame_0017.png` and `frame_0018.png`, showing the actual
model approaching and crossing the 120 mm edge. The capsule's brief rise above
the authored top is reproduced; this is not evidence of an extra jump or of
admitting a taller obstacle. Native evidence from the separate boundary test
still rejects 121/210/400 mm and protected bodies.

The original numerical gate remains **FAIL**: total foot rise exceeds the
historical 123 mm assertion. In this graphical replay the peak Y is about
0.126070 m over a 0.120 m top. Root accepts this observed transient **for the
component's surface-admission review**, because the requirement limits the
admitted surface height and the excess occurs later during native rounded
capsule sliding, with no new helper lift. The old assertion is not a suitable
proof of the surface-height limit. No epsilon, step limit, collider, velocity
or runtime code was widened or replaced to obtain this decision.

This does **not** set the raw result to PASS, accept the whole step package or
replace current-world interaction and comparable loaded-scene cost gates.
Those remain required before promotion through F5.

Preserved attempts:

- `visual01`: valid images but four inherited per-await serial assertions fail
  because PNG readback spans physics frames; not evidence of double movement.
- `visual02`: QA-only relative resource-path error for the new observer.
- `visual03`: corrected relative preload and independent physics observer;
  1590/1591 assertions, only the original 123 mm foot-rise assertion fails.

The helper change replaces a sampling assumption with observation of every
physics tick. It does not suppress native errors or rewrite previous evidence.
The user's original game/editor were preserved; the runner owns and closes
only its graphical test child. Parallel execution is not an FPS measurement.
