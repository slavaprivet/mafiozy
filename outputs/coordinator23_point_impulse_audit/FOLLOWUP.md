# Exact e4ec follow-up: frozen834 and real limb contacts

30 September 2026. Supersedes the earlier statement that e4ec had only110 parallax checks. No production/NPC/GPU/Git edits; candidate05 unchanged. Three bounded headless processes ran sequentially, no benchmark claim.

## Exact tested closure

Owner **e4ecf5b39a9d06244d51c01f9e1c4d2c8268ee90639600c690b09572d4096f04**; helper **fe4ddd5272e6ea0f0b746b003c8254022a561120a867b54088355ffddb53abe2**. `frozen/` copies those bytes and the translation-only uniform control. All external test inheritance/preload paths bind these local frozen copies, not Artist's mutable point_impulse_candidate. `FOLLOWUP_PINS.json` hashes the complete local test chain/results; critical candidate05 dependencies remain pinned in closure/MANIFEST.json. This is a test/evidence closure over candidate05, not a newly exported game.

## Frozen834: PASS

The original all-cardinal fixture rerun once with the exact corrected owner: **834 checks, zero errors, exit0, no engine errors,24.285s**.48 physical cases: all3rigs×4cardinal×medical/final×uniform/split. All24 point-versus-control torque signs positive, minimum dot0.166809; maximum joint error.114666m<unchanged.20m; every minimum floor difference0. No force/tolerance change.

Evidence: frozen834.json/log and frozen834_comparison.json. Original author834 results remain separate and are not renamed.

## Narrow limb proof:18 paired real contacts, PASS

`test_limb_contacts.gd` samples a bounded grid of real native standing-capsule ray contacts, compares each point with original outgoing physical capsule frames, and selects only a contact actually inside the requested hand/forearm/foot capsule. If none exists the script explicitly records uncovered rather than manufacturing a hit. All18 requested combinations were found: left/right hand, forearm, foot on residents72/169/252. Native body.apply_impulse independently selected the requested segment in every candidate case, with **actual reported capsule gap0.0m**.

Each contact then uses a real source Fire shot (ammo decrement asserted), actual native Deagle projectile sweep, completed ordinary HP final-death transaction, original physical host/body, and180 physics ticks. Uniform and split use the same shot/RNG/pose. There are36 physical runs =18pairs; no target collider, body pose, HP, mass, joint or impulse magnitude is fabricated to create limb contact. Existing isolated vehicle-ray corridor from the upstream native fixture remains explicit. This is not ordinary mouse-input acceptance and capsule overlap is not a skinned anatomical headshot proof.

**Exit0, no engine errors or assertion failures,17.192s.** Script reports104276 checks because finite-vector assertions repeat across16segments×180ticks; the meaningful coverage is18paired contacts, not104276 independent scenarios.

| Measure across exact limb candidate cases | Result |
| --- | --- |
| Point share / total Deagle impulse |2.5 /100N·s |
| Maximum joint anchor error |.1083075m (<existing.20m) |
| Maximum joint increase vs matched uniform |.000007473m |
| Maximum segment linear speed |4.627915m/s |
| Maximum segment angular speed |22.110693rad/s |
| Largest speed increase vs matched uniform |+.541762m/s linear, +2.014709rad/s angular |
| Minimum capsule/floor change vs matched uniform |0.0m in all18pairs |
| Capsule-to-contact distance selected by body |0.0m in all18point cases |

No velocities exceeded the existing start validation ceilings80m/s and30rad/s used as diagnostic comparisons; these are not asserted to be native solver clamps. Total J remains conserved by uniform+point, correct segment identity checked, and replay of the actual hit cannot apply a second point impulse.

Evidence: limb_contacts02.json/log and limb_contacts02_comparison.json. Raw positions/directions/lever arms, actual segment and matched control metrics are retained.

## Additional proxy-lever stress retained honestly

The first limb run deliberately maximized lever over native standing-capsule contacts mapped to the requested closest physical segment,36runs/18pairs,17.106s. It passed the same bounds, maxjoint.108283m, maxangular23.087864rad/s, minfloor difference0. However some foot points were.20–.24m outside the physical foot capsule, accepted by the existing generic.75m nearest-segment tolerance. **Those rows are proxy-attribution stress, not exact foot hits.** They are retained in limbs01.json/log/comparison. The later gap0 test supplies the actual limb-contact proof; no tolerance was widened to obtain it.

This also confirms a remaining runtime design limitation: production standing-capsule contacts can select a nearby physical part without intersecting it. The current owner inherits body.apply_impulse's.75m selection policy. If stricter visual/anatomical fidelity is needed, preserve exact native evidence and add an owner-defined contact refinement; do not silently treat the closest capsule as a proven skin hit.

## Cap decision and remaining limits

**No mass-aware cap proposed:** sampled small-limb physics does not establish that2.5N·s is too aggressive. Changing it now would change a tested gameplay response without evidence. Forces, masses, joints, contact reserve and tolerances remain exact; original e4ec proposal is unchanged.

These limb tests cover initial final Deagle100N·s with the full2.5N·s point share. They do not prove every combined225N·s shotgun limb launch, every angle/obstacle/animation pose, or medical limb getup. Frozen834 covers75/225 on head contacts and four directions; no genuine medical release is available. If future actual failures show a small-limb problem, a separately measured mass-aware split should subtract its reduced point share from the same requested total, returning the remainder to uniform J. Do not reduce total momentum or introduce a compensating second full impulse accidentally.

Floor minima remain the pre-existing initial capsule intrusion approximately-.141081/-.141641/-.130760m, identical to controls. This proves no worse minimum in these runs, NOT floor-clear correctness; a minimum over the whole trajectory does not prove every later per-tick surface contact identical. No floor tolerance or geometry adjustment was made.

Always-lethal anatomical headshots, corpse/ACTIVE follow-up response, live mouse/input, combined wound/headshot integration, exported candidate06, medical source-release/getup, and whole-scene frame-time/memory remain separate acceptance. Root can now validate the e4ec merge using stronger exact-file physical evidence; do not label these tests the finished whole combat package.
