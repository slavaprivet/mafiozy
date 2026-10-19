# Attention31 resume — frozen patch

Root may integrate only `patch/scripts/city/runtime/npc_threat_life30.gd` and
`patch/scripts/npc_visual/npc_attention29.gd` after checking `PATCH.json` base SHA.
No shared game, F5, release56, population or Git changes were made by this owner.

## Proven causes and change

1. RECOVER was a terminal stationary state until quiet15 expired. Repeated genuine
   visible-weapon observations extended quiet15 without returning to FLEE. A
   continuously observed weapon therefore kept the resident in place indefinitely.
   RECOVER now rests for two seconds and retries the existing bounded physical flee
   only if an authentic observation was delivered within the previous second.
   Each retreat retains the existing three-attempt, eight-second-per-leg and work
   budgets. This is not a promise that an obstructed resident moves within2s: it is
   a bound on the RECOVER state before another physical attempt.
2. ALERT and RECOVER performed only a native hold, without turning. They now turn
   smoothly toward the known observed point. They never read an unseen player's
   live position. Anonymous auditory events do not identify/track the player.
3. A blocked OUTBOUND driver can be inactive while the outer economy owner stays
   in EXIT_RETRY. Attention's pause then fails and previously returned before
   turning. It now turns but returns false, taking no movement hold and leaving
   the service/retry dispatch running. Under threat RELEASE_SERVICE similarly
   turns only while stationary, and still yields to the existing service owner.

LowHP/hospital, hit-stagger, combat, death and exact-life checks precede new
turning/retry logic. Flee remains ordinary speed multiplied by1.10. Quiet remains
15 seconds after the latest authentic observation. Normal attention retains its
prior movement-hold contract. Passage/collision changes belong to services owner.

## Native proof

`runs/baseline03/RUN.json` and `runs/candidate03/RUN.json`: PASS, no stderr, source
or harness drift. The same frozen fixture runs real World delivery/authenticity,
Threat, Attention, service wrapper and native capsule/route with controlled health
and service state. Baseline explicitly expects the three reproduced failures.

Baseline: continuously renewed RECOVER moved0m and all three tested headings
stayed0rad. Candidate: first native step on frame121 at60Hz, distance7.722m over
6 simulated seconds, maxstep0.033m, heading1.493rad after0.5s (target PI/2).
`Engine.is_in_physics_frame=true`, native delta1/60. All configured native drivers
and real focus camera ray passed. Tests also cover old-observation no retry,
quiet15 boundary, +10% speed, unidentified shot, medical/hit/death/generation
priority, service dispatch not held, and nearby wait-cohort exclusion.

Earlier baseline01/candidate01/candidate02 are preserved failed harness runs.
Missing surface metadata and headless cursor capture were corrected; the old
tick helper called movement after process_frame, giving rendering delta to
move_and_slide. Final fixture executes in the physics frame and does not lower
the movement-distance gate. Baseline02 used that old helper and is superseded.

## Remaining acceptance

Full city actual weapon/presentation validation is separate. Prepared
`entry_visual31.gd`, `observer_visual31.gd` inspect actual body, presentation and
skeleton yaw under a natively perceived Golden Colt; no NPC position, HP or threat
event writes. `run_city31.py` can run visual and inherited actual threat10 tests
read-only through the scheduler after root integrates. These are functional,
never performance acceptance. Wait-cohort code was inspected but not changed:
it excludes nearby player/camera within25m and caps eligible waits at100ms.

The live screenshot identity and exact cause of its historical41-dollar wait
are not established by this fixture. It proves concrete reachable mechanisms;
services deadlock and full-city long-term acceptance remain separate.


## Actual-city follow-up: rigid capsule drift proved and fixed

Frozen additional package: `yaw31/PATCH.json`, `yaw31/patch/`, `yaw31/HANDOFF.md`.
Baseline merged01 run `runs/merged_threat_diag03` failed ordinary return: 119 due choices/roam attempts, IDLE, no focus/health/owner block, unit-capsule admission rejected scale(0.999981,1,0.999981). Earlier full run kept this for200seconds.
`runs/yaw_threat_overlay01` changed only two stationary yaw helpers to rigid Basis(UP,yaw): complete actual native Golden/TT visibility, aim, miss, flight, phone,15secquiet, completed ordinary activity, actual nonfatal hit and another ordinary activity. 17/17PASS, exit0, source/harnessdrift0, stderr0. Observed capsule scale1 and configuretrue after recovery. No NPC placement, HP or route writes.
`runs/merged_visual03` independently proves actual rendered model/skeleton orientation and recover retry in merged01 before the yaw correction:11/11PASS; bodyerror0.01663rad, visible/skeletonerror0.03539rad at0.65sec,4viewportPNGs. Screenshots alert/recover visually inspected. It selected a moving life before its first native step; initial spawn yaw became backwards to QAplayer, so the native event was correctly delayed until the next leg. Earlier visual01/02 event timeouts preserved. The harness now waits for actual velocity>1m/s before placing its QAplayer; this robustness change has not yet been rerun. No game logic modified for the setup.

All production files frozen; root integrates and owns final merged/performance acceptance. No current native child or read lease remains at this handoff.


## FINAL exact merged02 acceptance

Root integrated both yaw31 and the independently tested exterior-envelope guard. Final exact game57 without overlays:
- `runs/final_merged02_threat01`:17/17PASS,79.10s, native HP60→36 (TT24), flee7.88108m, speed1.979945m/s, phone237frames,15secquiet, ordinary walk completed and post-hit AMBIENT completed. All ordinary capsule probes remain valid/unit scale. Post-hit nonzero walking speed was not sampled in this exact run; previous yaw overlay measured1.80032m/s.
- `runs/final_merged02_visual01`:11/11PASS,45.57s, actual GoldenColt event, bodyerror0.01523rad and model/skeletonerror0.03150rad atALERT0.65s. Native phone, RECOVER and renewed physical FLEE. Five viewportPNGs all visually inspected.
Both runs exit0, stderr0, source/harness drift0; SOURCE.json and HARNESS.json equal between runs. Exact archives and hashes in FINAL_EVIDENCE31.json. No NPC position/HP/route edits; only QAplayer input/position and temporary observer cameras.
Graphical/headless leases released; production frozen. Full catalog287 preserved, active10+12staff. This is functional acceptance; root owns long soak and isolated FPS gate.

Read-only merged02 envelope/passage review found no blocking issue for10+12: current live resident/staff pairs only, world/player/door/hit masks unchanged, symmetric pairs cleared and weak owner refs. Actor/member views clear each physics frame;22actors are below32/zone cap. Planner checks future-point zone while native/avoidance use current-frame zone; no static collision bypass.

Photo limitation:03_phone.png is the first PHONE tick with the locomotion transition still visible. It is not visual proof of a committed telephone pose. The requested alert/recover/return photos are valid;237committedphoneframes are proven by the native threat receipt.
