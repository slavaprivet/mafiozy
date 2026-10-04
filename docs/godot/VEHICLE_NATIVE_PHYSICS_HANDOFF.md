# Native vehicle physics — isolated package

## Actual source-map tyre-contact fixture — 30 September

`test_vehicle_tyre_tracks_source_map.gd` SHA-256
`39c950c7eeb9f54f726fb35abd95f59c83dff3fa533eae8e92a5ea25e9680b10`
loads the actual preview `block.json` and transport descriptors. It spawns the
city hatchback at the exact source parking ID
`parking:REBUILD-VISUAL-old_town_narrow_townhouse_v1-004:bay:0`, reconstructs
the solid source palette strips with their `vehicle_surface_id`, and attaches
the frozen host as a world sibling. Actual Godot 4.7.2 headless: 12/12 PASS,
25 road skid segments, four road contacts, no teardown leak. Source inputs:
block SHA `1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e`,
descriptors SHA `99d328bc4a581bc65815498b265ae5eec71a25b831512b15d376e1c0f5ac031a`.

Important real-source finding: the actual parking bay is **grass**, not road.
The fixture first verifies no fabricated road mark at that bay, then moves the
same physical car to source road tile row 21/column 25 and checks the four
native contacts before driving/skidding. Therefore startup at the bay should
not paint tracks; road entry should. The test does not prove the visual game
will emit marks, because current `main.gd` terrain colliders still lack this
palette metadata and the host is not attached in preview transport. Those are
Root23/transport integration seams; rendered culling/draw calls and comparable
loaded performance remain unverified. HOLD / NOT INTEGRATED.

## Tyre-track host lifecycle candidate — 30 September

`vehicle_tyre_tracks_host_candidate.gd` SHA-256
`35b4abd9c7e96abda10de4bbdf384430249673b2384b828db2e88a11c995b578`
is an isolated world-sibling host for one native body. It configures the
12-page track pool once, reuses the four original wheel rays via the fast
contact adapter, steps once per published physics tick (including empty rows
to age marks), uses planar speed, and disposes on body loss/life mismatch or
track failure. Render pool is `top_level` to keep mark poses in world space.
`test_vehicle_tyre_tracks_host_candidate.gd` SHA-256
`a55265a487e4b966ff3c9ef5134494b37b505c853000fc56e1cc143ee20a5883`
passed actual Godot 4.7.2 headless twice: 11 checks each; 123 skid segments
for the compact sedan and 105 for the **actual preview city hatchback** on a
road-tagged floor, world-space frame and body teardown cleanup. The host now
also queues itself for deletion when its car vanishes or its life changes; an
inert empty host cannot accumulate after respawns.
The host reads the already-published native tick/velocity fields directly
instead of allocating a full snapshot with duplicated arrays each frame;
the fixture checks their parity with `snapshot_state()`. This is a targeted
allocation reduction, not a measured whole-scene speedup, and binds the host
to the AE4D body-field contract.
An initial test caught a real freed-body early-return leak; it was fixed before
this hash. This is component lifecycle, not main/LIVE visual/performance proof.
Root still must tag actual terrain collider palette kinds and attach one host
beside the preview car, then run culling/draw-call/visual and comparable loaded
CPU/GPU gates. Candidate is HOLD / NOT INTEGRATED.

## Rounded full-width bumper experiment rejected — 30 September

`vehicle_runover_rounded_bumper_variant.gd` SHA-256
`2cf1afdfd93297b708d9f3cd1537f225756d5945c0076cec4daf4d0a59856b52`
replaces each wedge with a narrow physical cylinder at the same visible nose
and rear extents, retaining all ten underbody/cabin/wheel shapes. Harness
`test_vehicle_runover_sedan_visual_variant.gd` current SHA-256
`0dccd30a75ce15588e91e6430a265d62b283543550c45f8dcab63173739e3bd7`
accepts `--rounded`; actual Godot 4.7.2 headless exit 1: 17492 checks,
one overrun failure, rig1 joint error .619m, long car-contact runs
4.93/1.97/5.55s. It is **worse** than the full wedge. HOLD / NOT INTEGRATED.
The previous slick-bumper harness hash below is a historical exact revision;
the current harness includes both `--slick` and `--rounded` modes.

## Full bumper + friction-zero runover experiment rejected — 30 September

Isolated `vehicle_runover_slick_bumper_variant.gd` SHA-256
`00aa51551b2a09de1d247e27f13ea2ec80cc2ec14953332f60224cedd2778916`
keeps the real full-width wheel, body and wedge-bumper colliders but sets the
car-body PhysicsMaterial friction to zero. Updated test harness
`test_vehicle_runover_sedan_visual_variant.gd` SHA-256
`09f485b42aaa21a8fc1ae9923732842b1f949cd1e5ae3982a8ed68f69edc417e`
accepts `--slick`; actual Godot 4.7.2 headless returned exit 1, 18206 checks,
one capsule/joint overrun failure. Three original NPCs all physically contacted;
their longest sustained car-contact runs were 2.73/3.57/3.57 s, with the second
rig reaching .239 m joint error above the .20 m acceptance bound. Thus reducing
friction alone does not solve bumper dragging. **HOLD / NOT INTEGRATED.** No
NPC collision was filtered and no main/LIVE/Git file was changed.

## Tyre marks: physical contact adapter, not yet LIVE — 30 September

`scripts/vehicle_physics/vehicle_tyre_contact_provider.gd` SHA-256
`cadae1e18cf94c5b95f046f96f79306f40c7d6b72ce3babb55207fe83f1b013d`
adapts the existing four native suspension rays to the tyre-track input schema.
It rejects stale ticks, mismatched life/ID, invalid contact geometry and non-track
surfaces; it adds no raycasts or nodes. Independent physical sedan test
`test_vehicle_tyre_contact_provider.gd` SHA-256
`3d6469031add17b413a77d740c6eec2113dbc52bcbc3fbf0faa0b029f2eecf2f`
passed actual Godot 4.7.2 headless: 642 checks, 170 road contacts, 90 slipping
ticks, 124 paged-candidate track segments. This is component evidence, not a
rendered-game or FPS result.

Lower-allocation twin `vehicle_tyre_contact_provider_fast_candidate.gd` SHA-256
`623bc7bedeafec4f64f78ec82e318d00802ef70e002171302b1c30538a425a53`
reads the AE4D body's existing four published ray/array fields directly,
without extra casts, state-array copies or wheel dictionaries. It matched all
180 live drive/skid ticks plus stale-tick and changed-surface negatives in the
same headless test. Alternating-order 1000-call warm microbench: public adapter
26.5/27.7 us, fast candidate 7.4/7.4 us per call. This is *not* whole-scene FPS
and tightly couples to AE4D private field names; revalidate after body changes.
Prefer the fast candidate for future integration only after the root seam and
visual/performance gates below.

