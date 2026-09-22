# NPC death variants20 — runtime handoff

20 сентября 2026. Source producer и pose presentation подключены после release19.

## Изменение

`npc_source_lifecycle.mjs` переносит explicit deathRecord только для фактической смерти.
`npc_actor.mjs` передаёт запись в новый `npc_death_presentation20.mjs`, NPC-only
`npc_death_pose20.mjs` получает подтверждённую cause и направление.
Строгий normalizer `npc_death_profile20.mjs` проверяет targetId, deathKey,
confirmed/fatal/eventId. Generic epoch или неизвестная причина оставляют прежнюю
Artist14 позу без изменений. Прямой HP0, nearby blast и recent hit не используются.

Шесть вариантов: bullet, melee, super, kick, dropkick, blast. Fire/vehicle/bleedout
пока используют прежнюю позу. Source producer сейчас подключён только к финальной
street hitNpc смерти после medicalDowned решения. Другие семейства ещё аудируются.

Выбор фиксируется при первом показе смерти. Поздний receipt не переставляет уже
лежащего NPC. До первого pose разрешена гидратация matching record. Direction
переводится из world в actor-local по yaw первого показа. Новый epoch/явный respawn
сбрасывают выбор. Optional deathPresentation save поддерживает legacy save и строгую
validation до изменения surface; запись копируется и замораживается. Raw clocks,
HP, корневое положение, hero pose, blood и транспортная source authority сохранены.

## Проверки

- `test_npc_death_integration20.mjs`:24 actual male/female cases PASS — source
  lifecycle/configure→actor, все6cause, save/recreate, wrongid/key/confirmation,
  malformed atomicrestore, legacy save, repeated/late records, respawn/new epoch.
- `test_npc_death_pose20.mjs`:12 actual GLB pose cases PASS; distinct cause shapes,
  unknown exactbase, первый recovery frame exactbase, no root/bone scale movement,
  actual skin floor около0, maxhandstep2.4–3.8см при60FPS.
- Recovery audit8/8, lifecycle, surface serialization PASS после интеграции.
- Paired CPU pose sample108:base p50/p95 1.364/1.576мс,
  profile1.349/1.611мс. Это изолированный CPU, не общая сцена.

## Осталось

Производительность общей сцены не проверена. LIVE/reload окно у19.
После settling groundPose продолжает сканировать skin;19 запросил exact local
floor correction cache, bounded isolated helper поручен автору оптимизации.
Blast parts пока isolated: pending budgeted bake, ground/seams/atomic runtime не
готовы. Vehicle exit→death имеет отдельный воспроизводимый handjump54см;
транспорт готовит fixture для следующего actor continuity patch20.
Сохранение между external lifecycle sync и первым pose имеет отдельную clock
ошибку baseline; subagent готовит минимальный совместимый fix, не считать решённым.
