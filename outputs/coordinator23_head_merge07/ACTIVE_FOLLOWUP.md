# ACTIVE medical to anatomical head finish

**89 checks PASS, three original rigs,6.665s, exit0.** Exact frozen three-file merge from native800; all303 stage resources still hash-identical. No production change or new patch was required.

Each scenario creates a source Fire shotgun shot and sends it through the real native projectile producer to the torso. Source RNG selects the ordinary medical branch (HP1, ACTIVE ragdoll, eyes open). After180physics steps, the test samples the current physical bone frames. Heads have moved1.138 /1.137 /1.072m from their standing positions. A native TT ray from above hits the current original anatomical skin.

All three finish at HP0/final_dead with closed original eyes. The same16body and15joint instance IDs survive both transitions. Contact point/normal/native direction remain paired to the finishing ray. Max final joint errors0.376 /0.118 /0.925mm. Replayed medical and finishing receipts leave event count, HP and impulse unchanged; a disposed owner's replay cannot alter the final body. The existing ACTIVE final-confirm path does not apply initial medical impulse again.

ACTIVE_RECEIPT binds test inheritance, original800receipt, full stage pins and this result/log. ACTIVE_RUN01 records the exact command. ACTIVE_RESULT01 contains measured actor rows.

Limits: source Fire shot generation and real native rays are used with fixture-supplied muzzle; this is not actual player input or GPU. The inherited corridor disables the car and normal population. No loaded-scene perf claim; no new corpse impulse mechanic. candidate07, candidate08 and production were untouched.