**Root seam / HOLD:** `scripts/main.gd` solid-terrain strip construction around
lines 665–674 does not set `vehicle_surface_id`; native wheels therefore publish
`default` there and the adapter emits no marks in the real scene. Root23 owns
main: add the source palette kind as collision-body metadata, then verify skid
marks in the sole LIVE game and GPU appearance/draw-call/culling cost of the
12-page candidate. Do not call tracks integrated before that acceptance.

For future root/transport wiring, `preview_transport.gd` creates the native body
under itself at setup ~101 and already reads `body.snapshot_state()` per physics
tick around ~398. A tyre-track emitter must be a **sibling** of that moving body
(world-space transforms), configured with the current `vehicle_id`/life once,
then given at most one `collect_into(body, state.physics_tick, reusable_rows)`
and `tracks.step(delta, state.physics_tick, planar_speed, reusable_rows)` per
fresh tick. Clear/dispose it on the existing vehicle teardown/life transition;
never mount it under the car or accept contacts from an old generation. When
no skid contacts exist, still step with an empty array so old marks age out.
This is a seam description only; neither root-owned main nor transport-owned
preview_transport has been changed by this package.

## Current production and contact proposal — 29 September

Coordinator23 now owns main/export/LIVE/Git; Coordinator22's following LIVE
receipts are historical. The shared `vehicle_native_body.gd` is now
AE4D (`ae4d67e7f931e33e3cf65404af665579498986cb307418a45989dba5e0dfe5d5`):
the frozen braking candidate was adopted by root22 and passed its headless
regressions. Root22 subsequently reported actual after-PCK braking22 LIVE PASS:
physical W+Space brake end 3.001 m/s baseline to 0.039 m/s after, moving exit,
ragdoll/getup and driver release PASS. Those PID references are historical;
root22 alone owns the current game process. The braking comparison used the
small 8-building/1-car/0-NPC scene, NOT full-city FPS; see
`VEHICLE_BRAKING_22_INTEGRATION.md`. A382 references below are historical
baselines, not current production. Keep shared body frozen under root22.

New separate, unconnected packed raw-contact proposal:
`scripts/vehicle_physics/vehicle_contact_packed_observation.gd`
SHA `37e8552943e256a25f42c494048a346eeecb0ca73c5dd8bde34bb37bab681ec`.
Author test `test_vehicle_contact_packed_observation.gd` SHA
`44e7337e1b47cdd6a0755970ee381c7f7c4adf9763a08986ccb4cbe655af933f`
and independent test `test_vehicle_contact_packed_observation_independent.gd`
SHA `b129ec7ed45030b5c182ff9ccb7ce7dc24da86ddac8ef6a8150697695662315c`
were rerun by parent on actual Godot 4.7.2: 13+21 checks, zero failures.
The reusable fixed-eight packed buffer preserves the frozen D149 collector's
decoded rows, callback frame, identity gaps and conservative cap envelope.
Consumers must gate `valid && complete` and read only
`[0, retained_contact_count)`; public arrays retain unused/stale slots after
a shorter or invalid collect. `decode_legacy()` is guarded and detached.
The author test reports wall/cap callback p95 frozen/packed 68/31us and
109/56us, but it runs frozen first and excludes packed decode. Follow-up
alternating-order/decode-inclusive test
`test_vehicle_contact_packed_cost_order.gd` SHA
`e33c7478359590a69201cf54ebd7c6971a85b935333a4a017b77e15c914c4744`
passed actual Godot twice with zero decoded parity mismatches (123 wall ticks,
100 cap ticks/800 rows each run). At cap, p50 frozen first/second 105/94–96us;
packed raw first/second 60/51–52us, but packed **decode** adds 43–46us when
second, and packed first+decode totals 107–108us. This is no persuasive
end-to-end win over D149 at eight contacts; staging/consumer design must avoid
dictionary decoding to benefit. It is still not FPS, aggregate CPU, or an
allocation-count claim. Baseline D149 and live contact/damage/authority paths
remain unchanged; no performance adoption recommended yet.

### Onset observation proposal, still HOLD

Additive `scripts/vehicle_physics/vehicle_contact_onset_proposal.gd` SHA
`7511613d55648d1ba6004056739fa59f7ab4febe07cea549da58141dd509ecf5`
consumes only raw packed slots, returns at most one detached observational row
per target tick and allocates no output on idle ticks. Author test
`test_vehicle_contact_onset_proposal.gd` SHA
`81f297ad89a0bf32650887b9a210b229684cf5557138f5355ca88202f3d36824`
and independent test SHA
`ca2280260a9f821587b54809c10745edd58b3e06e898b0d398c8d4844eb1116d`
passed parent rerun on actual Godot 4.7.2: 30+9 checks, zero failures.
Independent review first caught a real 2.1→3.0 m/s continuous-contact loss
in the original BA28 candidate (independent 8/9 FAILED). The revised 7511
allows separate observational crossings of damage-rounding ~2.4502 m/s and
structural 2.5 m/s, without claiming source event or HP authority. Exact
same-row zero-impulse onset/rotated frame, lifetime, cap fail-closed and stale
slots covered. It is not an exact source damage adapter: passive source uses
linear-only speed, peer uses canonical directed delta-V, slide-speed-only
damage is absent, static obstacle role and global tick are unauthenticated.
No collision cooldown, pair canonicalization, event ID, HP or crash dispatch.
Producer+selector wall path was slower than D149+simple reference peak in
isolated ordered fixture (parent wall p50/p95 41/95us vs26/58us); reference
does not implement equivalent latch and this is not FPS. **No runtime wiring**
or performance adoption recommended. Original BA28 is superseded by 7511.

### Tyre-track aging performance proposal, not yet GPU accepted

The source-exact unconnected tyre marks component `vehicle_tyre_tracks.gd`
remains SHA `d8a8cc7cfc5d4b412d9afcbbea3cd48ab2db459b485d0147a3e01909ff97b4ae`.
Its 1200-active, single-vehicle headless `step` measured p50/p95 341/534us
before this experiment; it uploaded alpha for every live mark each tick.
Additive subclass `scripts/vehicle_physics/vehicle_tyre_tracks_age_candidate.gd`
SHA `e574289839b8d8e8575ba7b3940b0acac027a8ba28d3a917d4453b742899313c`
uses one shader-clock uniform and per-instance birth/strength, retiring expired
marks through bounded FIFO; no segment cap, lifespan, fade law, shape, colour,
surface, spacing or slip threshold is reduced. Author test SHA
`53e922bc38c5a109f9a09fd049a42fc8105852c2189c6a4b85390d4a8c40df26`
and independent test SHA
`04a3c475f1548a5da4c33e6d963db7c79d68241f5698fa9e885cb31c2bffaaeb`
passed parent actual Godot 4.7.2 reruns: 1247+1317 checks, zero failures.
These cover full-ring overwrite, partial expiry, 32s clock wrap, no ghost
reappearance, separate materials and clear/dispose. Alternating-order headless
1200-active idle p50 was frozen334us vs candidate4us; adding one mark at cap
frozen344us vs candidate13us (parent rerun). These are **CPU step only**, not
GPU appearance, render cost, four-wheel provider, full vehicle step or FPS.
Read-only culling audit confirms the inherited AABB grows forever and
`visible_instance_count` stays 1200 even when every mark expired: fragment
discard cannot avoid vertex/instance work. E574 therefore remains **HOLD** under
the no-lag gate despite its CPU gain. A separate proposed 12×100 temporal-page
renderer can retain all source marks while bounding each draw to 100 slots,
using per-page live bounds and visible prefix accounting for sparse high slots;
GPU cost still requires measurement. Next admission needs trusted world-wheel contacts, a world-sibling
emitter, GPU alpha/overdraw/culling and a whole-path comparable LIVE check by
root22. Original component and runtime stay unchanged.

