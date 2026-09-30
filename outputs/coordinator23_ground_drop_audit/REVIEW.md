# Ground-drop regression: exact current23e PCK

30 September 2026. Root-owned outputs only. No production, NPC, GPU or Git edits.

## Verdict

**Stale test assumption, not a broken same-frame reservation.** Current runtime correctly returns `ground_space` when every one of the four source-ordered candidate placements is occupied. The old assertion expected another placement from the previous wider ring search. Changing production to ignore the first gun, remove the player from collision, or extend beyond source candidates merely to pass this assertion would weaken the required placement rules.

Reproduced the original test on the EXACT compiled PCK023070fe6b1895cfc7571d9bb402d5c324577f84cccf74a73ec823c9e963f2bc, with --path and cwd set to its export directory (no raw source fallback). Original172 checks has one failure; diagnostics are trace.gd / trace_pck.log.

## Observed actual geometry

Player(31,.000234,-18), visual yawPI/2. GroundRules.drop_points uses source distances[.8,.55,.3,0] along +X. Original Walk order is walk_preview.mjs dropCurrentWeapon:1666. All four floor, water and sampled pedestrian path checks pass in this fixture.

First accepted Nagan placement(31.8,approximately0,-18), settled world bounds:

    position(31.61512,.009,-18.11371), size(.369766,.075146,.227424)

Second TT settled size(.276552,.100942,.254914):

| Candidate distance | Real reason for rejection |
| --- | --- |
| .8m | Same pickup centre; intersects first Nagan reservation |
| .55m | Centres only.25m apart; half-length sum.323159m plus.005m clearance, so overlaps |
| .3m | Clear of Nagan, but native shape query hits actual PreviewPlayer capsule |
| 0m | Native shape query hits actual PreviewPlayer capsule |

There is no stale falling-transform, missing identity, unsynchronized ground collider, water, focus or export-resource failure. First Nagan reservation is correctly canonical settled geometry while its visible node is still falling. Merely waiting a frame cannot make these same settled boxes fit.

## Minimal proposed change

`test_only.patch` touches only `godot/mafiozi_walk/scripts/tests/test_preview_cargo_regressions.gd`; base/proposal hashes in PATCH_RECEIPT.json. No runtime patch needed.

1. At the previously failing second same-heading drop, assert `ground_space` and unchanged authoritative inventory snapshot, item identity snapshot, held TT UID/ammo, first ground reservation and falling count1.
2. Rotate only the test fixture's player heading90 degrees, without awaiting physics, removing/changing colliders, granting ammo or writing inventory. Call the unchanged real cargo.drop_held again; it now finds the first free source candidate sideways.
3. Retain all original subsequent checks: both visible models still falling, canonical reservation independent of fall animation, no settled overlap, real same-UID revalidation allowed, different-UID overlap denied, synchronization identity preservation, settlement bounds unchanged, ownership expiry clears reservations.

The fixture facing change is explicit, like the existing fixture position/camera changes. It does not claim ordinary input acceptance; it retains the intended same-frame reservation stress without assuming an illegal second same-heading placement is free.

## Verification

Proposed external test against the SAME unchanged standalone PCK: **184 checks PASS**, no failures, exit0, no engine errors,2.36seconds. `corrected_pck.json` pins PCK hash; `corrected_pck.log` is exact output. The increase from172 to184 includes previously skipped downstream assertions plus new refusal-state checks. No copied/overridden production cargo or renderer module was used.

Limits: this bounded headless regression intentionally disables residents as the canonical test does; no performance/GPU or mouse-input claim. If user later requests dropping many weapons repeatedly without turning/moving, define a separate bounded placement policy extension with collision/path/water/UID tests; that is a gameplay change, not this bug fix.
