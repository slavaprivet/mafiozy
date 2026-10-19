# Минимальная LIVE-проверка времени суток в одной вкладке — 23 сентября 2026

Проверка не требует нового интерфейса и не меняет production-файлы. Она
использует одну уже открытую игру, существующие datasets, кнопку
`#night-toggle` и штатные `perfqa`/`isolationqa`.

## Что уже есть, а чего нет

- `window.Mafiozi3DBridge.getEnvironmentState()` возвращает авторитетные
  `hour`/`minute`; HUD показывает те же часы в `#gameClock`.
- После интеграции контроллер публикует `body.dataset.walkTimeOfDay`, а
  существующий `body.dataset.streetLighting` показывает фактическую мощность
  фонарей. При `perfqa=1` доступен `body.dataset.walkPerformance`.
- Существующая кнопка `#night-toggle` находится в
  `window.MafioziWalkShell`. После интеграции она переключает только QA offset
  `0 ↔ +12 часов`. Она подходит для проверки отделения offset от городских
  часов, но не может сама выставить 06:21, 17:00, 18:39 или 22:00.
- Параметра URL для точного времени и штатной паузы городских часов нет.
  `perfqa=1` включает замер, `isolationqa=1` — существующий автоматический
  renderer A–B–A. До интеграции `#night-toggle` напрямую меняет свет, поэтому
  результат day/night по ней принимать нельзя.

Один раз перезагрузить **эту же вкладку**, сохранив остальные параметры URL и
добавив `perfqa=1&isolationqa=1`. Вторую видимую или скрытую вкладку не
открывать.

## Точные контрольные минуты

В консоли страницы создать временный держатель исходных городских часов. Это
меняет только состояние текущего QA-сеанса; после перезагрузки исчезает:

```js
window.__walkClockHold?.stop?.();
window.__walkClockHold=(()=>{
  let target=_gameMinutes,timer=0;
  const write=()=>{_gameMinutes=target};
  return {
    set(hour,minute){
      if(!Number.isInteger(hour)||hour<0||hour>23||
         !Number.isInteger(minute)||minute<0||minute>59)throw RangeError('clock');
      target=hour*60+minute;write();clearInterval(timer);
      timer=setInterval(write,40);return {hour,minute};
    },
    stop(){clearInterval(timer);timer=0;return _gameMinutes;}
  };
})();
```

Последовательно вызвать `set(6,21)`, `set(17,0)`, `set(18,39)` и `set(22,0)`.
После каждого вызова ждать не меньше 4 секунд: фиксированный 250-мс опрос
успеет принять минуту, а палитра — стабилизироваться. Этот 40-мс держатель
нужен только для функциональных точек и одинаково работает во всех четырёх;
без него штатные часы продолжают идти по одной игровой минуте в секунду.

Минимальный readout без новой панели:

```js
const json=name=>{try{return JSON.parse(document.body.dataset[name]||'null')}catch{return null}};
console.log(JSON.stringify({
  source:window.Mafiozi3DBridge?.getEnvironmentState?.(),
  clock:document.getElementById('gameClock')?.textContent,
  time:json('walkTimeOfDay'),
  lamps:json('streetLighting'),
  perf:json('walkPerformance'),
  runtime:json('explorationRuntime'),
  freeze:json('renderFreeze')
},null,2));
```

Для каждой точки сохранить этот JSON и один кадр. `source`, `clock` и
`time.hour` должны обозначать одну минуту; rejected samples остаются нулевыми,
accepted samples растут не чаще четырёх раз в секунду. Ожидания:

- 06:21 — dawn около 1, daylight между 0 и 1, фонари ещё включены;
- 17:00 — фонари включены, `lampPower >= 0.48`;
- 18:39 — dusk около 1;
- 22:00 — night и `lampPower` равны 1.

После этих четырёх точек один раз нажать существующую кнопку через
`window.MafioziWalkShell.getElementById('night-toggle').click()`, проверить в
readout изменение только `stats.qaOffset`, затем нажать повторно и получить
offset 0. `source` и HUD-часы при обоих нажатиях не должны измениться.

## A–B–A в той же вкладке

Для общей стоимости дневного и ночного сценария использовать обычный игровой
кадр, не render freeze: freeze обходит главный update и поэтому не измеряет
`walkTimeOfDay.update/apply`.

1. Оставить героя неподвижным, зафиксировать положение камеры, разрешение,
   DPR, качество, тени, `npcWorld`, `vehicleFleet`, draw calls и triangles.
2. A1: `__walkClockHold.set(12,0)`, ждать минимум 5 секунд и до
   `walkPerformance.timings.frame.samples === 120`, сохранить полный
   `walkPerformance`, `walkTimeOfDay`, `streetLighting` и
   `explorationRuntime`.
3. B: `__walkClockHold.set(22,0)`, дождаться тех же 120 новых кадров и
   сохранить тот же набор.
4. A2: снова 12:00, дождаться 120 кадров и сохранить набор. Затем вызвать
   `__walkClockHold.stop()`.

При обычных 60 FPS пять секунд перекрывают rolling window в 120 кадров; явная
проверка `samples` защищает низкий FPS. A1/A2 принимаются только
при одинаковых камере, населении, машинах, draw calls, triangles и памяти.
Этот A–B–A измеряет **стоимость ночного сценария, включая фонари**, а не чистую
стоимость нового контроллера. Его `frame`, `interval`, `render` и агрегированный
этап `cullLights` сравниваются с средним A1/A2.

Отдельный renderer A–B–A для фонарей уже существует: на 22:00 нажать
«Зафиксировать 3D-сцену для замера», в панели isolation выбрать
«Без точечных источников света» и запустить проверку. Она автоматически пишет
baseline-before → variant → baseline-after в
`body.dataset.renderIsolation`. Это измеряет только вклад point lights в
отрисовку; update/apply во время hold не исполняются.

Штатного обратимого переключателя «legacy time ↔ integrated time» сейчас нет.
Поэтому чистый A–B–A накладных расходов контроллера без изменения production
провести нельзя; такой результат следует пометить `NOT RUN`, а не сравнивать
две вкладки или разные сборки.