The paged version now exists as an isolated frozen component:
`scripts/vehicle_physics/vehicle_tyre_tracks_paged_candidate.gd` SHA
`3d3e98e53fccde408719ea6325099a9adcbf1762642207b70af3090fbc6ec3ce`,
with actual Godot test `scripts/tests/test_vehicle_tyre_tracks_paged_candidate.gd`
SHA `708b87dd81e6bd972a03093931ad81ff64cf946cba1e557c6a8301f8508d3b7e`.
Parent rerun 16322 checks/exit0 preserved the 1200 source slots, 10s fade,
geometry and dense/sparse page prefix behavior. Twelve independently culled
MultiMesh pages of 100 slots bound local AABBs instead of the older ever-growing
single AABB. Alternating-order 1200-active headless CPU step p50 measured
frozen~341us vs paged~4us idle, frozen~350us vs paged~32us one new mark.
These are per-component CPU only, not GPU/drawcalls/FPS; 12 page draws and
shader appearance need Root23 GPU admission. No runtime hookup exists. Root23
now owns the next LIVE decision; the earlier root22 sentence is historical.

### Car-to-NPC underbody acceptance, urgent HOLD

30 September isolated follow-up: `vehicle_runover_tunnel_variant.gd` SHA
`9713dfeb92bee6c100274aabf57eb9f024dd8fee4a91844f02fb73c6af7166b8`
adds a raised central hull, two low sills and four rigid wheel spheres without
changing suspension rays or filtering NPC contacts. The actual three-rig host
wrapper (`test_vehicle_runover_tunnel_variant.gd` SHA
`f56cdc69fe7c4f1780fb8b2d1f56ab2ac003d5999ad96f25b14e4ed684d4297d`)
passes 6061 headless checks: 17 shape-owner-proven NPC wheel contacts, final
chassis contacts zero for each rig, joint error <=0.1335m and floor intrusion
<=0.0672m. Paired flat-floor drive/sweep fixture also exits zero. These are
isolated physical tests, not visual, GPU, full-city, source damage or LIVE
acceptance. The paired drive test currently logs two ObjectDB/one resource
leak warnings at process exit despite test pass; investigate cleanup.

Independent review found a real false-open: an NPC on collision layer256
blocked the physical hull at cast fraction 0.34765625, but compound
`body_sweep()` using only car mask1 returned 1.0. Isolated parent candidate
`vehicle_runover_shape_candidate.gd` SHA
`dff47abc6ee59fa38c4a00fbb386a02078900e07aaad9414830bcb00eafe0689`
now queries car mask|256, while suspension rays retain mask1. The independent
regression `test_vehicle_runover_sweep_independent.gd` SHA
`a5b1d84fd83f2facfd033b50315c63e3f10ee05140759e487934028b00b6e621`
now expects the blocking fraction; parent Godot4.7.2 reran sweep, paired drive
and 6061-rig checks at exit0. This only fixes the known ragdoll channel, not
arbitrary reverse-mask physics peers.

Read-only GLB geometry audit: source compact-sedan LowerBody center bottom
is y~0.341m and original authored collision extends to y~0; the candidate
physical center begins y~0.640m. The bundled current visual omits center
LowerBody/floor triangles in the inspected central band, so visible floor
penetration is not established for that emitted LOD. However, the proposed
side hull/sills extend x~1.03-1.19m versus visible sill x~0.83-0.94m, a
9-25cm invisible lateral blocker. Need targeted visual silhouette, curb and
vehicle-peer handling, lifetime/authority and whole-path cost before any
production/root integration. Candidate remains **HOLD**, no LIVE claim.

30 September compact sedan refinement remains **HOLD**:
`vehicle_runover_sedan_visual_variant.gd` SHA
`ffb9d27a8fd145a2008ffd0b136fa0c292258c6c109cc0b6fe4e6ef6c4017673`
uses a narrower x~0.9405m hull and sill plus axle-oriented 0.18m-width wheel
cylinders, rather than balls. Parent actual Godot reran the three real rigs
at 6068 checks/exit0: no persistent contact, 6 genuine wheel-cylinder
contacts across 2/3 rigs; the third centerline rig did not contact a wheel.
Per-rig no-snag/floor/joint checks remain. Paired flat-floor driving `--visual`
exits0: grounded15, 7.700m/s acceleration vs production7.700, braking0.041
vs0.083m/s, steering yaw difference ~0.0068rad. Not full-city handling.
Isolated alternating ABBA 2x180 tick cost test
`test_vehicle_runover_sedan_shape_cost.gd` SHA
`10a57a64e3d5d4a231c113e5b43d0af56a607dd4b66865a5ebca66fc2781a755`
exit0: candidate 7 physical shapes vs production1, frame wall p50 idle
165-166 vs154-155us and powered 167-168 vs146-151us. This is a 10-22us/car
isolated overhead, **not city FPS**. Its purported resting cars were actually
awake. Test harness process exit still reports two ObjectDB/one resource leak,
with verbose pointing at `vehicle_profile.gd`; investigate separately.

Independent GLB check rejected visual parity despite passing hardcoded width
assertions: actual emitted door skins extend x~0.9205 at y~0.33-0.89 and sill
x~0.9405 only near y~0.20-0.33, while candidate hull occupies x~0.9405 all
the way to roof. Candidate z endpoints +/-2.4542 exceed emitted visible
front/rear +/-2.29044/2.32254 by ~0.16/0.13m. Exterior body extrema by
y tier: [0.64,.9) x+/-.940801 z[-2.200440,+2.165800]; [.9,1.3)
x+/-.933 z[-2.176003,+2.132300]; [1.3,1.97) x+/-.893094
z[-.960,+1.405]. Shape must be derived or checked against emitted mesh by
vertical/longitudinal band, not assert the same constants in fixture.
No production adoption or LIVE claim.

