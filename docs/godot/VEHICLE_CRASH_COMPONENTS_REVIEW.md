# Crash components — frozen, isolated native package

## Worker batch candidate — component accepted, runtime NOT adopted

`scripts/vehicle_physics/vehicle_crash_solver_batch_candidate.gd` initial
SHA4eecdc85b720c4d5f882ca385287867a73214e4c02e7475b04980320948c475e;
test SHA bb5f9b9e41d9ae42963e68fdcc2bbfe376370e2ecaacc3f50eb22df766f71671.
Parent Godot4.7.2 headless1201PASS,20.705s, all13 profiles exact serial
state parity across worker limits1/2/4/8. Complete joined batch CPU includes
snapshot publication:72 states p95 parallel4/8workers16.552/16.423ms,
paired serial56.938/56.192ms;16 states3.067/3.003ms versus8.714/8.878ms.
32 measured batches,4warmups; timing variability and shared-host load apply.
One state is slower with task overhead. NOT FPS/full-city/GPU evidence.

Initial hash above is superseded and must not be adopted. Revised frozen
candidate SHAac553088e34defc70969c79e97d7b92c50231566e0b2c7e25384c97148aea2bd;
test SHA94fd4fd154091b0763b78dc68ede2c4c2455e89851f94dc164432affdb3d50b3.
Author and independent Godot4.7.2 headless1211PASS. Parent source reviewed
main-thread gates, typed/method/runtime admission, unique identity pairs,
main-only cross-executor claims, full-input stale-tick preflight, one-in-flight,
exact task join, poison/no partial publication and reset/retire join+release.
Workers mutate only distinct pure solver/holder references; main publishes
after join. Full serial parity across13 profiles and limits1/2/4/8.

Independent complete batch wall-clock latency (NOT aggregate CPU consumption):
72 states8workers p50/p958.471/10.554ms vs serial34.343/40.324ms;
4workers11.291/14.543ms vs35.311/41.498ms;2workers19.546/21.639ms.
These are isolated32-sample measurements, not loaded-city/frame/FPS proof.
Earlier CPU wording denotes timed caller latency only, not total worker CPU.

API configure(session,capacity<=72,workers1/2/4/8), bind_states(exact solver,
vehicle_id,life_generation rows), begin_step_batch(delta,speed,throttle,tick),
finish_step_batch(exact task id), step_batch synchronous wrapper,
reset_session_wait(new session), retire_wait(), contract(). Binding transfers
exclusive mutation ownership; callers MUST NOT call solver APIs until join.
Explicit retire required before dropping executor or claims intentionally
remain fail-closed. Reset/retire safely construct then discard snapshots.
Shared scalar speed/throttle API is a uniform-input fixture, not sufficient
for heterogeneous real traffic; per-vehicle inputs are the next separate
candidate. Global WorkerThreadPool contention remains unproven.
Production solver3896/bodya382 unchanged; no main/project/thread setting edits.

### Heterogeneous rows — separate candidate, independent review pending

`scripts/vehicle_physics/vehicle_crash_solver_batch_inputs_candidate.gd`
SHA08262b2870ce6662afba1454a76e2afd02d281552de5edf165ca75aad69d5cf9,
test SHA f7591feb9a2aed74d441ea9973fb4876bb342916d77d7bddbba97016e5dfd031.
Extends frozenAC553. Author+independent+parent Godot4.7.2 headless199PASS;13 profiles,
26 sequential heterogeneous batches exact serial parity. Per-vehicle/life
delta/speed/throttle/tick rows fully validated, identity-mapped and copied
before submit. Invalid/missing/duplicate/stale row causes no fleet advance;
caller mutations after begin do not change worker inputs. New public APIs
begin_step_batch_rows/step_batch_rows retain inherited finish/reset/retire.
Size1 synchronous exact step avoids worker scheduling but is not faster than
direct serial: parent64samples p50/p95 fast535/729us, direct516/703us,
group586/808us. Component independently reviewed without blockers; runtime
adoption remains HOLD. Output rows follow bound-slot order, not input order.
Additional independent+parent27PASS actual distinct per-state tick regression:
scripts/tests/test_vehicle_crash_solver_batch_inputs_ticks.gd
SHAc15d95f2d10be2c0bef2ace170e69e22d94b97eaed0cb80145e7a335b461b325.
Two reversed-input batches at ticks2/7/3 then6/8/11 match exact serial states;
one stale row rejects all states without advance or in-flight job.

