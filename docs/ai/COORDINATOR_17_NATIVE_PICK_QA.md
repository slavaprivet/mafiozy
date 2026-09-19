# Native terrain picking: natural hover QA

13 сентября 2026. Root17 поручил UI и low-cost measurement; native terrain ray index и его walk_preview integration принадлежат `mercenary_input_audit`. Этот patch не меняет walk_preview/render_freeze_qa и не открывает GPU/браузер.

## Запуск

На текущем локальном игровом URL добавить `perfqa=1&nativepick=1`. `mercenarypickqa` должен отсутствовать или быть не `1`: detailed wrappers переводят native fast path в fallback; при этом флаге новый QA helper намеренно не создаётся. Разрешены localhost/127.0.0.1, без account/auth URL параметров, как у существующих local QA controls.

Кнопка `#native-pick-qa` находится на top274px и переключает source `window.MafioziNativeTerrainPicking.setEnabled(bool)`. Startup ON устанавливает native owner; QA не делает начальный toggle. Дождаться города и отряда, оставить обычное наведение и одинаковую камеру/население. **Не включать hold:** в нём natural hover не выполняется и новые samples не появятся. Кнопка не вызывает synthetic rays, не меняет частоту .25s и не управляет renderer.

`document.documentElement.dataset.nativePickingHover` — JSON:

- `mode`: on/off/waiting; `generation` source и `revision` локального замера.
- `samples`: успешные разрешённые natural hover attempts в текущем mode/generation; отсутствие выбранного target тоже допустимый sample.
- `blockedSamples`: блокировка gameplay, открытый разговор или отсутствие бойцов. Такие нули исключены из p50/p95. `failedSamples` — отдельно исключённые исключения.
- `windowSamples`, `capacity:120`, `p50Ms`, `p95Ms`, `lastMs`: whole hover от guard/roster до source actions и selection, включая original pick. Это не чистая raycast стоимость. При пустом окне времена null.
- `source`: source.stats() для контроля native queries/fallbacks/build и числа meshes.

Fixed Float64Array ring120: O(1) запись при natural pick. Сортировка и source.stats/DOM publish максимум1Hz, дополнительно немедленно при toggle/generation reset. Подготовка QA, сортировка, source.stats и JSON выполняются вне измеренного whole-hover участка. Последняя опубликованная sample count может отставать до1с. Для сравнения дождаться одинакового числа actual attempts в ON/OFF. При steady4Hz окно120 соответствует примерно30с.

## Guards и ownership

Native owner подтвердил allocation-free `.ready`, `.enabled`, `.generation`. clear/build меняет generation; mode/API identity/ready/generation сбрасывают window/counters и отбрасывают начатый до изменения sample. До сборки/после clear кнопка disabled, mode waiting. Новый helper на том же document удаляет предыдущий; stale callbacks/dispose не изменяют source или DOM нового helper. Teardown снимает только свои listeners/DOM, source indices ему не принадлежат. Он не вызывает setEnabled при dispose и не восстанавливает чужое состояние после reload.

## Проверки

PASS `test_native_picking_qa.mjs`: local gate и QA-off zero source/timer/DOM access; 1Hz stats; ring120/percentiles; blocked/errors; toggle/reset; late source/clear/generation/API replacement; stale init/dispose. Actual createMercenaryWalk + Three: .24с →0 лучей, +.01с →1, далее ровно .25с; QA on/off одинаковые IDs/actions; кнопка не добавляет raycast; blocked и dispose не запускают поиск.

PASS `test_mercenary_walk.mjs` и `test_mercenary_picking_probe.mjs`. Helper только `native_picking_qa.mjs`; narrow import/init/natural-hover/dispose hooks — `mercenary_walk.mjs`.

**Производительность общей сцены не проверена этим агентом.** Родитель проводит LIVE A/B последовательно в единственной игровой вкладке.