Follow-up mesh-envelope experiment is also **HOLD**. The emitted GLB has
low bumper skins y~0.15-0.32m at z~-2.29/+2.32m; without collider, an actual
0.2m curb shape-cast first hits the tire ~0.5m after the visible bumper.
Adding bounded low bumper boxes made all three real NPCs remain in contact
~3-4s and dragged them ~50m under continuing throttle. A sloped wedge
`vehicle_runover_mesh_envelope_variant.gd` SHA
`8da8a4604179bd50d0bd3c00946c110b9fdd06d3a1b9f727eaa915a28b63af1c`
also failed actual 3-rig acceptance: a joint stretched to 0.302m and one
corpse failed separation. This is not an acceptable bumper fix, despite
curb/peer smoke tests passing. Newer mutable file hashes supersede the
quoted experiment; inspect exact outputs before reuse.

Independent bounded trace `test_vehicle_mesh_npc_spike_trace.gd` SHA
`e41a8f44265f41a90f1d4949a40bddc51573a49d96ff873764aa30fc43b52569`
found the no-bumper 31m/s peak is a ~0.52kg hand whipping through ragdoll
joints around ticks43-44, while car speed is ~7.2m/s and core/NPC total KE
~2242J; it is not the entire 75kg NPC travelling at 31m/s. The bumper box
instead continuously pushes torso/other parts to >20m/s over >200 ticks,
accumulating ~15kJ, a worse gameplay/physics failure. AE4D actual auto
inertia was measured `(3081.644,3271.155,1052.472)` kg*m²; original explicit
box formula missed +81.204 on X/Z because it omitted the COM parallel-axis
term. A corrected TEST_ONLY fixture matched production inertia but distal hand
peaks remained 30.4/31.1m/s. Do not clamp an isolated hand to hide a solver
issue or filter NPC collision. The next safe step requires coordinated Artist23
ragdoll joint/impact response and matching bumper/underbody contact design,
with exact pose/floor/no-snag/silhouette and bounded cost admission. Root23
owns subsequent LIVE; no production, GPU, HP or damage authority here.
The current `scripts/npc_visual/npc_body.gd` binds each Generic6DOF linear
axis with restitution 0.8 and softness 1.0; this is an Artist-owned factor
to measure in a controlled variant, not a proven cause and not permission for
Physics to edit NPC runtime. Preserve pose/floor and source life behavior.

Artist22's actual production `compact_sedan` + three cached 16-body ragdolls,
flat 1000m floor reproducer `scripts/tests/test_npc_ragdoll_host.gd` SHA
`0b785e2fdf0cf905e53940a0f8a13f7cd9668473ff1cd150bed7144739eb2e4e`
was rerun by physics owner headless with `--vehicle-acceptance`: intentional
exit1, nine acceptance failures. After 480 ticks/8s, each rig retains chassis
contacts (13/15/16 in pinned receipt), contact for ~7.6s, wheel contacts zero.
The current AE4D car has one flat chassis box with compact-sedan native
clearance ~0.1815m and four `RayCast3D` suspension probes, **no rigid wheel
collision shapes**. In this exact fixture the ragdoll layer256 is outside the
ray mask1, so rays do **not** treat these capsules as road; the general ray
support guard still requires review for other collider layers. No NPC collision filtering, deleted limbs,
faked wheel classification or full-game pass is acceptable. A separate shape
candidate must pass this exact rig fixture plus equilibrium/steering/braking.

Additive `vehicle_npc_contact_receipt.gd` SHA
`eb2685362d6cb1da913ced06a4e727087ebd78d448c4954a539fc81ce75b8de0`
author physical fixture 10PASS captures same-callback chassis point/normal,
speeds/mass and J without reapplying J. Independent test SHA
`59030819a31a57dbc18fcf96a1b9a13d694c0e369972c59fc977bedcea679b47`
found a blocking cross-body state spoof: direct state from car A plus car B
is accepted and labelled B (expected red, exit1). No public direct-state self
RID exists in the audited Godot API; root owner callback and external current
vehicle/NPC life tokens are required. First impact callback J=0, later J>0,
so this receipt cannot own source speed/event/HP or a second impulse. It is
**not safe for authoritative runtime wiring**. Artist23 owns ragdoll physics,
root23 owns main/LIVE/Git, this lane owns candidate vehicle geometry and
physical tests only.

## Current handoff, 27 September

Completed additive source-only component: polygonVehicleContact and passive
contactKinematics from pinned vehicle_contact.mjs668e776961d474e6a2bceb62f6435027b859f926b819c0f77da5f4bb0afd4020.
Purpose is exact support-on-car planar point/source passive speed transcript,
not replacement for native collision or confirmation of source obstacle roles.
Author completed geometry9cdc97825a072b14410b75e1dd3813aef6855e1e380b1a4f7c89ece36636fc9c;
Node exporterd0cf925313d193a90b801ef344504305e83c9ceec83741d59e147f1b7de33d26;
test28a5939e37e36ce457e47f2a6dee1b757875b58fa5f31577d1d3d63602b774a8.
Author+parent10347PASS/275actualJScases/3788numericcomparisons.
Independent review accepted: new test_vehicle_contact_geometry_source_independent.gd
SHAd156c68403b3aaa522d11a7b076558316b076c07119e4464bbc8b6f2dd5a7781,
982PASS/192rotatedcases. Parent isolated wall-latency p95242.414us/call;
notFPS/fullcity/per-frame admission. No native response/raycast/event/HP.
Wrapper valid is input shape only, not convexity, source obstacle role,
finite output at extreme finite coordinates, or authoritative contact.
Source result may be null/nonfinite; consumer must inspect before use.
Root released GPU measurement window after melee20/solegame35668; CPU/headless
work allowed again, no GPU launches without agreement. Orphaned9680/48792
were cleared by exact test command line; no game/editor processes touched.
Consolidated source/raw evidence manifest VEHICLE_CONTACT_SOURCE_COMPONENTS_MANIFEST.json
SHA5dd119401960587c0357dbc63858de3d0cd7ad56e216c76fefc4577802cd8fd6
pins16files, runtimeNOTADOPTED. Identity-cache candidate REJECTED:
vehicle_contact_observation_collector_cached_candidate.gd
SHA1f9d47d3a28f3e58a9ded61613e901fdea2b0f8e3e9f67974ae5d50f9daea2c2;
testea6e190d69f9d851a8fd1dd02adeeda6aaef57e8358102a11c4c844721046169.
Actual functional parity0 mismatches/lifecycle/gaps/isolation preserved but
author p50base/candidate127/129us,134/134us and p95209/217,195/216us.
Independent126/128,195/196us then noise107/106,178/177us: no repeatable gain.
Official mixed functional/perf exit is nondeterministic; green rerun is NOT
adoption. FrozenD149 preferred unchanged. Next separate redundant intermediate
copy-elision experiment only; preserve final sibling/caller copy isolation.
No contact filtering/deletion; performance qualification separate from PASS.