Transport3 reported rejected74e5 full-surface deformation uses the SAME global
WorkerThreadPool and same-frame join; strong compact436044vertices/68changed
surfaces cost34–38ms independently. It is NOT adopted. Combined solver+
deformation same-event latency is now covered by isolated stress below;
separate speedups cannot establish combined frame budget. Exact local-dent
candidate/fixture dependency pending.

### Combined pool contention — rejected full-surface path

`outputs/test_vehicle_transport_worker_contention.gd`
SHA4d66b50599d76e7dd30582f5fe9fb6711dc32b150501d459a37344c41c2531f5.
Independent two runs plus parent Godot4.7.2 headless17PASS (<9s).
Exact current rejected deformation74e5f0f2d1973674d497edfec89803b61270eed93d700d3527185b95339e7ddd,
testa3e4a5c292ce9aec08965bbec091167b2f78bba5fa06ceffa0e056cf47dfa982,
deformationoracleccd5b46084439ca3aaa12c7d23b94cfdc9b979bd81eed0edd80ac7a9fc7f69e7,
damageoracle8643b118/manifest38598/actual compact f2b7d7884d48 bytes.
Actual121candidate/68changed/436044vertices geometry digest
694547d017ae93ed6c769256d441fe27d76d1ad8d211bd9a58effdf27a44dd63
unchanged by contention. Native72 states/8workers/delta.1=24source substeps
each matched serial full states, actually in flight across deformation apply.

Independent isolated deformation36.974/38.500ms becomes51.948/48.258ms;
join5.170/9.191ms, combined57.421/57.761ms. Parent baseline34.152ms,
contended38.331ms+join9.406ms, combined47.955ms. These three observations
show a material pool contention/tail; NOT statistical p95, observed LIVE
scheduling, FPS or aggregate CPU. Stress delta.1 differs from earlier60Hz
fleet perf; do not compare as identical workload. Full-surface path remains
rejected; repeat combined runner against new frozen local-dent candidate.

60Hz follow-up NEW outputs/test_vehicle_transport_worker_contention_60hz.gd
SHA4739e836475b9bb7ca80b65ff6c7379333868f2d9e1be4205dc1477600e8445e,
independent two runs+parent78PASS, <11s,8 reset/rearm samples each.
Exact same geometry digest/counts and native72 serial parity at delta1/60,
4source substeps/state. Parent combinedwall p50/max39.776/42.955ms;
baseline deformation34.973/40.224ms, concurrent36.764/39.709ms,
finish/publication2.640/2.918ms. Independent combined p50/max34.742/41.718
and39.422/41.471ms. With8samples reported empiricalp95 equals max; not
robust statisticalp95/significance. Native starts in flight8/8 and completes
before deformation returns8/8: dominant tail is rejected full-surface
deformation, no proof of material60Hz slowdown versus isolated baseline.
Preparation/rearm/geometry digest/reference are outside timed region; noFPS.

Machine-readable frozen candidate API/ownership manifest:
docs/godot/VEHICLE_CRASH_BATCH_CANDIDATES_MANIFEST.json
SHAd62ceddb513db6948e9cbd4a07c33642ae9411682d9e43a1a0b87e301325f45d.
This pins original .1stress separately;60Hz follow-up is additive evidence.

Transport3 local-dent functional883a4559323649b21315098ae4f6324566e9302bb25a8110a1b8c7dd7c93459e
and real-source oracle790b7d5e93ddd2cc50db20010012fa786df65ad5dbef5df02910b44f35041059
are PERFORMANCE REJECTED too. Read exact TRANSPORT_LOCAL_DENT_MANIFEST.json
and HANDOFF.md: main-thread pure buffers/no workers, preparedv0163 25752
vertices stage+commit p9516–22ms,90000 all-inside >100ms, excludes normals/
bounds/upload/hulls. Pass-fusion replacement pending; do not benchmark this as
adopted or attribute its cost to worker contention. Re-test combined scheduling
only with qualified future candidate and exact source input.

