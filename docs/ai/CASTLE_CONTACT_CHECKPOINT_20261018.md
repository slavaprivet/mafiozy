# Combined castle contact checkpoint — 2026-10-18

Published base4d83ec20f004d69ed37e52c00529ac6c3aa3dc48 includes siege map, armor22/visual23, bow world tick and prior spear/vital fixes.

## Exact candidate and working launch

D:/MafioziCastle31/main4d83_candidate31; sibling main4d83_candidate31_SOURCE_PINS.json verifies770/770 tracked scripts/scenes plus project.godot against Git, missing0/mismatch0. Generated UID extras are recorded separately. Scheduler import main4d83_candidate31_import01 PASS37.64s exit0/stderr0.

Normal launcher tools/launch_castle_latest.ps1 targets shared outputs/coordinator31_npc57/game. Its armor controller/damage/visual/sword were older than the published main. After exact preflight hashes they were backed up to D:/MafioziCombat31/shared_sync_4d83_20261018_064109 and replaced with published4d83 bytes. SYNC.json records before/after hashes. Those four plus map site/props/main now match4d83 after newline normalization. No shared branch switch/reset; other WIP preserved. Existing running processes are not claimed to have hot-reloaded.

## Moving helmet collision

D:/MafioziCastle31/qa/armor23_eye_contact4d83_01 PASS exit0/stderr0. External fixture SHA D9BE8AB2B8171412D97D6FDF5B0AD8F9D3E7204CC4DEF784B4A71AB0CD9E1A82 derives targets from actual rendered mesh eye apertures, not from damage-region thresholds. Real physics rays across three controlled NPC positions/rotations hit actual Hithead. Both eyes resolve joint:20.8 damage and bleed; central nose resolves plate:6.471damage/no bleed. No sever. Uses production bow contact handler with true ray hit data, not free-flying arrows or autonomous NPC movement.

## Natural sword input

Initial72ce diagnostic used too much mouse movement and mismatched starting camera/player facing; no useful body-hit acceptance follows from its zero generic-hit counter. Bounded4d83 test uses normal Q selection, LMB and mouse motion; no direct weapon transform/sweep/damage calls. Separate per-part HP must be checked: global NPC HP and generic hit count alone do not measure part wounds. Final result below.

Natural frontal strike diagnosis: D:/MafioziCastle31/qa/natural_sword4d83_diag/run02 scheduler PASS exit0/stderr0. Read-only physics diagnostics see head14/forearm_r8 ray contacts and valid entry normals, but actual player_blocks increments1 and sparks16: production NPC blade barrier consumed the stroke. Part-HP dictionary remains empty. This is successful ordinary-input steel parry evidence, not a body-wound acceptance. No damage/collision thresholds changed to make the test pass.

One exposed-side run on the same immutable source: D:/MafioziCastle31/qa/natural_sword4d83_side, scheduler PASS/empty stderr. Real Q/LMB/mouse, player starts +X1.05m, NPC AI and sword intact. Tagged read-only rays reach forearm_r14/hand_r1/head12/upperarm_r6; blade overlaps hitbox surface. Again steel-clash counter+1, sparks16, no part wound/bleed/sever. Natural unblocked wound remains UNPROVEN. These establish that production selects a steel clash, not that steel/body chronological occlusion is independently certified. Follow-up: verify first-contact ordering; current sweep tests steel before body rays and compares world-ray distances across samples. No mechanics changes based solely on these runs.

## Confirmed contact-order defect and narrow correction

Controlled baseline on exact4d83 proves a defect: body-only damages forearm; steel-first blocks correctly; body-first/steel-later incorrectly also blocks. Baseline raw stdout retained under D:/MafioziCastle31/qa/sweep_order4d83/run02; BASELINE_FROM_STDOUT.json is an explicitly reconstructed result because an intermediate fixture reused its output path. Do not treat that reconstruction as an independent raw run.

Candidate only changes sword sweep selection: find earliest steel-contact time by bounded10-step prefix distance search; compare with normalized body-ray hit time across blade samples. Steel wins effectively simultaneous contacts within0.001 tick fraction. A later steel contact no longer cancels earlier body damage. Existing damage values/input/armor logic unchanged.

Candidate source SHA256526787170AB1AA02D87A56A4490202E37D08417B26FE93FA2BA4F74155A07490; isolated stage D:/MafioziCastle31/sweep_order_candidate31 differs from exact4d83 in only this script. Import passed. Reusable regression added as scripts/tests/dsh_melee_contact_order31.gd, SHA7DB7CA4C2AE8EA92CBB523F922E248842EF65B7CEC18A5F309E2C6FAF54B3858. Run through scheduler with --script and -- --castle=1 --qa-out=<unique-D-directory> [--qa-source=<source-ref>]. Final run_final_reusable01 PASS exit0/stderr0: body-only and body-first wound with no clash; steel-first and tight-steel-first block without wounds. Earlier optional co-center test FAIL retained: its box face and blade radius did not define simultaneous contacts. Exact coincident-contact geometry is not claimed independently tested.

Unchanged natural-input replay on corrected candidate: D:/MafioziCastle31/qa/natural_sword4d83_candidate/run01 scheduler PASS/empty stderr. Same Q/LMB/mouse trajectory still selects earlier steel (blocks1/sparks16/no part wound). The correction fixes the demonstrated controlled ordering defect; this trajectory still does not prove an unblocked natural flesh wound. No input/damage tuning was used to manufacture one. Natural attack feel, unblocked wounds across angles and animated skinned cuts remain future acceptance work.