Minimal copy-elision NEW candidate3f292a9a83bd5adc529d279e07b3467af2a033d7b8db7c122472f55bbb437074
testcc20bd016716a349f6eb8aac88b563d9aae05b3b0a71909fd252648a0dd92bf5
author2runs+parent16functionalPASS/0parity; removes ONLY redundant freshowned
intermediate peeridentity duplicate, preserves final perrow deepcopies.
Parent6/6 alternating epochs faster, medianp50ratio1.131868,90samples/epoch:
baselinep50101–103us vs candidate89–91us. Onep95epoch115→118us,otherslower.
Author medianratios1.098/1.113. Independent16PASS/0parity and6/6 faster
epochs, median1.10989; component correctness accepted. Safety depends on
Identity.describe returning a fresh owned Dictionary (currently verified);
keep CC20 regression if adopted. RuntimeNOTADOPTED, D149 unchanged.
This is 8-contact callback wall latency, notFPS/aggregateCPU/fullcity or
single-contact speedup. No blanket allocation-count claim was measured.

NEW raw observation collector is now component-reviewed, NOT runtime wired:
scripts/vehicle_physics/vehicle_contact_observation_collector.gd
SHAd14946c97ecdb43105d6d760553a7de0151eda64b22e3254b285a94987c759f0.
Author test8fa1206f1780150876cc3d8134120da8013934de1da756ce0c2c4cbb3db0f87b
33PASS; independent test34341e020525d7dc6038b6e97cad23da509d7e35ad107bc6fb637b4987e1fe21
27PASS; parent reran both. API collect(directstate,selfref,tick)/contract().
Fixed8 raw rows retain self/counterpart point, ONself normal, point velocities,
closing, J, samecallback state.transform and explicit valid/complete envelope.
Tick/selfidentity non-authoritative, closing NOT source impactSpeed. Cap8
conservatively incomplete90/90; unbound identity87gaps. Rotated actualwall
zeroJ/closing7.4937 onset38 and laterJ39 retained without aggregation.
Parent callback wall-latency p95 wall92us/8contacts173us, notFPS/fullcityCPU.
Own collector perbody, no concurrent shared instance; no crash/HP/authority.
Frozen73843/dfe/a382 unchanged. Source obstacle role, canonicalpeer resolver,
eventauthority and actualmain producer are still required before damage wiring.

Contact-to-crash wiring HOLD: read VEHICLE_CONTACT_CRASH_AUTHORITY_GAPS.md
SHA75533572b698e97c19fff790c2dc42d7c56b5e4720cb1638218b992f2e0a8adc.
Frozen bridge manifold point/normal cannot be combined with peakclosing into
a solver event. Need coherent raw selfpoint/normal/pointvelocity + frozen
rootframe/envelope completeness; Godot ONself normal must be negated for source
outward. ZeroJ onset retains incoming closing; laterJ does not recover it.
Peer source directed deltaVA/B requires reviewed pair resolver/state inputs,
not closing or J/m. Event/life/sequence/cooldown/serverHP authority remains
outside this scope. Isolated raw observation collector reviewed above, NOT adapter.
NEW pure source planar pair resolver independently accepted, not runtime wired:
scripts/vehicle_physics/vehicle_pair_impulse_resolver.gd
SHA840cb2ea2977c43f22efb3936f653ccf1c492264f6f02cb640d80d254034cd18.
ActualJS exporter845d8207f1ec481e450257acdb6c87d3a96d530b6b6a14f5f4add5e5e2060518;
officialtest2ae420b73b81ef86c0941ce5370038df8730ba979cf152dd6243d4d86da0edb8
10963PASS/278actualsourcecases/3926numericcomparisons; independenttest
6f326287ca0a82fc70310ed4d70bb43822ddee1676198e50f750f42f84870681
2121PASS/512cases, parentbothrerun. Source544a pinned. API resolve_source(a,b,
contact,options)/propose/contract uses SOURCE +X/+Z yaw+Y normalA→B, not
native-axis inputs. Includes directed deltaVA/B and source finite fallback,
angular option/restitutionclamp; momentum/angularmomentum/energy/swap/purity.
Parent isolated dictionary wall-latency p9535.695us/call, notFPS/totalCPU.
propose.valid means container validity only; source_result.resolved checks math,
neither proves collision authority. No bodyforce/event/HP/canonicalization.
Frozen oldmodules unchanged; requires lawful pre-solve states/contact from
root-owned event producer. NEVER apply a second impulse over native solver J.

Worker batch isolated candidate AC553 is component-reviewed: author,
independent and parent Godot4.7.2 headless1211PASS, exact serial-state parity
all13 profiles/worker limits1/2/4/8. Parent72-active joined wall latency p95
4/8workers12.348/12.348ms versus serial38.603/39.226ms,32samples.
Not total CPU/FPS/fullcity proof and NOT runtime adopted. Lifecycle requires
exclusive solver ownership and explicit retire. Uniform speed/throttle
fixture needs separate per-vehicle input API before real fleet integration.
Exact hashes/API/limitations: VEHICLE_CRASH_COMPONENTS_REVIEW.md.

Additive heterogeneous input08262 now independently199PASS (13 profiles,
26batches), no component blockers; output order follows bound slots.
Actual combined native72/.1delta plus rejected full-surface deformation74e5
stress17PASS: three joined wall-latency observations47.955–57.761ms, exact
geometry/state parity preserved. This is pool-contention evidence, not LIVE
FPS/statisticalp95, and is a different workload from60Hz solver benchmark.
Local-dent replacement awaits Transport3; repeat combined proof before adoption.

Latest frozen crash/contact component manifest is
`docs/godot/VEHICLE_CRASH_COMPONENTS_REVIEW.md`: solver3896 independent7020PASS,
contactbridge73843 parent81PASS, all13 source profiles and explicit snapshot/API
boundaries. These are isolated components, not LIVE damage. Solver native
performance now has separate≥240-sample single-car CPU receipt; fleet/FPS remain
unqualified. Contact actualcap8 is covered by separate13-check stress fixture.
Sharedproduction
bodya382 stays frozen; brakingcandidateAE4D awaits Root actual-main adoption.
Root's current character-physics priority is separate and not touched by this owner.

Status: Stage 1 is consumed by Coordinator21's opt-in `preview_transport.gd`
main-scene integration. Coordinator21 reports the signed steering repair in
the sole LIVE vehicle13 instance; dedicated dynamic LIVE driving acceptance
remains separate from the short static capture. Damage, fire,
seat authority and server ownership remain separate components.

## Contract

- SI units: metres, kilograms, seconds, radians. Godot axes are `+Y` up and `-Z` forward.
- `NativeVehicleProfile` converts the immutable transport descriptor into body,
  wheel and control parameters and fails closed on invalid/non-finite geometry.
