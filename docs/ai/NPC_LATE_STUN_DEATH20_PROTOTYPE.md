# Late expired stun + fresh death — bounded prototype20

**IN MEMORY ONLY / NOT PRODUCTION READY.** Runtime freeze соблюдён,
production actor/source/hero/surface не менялись. Отдельный production
recovery пакет из `NPC_RECOVERY20_HANDOFF.md` остаётся READY.

Новый `test_npc_late_stun_death_prototype20.mjs` проверяет 12 actual GLB
случаев: male/female × inline/external lifecycle × endedAge4/.1/0.
Основная коррекция проходит: late snapshot получает ту же authored pose,
что NPC с вовремя доставленным окончанием stun. Сырые source death ages0.

Причина: lifecycle приходит до обработки нового stun snapshot, и
continuity наследует старое `sourceDown.active`, хотя endedAge уже говорит,
что NPC успел подняться. Prototype допускает однократное уточнение bias
**до первого отображения смерти**, только по explicit active=false и
finite nonnegative endedAge. Из веса в момент окончания stun вычисляется
author recovery к истинному sourceDeathAt; ни HP, ни таймеры не меняются.
После первого death presentation уточнения запрещены. Без endedAge или
при active=true ничего не угадывается.

На endedAge4: male head0.2791→1.3587м, female0.3297→1.4352м — это
правильная upright стартовая поза новой смерти после давно прошедшего
stun, подтверждённая on-time reference, а не визуальное притворство.
Для endedAge.1 и0 сохраняется фактическая стадия recovery/lying.

## Почему весь prototype пока красный

Добавлен важный отдельный сценарий: source lifecycle синхронизирован
внешним вызовом atTime15, но actor.update ещё не был вызван, private
presentation time10. Если между ними сохранить actor:

- saved.surface.time=10;
- saved raw death age=0 (sourceDeathAt15);
- restore(time15, elapsed5) восстанавливает death age5, хотя death свежая.

Это воспроизведено на baseline **без нового mixed-case patch** и на
prototype: restoredRawDeathAge5 в обоих. Pending-held flag в optional
reactionVisual переносится, но этой информации недостаточно: исходная
ошибка абсолютного времени смерти уже случилась. Исправление persistence
clock contract нельзя незаметно смешивать с presentation-only patch.

Тест выводит `corePass:true`, `productionReady:false`, два unresolved
кейса (оба GLB), exit1. Это намеренно честный незавершённый prototype,
не regression интегрированного recovery и не PASS полного сценария.

## Необходимый review перед следующим шагом

Нужен отдельный согласованный persistence-контракт для externally synced
death до первой pose: например точное absolute sourceDeathAt в optional
payload или сохранённое отношение death-clock к snapshot time. Это
предложение, не реализованная правка. Root параллельно ведёт explicit
fatalrecord/causeprofile; границы state/callback/save следует согласовать.
Не менять source clocks или raw age в обход этого контракта.

Browser/GPU0. CPU/FPS/полная visual acceptance для этого незавершённого
prototype не заявляются. Производительность общей сцены не проверена.
