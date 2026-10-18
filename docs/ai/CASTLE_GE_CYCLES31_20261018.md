# Ordinary castle G → E pickup cycle, four weapons

Frozen isolated D stage: `D:/MafioziCastle31/main07bb_ge_cycle31`; exact published source `07bb6804c7f6c25ce8c7164285d0588aedcf374b`. Manifest `D:/MafioziCastle31/main07bb_ge_cycle31_SOURCE_PINS.json` verifies 779 tracked scripts, scenes and project files, zero mismatches; asset junctions are read only. Scheduler import PASS `D:/MafioziCastle31/main07bb_ge_cycle31_import/SCHEDULER_RUN.json`. Shared game and user F5 were untouched.

External ordinary input fixture: `castle_ge_cycle31.gd`. Each independent graphical scene used Q card to take the real rack item, G to drop it (shield uses held RMB+G), E to pick it up. No direct `interact`, `_claim_display`, `_spawn_fallen_display`, `equip` or manual damage was called. The fixture checked carried/fallen before and after, physical `RigidBody3D` and collision shape before E, body removal after E, equipped selection and inventory capacity.

| Item | Native result | Floor distance | After E |
| --- | --- | ---: | --- |
| Sword | `D:/MafioziCastle31/ge_cycle_sword31/CASTLE_GE_CYCLE31.json` PASS | 1.27 m | selected sword, carried sword, 1 slot |
| Shield with sword | `D:/MafioziCastle31/ge_cycle_shield31/CASTLE_GE_CYCLE31.json` PASS | 1.27 m | selected sword and equipped shield, carried both, 2 slots |
| Bow | `D:/MafioziCastle31/ge_cycle_bow31/CASTLE_GE_CYCLE31.json` PASS | 1.30 m | selected bow, carried bow, 2 slots |
| Spear, two handed | `D:/MafioziCastle31/ge_cycle_spear31/CASTLE_GE_CYCLE31.json` PASS | 1.27 m | selected spear, carried spear, 2 slots |

Each folder contains `SCHEDULER_RUN.json` with exit 0. In all four, G removed the item from carried, added fallen and spawned a colliding rigid body; E removed the body/fallen and restored carried. No new source patch was needed.

After these cycles, one bounded 36 s mixed smoke ran through scheduler on the same stage: `D:/MafioziCastle31/main07bb_mixed_smoke31/MIXED_COMBAT_SOAK31.json` and `SCHEDULER_RUN.json`, exit 0 with no fixture failures. It used real sword input, fired one bow shot, dropped bow through G, selected spear and recorded one real spear throw. NPC attacked/hit 13 times; wounds and bleeding were observed. The player was dead by the end, so this is a short component coverage result, not a long combat or FPS acceptance. No 120–180 s soak was run.

The mixed fixture still writes the literal `source: main60001` label from its earlier version. The authoritative source for this run is the scheduler command `--path D:/MafioziCastle31/main07bb_ge_cycle31` plus the zero mismatch 07bb source manifest above. Fix that fixture label before any later soak.