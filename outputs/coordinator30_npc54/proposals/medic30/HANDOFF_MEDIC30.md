# Medic30 — готов к scoped интеграции

Статус: **READY_SCOPED_NATIVE_AND_RENDERED**. Общая `game54` этим пакетом не менялась.
База — актуальная game54 с ambient30, injury30, avoidance30 и route3; точные source pins каждого прогона сохранены.

## Изменение

У трёх медиков белый медицинский халат с полами до колен, лацканами, карманами, пуговицами и небольшим знаком; белая шапочка с красным крестом. Детальный кейс имеет отдельную крышку, окантовку, П-образную ручку, две застёжки, задние петли, ножки и красный крест. Новый кейс остаётся дочерним объектом того же owned counter body и следует его разрушению.

Внедрять ровно три файла из `BASE_MEDIC30.json`:

- `scripts/venues/npc_medic_style30.gd` — новый visual-only helper;
- `scripts/venues/npc_venue_staff_actor29.gd` — один hook только для role=medic;
- `scripts/venues/npc_venue_staff_host29.gd` — замена трёх hospital boxes одним batched case; cashier ветка эквивалентна прежней.

Риг остаётся canonical28, коллизия медика — прежняя капсула. Геометрия тела, skin weights, индексы, нормали, UV и другие атрибуты исходного FABRIC сохранены; изменены только COLOR у ровно1648 вершин куртки. Тёмные брюки, обувь, сорочка и галстук сохранены. На каждого медика добавлены3 BoneAttachment и3 меша; pose/update/service/queue/placement не менялись. Девять кассиров не перекрашены и имеют прежние native counts.

## Применение

`apply_medic30.py` сначала проверяет **все** base/proposed SHA трёх файлов и лишь затем пишет. Неизвестный destination отвергается до первой записи. Повторное применение ничего не меняет. Все три свойства проверены на маленькой source-only копии в `apply_validation`.

Из корня репозитория:

```powershell
python -B outputs/coordinator30_npc54/proposals/medic30/apply_medic30.py outputs/coordinator30_npc54/game --report outputs/coordinator30_npc54/MEDIC30_APPLY.json
```

CLI сам получает scheduler write lease. Если root уже держит write lease этой game, вызвать `apply(game, report)` из модуля внутри существующего lease, не вкладывать второй. Пакет не разрешает запись вне coordinator30_npc54. `build_medic30.py` — исторический сборщик; после интеграции его повторно не запускать.

## Доказательства

- `runs/inspect02`: actual city baseline, import/native0, stderr0, source drift0; decoded COLOR histogram и packed bytes.
- `runs/candidate02`: actual main_city, graphical PASS; 12 staff,3 dressed medics,9 unchanged cashiers; native/import0, stderr0, drift0. Оригинальные снимки в `observed/medic_front.png`, `medic_side.png`, `medic_case.png`.
- `VISUAL_REVIEW_MEDIC30.json`: просмотрены все три снимка. Халат, шапочка и кейс читаются; в проверенной стоящей позе видимого пробивания нет. На прямом переднем снимке существующие floating venue labels перекрывают часть шапочки; боковой снимок показывает её полностью. Это прежние таблички сцены, не часть пакета.
- `runs/contracts01`: **637 PASS**, failures=[], импорт/native0, stderr0, drift0. Настоящий world,12 сотрудников/336 костей, physical client approach, FIFO286 без включения толпы, service/cancel/promotion/reset/counter destruction. Проверенный frozen fixture перенесён без изменения поведения.
- `REVIEW_MEDIC30.json`: сверка предложенных SHA с обоими финальными native прогонами, цвета/rig/colliders/cashiers, стоимость, guarded apply.
- `runs/candidate01` сохранён как честная неудачная попытка: palette guard дал changed0 и не допустил частично одетых медиков. `inspect02` установил truncating uint8 COLOR encoding; исправление дало ровно1648. Guard не ослаблен, sRGB conversion не добавлено.

Native replay: `python -B .../run_medic30.py <new-name> --mode graphical` или `<new-name> --contracts`. Используется существующий собственный reusable ambient30/oracle01/project с delta staging под write lease, без новых полных копий. Frozen receipts и TESTED_SOURCES сохраняют каждую проверенную версию; содержимое reusable project не является immutable доказательством.

## Фактическая стоимость

| На одного медика | До | После |
|---|---:|---:|
| Узлы |24|30|
| Меши сохранённые / видимые |11 / 11|14 / 9|
| Вершины сохранённые / видимые |7510 / 7510|8132 / 7422|
| Треугольники сохранённые / видимые |11208 / 11208|11640 / 10536|
| Кости / коллизии |28 / 1|28 / 1|

Пять hair meshes под шапочкой скрываются только у медика. Новая одежда:622 вершины/432 треугольника, три batched meshes. Кейс: один mesh,528 вершин/264 треугольника вместо трёх meshes,72/36. На все три больницы: **+12 узлов, +3234 сохранённых вершины, +1980 сохранённых треугольников; видимых мешей −12, видимых треугольников −1332**, видимых вершин +1104. Новых коллизий, костей, path planners или per-frame callbacks нет.

«Видимые» — native MeshInstance3D.visible до прежнего range/occlusion culling; это geometry accounting, не измеренное число draw calls или FPS. Графическая проверка функциональная, performance_accepted=false. Финальная проверка общей сцены и сопоставимый perf остаются у root.

## Границы

Palette guard намеренно привязан к принятому staff72 FABRIC (2229 vertices/1648 coat vertices); будущая замена канонического ресурса потребует нового аудита, иначе medic admission явно завершится ошибкой. Костюм проверен на настоящем стационарном персонале и service fixture; произвольные locomotion/combat позы другого типа NPC не заявляются. Старые29, cashiers, обычный launcher/F5, Git и общий проект не менялись.
