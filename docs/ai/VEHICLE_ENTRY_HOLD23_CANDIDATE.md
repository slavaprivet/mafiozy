# Кандидат: 0,3 секунды удержания E независимо от шага анимации

23 сентября 2026. Только isolated candidate и CPU regression. Production
файлы не менялись, браузер не открывался. Решение ждёт review root/transport
и сверки с готовыми пакетами Астра.

## Что предлагается

Новый `vehicle_entry_hold_clock23_candidate.mjs` содержит маленький clock
только для admission посадки/выхода. Два существующих hold-gate в Walk читают
`performance.now()/1000`; движение, переход через дверь, moving exit и физика
сохраняют прежний `dt=min(rawDt,.04)`. `advanceEntryHold` и source adapter API
не меняются; у adapter.advanceHold сейчас нет runtime caller в Walk.

Clock начинает отсчёт при первом наблюдении допустимого нажатия, не начисляя
время до E. Нужны непрерывные 0,3 секунды в допустимом состоянии. Готовность
появляется на первом следующем кадре; при 7 FPS точнее одного кадра UI стать
не может. Clock переиспользует один result object, не создавая объектов в кадре.

Разрыв между наблюдениями >0,5 секунды, обратный или нечисловой clock отменяет
удержание и требует отпустить кнопку. Это сохраняет работу при 7 FPS и не
позволяет уснувшему/замороженному окну автоматически посадить героя после
возвращения. При устойчивом FPS ниже 2 этот защитный порог намеренно требует
нового нажатия; проблему зависания нужно лечить отдельно.

## Минимальные будущие production hooks

1. Импортировать `createVehicleEntryHoldClock` из одобренного runtime файла,
   создать один `entryHoldClock` рядом с entryHeld/entryArmed.
2. В source-exit ветке заменить только вызов accumulator:
   `entryHoldClock.advance(pressed&&entryArmed, sourceVehicleState.phase==='driving', performance.now()/1000, EXIT_HOLD_SECONDS)`.
3. В общем local/source-entry и local-exit gate сделать тот же вызов с
   существующим eligibility expression и holdDuration. `entryHeld=hold.elapsed`
   и `hold.ready` остаются прежними, animation dt не меняется.
4. Добавить `entryHoldClock.reset()` в существующий `releaseControls()`.
   Его уже вызывают blur, document.hidden, pointerlock loss, меню и блокировка
   ввода. Они очищают E/pointerHeld; новая попытка начинает полный отсчёт.
5. Добавить reset в существующий E keyup, pointerup/pointercancel кнопки машины.
   Это обязательно: release/repress между двумя редкими кадрами иначе можно
   принять за одно непрерывное нажатие.
6. QA onRelease/onEntryHold(false) тоже должны сбрасывать clock, если эти hooks
   сохраняются; они не должны оставлять старый clock при повторном нажатии.

Перенос poll перед active-gate, уже сделанный root, сохраняется. Никакие
разрешения источника, seat identity, occupied checks и server receipts не меняются.

## Actual-function проверка

`test_vehicle_entry_hold_clock23_candidate.mjs` вырезает текущую настоящую
`updateCarInteraction` из Walk, заменяет в памяти только две строки accumulator
и выполняет четыре ветки: local entry, source entry, local exit, source exit.
Адаптеры внешнего действия подменены счётчиками; этот тест проверяет admission,
а не моделирует серверный успех самой посадки.

| FPS | Кандидат: секунды после первого наблюдения E |
|---:|---:|
| 7 | 0,4286 |
| 15 | 0,3333 |
| 30 | 0,3000 |
| 60 | 0,3000 |

Текущий runtime при 7 FPS разрешает действие через 1,0 секунду после первого
наблюдения (1,14 секунды, если считать с начала первого интервала кадра).
Все 16 комбинаций прошли. Дополнительно: короткое нажатие; release/repress
между кадрами; потеря eligible; actual blur/visibility release handlers;
20 секунд сна без focus event с требованием отпускания; actual E keyup и
pointercancel reset. Moving exit получает прежние .04, строки анимационного
накопления остаются побайтово прежними. `frame()` не менялся.

```
node assets/maps/city_rebuild_v1/test_vehicle_entry_hold_clock23_candidate.mjs
```

CPU PASS не является LIVE. После принятия: в единственной игре проверить E
при нормальном и низком FPS, отпускание до 0,3 секунды, Alt-Tab во время
удержания, вход/выход source и fleet машины. Производительность общей сцены
не проверена; ускорение hold не является повышением FPS.
