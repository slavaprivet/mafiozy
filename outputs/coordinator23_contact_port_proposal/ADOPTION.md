# Final-dead contact port — proposal for Artist/root review

Frozen port SHA256: `bc7c93a5028482d65fb4e1bc01c8a1f3b54449ad1f86eac91b8b49c73b490aa3`.
This is an isolated proposal, not enabled production or visual/performance acceptance.
No NPC production file, GPU window, Git state, damping, collision masks or corpse poses were changed by this task.

## Minimal public connection

Artist-reviewed accessor patch: `ARTIST_REVIEW_public_accessor.patch`.
The root installed this read-only accessor in candidate06 for testing; its resident-host SHA is
`fca338454eff819e31946b54c5d51f06f6ece989c65c791dae79bbf2301882fb`.

`residents.public_final_dead_contact_capabilities()` returns current prepared original hosts,
bindings and `Callable(residents, "public_final_dead_contact_current").bind(host)`.
The public validator checks both current binding/life and registry host identity, then the trusted
host's ACTIVE/final_dead/nonempty death key. Registration may happen before death; admission cannot.
Root must not scrape the private NPC registry to register production capabilities.

Root stage06 already provides `scene._bind_final_dead_contact_port(limits)` and the population
ready/admit forwarding methods. Put the frozen port at
`res://scripts/npc_visual/final_dead_contact_port.gd` in an isolated review candidate and supply
`MEASURED_LIMITS.json` explicitly. Default OFF and empty limits must remain fail-closed until
owner review, actual-main connection tests and paired scene performance/visual acceptance.
Dispose the port before disposing NPC owners. Bind a new port when the population/life pool changes.

The actual player must expose `completed_ground_move_receipt()` with
`{frame, serial, pose_epoch, start, end}`, stamped only after canonical normal `move_and_slide()`.
The updated root sampler supplies `movement_serial`. Missing/old receipt or old sampler fails closed.
Port admission consumes each completed movement serial at most once and also deduplicates event IDs
(bounded last 1024). ObjectID-derived positive port epochs distinguish replacements within a process;
this is the existing local new-session preview scope, not server/persistent authority.

## Actual native result

`native12/RESULT.json`: **119 checks PASS**, 23.759 seconds, no engine errors/warnings.
Godot 4.7.2 headless, actual candidate06 main, unchanged three original NPCs, real revolver inputs
first causing medical survival and then final death. This includes candidate06's corrected point
impulse, so the ragdolls were tested after actual medical drift, not a zero-impulse baseline.

Each positive scenario executes three complete 45-step approaches with ordinary InputMap actions
and the actual production `player._physics_process()`, including the production sampler and move
receipt. The scheduled callback is disabled and that exact canonical method is invoked once from
the harness physics callback. Player start placement is a declared QA fixture on a verified floor;
no corpse position/velocity is set. Later approaches prefer the first admitted exposed body region.
The harness paces contacts with real 16ms delays because `--fixed-fps` otherwise accelerates virtual
physics past the owner's real-time cooldown. Settling and post-measurement remain accelerated.
Observation runs throughout contacts, not just after transient motion has stopped.

| Original NPC | Natural baseline | Accepted contacts | Peak segment displacement | Peak kinetic energy | Peak joint error |
|---|---|---:|---:|---:|---:|
| resident_72 | Rested, small jitter; 0/16 asleep | 9 | 6.85 cm | 0.158 J | 0.45 mm |
| resident_169 | Rested, small jitter; 0/16 asleep | 4 | 6.33 cm | 0.299 J | 0.91 mm |
| resident_252 | All 16 naturally asleep | 6 | 3.92 cm | 0.322 J | 3.64 mm |

The exact contacted sleeping part of resident_252 wakes through native `apply_impulse`; no explicit
unfreeze/wake write is used. Maximum observed speed 0.539m/s, angular speed 10.47rad/s.
All scenarios preserve HP, blood/death receipts, each segment mass/filter/freeze value and 15 joints.
Stationary and moving-away scenarios admit zero commands. Awake baseline velocities, energy/support
and sleep counts are retained in the result; the first two corpses are not claimed fully asleep.

Measured limits are 3Ns absolute, 1Ns per m/s of closing speed, 160ms per-corpse cooldown,
predicted exact-part delta energy <=1.5J, linear <=2.5m/s, angular <=15rad/s. A bounded ten-iteration
search reduces point impulse to those limits. Coarse halving discarded too much safe impulse and
the 2Ns candidate failed the >1cm sustained criterion for resident_252; it was not silently accepted.

## Guard evidence and remaining boundaries

Final result records rejection reasons and zero accepted deltas for old epoch/frame/serial,
wrong actor/shape/contact point, stale clock, old-instance replay, same event replay, a new event
reusing the same completed move, and an old move relabelled as a new physics frame.
Actual current-life callback disposal is tested at the first check and immediately before commit.
A replacement host exposing the same binding/body pool is rejected by the real public resident
validator. Alive and medical original hosts are separately rejected by public readiness.
Vehicle-authority and active-jump negatives inject/restore only player state synchronously; they
are state-filter tests, not actual seat/jump gameplay acceptance.

The new port repeats native capsule contact and a layer1 obstruction ray before applying force.
The earlier native sampler54 includes actual wall/vehicle/jump geometry negatives. The final new
port test does NOT claim a fresh wall-obstruction admission proof: native11's attempted same-callback
wall insertion was not yet present in the physics query and the test correctly failed. That faulty
fixture was removed, not used to weaken the guard. Its failed evidence remains on disk.
Actual wall/seat/jump transitions and root population binding remain for the root integrated harness.

Read-only private NPC snapshots are used solely by the test observer for measurements/aiming,
inherited from the original author test. Production registration/admission uses the public accessor.
The inherited observer camera is a test aiming fixture, not ordinary-camera parity or visual proof.
No global scene performance has been measured. `ready()` scans registered hosts and public life
validation can traverse the owner's scene; do not describe this as O(1). Sampler and independent
admission together use at most four rest queries, two casts and two wall rays per attempted contact.

## Portable test closure

Keep `test_three_actual_corpses.gd`, this frozen port, and the exact shared original parent
`outputs/artist23_combat_next/test_combined_eyes_input.gd` (SHA in `CLOSURE.json`).
The original parent is standalone SceneTree with no local extends/preloads. No old sampler54 preload
is needed: the test executes the updated sampler through the actual player setter.
The complete Godot project/imports are external runtime inputs, not embedded in this test directory;
the verified candidate06 and root overlay hashes are recorded in `CLOSURE.json`. A fresh checkout
must apply the reviewed root movement-receipt/sampler and NPC public-accessor overlays before this
test can run. A PCK without those methods cannot substitute for those inputs.

Run headless with the candidate project path, absolute `--script .../test_three_actual_corpses.gd`,
`--fixed-fps 60`, and `-- --qa-out=ABSOLUTE_OUTPUT_DIRECTORY`. Deadline is 30 wall-clock seconds.
Do not run during another owner's CPU measurement window.
