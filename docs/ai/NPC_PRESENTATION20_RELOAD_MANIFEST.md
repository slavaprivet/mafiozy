# NPC presentation20 — список для следующей загрузки19

20 сентября 2026. Это manifest текущих изменений, не LIVE приёмка.
Reload существующей игры/GPU окно ведёт Художник19. Родительский координатор20
сам новую GPU-вкладку не открывал. Actor20: перенос2 сохранён; recovery и death variants подключены, reload ведёт19.

| Пакет | Production файл | Статус и проверка после загрузки |
|---|---|---|
| Начало посадки | `assets/maps/city_rebuild_v1/npc_activity_pose.mjs` | READY, root diff reviewed, actual GLB CPU PASS. Наблюдать переход стоя→лавка и позднее появление уже садящегося NPC; угрозы/оружие должны немедленно прервать посадку. `NPC_SEAT_ENTRY20_HANDOFF.md` |
| Завершение чтения | `assets/maps/city_rebuild_v1/npc_social_pose.mjs` | READY, новыйactualGLB+старыйsocialsuitePASS после2pooledphoneassertion fix. Руки+книга до normalexpiry, bench occupation прежняя, threat immediate. NPC_READING_EXIT20_HANDOFF.md; LIVE/FPS pending |
| Выход обычного help/talk | `assets/maps/city_rebuild_v1/npc_actor.mjs` | READY, узкаяинтеграцияпосле2actorREADY.42–55см→3.5–4.6см при60FPS,26priority+8longgapPASS. Phone/cash/surrender сохранены, source timers не задержаны. NPC_GESTURE_EXIT20_HANDOFF.md; LIVE/FPS pending |
| Повторный stun/смерть во время подъёма | `npc_actor.mjs` | READY, audit8/8PASS; голова1.1м→<0.4мм при1ms. NPC_RECOVERY20_HANDOFF.md. LIVE/FPS pending |
| Причина и направление смерти | `npc_actor.mjs`, `npc_source_lifecycle.mjs`, новые `npc_death_*20.mjs` | IMPLEMENTED/TESTED: 6поз, source→actor/save24casesPASS, recovery/lifecycle/surfacePASS. Только street finaldeath producer пока даёт record. NPC_DEATH_POSE20_HANDOFF.md. LIVE/FPS pending |

Нет изменений draw calls у seat patch. Изолированные CPU измерения не доказывают
производительность общей сцены. Внешний вид и стоимость проверяются на той же
загруженной сцене после прогрева, без уменьшения числа NPC/качества/коллизий.

Capture/HQ20 не входит в presentation reload: native_site_control.mjs сейчас
не импортирован runtime, отдельный source вертикальный срез в подготовке.
