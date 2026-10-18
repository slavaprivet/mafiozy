# Ordinary castle combat on the published battlefield

Base: `1c4e4c6084dbc889cac3896ffc3aa3f43b458c47`, including battlefield `134fcdc7`.
Frozen D stage: `D:/MafioziCastle31/main1c4e4c60`; 833 copied source files verified against Git, zero blob mismatches. Scripts are independent copies; asset junctions are read-only. Import passed under the shared scheduler.

## Ordinary input evidence

- Spear `D:/MafioziCombat31/spear_current_qa31/native04`: PASS, exit 0, empty stderr. Ordinary castle contains BattlefieldSite. E at the rack, Q/5 selection, RMB aim and LMB release, real tip collision with NPC head, death, sticking and following the moving target. No manual combat-host installer. Charged screenshot reviewed.
- Armor E baseline `D:/MafioziCastle31/qa/baseline_graphical02`: defect reproduced at default camera distance, player only 0.549 m from the item but focus empty. Q/1 still creates exactly one combat host and selects the sword. This baseline script completes successfully because it expects the defect; it is not acceptance of the broken interaction.

## Narrow correction

The armor focus ray limit now includes the distance from camera to player plus the existing 2.6 m interaction reach. Player-to-item reach, occlusion and input-state guards are unchanged. This one-line change is independent of the unfinished armor22 visuals/controller optimization.

Exact-main plus this one-line candidate: `D:/MafioziCastle31/qa/focus_graphical04/SCHEDULER_RUN.json`, PASS exit 0/empty stderr, 10.37 s. Default camera distance 5.11957 m; E at 3.015 m rejected, nearby E equips light_head before any combat host, Q/1 creates exactly one host with the correct armor snapshot, repeated Q does not duplicate it, U removal clears the snapshot. Candidate controller SHA256 starts `863443D2`; all other scripts match the published base.

## Limits

The scene's initial 400-frame position correction can return a player who moves more than 25 m from the spawn. The spear fixture waited for it to end naturally; the map owner is preparing a separate real-input fix. No claim of general FPS acceptance or final armor22 acceptance is made here.

The ordinary sword swing generated 490 collision rays but did not hit the target; this is not body-contact acceptance. A separate medium_head stand attempt was obstructed before reaching the target and remains an armor-owner follow-up, outside the focus-distance fix. Bow ordinary-input validation is still in progress at this checkpoint.
