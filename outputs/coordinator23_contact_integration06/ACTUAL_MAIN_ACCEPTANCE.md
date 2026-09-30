# Actual root integration — scheduled player

`main07_02/RESULT.json`: **64 PASS**, 14.172 seconds, no engine errors/warnings.
Harness SHA256: `311e970286358f4f1e99404e475a8b23c63fafda8c9a6fffeb06f9e40a89aa4b`.
Candidate07 NPC owner remains `fa1c551a8501f1f731126d374c25ab07ac209137862febd5ee40ec0b7102049e`.
No candidate or production files were edited. The failed `main07_01` evidence is preserved.

The harness invokes `scene._bind_final_dead_contact_port(measured_limits)` once. It leaves the normal
player physics schedule enabled throughout and uses ordinary InputMap actions. It never calls
`player._physics_process`, installs a second sampler, rebinds the root sampler callbacks, invokes an
external admission path, or applies force. Public population/port and canonical movement receipts
are exercised through the production hook. Private references are read-only observers for stats,
the inherited actual-hit aiming fixture, native body snapshots and original eye state.

Original resident_252 receives two real input shots: medical survival at HP1 with eyes open, then
the fallen finisher at HP0 with eyes closed and the accepted blood revision. Source survival RNG is
seeded; no hit, HP or ragdoll state is injected. After all 16 original parts naturally sleep, three
complete 45-step walking approaches produce seven admitted physical contacts. The exact sleeping
hand wakes, maximum segment motion is **3.47cm**, energy **0.228J**, linear speed **0.385m/s**, angular
speed **8.19rad/s**, and joint separation **2.98mm**. HP, blood/death revision, per-part mass, masks,
freeze state and joint count are unchanged by movement.

Alive, medical, stationary, moving-away and wall-blocked cases each admit **zero** impulses. The wall
is a genuine StaticBody inserted in an empty reserved region, registered for four physics ticks
before movement, verified by the native ray, and then verified by an actual player slide collision
and blocked displacement. It does not overlap NPC parts. This corrects the prior same-callback wall
insertion experiment from the component harness; that experiment was never a valid wall proof.

Fixture fixes: standing bodies use a larger 1.15m supported approach; fallen bodies search all low
native parts and valid directions. Every shot explicitly restores camera tracking and reacquires
both real camera and actual muzzle visibility after a movement case. Only the player is placed for
QA, never a corpse. Contact scenarios are paced against actual wall-clock cooldown; no timer is faked.

The five optional screenshot stages are retained and stay offscreen/NO_FOCUS. **No GPU was launched**.
The inherited top-level aiming/observer camera is an explicit test fixture, not ordinary AimCamera
parity or visual/FPS acceptance. The separate GPU/performance harness must use its own normal-camera
driver when measuring that behavior. Resident walking remains disabled as in the author input test;
all three original NPCs remain loaded.

Run the console Godot with `--headless --path ABS/candidate07/godot/mafiozi_walk`, this absolute
`--script`, `--fixed-fps 60`, and user args `--qa-out=ABS/NEW_RESULT` plus
`--contact-limits=ABS/outputs/coordinator23_contact_port_proposal/MEASURED_LIMITS.json`.
Bounded deadline: 45 wall-clock seconds. The exact source closure and runtime hashes are recorded in
`TEST_ORIGIN.json`. The old preparation script now records hashes only and cannot overwrite this
hand-maintained scheduled-player rewrite with the previously failed prepared harness.
