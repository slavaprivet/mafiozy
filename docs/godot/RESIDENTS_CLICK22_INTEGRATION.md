# Three residents and click-to-control — 30 September 2026

The local preview admits the original resident models/IDs 72, 169 and 252 near
the starting car through current source permission, floor and physical clearance.
Immediate owned-footprint reservations prevent a same-frame double spawn before
the physics broadphase updates. Their source birth packet is unchanged.

The present two-metre walking exercise is not the original agenda. The user
reported aimless back-and-forth movement and abrupt turns; these remain distinct
acceptance items. This checkpoint includes Artist22's independently frozen
`018e0ab089384e44d62fd855c0d13c5573d662ccba330c2136b04add1503a4d5`
host: visual heading interpolates the shortest yaw over the source default .1s,
without changing body heading, speed, navigation or collision. Later combat WIP
in the shared working tree is excluded from this checkpoint.

The player starts with a free cursor. A click acquires control and consumes that
click; Esc or focus loss releases controls and held actions. Returning focus
does not acquire control. Inactive walking, jump, E and vehicle input are blocked.

Accepted visible build: `s01-20260930-residents22b`, PCK SHA-256
`de2728bb6136aeefe0af64a1d07b6e511910912594d5cacc9237d7cd0698f49d`.
It contains the earlier host326daf9e; the smooth-heading change requires the next
verified export/restart. Acceptance PID37616 is historical: fresh01:09 inventory
found no MafioziPreview process.

## Comparable LIVE evidence

`outputs/coordinator22_residents/retry05`: same pack, NPC off/on, fixed camera,
1280×720, 5s warm-up and 12s samples, 1731 actual drawn frames each. GTX980,
Forward+,144 cap; quarter of eight buildings, eight decor items and one car.

| Measure | NPC off | Three residents |
| --- | ---: | ---: |
| Process-frame interval p50/p95, ms | 6.987 / 8.220 | 7.020 / 8.747 |
| Actual frame_post_draw interval p50/p95, ms | 6.923 / 7.389 | 6.944 / 7.194 |
| Draw calls | 1021 | 1161 |
| Primitives (not triangle count) | 503932 | 639740 |
| Sampled peak process working set, bytes | 609038336 | 634728448 |
| Video memory monitor, bytes | 229716528 | 231381600 |

Resident movement was 6.909,8.550,5.690m. No recorded input contamination or
runtime errors; start/end PNGs were reviewed. This does not establish full-city
FPS, original NPC actions, combat, HP or progress. QA arrays and image capture
allocate memory, so sample before/after memory is not a leak trend measurement.

Compiled b pack: click18 and vehicle-cycle14 PASS; actual-main population24 PASS.
Smooth checkpoint: clean archive import; click18, population24 and actual staged
movement/turn/access-denial/recovery PASS. Eight abrupt physical body turns were
observed, maximum visible turn .523599rad/frame, paths unchanged. Legacy host73
and vehicle14 are checked in the same clean archive. The resident speed oracle
fixture is included so the test does not depend on untracked workspace files.

## Remaining work and ownership

Root22 owns gun/inventory/trunk/input and true hit integration. Artist22 owns NPC
actions, current target identity and hit/death presentation. Guns, blood, HP,
physical death and cargo are not present in accepted b. The user additionally
requires crouched/seated, prone and cover weapon checks; isolated pose checks
will not be reported as live gameplay acceptance.

The fifth pinned traversal chat was stopped by user instruction. Do not send it
tasks or wake it. Both its automations are PAUSED; UI interruption could not be
confirmed because window capture timed out. Preserve its uncommitted files.
