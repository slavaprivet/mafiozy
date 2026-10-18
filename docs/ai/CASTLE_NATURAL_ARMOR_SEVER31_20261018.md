# Natural castle sword versus armor, exact published `56abc45d`

Source: `D:/MafioziCastle31/main56abc_soak31`, Git `56abc45d26901ec9b38c87201a3826c9f603fb8f`. `D:/MafioziCastle31/main56abc_soak31_SOURCE_PINS.json` verifies all 779 tracked scripts/scenes/project; scheduler import receipt `D:/MafioziCastle31/main56abc_soak31_import/SCHEDULER_RUN.json` passed with exit 0 and empty stderr. This stage was read only in the tests.

Fixture: `D:/MafioziCastle31/qa/natural_armor56abc/fixture.gd`, SHA256 `43BD0A671F68BE5EBA9B2D84D731336C2DC69F767ECDA35E8C4B71C8F0012355`. Ordinary castle Q then 1 selects the sword. LMB and mouse motion drive every attack. Fixture sets only initial player position behind the NPC and camera facing; it does not call a sweep, damage helper, modify HP, move the weapon directly, turn off AI, or remove NPC steel. For the armored fresh scene, the published `set_npc_armor31` API equips all five heavy pieces, committing visual and protection together. NPC shield is absent from this resident model.

Graphical scheduler runs, all exit 0 / empty stderr:

| Run | Contact result | Blood / steel | Receipt |
| --- | --- | --- | --- |
| `bare01` | Head part HP 50 to 46.529, NPC global HP stays 90 | blood true, sparks 0 | `bare01/SCHEDULER_RUN.json` |
| `heavy01` | Full heavy visual/equipment present; head HP 50 to 48.835 | blood false, 8 sparks | `heavy01/SCHEDULER_RUN.json` |
| `death01` | 16 alternating strokes: right upper arm HP 34 to -6.118 and real sever at stroke 12, sword disarmed | blood true; no death | `death01/SCHEDULER_RUN.json` |
| `death02` | 16 repeated same-direction attacks after ordinary mouse return; head 50 to 49.482 | NPC steel clash with 16 sparks on every stroke; no death | `death02/SCHEDULER_RUN.json` |
| `fast01` | 12 stronger alternating strokes; right upper arm HP 34 to -3.834 and sever at stroke 10. Head 50 to 41.851, chest 100 to 95.848. Dropped ground sword count 1. | blood true, no death | `fast01/SCHEDULER_RUN.json` |

Each run has `result.json`. Visual proof of a separated arm, detached sword and blood: `fast01/first_sever.png`. The unarmored/heavy pair used the same input and initial placement, but moving AI may change exact contact speed/point; it shows reduced residual head wound and no blood for this actual armored contact, not a fully controlled single-variable damage curve.

Death and fall remain **unverified**: the NPC did not reach a lethal head/chest threshold in these bounded natural attacks, so no native death observation exists. The current source implements `_npc_fall` through scripted rotation of a `CharacterBody3D` and hull after death; it is not an articulated ragdoll. No shield exists on this NPC, so shield drop is outside this fixture. No production files changed and no speculative mechanics patch was made.
