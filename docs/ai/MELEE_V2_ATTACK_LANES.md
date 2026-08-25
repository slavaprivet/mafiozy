# MELEE V2 — attack-lane matrix

| Lane | Unarmed route | Armed route | Presentation source | Damage authority |
|---|---|---|---|---|
| Street civilians / angry residents | `_fightingMelee`, punch or 20% kick | `_fighting` only after a real/concealed weapon is assigned | shared NPC `_shotAt` + `meleeType` | local world NPC rules |
| Street hostile / business guards | melee when `weapon`/`_fightWeapon` is empty | existing weapon fire when present | shared NPC melee or weapon pose | local world rules |
| City cops / prison police | melee-compatible shared pose if unarmed | pistol/SMG/rifle/shotgun route | shared pooled NPC rig | server event for online targets |
| Gang NPC / empire crew / holding guards | shared punch/kick pose when weapon key is empty | authored unique/generic weapon pose | shared pooled NPC rig | existing gang/empire authority |
| Bosses | shared punch/kick when authored profile is unarmed | authored boss weapon/melee-weapon swing | shared pooled NPC rig | existing boss authority |
| Interiors (bank, business, major, HQ) | `_punchAnim`/`_shotAt` shared punch or kick | existing interior weapon route | same shared pooled NPC rig | existing interior/server checkpoints |
| Online players | `player_melee` only | `player_shoot`/weapon routes | predicted local pose + broadcast event | server-owned target, range, LOS, cadence, critical, armor/block and durable receipt |

Global gates: dead, downed, arrested/cuffed and prone attackers are rejected.
RMB block is valid only for a live, standing/crouched, unarmed player and only
while the held-input sequence remains active. Melee damage is reduced to 10%;
weapon damage does not use the melee block.

NPC bruises use one shared instanced mark per visible NPC (`NPC_CAP`). A mark is
shown from the stable hit timestamp, then hidden deterministically on death,
despawn or slot reuse. No materials, textures or meshes are created per frame.
