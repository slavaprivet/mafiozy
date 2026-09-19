# Profession interaction and crew pathfinding — 19 September 2026

Coordinator17 ongoing integration. User priority: reliable X interactions and crew pathfinding, readable selection, no visual quality reduction.

## Final interaction contract
X over a supported object orders the matching specialist; X on ground cancels unfinished work and rallies. V follows. Armed bombs and pending receipts retain their safety rules. X on an eligible hostile/neutral non-crew NPC focuses squad fire through existing damage rules; target death/despawn clears focus while independent combat threats remain. This focus command still needs live acceptance.

Latest user superseded full red tint: real geometry silhouette outline only. Red for ordinary specialist objects, white for vehicles, green while current task is working/awaiting/armed. NPCs, including own gang, retain original materials and only a lower selection ring. Contour implementation is under final performance validation before reload; do not treat the earlier tint screenshot as acceptance of this final appearance. Small safes/power panels receive a forgiving selection band with genuine line-of-sight checks; foreground panels take priority over a fence behind them. Registered car roots take priority over child Door names. A small centre dot shows command aim. Names and MY GANG badges are restored: fullscreen action-timer overlay was incorrectly treated as an opaque HUD mask.

## Physical approach and routes
Source NPC footprint is .18 tiles = .738 metres, not .18 metres. Old close work anchors were unreachable. Authored offsets now fence .92m, power1.02m, safe1.34m, vehicle halfwidth+.84m; work approach tolerance .08m. Core accounts for height delta without widening the physical sphere. Vehicle work side is stable per rendered object and no longer flips as camera turns. Torch has a physical longer nozzle and contact-gated flame, tested with actual male/female actors at .92–1.09m without root teleport.

mercenary_route.mjs adds bounded incremental local paths for follow/rally/approach/retreat, retaining actual source/native collision and crew separation. See MERCENARY_CREW_ROUTES_20260919.md for budgets, CPU comparison, limitations and 100 selected tests. No global NPC routing ownership changed.

## Local showcase and diagnostics
Single user game has mercenaryqa=1. UI prepares genuine cage, power circuit, source-bound safe/money bag, damageable car and actual hired specialists; wounded bruiser is a real downed member. QA-only rescue deadline persists without extension across reload; Prepare resets only this test bruiser from hospital, keeping identity/equipment. Combat QA target is excluded from adoption. Source diagnostics appear in body.dataset.mercenaryShowcase at 1Hz, including member positions, current actions, work anchors and object receipts. Inspect buttons aim using the hero-follow camera pivot, so the next frame does not recenter away from the object.

## LIVE receipts so far
Single IAB tab2 preserved. In session QA-MERCENARY-1789844066917, X cut_fence produced cut=true; engineer disable_power then produced powered=false. X on patient showed Поднять союзника; medic raised Sofia Mancini from hp0/downed to hp35/active. The second manual safe command again ended without opening; debugging movement remains mandatory. A bomb command also remained in approach and car HP stayed240. Own squad names visible again. Enzo Romano safecracker is present and command unlock_safe has been dispatched; safe completion is still pending at this writing. General scene performance not measured in matched A/B; source CPU tests are not FPS acceptance. User also plays during the checks, so do not attribute every input to root.

Final NPC-no-red and wider compact-object selection are in source but require next combined reload. Artist17 has a separate READY NPC route/traffic package for that reload. Root did not stage or commit the broad dirty workspace.


## Additional user steering, source-ready pending combined reload
HP decrease before work completion cancels unarmed work without effect/reward; death already cancels, armed and sent receipt states remain independent. Medic does not automatically restart a damaged task; next V/X releases hold. C/Z mirrors the accepted source player stance through existing crouching/prone snapshot flags, movement speeds1.5/.65m/s; downed/specialist pose has priority. No global NPC actor/clock edits. 114 selected tests passed. Actual source V-after-revive regression now reaches follow goals for medic and bruiser; route heuristics improved and bounded search progress no longer falsely triggers 10s blocked timeout; absolute40s cap retained.
QA getMember.movement exposes search progress/path index/goal/reason/last completed-or-cancelled action. Root includes this and posture in showcase DOM dataset for forthcoming LIVE diagnosis.
Near-door highlighting module connected only to existing approved entry candidate and <=1.3m outside-door entry distance, white outline; same four seats and E0.3s preserved. Tests14 for integration/outline/door passed before further async outline optimisation; performance sharedscene remains unverified.