- `NativeVehicleBody` owns a real `RigidBody3D`, box collider, four suspension
  probes, internal bounded 120 Hz force substeps, one tyre friction circle,
  service/rear-handbrake forces, a bounded contact proposal ring, immutable
  state snapshots and body sweep admission.
- `NativeVehicleBodyFactory.spawn_from_descriptor()` consumes an explicit
  transport roster record plus one frozen profile. The record position is the
  source-ground pivot; collider/COM/suspension offsets remain physics-owned.
- Controls are monotonic by `sequence`, `source_clock` and vehicle life. State/contact rows carry
  `vehicle_id`, `life_generation` and physics/contact sequence numbers.
- The contact hot path uses fixed packed arrays and a fixed counterpart ledger.
  Persistent manifolds emit one onset, separation rearms them, and a full
  critical ring reports an explicit GAP instead of overwriting unread events.
- Contact receipts are proposals only. Server damage, fire, death and identity
  generation remain outside this module.
- Actor exit clearance remains the transport owner's capsule query. This module's
  `body_sweep` is only for vehicle placement/motion admission.

## Source fidelity

The production input is frozen Transport3 descriptor
`data/transport/vehicle_descriptors.v1.json`, SHA-256
`99d328bc4a581bc65815498b265ae5eec71a25b831512b15d376e1c0f5ac031a`.
All 12 profiles are admitted. The independent representative fixture is also
receipted against `vehicle_fleet_models.mjs` and checks exact mass, wheel radius,
wheelbase, acceleration and speed for compact sedan, sport coupe, bus and fire engine.
The descriptor now carries actual post-assembly visual bounds. Those values feed
the native collider, derived COM and track, so they are not presentation-only data.

Walk does not author ground clearance, centre of mass, track width, suspension
rest length or angular drag. They remain visibly listed in
`native_default_fields`; current neutral native defaults are derived from wheel
radius/body envelope and are not described as manufacturer/source facts.

## Validation

Run without creating another visible game:

```powershell
& 'C:\Users\Слава\AppData\Local\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk -s res://scripts/tests/test_vehicle_physics_native_body.gd
```

The headless scene contains a 40×70 m asphalt body, a 12×3×0.6 m impact wall
and a side barrier. The test exercises actual Godot settling, wheel contacts,
throttle, braking, steering/handbrake lateral motion, collision sweep, bounded
and deduplicated wall contact receipts, all-source admission and stable lifetime
identity. Per-wheel load/slip/longitudinal speed is exposed for wheel animation,
tyre marks and smoke without a second presentation-side dynamics solver.
Actual Godot 4.7.2 result after the descriptor/ground-root bridge update:
**127 checks PASS** plus **26/26 independent checks**
(update these numbers only
from a fresh run). Printed snapshot microseconds are isolated API measurements.

The actual exported compact-sedan visual was also mounted unscaled and without
an offset on the native body, then settled on a flat collider. The 25-check
alignment receipt verifies converted source bounds, all four authored wheel
bottoms, all four suspension probes, bounded probe/visual spacing, collider
margin, upright settling and the authored driver root. The suspension ray now
starts at the strut mount and uses the same explicit loaded-length ratio as its
spring-rate equation. The measured wheel bottoms are 3.5–3.9 mm above the flat
surface rather than the previous 104 mm.

```powershell
& 'C:\Users\Слава\AppData\Local\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk -s res://scripts/tests/test_vehicle_physics_visual_alignment.gd
```

Scaling command:

```powershell
& 'C:\Users\Слава\AppData\Local\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk -s res://scripts/tests/test_vehicle_physics_cpu_scaling.gd
```

Godot 4.7.2 / 60 physics Hz / 120 warmup + 240 measured ticks:

| Headless scenario | Physics-process CPU p50 | p95 | max |
| --- | ---: | ---: | ---: |
| baseline | 0.125 ms | 0.174 ms | 0.240 ms |
| 1 active | 0.699 ms | 3.048 ms | 3.048 ms |
| 16 active | 1.475 ms | 1.848 ms | 1.848 ms |
| 72 active | 4.840 ms | 4.930 ms | 5.386 ms |
| 72 sleeping | 0.871 ms | 5.226 ms | 5.226 ms |

These are headless engine physics-process CPU monitor values, not render frame
time, GPU, full-city LIVE or FPS. The sleeping tail needs a longer investigation;
the median proves sleep removes steady callbacks, but the p95 spike is not yet accepted.

Independent boundary tests additionally verify strict malformed/non-finite profile
rejection, clean life-generation reset, COM-relative anchor velocity, reusable
contact slots, exact 30/60/120 Hz force partition and fail-closed rotation sweeps.
Rotation-only admission is explicitly unsupported until a rotational cast is
implemented; it never returns a false safe result.

This Stage 1 is a native 3D force model, not numerical parity with the source 2D
dynamics solver. Independent evidence currently measures a different first-tick
steering response and rear-grip release curve. Source trajectory/yaw/slip parity
is therefore OPEN and must not be claimed from these tests.

## Stage 2 pure crash rules

### Static direct-state diagnostic

`test_vehicle_physics_static_contact_bridge.gd` SHA
`aee79042a8b744e56fed3434388660b259b78f0ff2197012577b4d6797a2a102`
passes31 checks against unchangeda382. A real source-tagged rotated static
wall produced311 points/87ticks, at most4points per tick. Production collector
emitted0 receipts because static counterparts lack vehicle_id.
Godot4.7.2 contact_local_position/contact_local_normal are already world-space
in this actual callback: point gap5.73mm, normal dot1; applying body transform
again creates30m error. Impulse direction is on-self, but onsetJ0/closing7.494
and next-tickJnonzero/closing0 show temporal mismatch. Reported summedJ covers
only62.5% of full mΔv (37.5% discrepancy), so this API cannot prove complete
impact momentum or a single pre/post-solver sample. One normal impulse has
negative roundoff−6.55e-5Ns; explicit bounded clipping is under separate review.
No runtime damage, static bridge or energy-conservation claim is admitted.

### Crash cage initial geometry

Full-chain independent review retracted its temporary geometry objection:
factory403–415 mutates car.profile to post-assembly bounds before crash31
consumes it. Manifest/oracle/descriptor agree across12 profiles within4.49e-10.
Pre-factory artist specifications are not the LIVE crash dimensions.

`vehicle_crash_cage.gd` initial SHA2cbce4bf67afc3df1cf8acfdd37e3d7e1066c6b337be2dd589d2c056397e5faa,
test SHA f1310955294b7fbd62b75537b14cad727cb5b970002f2684e2d01f33bf118a3d.
Fixed45nodes/232beams and trilinear sample, source/native axes(-X,+Y,-Z).
Actual Node source oracle plus Godot872checks PASS on three profiles;
independent review pending. No impacts, HP, damage simulation, visual/debris
or runtime hooks. Transport3 owns the visible deformation/debris adapter.

