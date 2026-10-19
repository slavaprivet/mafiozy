# Armor22 integration checkpoint — 2026-10-18

Base main a0b6cd2dbedfa5714d29207a0bb7b23684db8941. Owner package D:/MafioziArmor22/package/MANIFEST.json: all 22 hashes verified. Integrated three modules and narrow sword patch, preserving prior spear, arrow and vital-wound fixes.

Merged independent stage: D:/MafioziCastle31/armor22_candidate31 (CANDIDATE31.json SHA prefix DA084C1A). Four changed scripts match publication sources after line-ending normalization.

## Verification

- Scheduler import PASS, exit0/stderr0: D:/MafioziCastle31/qa/armor22_import01.
- Damage matrix 97/97 PASS: D:/MafioziCastle31/qa/armor22_matrix_merged01.
- Live contact checks 20/20 PASS: D:/MafioziCastle31/qa/armor22_live_merged01.
- Ordinary default-camera E/Q PASS, exit0/stderr0: D:/MafioziCastle31/qa/armor22_lazy_fixed01. Far E rejected; light helmet equipped before combat host; Q1 creates exactly one host; replacement medium helmet and removal update its snapshot.
- Original lazy01 fixture FAIL retained: its far position was within reach of another stand. Only external test position corrected, production unchanged.

Armor and displayed pieces are committed together; default peasant is unarmored. Plate transmits trauma without automatically producing an open wound or severing. Eyes/neck and uncovered regions remain vulnerable. NPC replacement clears old wounds and armor; severing removes attached armor pieces.

## Limits

Damage scripts exercise live contact methods, not independent mouse combat. Player contact mapping still uses a broad capsule; skin cuts still have bind-pose limitations. This checkpoint does not certify complete dismemberment realism or battlefield performance. Owner visual23 work is separate. Bow-selected world simulation fix is pending a separate checkpoint.
