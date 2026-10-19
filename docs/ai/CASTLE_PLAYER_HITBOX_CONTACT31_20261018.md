# Castle NPC player hitbox collision

Base: Git `8e46cd69c0a70769de5f179434d7d116acd209f2`, sword SHA-256 `e5a892cc5d612d4feedd6ed4be7123d8040fd006ae0974e00f3a84893b9e2784`.
Only code change: `HITBOX8E_PLAYER_EXCEPTION.patch`, +5 lines in `_add_npc_hitboxes`; player and each tagged AnimatableBody3D become mutual collision exceptions. Layer 1 stays available to blade and projectile ray queries. Existing NPC and rigid corpse collision are unchanged. The player's physical collision with the real rigid corpse remains enabled.

Candidate: `D:/MafioziCastle31/main8e46_hitbox_candidate31`.
Pins: `HITBOX8E_SOURCE_PINS.json` (779 tracked scripts/scenes/project; missing 0, unexpected mismatch 0, only scoped sword override).

Native scheduler receipts:
- `hitbox8e_import01/SCHEDULER_RUN.json`: import exit 0, stderr 0.
- `hitbox8e_walk01/result.json` and `SCHEDULER_RUN.json`: real castle map and catapult death. All 15 tagged boxes in player exception list. Player direct path stopped on `SwordKnightCorpse31` (182 slide contacts), zero AnimatableBody3D slide contacts; side route passed. A direct line through the narrow gap remains obstructed by the real body, which is intended. The shape query still lists tagged hitboxes because queries ignore player-specific collision exceptions; this is not a player-motion blocker.
- `hitbox8e_natural01/result.json`: normal Q1 then LMB/mouse swing on resident; 370 sweep rays, 42 ray hits, head part HP 50 to 47.50395; no NPC steel block, stderr 0.

Current shared sword has different SHA due to concurrent edits. Integrate the hunk, not the full file. Joint death work remains a separate D-only prototype and is not included here.