Root21 owns main, one LIVE game, adoption and Git. Production body remains
a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401.
Transport3 owns visible deformation/debris. These modules do not apply HP,
create explosion events, mutate vehicle motion or provide server authority.

## Solver — independently reviewed

scripts/vehicle_physics/vehicle_crash_solver.gd
SHA3896afa6c14845c84835f1fd8221d1b0927947d716008cc2e6422991afc01129.
test_vehicle_crash_solver.gd
SHA615c0d605e4bd6ef6cdd28676203c058e7c57dfa489d2f4cdf70067b3ced142f.
All script paths are inside godot/mafiozi_walk; tests inside scripts/tests.

Independent Godot4.7.2 headless7020PASS plus parent rerun. Actual Node oracle
7866034066574af841c2f6bdf4c9b6a43cbcb3e8782acac2678471f296e97d0a.
Pinned visual manifest38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03.
Trusted caller verifies the file SHA and supplies exact post-factory
entries[profile_id].nodes[*].source_metadata.vehicleProfile. Passing a hash
string alone is NOT authentication. All13 admitted; six missing rear mounts
use exact source logical fallback, never fake physical panels.

API: configure(vehicle_id,life_generation,profile_id,manifest_sha,profile);
apply_impact_native(contact); step(delta,speed,throttle,physics_tick);
sample_deformation_native(point); deformation_snapshot_native();
mechanical_snapshot(); snapshot_source() (cold diagnostic).
Contact requires vehicle/life, native-LOCAL point/normal, impact_speed_mps,
nonnegative nondecreasing physics_tick, strictly increasing impact_sequence.
Optional event_id is bounded diagnostic dedup, not replay authority.
Step tick is independently strict. State has45nodes/232beams, source plastic
impact/parts/wheels/thermal mechanics and bounded240Hz settling (dt≤.1,
≤24steps). All damage and detachment results are proposals only.

deformation_snapshot_native copies two45-node PackedVector3Array plus identity
and structural revision. mechanical_snapshot copies scalar/wheel state; source
thermal changes may occur without structural revision/changed. Read it
independently, not only on revision changes. Do not deep-snapshot232 beams
every render tick. Native performance is UNQUALIFIED: embedded16 samples are
smoke only. Separate test_vehicle_crash_solver_perf.gd SHA
ae786dbd7f37c4b84778649b070fde8c464806cefca91f9206223f960bb365d5
passes3664:32warm+240active/idle samples per120/60/30Hz, rearm/config outside
timedcall. Author single-car60Hz p50/p95/p99/max432/561/641/691us, idle3us.
120Hz220/264/347/428us;30Hz860/1086/1601/2858us. These are native raw call
costs on i9-10900F, not FPS/GPU/full-fleet. Thermal accessor after actual
radiator/engine evolution matches Node while structural revision stays stable.

Fleet test_vehicle_crash_solver_fleet_perf.gd SHA
c8a9d20417da8ff981e05e367fea4e73c4e74b2fbdb5223db5e892d23212e795
passes776;32warm+96independent measured batches/case, runtime25.293s. Requested
240-sample calibration exceeded53s and was rejected under<30s run constraint.
60Hz batch p50/p95/p99/max:16active7.604/9.267/13.597/13.597ms;
72active34.935/40.983/44.496/44.496ms. Exact source-settled damaged16
0.074/0.133/0.182/0.182ms,72 0.349/0.470/0.505/0.505ms. Active batch72
exceeds16.667ms reference; this is a confirmed rawCPU scalability bottleneck,
not fullsceneFPS. Do not label mass-crash handling optimized/lag-free.
Separate hot-loop caching candidate underway; frozen3896 remains unchanged.

