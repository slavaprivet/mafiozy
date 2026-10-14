# Native parked-car pause lease (tools only)

The live car's handbrake does not imply zero motion. The earlier K gate
(`linear_velocity <= 0.01 m/s`) can refuse a harmless parked car forever.
This lease instead needs 31 consecutive physics samples (roughly half a second
at 60 Hz), all four wheels grounded, no contact receipts/gaps, neutral driver,
`<=0.03 m/s` linear and `<=0.005 rad/s` angular speed, and `<=0.01 m` actual
displacement / `<=0.003 rad` rotation over that window. It freezes only the
physics body. Its exact owner receipt checks body/session/lifetime/sequence,
transform, tick, and contacts while held. Exit restores the captured freeze,
velocity, angular velocity, and sleep state. It never edits collision or visual.

The first actual-body check exposed a one-physics-tick observation gap: the
body had advanced to tick 902 while the last lease sample was tick 901.
The lease now samples that current tick exactly once during `acquire`, while
still rejecting skipped ticks or changed owner state. In fresh isolated stage
`outputs/map-editor-actual-k-atomic-WlR1pi`, Godot 4.7.2 import exited 0;
the actual preview car admitted, verified and released with headless exit 0.
It retained ~0.01239 m/s, four grounded wheels, zero contacts, and freeze
returned to false. A changed transport session was refused while held; after
restoring the original session, exact release succeeded. This is a native
actual-body check, not K/LIVE acceptance.

This is not installed in production or the actual-K composition. `patch.mjs`
generates a SHA-pinned extension of the actual transport owner without writing
production files; its three methods issue/verify/release the real owner receipt.
The adapter never freezes a body itself. The host must
acquire the lease before tree pause, include the receipt in its K snapshot,
verify it before each edit/exit, and release it while tree-paused immediately
before unpause. Any failed acquire/verify/release is a terminal HOLD, not an
unsafe resume. The owner extension still requires negative native fault tests,
actual-K integration, and moving-production rebase. An earlier synthetic RigidBody3D test was run
before owner extraction; it does not validate the current owner extension.
No LIVE acceptance has been claimed.
