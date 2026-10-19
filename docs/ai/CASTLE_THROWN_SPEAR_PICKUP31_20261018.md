# Thrown spear E pickup — 2026-10-18

Component baseline62ed6410, sword blob0ae09a4a966ce088e4918ab673d950ad639510bb. The ordinary input gate only allowed `_sword_grounded`; throwing sets `_unarmed` instead. Existing pickup implementation already supports `_unarmed`.

Baseline `D:/MafioziCastle31/thrown_e_baseline31/THROWN_SPEAR_E31.json`: ordinary Q spear, RMB+LMB throw, WASD approach to1.158m, E while alive; spear stayed on ground and player remained unarmed.

Candidate one-line gate accepts either state, preserving the catapult interaction guard. Import `D:/MafioziCastle31/thrown_e_candidate31_import/SCHEDULER_RUN.json` PASS. Same native ordinary-input probe `D:/MafioziCastle31/thrown_e_candidate31_probe/THROWN_SPEAR_E31.json` PASS: approach1.273m, E clears unarmed, ground count1 to0, spear selected. Candidate sword blob dfe919da9ef581a441e2096324ea620c73af47c2. All native invocations through scheduler; isolated D source only before integration. No long combat or FPS acceptance claimed.