Cached candidate311ace8beec43bdcb98c106574b5a94bf26d63c4a72a8e13dd84809b905d755d
is REJECTED for adoption. Author testb0a70e2787002b13e4e7a91963578bf84eaa559e52232d63f1bfd4293e49a458
passes1345; independent exactmath runner5d08b5f905f2bb14992bcbeec73b2a0159bfa32a37af9a9a489d1020ba306bf8
passes138/1,322,086 recursive comparisons with0mismatches across13 profiles.
But paired72-active CPU batch p50/p95 regresses:base32.352/34.779ms versus
cached34.607/35.895ms. Do not report a speedup. Base3896 remains unchanged.
Next isolated prototype uses native WorkerThreadPool on independently owned
pure CPU states; thread-safety, lifecycle/join guards, exact math and native
cost must pass before any adoption. No reduced timestep or content deletion.

## Direct contact bridge — component verified, unwired

vehicle_contact_state_bridge.gd SHA73843ce758381b7911aa432ade0e66cfb9ea96ebd05986f0e9f39bc64a1de1a7.
test_vehicle_contact_state_bridge.gd SHA123a641a89e3b9d9e9e63348e75e821c3bf3243e3285480ca8dca97aa123c30a.
Parent81PASS. collect(direct_state,self_ref,global_tick,body_frame,COM_world)
returns directed proposals; accept ONLY valid&&complete. GAP collections are
not complete damage evidence. Bounded8points/8counterparts/8cached identities;
self-pair rejection, changed metadata failclosed, explicit lifetime reset.

Dependencies: manifolddfe706e678fd64a6ac2d67f27bd659733287ff9aba6e62c6b9343889ba3ed9dd;
identityeb6ad8ba8b5bf1a14fb1a1a75cbbee8b25f09145909dd448f2ba97a2e6bec256.
Actual rotated wall and peer each311points/87ticks, maximum4. New cap stress
test_vehicle_contact_state_bridge_cap_stress.gd SHA
551611d3eb65dbdab030540e1a67b2683f98740feef2dcffd1a1e4e0ae74d890
passes13:actual8 source-tagged statics produce8points on120ticks, explicit cap
GAP/complete=false everytick, no identity/manifold gap. Parent rerun hotcache
p50/p9513.73/16.53us and syntheticcold40.22/47.42us per8-identitytick,
240warmticks/128blocks; isolatedcache cost, not fullcontact/FPS.
Cold wire identity separate from engine lookup IDs.
Godot contact_local_position/normal already WORLD: do not transform twice.
Zero-J onset retains paired-point closing speed; impulse chronology is only
contact_api_observation_only, not a full pre/post-solver conserving sample.
No full J/m, energy, fleet canonicalization, ledger/rearm or authority claim.
Runtime wiring/impact event sequencing/dedup belongs to explicit future adapter.

## Other isolated components

Tyre emitterd8a8cc7cfc5d4b412d9afcbbea3cd48ab2db459b485d0147a3e01909ff97b4ae
passes38;1200 segments/10s, source geometry/color/fade. Same-tick wheel contact
points and trusted surface metadata required; unwired, GPU acceptance OPEN.
Blast proposal dfbf96e7d0d4ea83c048d362494a048560b7d04258008a9531f6a6ad022d5656
supersedesd5df/8d45; test6427a1f9a986d059a5caaadc86a502b361f25ebe587e8044989b4916c0973349
passes54author+independent; no component blocker. Sibling/caller replay keys
are deep-copy isolated. Supports none/external/vehicle
sources; excludes exact vehicleID+life rather than ID alone. Explicit pure
proposal_only/server_admissible=false, caller dedupe event+targetlife. Raw
HP+rollover-contact only, never generic body impulse. Caller owns confirmed
event/cover/exclusions; source event≤250chars supports exact blast:prefix≤256.

## Remaining adoption work

Root actual-main/oneLIVE integration and cost; Transport3 visible mesh binding,
real detached assemblies/physical debris; contact ledger/canonical pair and
source event authority; authoritative HP/fire/occupant damage; GPU appearance.
No visible damage, explosion or FPS outcome is claimed by these headless tests.
