# Articulated character reactions — integration checkpoint

27 September 2026. User wants physically responsive falls, moving-car exits,
melee, bullets and explosions, with stable ordinary walking and aiming.

## Current playable boundary

Updated physics19: sole interactive game PID46688. The actual hero now has an
explicit admitted-impact install seam, verified with TEST_ONLY weak/repeated
impulses, physical fall and recovery in the real native scene. Real combat input
is not installed by default. Quiet indirect support and loss/motion of support
during getup are fixed. Full acceptance and measurements are in
PLAYER_IMPACT_HOST_INTEGRATION.md. Export19 main and impact PCK tests pass.

Historical physics18 milestone:

Current visible game is **physics18, PID19064**, with articulated exits enabled
by default. Fresh inventory on the resumed goal turn showed the previous game
was closed. Two successive actual native E/W drive tests passed; each restored
a fresh interactive scene and the older window was closed before the next run.
Source combat, NPC controller integration and general impulse producers remain
unfinished.

Native01→native02 p95 frame time during the exit/fall/recovery was
**10.957→9.231 ms**, p50 **6.941→6.946 ms**; pre p95 **8.130→8.079 ms**,
post **7.818→7.784 ms**. Same source quarter, camera, one car, zero NPC,
Forward+/GTX980 and144 FPS cap. PNG readback plus three subsequent frames were
excluded; native02 adds prone and mid-getup captures. This is a short scenario,
not a full-city/fleet benchmark. Both reports have stable source hashes and no
failures. Viewed release, tumble, prone, mid-getup and standing screenshots.
Camera remains4.8 m; fullbody falls beside the coasting car, then stands.

The optimized exact full-skin grounding override is now in
`character_physics_pose.gd` (`1118f21a…`). Independent source comparison confirms
only13 instrumentation lines were removed from the tested candidate; legacy
vehicle pose and clearance modules are unchanged. Paired actual-map floor-query
CPU p95 **4.522→1.941 ms**, with no position/skin differences, plus787 parity
checks and629 full-skin coverage checks. Every vertex remains represented.

Export `s01-20260927-physics18` passed PCK startup and actual E/W drive. Final
`s01-20260927-physics18b` only narrows transport data packaging to the two runtime
JSONs, excluding unused test/oracle data; source game behavior is unchanged.
Its PCK startup, water/dive/interior and transport checks pass. Receipts are in
the export directories and `outputs/coordinator21_vehicle_liveqa`.

## Implemented optional path

`preview_transport` replaces only its fast-exit transition with
`ragdoll_actor_transition`. Boarding and slow exits retain their existing
transaction. The actor keeps its seat reservation until physical recovery and
ground admission finish. The body inherits each segment's actual point velocity
from the car, including angular velocity, plus one outward impulse. Sixteen
prewarmed bodies and fifteen joints interact with the world and car. One existing
pose writer applies the retargeted bone rotations; authored lengths are retained.

The invisible player capsule follows the body for camera/void detection and
does not compete with its collisions. Recovery requires floor support, a clear
standing capsule and a conservative bound of the complete skinned pose path.
A moving obstacle resumes physics from the last displayed pose without a seam.
The camera stays upright and excludes its own character bodies and vehicle.

The original `settled` predicate is preserved. An additional authored recovery
gate permits a supported torso to start getting up before all small arm motions
stop: core speed ≤.35 m/s, angular speed ≤.8 rad/s; all segments ≤1.5 m/s and
4 rad/s; valid specific kinetic energy ≤.15 J/kg; joint error ≤.025 m; floor
support including a core contact; continuous .2 s after at least1.2 s of fall.
This is game recovery tuning, not a medical or biomechanical measurement.
The old settled+.35 s route remains a fallback. Both routes still require
standing and full-skin clearance. Death prevents recovery.

Damaged/retired physics pools enter explicit `FAULTED`, never report an active
fall or grant walking. The test scene shows a restart message; R creates a fresh
scene. This is separate from HP/death and does not fabricate a safe teleport.

## Verified results and regressions

- `ragdoll_self05/report.json`: actual main, real E/W input, boarding, acceleration,
  fast exit, physical fall, recovery and ON_FOOT all pass with stable source
  hashes. Recovery begins at3.433 s, compared with9.083 s in self04. Both are
  headless behavior tests, not native visual/FPS acceptance.
- self03's failed recovery is retained. A conservative sweep touched the side
  of a neighboring floor tile below its top, X34.85001/Y0. The corrected query
  admits only bounded sub-support pairs and independently checks the above-floor
  volume. Coplanar seams pass; same-RID walls, ceilings, 2 cm obstacles and
  combined below-floor/above-floor geometry remain blocked. No floor RID is
  excluded.
- Reverse01 is not a passing ragdoll case: speed fell from4.316 m/s before the
  hold to3.408 m/s at transition, so the existing15 km/h rule correctly chose a
  walking exit. A faster genuine reverse-driving scenario is still needed.
- Body tests:1250 original and342 independent physical checks; indexed/named
  skin compatibility1693 owner,1589 independent and468 actual cached-NPC checks.
  Additional diagnostics/rolled-normal suite3229 checks. Current body diagnostic
  SHA `822966ac0b03bbb0dbb37085fccf915fdbc11d07d8c6d05bd9035c66f26f58f8`.
- Full-skin recovery bounds629 checks; blocked-resume seam ≤.268 micrometres
  across28 bones; lifecycle/fault suite39 checks. Actual-main R restart passes.
- Observed limitations: soft joint limits can transiently exceed configured
  anatomical angles; self-contact is approximated by per-instance exclusions;
  transient hand skin penetration up to15.87 mm in the tested impact, while
  settled tested skin remains above the floor. This is not a guarantee for all
  geometry or a finished active-ragdoll fighting system.

## Performance and remaining work

Before additive diagnostics, isolated CPU p95 was .218 ms for the falling
driver and4.140 ms for getting up; this excludes the physics solver and rendering.
The full-skin floor-cell reduction dominates the latter. An output-only exact
optimization candidate is being measured; it has not replaced the accepted
helper. No loaded-scene FPS result exists for the articulated path yet.

The pure impact policy is published in commit
`ef0b3aa176dc5f22e1271399ba63b42e1bef78ab` with158 passing checks. The local
damped hit-response sampler and synchronous single-dispatch impact sink are
separate work in progress. Current combat source receipts do not supply measured
physical impulse; damage/72 and old visual speeds must not be repurposed as J.
No claim is made that melee, bullets or explosions already use this system in
the visible game. NPC rigs are compatible with the body module, but the current
recovery driver still uses the player's controller/capsule and75 kg profile.

Next admission: integrate the reviewed local-response sampler and impulse sink
with actual combat producers and controller leases. Do not label their isolated
tests as a finished melee system. More directions/speeds, obstacles and repeated
exits remain useful additional gameplay scenarios.