`vehicle_crash_solver.gd` initiald3517f8bee25ebe09d32b2b4cba14819ca9fc8658220fbf4170060714205fa73
adds proposal-only plastic impact/parts/wheels/components and sample, configured
by vehicle/life/profile and exact manifest38598 vehicleProfile mounts. Parent
reran947 checks versus actual Node3 sequential compact impacts. Test SHA
1463b2af1bfbec2900de04dc144d9b78c21ab80e78a08890c0b699cd5f6aa7e0.
Independent identity/multiple-impact review pending; current same-tick admission
is too restrictive for multiple peers. Elastic step240Hz is not implemented yet.
No visible dents/debris/HP/body motion or authority is claimed from this stage.

Next solver candidateff40d0e40fd13b7c376a900d14cd717c621ab05612e4f536ef59859a19919297
adds exact240Hz settling/thermal source mechanics, requiredimpact_sequence,
nondecreasingimpacttick and separate strictsteptick. Parent6184PASS versus
Nodecompact/hatch/bus impact+step states; testd5cfcbebdffa0c107c7c13b26abdcf6630dd7c8450f30e9f051e0bf1ec229a17.
Independent review found all-fleet BLOCKER: canonical logicalrear-door fallback
was bus-only, rejecting five other legitimate two-door profiles. Fix/all13
admission checks pending; do not adoptff40 as all-fleet ready. Missing physical
rear panels must stay invisible, while exactsource logicalparts remain in state.
Root/Transport3 notified; no sharedbody/main adoption.

Current solver3896afa6c14845c84835f1fd8221d1b0927947d716008cc2e6422991afc01129
supersedesff40. Exact six-profile rearlogical fallback admits all13 manifest
profiles, no family spoof. Negative impacttick rejects; deformation_snapshot_native
returns copied45-node native arrays+identity; mechanical_snapshot supplies scalar
and wheel state separately from structural revision. Parent7020PASS; test
615c0d605e4bd6ef6cdd28676203c058e7c57dfa489d2f4cdf70067b3ced142f.
Raw Node oracle7866034066574af841c2f6bdf4c9b6a43cbcb3e8782acac2678471f296e97d0a.
Independent review still pending. Preliminary16-sample CPU call-cost is not a
robust fleet/FPS benchmark; no runtime adoption or performance acceptance.

Contactstatebridge currently973a402382c6d08d57fdc2ded17654e8b032016848addfe8b928aa1f6f9c6834
passes54 author+independent checks: actual sourcewall/vehiclepeer311points each,
same-instance metadata changes failclosed and refresh nexttick, explicitreset.
Review found self-pair rejection and untestedcap/cacheedge cases; owner preparing
patch and top-level completeness admission. Consumers must never use valid=true
alone to accept a GAP-containing partial collection. Stillunwired.

### Static counterpart identity adapter

`vehicle_contact_identity.gd` is a cold, unwired proposal-only adapter for
existing source-tagged StaticBody3D building colliders and lifetime-tagged
vehicle bodies. It never invents IDs from node names/runtime IDs and rejects
sensors, missing source shape indices and missing vehicle generations.
Production main already assigns building `source_id`/`source_index`; ground
and temporary boundary lack this binding and remain explicitly unbound.
Actual headless14/14 PASS, no warnings, including spoofed vehicle tags on a
sensor (vehicle counterpart must actually be RigidBody3D). Component SHA
`eb6ad8ba8b5bf1a14fb1a1a75cbbee8b25f09145909dd448f2ba97a2e6bec256`;
test SHA `a255d41522925fb80343f66ea772736aa0aa893618df9f5d565d03b3651ccd6a`.
This does not wire direct-state collection, damage authority or visible dents.

### Directed manifold candidate — 27 September

Latest frozen manifold isdfe706e678fd64a6ac2d67f27bd659733287ff9aba6e62c6b9343889ba3ed9dd.
Explicit numeric tolerance permits J·n in[-1e-4,0)Ns by removing only its
negative normal component. Clipping lifetime count/per-tick correction are
published; lower negative values still reject. Synthetic34PASS; actual static
wall32PASS accepts311/311 contacts with exactly one6.5478e-5Ns clip, no invalid
or overflow. Parent rerun syntheticCPU onepeer665/829us, eightpeers762/849us
p50/p95; isolated headless workload, not FPS. Test SHA
cf313fe616783a926bd224bb60c176d3948e3abde77283454385fb2bb872688f;
static diagnostic SHA b2972a3ad0141eaadef63d5cc322ff2609c374ae7daa1918a1c5ea75bb27ea69.
No direct-state runtime bridge has been wired.

`vehicle_contact_manifold.gd` provides fixed-capacity per-body/per-global-tick
aggregation of world-space contact points, full vector impulses and COM-relative
angular impulses. It retains zero-impulse onset closing speed, marks invalid input
or overflow as a GAP, and exports proposal-only rows. Runtime IDs are local lookup
keys and are never declared server identities. Snapshot export allocates; raw
observation uses preallocated packed arrays.

Actual Godot headless result: 26 checks PASS, including pure torque with zero
net translation, symmetric frontal contacts, point-order reversal and overflow.
A warmed synthetic 72-body/eight-contact workload measured 656 us p50 / 842 us
p95 per tick for one counterpart; eight distinct counterparts measured
766 us p50 / 835 us p95. This includes synthetic input construction and is an isolated CPU
diagnostic; it does not accept full-fleet runtime cost. Further pair lifecycle,
canonical two-body reduction and direct-state bridge are required before wiring.
Direct-state integration and lifecycle cost remain unmeasured.
Collection, overflow and invalid-input GAP flags are separate. A single
zero-impulse onset retains its normal; exact opposing normals are marked invalid.

```powershell
& 'C:\Users\Слава\AppData\Local\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk -s res://scripts/tests/test_vehicle_contact_manifold.gd
```

`NativeVehicleCrashRules` is an isolated proposal-only source-parity package. It
freezes the 12 structural part IDs, debris proposal caps, deformation envelope,
collision-damage formula and smoke/fire thresholds. It rejects malformed or
out-of-source-range geometry, keeps structural deformation separate from the
sub-threshold local collision-damage proposal, and never mutates HP, starts fire,
starts an explosion or revives a wreck. Current Godot result: **47 checks PASS**.

```powershell
& 'C:\Users\Слава\AppData\Local\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk -s res://scripts/tests/test_vehicle_crash_rules.gd
```

Runtime contact reduction, panel nodes, debris bodies, fire visuals and occupant
damage are not implemented by this pure package. Stage 2 runtime wiring remains
blocked until the first opt-in car proves the Stage 1 bridge in the integrated scene.

## Integration gate

### Signed steering repair after user feedback

