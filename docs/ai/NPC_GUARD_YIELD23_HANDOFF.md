# Hospital guard yield23 — isolated, not wired

Приоритет отложен из-за новых прямых поручений пользователя про resident needs
и автомобильные анимации. Production не изменён.

Files: root `npc_guard_yield23_candidate.mjs`, `test_npc_guard_yield23.mjs`;
report `outputs/npc_guard_yield23_candidate.json`.

27 contract cases PASS:1000ms query-free wait, no movement until atomic two-actor
lease acknowledgement, both-lock conflict (no partial acquisition), one500ms
backoff/two claim attempts,12 candidate limit,2048 total/64 per slice callbacks,
cooperative2ms,20s job/12s lease, owner/revision/generation/state/cancel/clock,
false arrival, expired/lost lease, blocked geometry, terminal no-retry, physical
body remains after lease expiry. Host must atomically commit both actor locks and
both target reservations, honour holdActors/stopActors/release and check each real
movement sweep. Helper emits intents and never owns the registry/actor positions.
No scheduling fairness or arbitrary moving crowds acceptance is claimed.

Actual hospital crowded slot1/step1, existing .34-cell source arrival follower:
15/7/5/3Hz 4/4 final arrivals,0unsafe/interior,81 physical steps total. Same second
candidate .8cell away from passage works across rates; source actual stop is
revalidated before waiting guard receives its route. No teleport/exact stop hack.
157–213 callbacks/job;maxslice2.55ms (cooperative callback/GC overrun), CPU whole
jobs3.54–10.91ms in recorded cold/small sequence. This is not wholecityFPS.
**Производительность общей сцены не проверена.** Root controls LIVE.

Trusted inputs select an existing owned site, actual actors and already-valid
post target. No new HQ, capture, identity grants, HP changes or source kind switch.
Current exterior wait/detour candidate remains4/6; this separate helper is not
integrated into it and does not upgrade that acceptance score.
