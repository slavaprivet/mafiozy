# Нанятая банда: физический выход из воды — production 23 сентября

**IMPLEMENTED + CPU TESTED, LIVE у Координатора20.** Root разрешил перенос после
публикации `31f8ea6`. Runtime scope освобождён после READY; новых GPU-вкладок,
backend/DB, commit/push этот агент не создавал. `mercenary_core.mjs` не трогал.

## Что подключено

- `assets/maps/city_rebuild_v1/mercenary_world.js`: выход из уже занятой воды
  перед обычным сухопутным маршрутом; явная скорость 1.5 м/с, существующие
  bounded elapsed/substeps. Source ID, цель follow/rally, оружие, деньги и
  очередь действий сохраняются. После высыхания **всего** тела маршрут к игроку
  строится обычным planner. Интерьеры, транспорт, dead/downed/hospital и
  local/server/custom authority gates сохраняются.
- `world.html`, только `NPC_NATIVE_WATER_ROUTING`: optional body-depth по
  существующему радиусу `.18` source, continuous native solid sweep,
  существующий shared route budget и запрет углубления в воду.
  Старые вызовы обычных NPC/police без options сохраняют прежний режим.
- `npc_native_water_source.js` теперь **точное зеркало** блока world.
  В зеркале восстановлены уже существовавшие в world `_walkTrafficNavigationResolver`
  и `finally _npcFinishRouteWork`; это синхронизация прежнего отставания зеркала.

Дополнение по настоящему LIVE repro root: трое hired `merc_resident_95/33/187`
стояли в одной точке `r27.799313847727056 c41.644286187278674`, body y≈−1.27 м,
hero `r40 c40`, HP положительный, follows_player. Этих же сохранённых бойцов
root проверяет после reload; standalone fixture не объявляется копией озера.

Overlap regression обнаружил недостаток исходного кандидата: при 7/15 FPS
трое расходились, затем выбирали пути друг через друга и ожидали бесконечно.
Исправление проверяет **crew canStep уже при выборе каждого сегмента выхода**,
а не только при фактическом шаге. Внутри исходного пересечения разрешено
только увеличение расстояния; после разведения сохраняется 1.1 м. Коллизии
не отключались, прямого изменения координат к берегу нет.

## Наблюдение в существующей игре

Под `localhost`, `127.0.0.1` или `[::1]` и `npcqa=1` доступен DOM JSON:

```js
JSON.parse(document.documentElement.dataset.mercenaryMovement)
```

Версия `water-follow23-v1`; обновление **не чаще раза в секунду**.
Поля: `at`, `local`, `nativeConnected`, `hero:{r,c}` и `crew` с
`id/r/c/waterEscaping/bodyDepth/moveReason/order/goal/followSpeed`.
Goal r/c — source units, bodyDepth — метры, followSpeed — метры в секунду.
Только чтение состояния персонажей. На обычной странице без флага и на
внешнем hostname диагностика выключена; URL gate вычисляется один раз.

## Проверки на production

Новый самостоятельный test:
`node assets/maps/city_rebuild_v1/test_mercenary_water_follow23.mjs` — **20/20 PASS**.
Он исполняет полную текущую `mercenary_world.js`, текущий water block world,
действительные core/path/footprint/native navigation; подменяется только
граница браузерного dynamic import для Node. Кандидатные преобразования
в тесте отсутствуют. Озеро/стены — заданная fixture, не полный город.

- Выход и возвращение к игроку при 5/7/10/15/30/60 FPS. На 7/15/60 FPS весь
  footprint сухой примерно через 14.71/13.67/13.60 с, затем боец приходит.
- Пять бойцов выходят и следуют без пересечения тел.
- Трое **в одной точке** расходятся и приходят при 7/15/60 FPS. Разведение
  всех пар до 1.1 м через 1.86/1.67/1.73 с; ни одного teleport шага.
- Сухой центр/мокрый footprint, альтернативный берег при стене, отказ от
  полностью перекрытого выхода и непрерывный veto тонких стен.
- Shared budget/resume, сохранение orders/identity и server/custom gates.
- Зеркало water block проверяется на полное текстовое совпадение.
- QA hostname/флаг/частота обновления проверены.

Дополнительно **69/69 PASS**:
`test_npc_native_water`, `test_mercenary_follow18`, `test_mercenary_elapsed`,
`test_mercenary_world`, `test_mercenary_combat_collision`,
`test_mercenary_vehicle_follow18`, `test_mercenary_safe_exit18`.
Синтаксис трёх JS-файлов и всех 7 inline scripts world — PASS;
scoped `git diff --check` — PASS.

## Сухая стоимость

600 production updates сухого бойца: **0 water searches, 0 shared admissions**,
никакого полного поиска выхода на сухом месте. Fixture update p50/p95
`.0439/.1451 мс` (включает обычное следование и прочие source проверки).

Для 5 сухих персонажей отдельный ABBA admission замер, 600 samples на вариант:
center-depth `.0055/.0073 мс` p50/p95; body-depth `.0218/.0249 мс`.
Это ровно 25 native point probes вместо 5, **0 path searches**. Добавлено
20 point probes на пятёрку; options object постоянный, URL не парсится в hot loop.
Это ограниченная CPU fixture; не before/after FPS загруженного города.

## Сохранённое ограничение

Существующий mercenary A* `maxDistance=48 м` не расширялся. Regression явно
сохраняет дальний случай: после выхода все 5 сухие, 4 дошли, один остаётся
`no_route` в 38.27 м по прямой, поскольку обход длиннее budget. Это отдельная
задача дальнего следования, также возможная для root LIVE далёкого merc138.
Нельзя объявлять проблему всей банды закрытой до LIVE и разбора этой дистанции.

## Файлы для review

Runtime diff относительно `31f8ea6`: `outputs/GANG_WATER_FOLLOW23_RUNTIME.diff`,
3 файла, **73 добавления / 27 удалений**. Помимо runtime — новый production test
и этот handoff. Исторические три исходных дефекта сохранены в
`GANG_WATER_FOLLOW23_AUDIT.md`. Старый `outputs/test_gang_water_follow23.mjs`
теперь только импортирует maintained production test; больше не применяет
патч повторно. `outputs/gang_water_follow23_candidate.mjs` — архив аудита,
не текущий тест и не runtime dependency.