The source visual wheel uses positive steering toward vehicle-left after its
PI-around-Y export wrapper. The native tyre basis previously rotated by the
opposite sign. With the host's `-Input.get_axis(left,right)` this made A show a
left wheel while physics turned right, and D the reverse. The native front
direction now rotates by positive steering, matching the authored visual; the
existing host mapping stays consistent. New body SHA:
`a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401`.

`test_vehicle_physics_steering_response.gd` exercises ordinary full-throttle
turning without handbrake in both directions at 3/8/16/28 m/s. All eight signed
yaw/displacement scenarios pass. Native127 and unchanged independent26 pass on
the same body. This verifies the simulation change; Root21 updates the sole LIVE
instance and owns the final input/visual check.

The new `test_vehicle_physics_all_profiles.gd` adds actual 12-profile flat-floor
settling evidence: 138 checks PASS, all four rays grounded for every profile,
60 consecutive stable ticks reached at tick239. Worst root height was 5.56 mm,
worst velocity 0.0101 m/s and worst consecutive-frame root displacement 0.475 mm.
This proves flat-floor equilibrium; building, curb and rollover collision behavior
requires the separate actual-block driving investigation requested after LIVE feedback.

### Actual-block fall diagnosis, 27 September

The explicitly temporary crop boundary is now supplied as
`scripts/preview_boundary.gd`, SHA-256
`ba9b9797e8982ede31909786ff8fe3e5c2a34a1537643eb84356d60a864c1e87`.
API: `configure(bounds_value: Variant, label_anchor_local_m: Variant = null) -> bool`.
Four visible, matching static walls stay inside actual source bounds; no
fabricated floor or water replacement. `test_vehicle_preview_boundary.gd`
SHA-256 `e462fad314907d7266606cf1dc791ccb34a27a74bf80b0760c88ce1f7757f897`
passes 56 checks. Its east test uses exact source dry strips, actual parking,
normal gravity and free roll/pitch at 6.5 m/s: maximum front X42.76375 versus
edge43.05, minimum root Y0.003506, final support mask15. The other four wall
tests are explicitly axis-locked geometry isolation, not rollover acceptance.
Root owns main wiring and reports the visible boundary in LIVE13.

### Proven next defects — not part of the a382 freeze

Latest completed candidate is AE4D, not the historical873/67da below. Exact
manifest: `docs/godot/VEHICLE_BRAKING_CANDIDATE_REVIEW.md`. Parent repeated
actual independent107 + braking30 PASS. It fixes opposite-pedal service
braking, separates rear longitudinal handbrake grip from reduced lateral grip,
and stops from10m/s in2.6167s/13.42m. Production remains exacta382 pending
Root independent actual-main review/adoption. Tyre emitter finald8a8cc7
passes38 checks but requires same-tick contact-point/surface seam; unwired.

Coordinator21 requested production remain exactly a382 for the imminent LIVE
moving-exit capture. This exact hash has been restored and verified. Candidate
body is preserved separately in `outputs/vehicle_native_body_candidate_873976.gd`,
SHA-256 `873976e64de0ae56fabb87af9f73df8a6940901a0f10a3368b825321cd5fc1d7`.
It combines supported-normal admission, tangent tyres and grounded-only road
coast. Unchanged independent26 passes on this candidate. Prior efb candidate
had airborne coast and failed five isolated impulse checks; it is superseded,
not accepted. Native127/wall24/steering8/coast18 were run on efb before the
grounded-only adjustment and must not be reported as fresh873 acceptance.
New test files currently describe candidates, not production a382 acceptance.

Candidate873 coast regression now separately passes22 checks. It SHA-verifies
the exact candidate and removes only the duplicate global class declaration
in memory before compilation (production already registers NativeVehicleBody).
Grounded coast8.226727 versus source8.252822 has a measured0.0261m/s tyre
difference, checked with explicit0.04 tolerance. Airborne horizontal10 and
vertical3 are conserved; hatch28.01717/compact31.03491 reach authored caps.
This is not LIVE or productiona382 acceptance.

Production handbrake diagnosis intentionally fails two source gates: coast
stops4.317s/11.572m, neutral+handbrake2.500s/8.843m, throttle+handbrake never
stops in15s (50.514m, final2.8025m/s). Source disables propulsion when braking;
native front drive currently overcomes grip-limited rear braking. A separate
outside-production candidate `outputs/vehicle_native_body_candidate_handbrake.gd`
SHA `67da32426d7b503eee0f92294f7e57c0406a857a17ee1f6e91a2eabf34cc4c0d`
adds only handbrake/service-brake propulsion suppression to873. Its regression
is pending; no production adoption while Root LIVE QA is frozen.

Tyre-mark source audit establishes a bounded1200-segment10-second ring with
0.28m spacing/0.19m width and source fade timing. Implementation is separate
from current body; actual same-tick wheel contact position/normal and trusted
source surface metadata are required before wiring. Visible crash deformation
remains OPEN: current collector drops static colliders without vehicle_id,
so buildings/walls cannot yet feed the proposal pipeline. Pure47-check crash
rules are not a visible dent/debris implementation.

An isolated vertical-wall test with no floor proves rotated suspension rays
can incorrectly report ground support at roll70/80/90 degrees. All hit normals
have world-up dot0, yet old body reports masks10/10/15 and positive loads.
Support admission and tangent-plane tyre forces are being repaired separately.

The source `coastDrag` value0.75 is a deceleration in m/s², not velocity
damping. Mapping it to Godot `linear_damp` combines with project0.1 and slows
every axis even under full throttle. Actual 10-second tests on a382 reached
only hatch7.023/compact7.393 m/s versus source caps28/31. A separate source-
branch planar coast regression is required before replacement is released.

An actual headless main-scene investigation reproduced the reported fall using
the parked hatchback: its settled centre was `(37.082, 0.00356, -9.734)` and the
exported dry surface ended at local X43.05. The front bumper was only 3.85 m from
that edge. Driving east crossed the cropped surface, lost all wheel support and
fell into empty space (tick180 Y-4.56; tick600 Y-78.8). Building and low-object
impacts stopped at their expected collision boundaries without tunnelling in
the investigated runs. Coordinator21 owns extending the actual source surface
export; native body and profile remain frozen. This diagnosis does not establish
every wall/curb/rollover case, and does not authorize fabricated ground over water.

Root/Coordinator21 should connect this module only after reviewing the descriptor
bridge from Transport3. The first runtime hook must remain opt-in and preserve one
physics owner per vehicle. Do not run a parallel browser dynamics controller.

Still open after Stage 1: all-profile/LIVE model-hull bridge, surface coefficient map, water/sunk
state, panel damage/destruction, two-vehicle canonical impulse aggregation,
occupant crash response and authoritative damage/fire receipts. This owner does
not alter `main.gd`; LIVE admission belongs to Coordinator21.
