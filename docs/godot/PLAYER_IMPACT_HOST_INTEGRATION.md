# Native player impact integration

Root21, 27 September 2026. Native integration verified; gameplay combat producer remains open.

The fixed preview hero now has an explicit installation seam:
`main.install_character_impact_source(resolver, reaction_profile, local_inertias)`.
It constructs `character_physics/player_impact_host.gd` against the existing
transport session, player, appearance, physical pool and pose writer. The default
game does not call it: the source combat/contact producer is still missing.
Tests which inject admitted events must label that resolver TEST_ONLY. They prove
native integration, not server authority, NPC combat or real contact generation.

## Ownership

The host supplies the sink's real owner/preflight/dispatch/presentation ports.
Only accepted-event resolution remains with the source owner. Actor/life/session
come from the actual player metadata and current transport session. This adapter
supports the present 75 kg player, not arbitrary NPCs or source mass conversion.
The appearance is fixed at native geometry revision zero; changing the skeleton,
mesh or Skin resource rejects events and requires a new source binding. In-place
geometry edits and source contact anchor validation remain the producer's job.

Weak impacts decorate the chosen locomotion/airborne pose before the existing
single skeleton writer. Feet, root, translations and gait remain those of the
base pose. When there is neither a new hit nor a residual reaction, the decorator
returns the original dictionary without sink snapshots, copies or spring work.
Local inertias and force/stance thresholds are explicit caller-supplied tuning;
the preview does not derive any impulse from HP.

Strong impacts use the existing driver and pool. The driver captures the displayed
pose before taking `physical_impact` ownership. The host advances that owner once
per physics tick; transport continues owning a car exit or confirmed void death.
Repeated impacts act on the existing body, and GETTING_UP can be interrupted.
After driver DONE, native support is checked again before returning walking.
E interactions cannot steal the character's movement while physical ownership
is active. A removed or failed owner must stop with an explicit fault, retaining
collision ownership until restart, rather than invent a safe standing location.

The sink remains responsible for per-event consume/commit checks; source durable
replay protection remains mandatory beyond its bounded history. An unknown
partial physical commit is terminal, never a reason to apply the impulse again.

## Native acceptance, physics19

Actual-main independent lifecycle 98 checks and invalid-install/retry 25 checks
PASS against driver `434b2b9175c1533329b897a6812d284c77e79503f1ff94c2adc1aa4af8674bbb`.
The deliberate active-host removal produces the expected explicit FAULTED error.
Endpoint 253 and legacy driver 39 checks pass. Weak-gait/idle review passes 5593
checks: inactive cost about .64/.73 microseconds p50/p95; active 60 Hz weak
reaction .188/.240 ms. These CPU figures are not whole-scene FPS measurements.

Recovery now admits a quiet body supported through spine/limbs: at least two
external upward contacts and <=.02 J/kg, retaining torso/limb speed, joint error,
continuous stability and full standing/skin clearance checks. Contacts do not
prove a support polygon. A world-anchored get-up requires support point speed
<=.15 m/s. Lost/moving support or unavailable floor resumes physical falling from
the last displayed pose. Moving-platform-relative get-up is not implemented.
Independent native support suites pass 70 and 665 checks, including a frictionless
3 m/s conveyor, rotated offset COM, and actual floor disappearance mid-getup.

`outputs/coordinator21_vehicle_liveqa/impact_native01/report.json` passes with
stable sources and restored interactive scene. All six viewport captures were
inspected: weak upper-body response, repeated physical fall, intermediate getup,
and upright recovery. This uses TEST_ONLY admitted impulses on the real hero in
the real main scene; it does not establish playable melee or source authority.
Its frame delta samples are engine-smoothed and must not be used as a wall-time
performance benchmark. Final native02 wall-clock p50/p95 in milliseconds:
baseline6.958/7.749, weak6.952/8.055, fall6.954/8.186,
getup6.906/9.665, recovered6.948/7.796. Screenshot readback and the next two
frames are excluded. This is a short one-character/one-car crop test on GTX980
at 1280x720, not combat-crowd or full-city performance. Native02 passes and
restores the sole interactive physics19 game, PID46688.

Actual main E/W driving regression also passes against the same driver:
exit speed5.755 m/s, GETTING_UP1.751s, DONE2.650s, final ON_FOOT grounded and
driver seat released. Evidence: outputs/coordinator21_recovery_final/car_exit_434b.

Final release export is `exports/win64/s01-20260927-physics19b` (notes newline
normalization only after19). Real PCK main plus full TEST_ONLY impact pipeline
pass. A fresh archive of staged tree9c2d42f0 imported without inherited caches
and passed the same actual-main impact pipeline; no untracked runtime dependency
was required. The reusable external harness is tools/godot/test_player_impact_liveqa.gd.
