# Удержание E 0,3 с при низком FPS — runtime интеграция

23 сентября 2026. Узкое исправление принято координатором после LIVE: у двери
Kingswell короткое E 0,2 с корректно оставляло героя пешком, но QA удержание
0,7 с тоже не начинало посадку; индикатор успевал накопить только 0,12 с.
Причина — накопление взаимодействия через анимационный `dt`, ограниченный 0,04 с.

## Изменения

`vehicle_entry_hold_clock.mjs` подключён к настоящему `walk_preview.mjs`.
Два существующих допуска посадки/выхода теперь читают `performance.now()/1000`:
source exit и общий local/source entry + local exit. Требования доступности двери,
места, серверного допуска и источник владения сохранены. Poll receipt остаётся
перед проверкой source active. `car_entry.mjs`, adapter API, физика, moving exit
и анимационный `dt` не менялись.

Начало отсчёта — первое наблюдение допустимого удержания. Отпускание E,
pointerup/pointercancel, QA onRelease/onEntryHold(false) и releaseControls
сбрасывают отсчёт сразу, включая release+repress между кадрами. Штатные blur,
document.hidden, pointerlock/menu release продолжают использовать releaseControls.

Разрыв наблюдений более 0,5 с во время уже начатого удержания, обратный или
нечисловой clock отменяет старое удержание и требует отпустить ввод. Первое
нажатие после простоя начинает новый отсчёт с нуля. Возврат после долгой паузы не вызывает
автоматической посадки. При устойчивом FPS ниже 2 порог намеренно отменяет
удержание: зависание сцены требует отдельного исправления. Один result object
переиспользуется, новых объектов на каждом update этот helper не создаёт.

## Проверка текущего production

`test_vehicle_entry_hold_clock23.mjs` исполняет **неизменённое** тело текущей
`updateCarInteraction`, настоящую инициализацию clock, actual keyup, button,
QA и releaseControls callbacks. Он не превращает старый код в candidate внутри
теста. Внешние действия посадки/выхода заменены счётчиком: тест доказывает допуск
взаимодействия, а не серверный успех посадки.

**100 сценариев PASS**: четыре local/source ветки при 7/15/30/60 FPS, короткое
удержание 0,2 с, потеря доступности, мгновенное отпускание+повторное нажатие,
keyboard/pointer/QA, blur/hidden/releaseControls, 20 секунд сна без focus events,
нечисловое/обратное время, запрет повтора без отпускания. Actual moving-exit и
entry transition получают прежний шаг 0,04 с.

| FPS | Допуск после первого наблюдения E, секунды |
|---:|---:|
| 7 | 0,4286 |
| 15 | 0,3333 |
| 30 | 0,3000 |
| 60 | 0,3000 |

Дополнительно PASS: `test_vehicle_entry_pending23_audit.mjs --require-fixed`
(offline exit / online exit / interrupted entry; его VM получил настоящий новый
clock), `test_car_entry.mjs`, `test_world_vehicle_player_access.mjs`, syntax
Walk/helper и `git diff --check` scoped файлов.

```text
node assets/maps/city_rebuild_v1/test_vehicle_entry_hold_clock23.mjs
node assets/maps/city_rebuild_v1/test_vehicle_entry_pending23_audit.mjs --require-fixed
node assets/maps/city_rebuild_v1/test_car_entry.mjs
node assets/maps/city_rebuild_v1/test_world_vehicle_player_access.mjs
```

Четыре code/test файла: Walk, новый runtime helper, новый production regression,
две fixture-строки в существующем pending23 audit. Старые candidate helper/test
не импортируются runtime и исключены из checkpoint. Актуальная передача заменяет
историческое предложение `VEHICLE_ENTRY_HOLD23_CANDIDATE.md`.

## QA trace и уточнение результата LIVE

Первый повтор LIVE после интеграции **не дал PASS**: после попытки QA hold 0,7 с
герой остался on_foot. У окна были timeout/focus события; root затем подтвердил
foreground frame interval p95 580,1 мс. Это риск ложной отмены текущим порогом
0,5 с, а не доказанная причина конкретной неудачной попытки.

