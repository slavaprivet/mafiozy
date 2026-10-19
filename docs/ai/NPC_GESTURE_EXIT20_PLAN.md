# Плавный выход help/talk — prototype20, 20 сентября 2026

**Последнее состояние: интегрирован после отдельного разрешения root и
освобождения actor2. Актуальный итог `NPC_GESTURE_EXIT20_HANDOFF.md`.
Ниже сохранён исходный prototype plan; его NOT INTEGRATED исторический.**

**PROTOTYPE / NOT INTEGRATED. Production `npc_actor.mjs` не изменён.**
Координатор20 запретил запись actor до освобождения участка Проверщиком2:
тот переносит phone/cash, surrender, visual update/dispose/diagnostics.
После bounded READY автор этого прототипа ждёт нового назначения scope.

## Подтверждённая проблема

Снятие `helping` / `talking` сразу обнуляет gesture и gestureBlend.
На actual male/female GLB рука за один кадр перескакивает на 42–55 см.
Ранее измеренные 87–92 см относятся к **phone**, который в этот патч
не входит. Его семантика и реквизит остаются у Проверщика2.

## Минимальный план после освобождения actor

Три точки изменения внутри `createNpcActor`, без новых production helpers:

1. Рядом с `gesture/gestureBlend` добавить отдельные поля outgoingGesture,
   outgoingAt, outgoingBlend, outgoingPoseTime, lastGesturePoseTime и
   lifeGestureApplied. Все private для одного actor, без props/meshes.
2. Перед обычной сменой gesture проверить допустимость спокойного выхода.
   Только переход из **реально применённого** generic help/talk в null
   запоминает предыдущий вес и фазу. Исходный logical gesture всё равно
   немедленно становится null. Это не задерживает mercenary/social/police
   и не продлевает source state.
3. После существующего вызова `applyLifeGesture` фиксировать факт/время
   действительного применения. Отдельно на спокойном выходе вызвать тот
   же pose с сохранённой фазой и весом
   `oldBlend * (1 - smoothstep(age, 0, 0.3))`. Через 0.3 с выйти в точную
   обычную позу. Дополнительных событий, таймеров AI и source writes нет.

Уточнение после root review: outgoingAt берётся **из lastGesturePoseTime**,
не из `time-dt`. Восемь actual-GLB регрессий (male/female × help/talk ×
gap1/5 секунд) с `dt=1/60`, но скачком абсолютного snapshot.time, проверяют
отсутствие воспроизведения давно закончившегося жеста после пропуска
наблюдения/возврата actor. Во всех новый кадр совпадает с neutral baseline.
AI таймеры не меняются; используется существующий presentation timestamp.

Дословный executable prototype всех трёх замен находится в начале
`assets/maps/city_rebuild_v1/test_npc_gesture_exit20.mjs`. Он подставляет
actor только через Node loader hook, не пишет production. Каждая замена
требует ровно одного исходного anchor и останавливает тест, если чужой
перенос изменил этот участок: запрещён слепой перенос старой версии файла.

После phone/cash переноса владельцем тест дополнительно поддерживает
новый reviewed anchor с `gesture!=='phone'`. Этот guard сохраняется в
prototype; новая phoneVisual продолжает полностью владеть телефоном.
Production actor и phone helper автор прототипа не редактировал.

Разрешать outgoing только при отсутствии busyLife, weapon, escaping,
moving, requestedGesture, activity, seat, profession/mercenaryAction,
policeObservation, hijackReaction и воды. При появлении любого из них
сбросить outgoing **до** применения позы в этом же кадре.

Отдельный важный guard: lifeGestureApplied. Когда `life.talking` ещё true,
но social activity владеет анимацией, generic talk не применялся. Нельзя
внезапно создавать его outgoing pose при завершении social activity.
Эта отрицательная регрессия включена в тест.

## Проверки actual GLB

`node assets/maps/city_rebuild_v1/test_npc_gesture_exit20.mjs` — PASS,
примерно 1.64 с весь процесс, без browser/GPU.

| Жест/модель | Частота кадров | Максимальный шаг руки до, м | Прототип, м |
|---|---:|---:|---:|
| help male | 60 | 0.4252 | 0.0354 |
| help female | 60 | 0.4492 | 0.0374 |
| talk male | 60 | 0.5204 | 0.0432 |
| talk female | 60 | 0.5497 | 0.0457 |
| help male/female | 10 | 0.4274 / 0.4515 | 0.2058 / 0.2174 |
| talk male/female | 10 | 0.5260 / 0.5556 | 0.2533 / 0.2675 |

Первый шаг при 60 FPS 3.9–5.0 мм. Через 0.3 с bone matrices совпадают
с прежней neutral позой; logical lifeGesture во время fade уже null.
На 10 FPS движение распределено всего на три кадра: улучшение измерено,
но идеальной плавностью это не объявляется.

26 проверок приоритетов (13 сценариев × 2 модели): после начала fade
на следующий кадр combat/punch, flee, panic, движение, cuffed, surrender,
новый talk, shop, seat, profession action, mounted weapon, source stun,
death. Во всех максимальная разница мировых bone matrices относительно
немедленной production реакции равна **0**. Проверены source root/yaw и
сохранение parent установленного оружия. Дополнительно phone exit и
завершение social-owned talk остаются идентичны production.

## Стоимость и ограничения

Лёгкая диагностика на тех же двух rigs и кадрах выхода: 128 samples
каждого варианта, измеряется actor update вместе с identity assertions.
До p50/p95 **0.0619 / 0.1041 мс**, prototype **0.1473 / 0.2538 мс**.
Это дополнительная работа IK во время короткого выхода, а не оптимизация.
Затем outgoing прекращается полностью. Новых ресурсов THREE/геометрии
патч не создаёт, но использует существующий allocating `applyLifeGesture`.
После освобождения actor оптимизацию scratch этого helper обсуждать
отдельно с его владельцем, не смешивать с текущим crime переносом.

**Производительность общей сцены не проверена.** LIVE, внешний вид
и несколько одновременных выходящих из жеста NPC должны быть проверены
Художником19/Координатором20 в согласованной существующей игре. Прототип
не загружен в игру; его PASS не означает готовую интеграцию.
