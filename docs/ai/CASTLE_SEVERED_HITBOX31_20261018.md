# Detached NPC limb hitboxes — 2026-10-18

Component base63f771ec. After upper-arm sever, original upper-arm, forearm and hand bone colliders remained queryable although their visible skin became physical debris. A later spear could hit the invisible hand instead of the remaining body.

Scoped sword change disables the severed branch's original collision layers/masks, reusing the existing descendant mapping. Head/chest and detached physical debris retain their existing ownership.

D-only import and graphical check passed with empty stderr: D:/MafioziCastle31/qa/npc_corpse1376/stable_hitbox63f/import01/SCHEDULER_RUN.json and native01/result.json. The fixture uses a controlled upper-arm sever (not ordinary-cut acceptance), verifies upperarm/forearm/hand layers0 and head/chest1, then an ordinary spear throw hits the head and kills. Prior same-input phantom-hand failure was retained. No joint prototype is included. Patch SHA25670BB1E7A prefix; source pins in stable_hitbox63f/SOURCE_PINS.json.