При включённом car QA clock хранит максимум 16 наблюдений: стабильное удержание
не чаще 1 раза в секунду, дополнительно — смены pressed/eligible/ready/interrupted,
канала, release latch и события отпускания. Публикация через существующий
`body.dataset.carDrive.entryHoldTrace`. В активной source машине функция рано
возвращается, поэтому тот же ring доступен в
`body.dataset.sourceVehiclePlayer.entryHoldTrace`. Новых DOM queries нет;
вне car QA записи не создаются и поле не сериализуется.

Поля записи: `at`, `pressed`, `eligible`, `elapsed`, `ready`, `interrupted`,
`channel`, `gap`, `latched`, `reason`. Channel различает local/source entry/exit;
reason отмечает keyup, pointer-release, qa-release, qa-hold-release,
controls-release. История сохраняется при reset, чтобы не терять причину отмены.

Root review отдельно выявил и исправил проверяемый дефект helper: первая новая
попытка после длинного idle gap ошибочно считалась старым зависшим удержанием.
Теперь gap-порог применён только при `startedAt!==null`; до первого наблюдения
по-прежнему не начисляется время. Production regression добавляет все четыре
ветки idle/focus gap, QA trace limits/transitions/реальную публикацию DOM.

Отдельный сценарий **0,58 с foreground gap по-прежнему отменяет активный hold**
и требует отпускания; это явно зафиксированный текущий контракт, не утверждение
правильного пользовательского поведения в загруженной сцене. Held sleep 20 с
также отменяется. Порог 0,5 с не изменён до actual LIVE trace.

Последующее уточнение root: неуспешный CDP клик завершился deadline **до dispatch**,
окно было неактивно, trace оставался пустым. После отдельного visibility(true)
существующего окна реальный QA E 0,7 с начал посадку: state entering;
press at 503,1778, ready at 503,6093, elapsed 0,3, ready true, gap 0,2298.
QA release at 504,173 с gap 0,5637 произошёл уже после успешного допуска.
Этот trace **не подтверждает отмену посадки из-за порога 0,5 с**. Порог сохранён.
Завершение анимации и итоговый driving проверяет root отдельно.

## Синхронная готовность после отпускания

Отдельный actual-handler review нашёл крайний случай: admission выставляет
`entryArmed=false`, а QA timed() делает release→press до следующего кадра.
Clock сбрасывался, но entryArmed возвращался в true только при кадре !pressed.
Новая попытка могла оставаться заблокированной, если такой кадр не состоялся.

Все существующие release callbacks теперь синхронно ставят `entryArmed=true`:
E keyup, pointerup/pointercancel, QA release/hold(false), releaseControls.
Снятие блокировки само не допускает посадку: прежние clock, eligibility и
полные 0,3 с остаются обязательны. UI capture, очередность взаимодействий,
physics/animation dt и предел длинного кадра не менялись.

Новые actual-production сценарии сначала получают admission/disarm, затем
release+repress между кадрами и второй admission; отдельно pointercancel,
QA release, controls, blur и hidden. Четыре ветки проверены при 4 FPS с явным
временем событий: короткое E до 0,2 с не допускает посадку; наблюдения
0,24/0,49 и отпускание в 0,7 дают только 0,25 с подтверждённого удержания и
не допускают посадку. Продолжение удержания до кадра 0,74 допускает её.
При фазе кадров 0/0,25/0,5 допуск происходит в 0,5. Это честная дискретность
отсчёта от первого eligible-frame; время до него не выдумывается.

После этой узкой release/rearm правки: 100 hold-clock сценариев PASS,
pending23 --require-fixed все три режима PASS, Walk syntax и scoped diff check
PASS. После предыдущей версии car-entry/source-adapter тоже PASS; их production
не менялся. Финальную LIVE проверку последнего release/rearm выполняет root.
Сокращение задержки удержания не является заявлением о повышении FPS.
