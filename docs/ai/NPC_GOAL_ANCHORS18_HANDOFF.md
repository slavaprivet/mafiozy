# Native visit goal anchors — Художник18

20 сентября 2026. Узкий патч для реальной двери, возле которой сетка 4,1 м не имеет проходимого центра в прежнем радиусе завершения. Владельцем переноса в production и LIVE остаётся root; субагент production не менял.

## Передача

- `test_npc_native_fast_path18_goal_candidate.mjs`: окончательный exact transform `stageNativeGoalAnchors(source)` для `assets/maps/city_rebuild_v1/npc_native_directed_route_source.js`.
- `test_npc_native_fast_path18_goal.mjs`: actual coastal house002/printshop/hospital, движение к двери, отрицательные sealed/water/dynamic-door/dynamic-car и fine-only corridor. Автоматически работает с staged или уже applied source.
- `test_npc_native_fast_path18_goal_regressions.mjs`: существующие direct/adaptive/shop lifecycle тесты через временную подмену чтения source внутри CPU-процесса. Production-файл не пишет.
- Независимый review: `test_npc_goal_anchor_independent18.mjs`, владелец resident_activity_lifecycle18. PASS fine-only corridor, continuation, origin/goal/pass/resolver invalidation.

## Причина и результат

LIVE resident16: старт `(139.111932568,173.181051759)`, дверь `REBUILD-VISUAL-coastal_orchard_house_v1-002` `(150.89358536790058,165.7479268829997)`. Два центра сетки в goalRadius 0,8 оба заблокированы. Дверь и старт физически доступны. Проверенный ближайший подход `(150.5,167.5)` находится на расстоянии 1,7957 source от двери и имеет полностью свободный connector.

Один сопоставимый CPU-прогон с реальным source queue/shared4ms без конкурирующих NPC: before false, 46 slices, 190,21 мс суммарно, 1160 expanded / 1200 visited; candidate true, 3 slices, 10,66 мс, 18 expanded / 50 visited. Максимальная slice 4,79 → 4,20 мс: существующие атомарные проверки могут немного пересечь дедлайн.

Физическое движение через actualFootTick прошло 75,866 м за 926 кадров по 0,05 с. Максимальный шаг 0,082 м; остаток до двери 0,311 м, внутри штатного порога остановки 0,08 source. На каждом шаге проверена проходимость. Полные числа и маршрут: `outputs/npc_goal_anchor_candidate18.json`; applied mode пишет отдельный `outputs/npc_goal_anchor_applied18.json`.

## Контракт

Сначала сохраняется короткий прямой подход. Затем resumable discovery ищет проверенные terminal anchors в исходном goalRadius; только при их отсутствии сканирует конечное множество центров в радиусе 2,25 source. Проверяются callback и полный swept connector к точной двери. A* завершает только на доказанном anchor, перепроверяет connector и добавляет exact goal.

Если coarse anchors отсутствуют, bounded probe четырёх стартовых coarse edges различает заведомо бесполезный coarse поиск и существующий isolated-start fine fallback. Любой доступный coarse edge даёт быстрый false; полностью изолированный старт сохраняет прежний fine поиск. Независимый review обнаружил и проверил исправление важного случая: узкий коридор вообще без coarse центров, start `(10.1,2.1)` → goal `(10.1,12.1)`, по-прежнему проходит fine за 39 nodes, без рестартов.

Сохраняются shared4ms/FIFO, max1200, resumable search и инвалидирование origin/goal/pass/resolver. Радиус тела не уменьшен. Planned visits передают body-aware callback; исторические non-plan visits передают point-level callback плюс native swept resolver — этот отдельный контракт патч не расширяет и не ослабляет.

Перепроверяется terminal connector, а не вся цепочка ранее найденных parent edges. Подвижная машина на промежуточном участке может вызвать штатную остановку/repath при пошаговой проверке движения. Нельзя описывать этот патч как повторную проверку всего пути в момент публикации.

## Проверки и пределы

Последний staged прогон: goal tests PASS; independent review PASS; direct/adaptive/actual shop lifecycle PASS. Реальный shop цикл вошёл, купил newspaper за3 (55→52), вышел и продолжил маршрут. Printshop/hospital fine-start случаи сохранены. Стены, вода, изменившиеся дверь/машина не публикуют ложный terminal.

Это CPU-проверки actual source, GLB и snapshot; производительность общей сцены и LIVE текущей вкладки не проверены. GPU-вкладок субагент не открывал. Исправление одной причины зависших визитов не означает завершения задачи живого города.

## APPLIED — подтверждение root

Root перенёс final transform в production module и сообщил `navigationVersion: physical-grid-v3`, syntax PASS. После переноса один applied-прогон `goal.mjs` PASS (resident16: true, 18 expanded / 50 visited, 4 slices / 17,11 мс, то же физическое движение 926 кадров); один `goal_regressions.mjs` PASS — direct, adaptive, actual shop entry/pay/exit. Staged baseline-отчёт сохранён отдельно. **Производительность общей сцены и LIVE текущей сборки не проверены.**
