# Actual София12 — устаревшая pending цель, 23 сентября2026

IMPLEMENTED / CPU TESTED / READY. После isolated reproduction координатор20
разрешил ровно описанную одну строку для следующего общего LIVE-пакета.
Она внесена в world.html. После этого runtime freeze до SHA; никаких расширений.
Название файла сохранено для прежних ссылок. LIVE этого изменения ещё не принят.

`node test_empire_escort_retarget23.mjs --require-fixed` исполняет fixed crew
branch дословно из текущего world, без подмены fixed source. PASS: pending goal,
одна заявка, сохранение обеих очередей, generation4/targetKeysofia,8кадров без
чёрна цели, next-slice rebuild,near drift/otherowner/combat/panic.
После production повторно PASS escort cancel, empire pending19/19,check_world7.

## Фактический вход

Штатный export `C:/Users/Слава/Downloads/npc-inspection-1790116199540.json`,
capturedAt2026-09-22T22:29:59.531Z. `empire_crew_sofia_12`:

- position33.39145238586954/74.38497662929882;
- pending goal30.5/72.5,kind empire_escort,radius.75,limit6000,targetKey sofia;
- current formation target27.5/80.5 — сдвиг8.544cells (~35.03м);
- age46.090s,32expanded/45visited,6workQuanta,restarts1.

Босс София в тот момент шла28.763414634146336/78.5. Старый IDsofia25 после
reload отсутствует; его не подменяли новым ID без явного описания.

## Причина и одна строка candidate

Готовый escort route пересматривается при goal drift>5.2cells. Pending route
игнорирует тот же drift, поскольку вызов планирования закрыт `!_empireRouteQueued`.
Даже ушедший далеко босс не обновляет цель уже идущего поиска.

Только в мирной crew branch заменить условие перед `_planEmpireRouteTo`:

```js
if(!n._empireRouteQueued||n._empirePendingRoute?.kind==='empire_escort'&&Math.hypot(n._empirePendingRoute.goalR-target.r,n._empirePendingRoute.goalC-target.c)>5.2)
```

Заявка coalesce через существующий `_planEmpireRouteTo`: сохраняется место
в очереди, единственная заявка, привычные4мс/8допусков,0новых поисков за кадр.
Следующий уже разрешённый slice перестраивает frontier по штатному key.
Сдвиг<=5.2, одинаковые цели, combat/panic и другой request.kind не затронуты.

## Проверки и результат

`test_empire_escort_retarget23.mjs`: actual crew/pump/planner с captured Sofia12
позициями и контролируемыми open predicates. Baseline сохраняет30.5/72.5;
candidate обновляет27.5/80.5. Очередь не дублируется, идентичная цель8следующих
кадров не заменяет request; следующий slice меняет frontier один раз.
Near drift, другой owner, hostile, melee, panic сохраняют заявку.

`test_empire_live_route_replay23.mjs` — actual native planner с настоящим
GLB/entry old_town_narrow_townhouse_v1-017. Обе цели проверены в одной и той же
геометрии этого здания. Остальные здания — static snapshot; это не full LIVE.

- Старый actual goal:5834expanded/6000visited,133slice,~539msCPU → EMPTY.
- Current formation goal:13expanded/35visited,3slice,~11.53msCPU → READY.
- Готовый путь48.785м;0заблокированных сегментов. Actual `_npcAdvanceRoute`
  проходит его за10.571симулированных секунд, arrives точно27.5/80.5,
  максимальный шаг.168571cells, без телепорта. Босс/препятствия в replay неподвижны.

Ранняя версия стенда неверно считала цель сплошным building AABB. Это исправлено
в самом replay: для каждого actual goal загружается именно GLB нужного instance,
геометрия дверей и пол. Текстуры отключены только в CPU загрузчике. Нельзя
использовать ранние `blocked goal` результаты как доказательство дефекта LIVE.

## Другие наблюдения из того же экспорта

- resident205 walking walk, resident206 walking building_entry,
  resident207 pending walk227ms. Это snapshot, не многократный LIVE A/B.
- Nico неpending, backoff2669ms после failed patrol к25.64710643/148.93801955.
  Actual pavilion002 endpoint free, но терминальные подходы отсутствуют → EMPTY
  за2slice. Непрерывный старый8минутный pending не воспроизведён этим snapshot.
- Marat6 current formation target находится~.2cells от самого охранника, а
  stale pending goal внутри bookmaker002. Это покрывает предыдущий готовый
  cancel-direct/arrival patch, пока не включённый в этот LIVE reload.

## Файлы/воспроизведение

- test_empire_escort_retarget23.mjs
- test_empire_live_route_replay23.mjs
- outputs/empire_escort_retarget23_candidate.json
- outputs/empire_live_route_replay23.json
- outputs/empire_live_route_replay23_retarget_candidate.json

Команды (read-only к исходному экспорту, записывают только output reports):

```text
node test_empire_escort_retarget23.mjs
node test_empire_live_route_replay23.mjs C:/Users/Слава/Downloads/npc-inspection-1790116199540.json unique_niko empire_crew_sofia_12 empire_crew_marat_6 --current-target
node test_empire_live_route_replay23.mjs C:/Users/Слава/Downloads/npc-inspection-1790116199540.json empire_crew_sofia_12 --retarget-escort --walk-result
```

Производительность общей сцены не проверена. Точные очереди/фронтиры/движущиеся
цели и автомобили не сохранены в export; CPU скорости не равны LIVE ожиданиям.
