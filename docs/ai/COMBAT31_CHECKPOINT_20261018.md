# Castle combat checkpoint — 18 October 2026

## Follow-up: vital blunt and stab wounds

The sever gate previously also prevented lethal non-slicing head wounds from killing the NPC. Death now follows depleted vital-part health independently of severing. Mace/sledge contacts cannot enter the slicing sever path even when their motion is transverse. Tagged and legacy contacts share this gate.

Native castle damage semantics: `D:/MafioziCombat31/vital_wounds31/baseline01` reproduced the bug; `native04` PASS exit 0/empty stderr for weak contact survival, lethal blunt/stab head wounds without debris, cumulative torso death, legacy head damage, and strong slicing head cut with 3 real debris pieces. These are post-armor damage injections, not live swing acceptance. Tested candidate and integrated source have identical Git blob `262bb03de90e353cc18899581c71a0300941a233` (raw hashes differ only by line endings).

Scope: shared `outputs/coordinator31_npc57/game`, castle scene only.
This is an incremental checkpoint, not acceptance of the complete combat system.

## Changes

- Spear: single throwing arm over the shoulder, free support hand, visible 0.18 s forward cast before release; complete spear model survives pickup.
- Embedded spear follows the struck body; transfer to physical cut debris is handled separately from the damage calculation.
- Animated NPC hitboxes synchronize with their bones; broad movement hull no longer masks limb contacts. Fast slicing contact is required for severing. Fallen limbs remain hittable.
- Arrows: partial draw release, damage based on impact speed squared, corrected close aiming convergence, damage through armor-aware puncture entry without severing, embedded arrow follows detached debris.
- Player puncture damage no longer invokes slicing/severing; tiny wounds retain their actual damage.

## Evidence on D

- `MafioziCombat31/combined_pose01`: actual shared castle graphical test, PASS, exit 0, empty stderr. Charged side/rear and forward-release images reviewed.
- `MafioziCombat31/spear_attachment31/current_B606_sever03`: current sword SHA256 `B606A3B8D3833DFEEAEDAFC9CA205C0CE6C80AB66D21DD00EC1AB9ED9163AF74` with matching production MeshSever SHA256 `1A784BB4356A05ECC06760FC93261C53671A7EA7CCBAF6ECD7778DC15F17A341`, PASS. Real throw/tip hit/death/stick, then controlled mesh sever; spear transfers to a newly created physical fragment and follows it. Sever invocation in this fixture is synthetic, not a second player attack.
- `mafiozi_npc_sweep31_current01`: production-equivalent sword + current mesh cutter, actual swept head/arm/leg contacts PASS.
- `mafiozi_npc_sem_arrow02`, `mafiozi_npc_sem_puncture01`: damage semantics PASS; weak hits do not sever, armor reduces damage, lethal head puncture kills without severing, dead target rejects repeat damage.
- `MafioziCombat31/bow_contact31/final_full03`: actual partial/full arrow contacts, different damage, no repeated damage, head death, detached-arrow follow PASS. Shield check here is damage-point semantics, not an independent physical shield collision test.

## Limits and failed diagnostics retained

- `combined_sweep01` timed out because a graphical screenshot fixture was incorrectly run headless. It is not a passing proof.
- `current_B606_sever01` had a stale D-stage mesh cutter dependency; production already has the required material surface mapping. The failed receipt is retained.
- `current_B606_sever02` had an overly narrow test assertion selecting only the last of two new fragments. Corrected fixture checks membership among all new fragments; production code was unchanged for run03.
- Mesh cutting still uses bind-pose geometry; exact deformation-aware cutting remains unresolved.
- No claim of complete torso separation, complete physical death behavior, final armor appearance or comparable FPS acceptance.
- Castle/armor/map changes owned by other chats are excluded from this checkpoint.
- New test outputs stay on D. C ran out of space; another coordinator subsequently reported freeing space through standard npm cache cleanup.
