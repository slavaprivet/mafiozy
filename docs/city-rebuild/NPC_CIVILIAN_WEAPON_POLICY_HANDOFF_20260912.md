# Civilian firearm policy — 2026-09-12

User/Coordinator16 requirement: ordinary civilians have no guns; peaceful mercenary presentation is controlled separately by mercenary core while inventory remains.

Added npc_civilian_weapon_policy.mjs, mirrored exactly in world NPC_CIVILIAN_WEAPON_POLICY_START/END. Ordinary residents return visible weapon none even when stale source weapon/_fightWeapon is populated. Police/guards/bosses/gangs/explicit story and mercenary roles remain protected. Mercenary source weapon none stays none; inventory is not used as a display fallback.

World snapshot uses the policy; civilian counterattack chooses melee, and an old civilian _fighting flag is redirected before the generic fallback pistol branch. Source inventory/HP/IDs are not erased. npc_population uses the same policy for normalization and mounting. npc_actor and skeleton-sharing optimizer code were not changed.

PASS test_npc_civilian_weapon_policy.mjs: actual world trigger function, civilian stale gun→melee, no inventory mutation, protected guns retained, none mercenary retained, normalized civilian melee and armed police separate. PASS existing test_npc_population.mjs21/21, including actual actor weapon, gait, culling/eviction and lifecycle regressions. PASS full world inline syntax.

CPU72 mixed snapshot rows,100 iterations/window,20warmup+100measured: new policy p50 0.0252ms,p95 0.0383ms per72-row batch. This is standalone CPU policy cost, not full-frame/FPS comparison; no GPU run. Coordinator owns mercenary draw/combat transitions, so those gameplay transitions were not reimplemented here.
