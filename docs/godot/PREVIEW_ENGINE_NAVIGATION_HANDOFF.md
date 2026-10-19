# Godot NavigationServer3D: проверенный локальный backend

27 сентября 2026. Новый backend действительно строит Recast mesh из текущих authored collision triangles, публикует частную navigation map, запрашивает штатный маршрут и допускает его через текущие source/physics predicates. В headless Godot 4.7.2 тестовый CharacterBody3D с NavigationAgent3D физически проходит открытую дверь и пандус типографии. Это groundwork для интеграции; в main, игровом roster, player и source Walk изменений нет. Все `fixture:engine-*` — только тестовые личности. GPU не запускался.

Предыдущие `npc_native_navigation.gd`, sweep и queue сохраняются как source reference/admission contracts. GDScript A* не выбран окончательным игровым планировщиком. Этот пакет использует поиск и построение mesh самого Godot; совпадение списка точек с JS не является критерием приёмки.

## Файлы и запуск

- `godot/mafiozi_walk/scripts/navigation/preview_engine_navigation.gd` — backend, без Node/актора/сцены.
- `godot/mafiozi_walk/scripts/tests/test_preview_engine_navigation.gd` — реальные async bake/query, physics и CPU проверки.
- `godot/mafiozi_walk/scripts/tests/fixtures/engine_navigation_fixture.gd` — только тестовая сборка текущих данных, физический мир и admission provider.
- `godot/mafiozi_walk/scripts/tests/fixtures/engine_navigation_api_472.json` — закреплённые API signatures и source hashes.
- `outputs/coordinator21_npc_port/engine_navigation_headless_result.txt` — воспроизводимый отчёт; output не заменяет исходники теста.

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --fixed-fps 60 --path godot/mafiozi_walk --script res://scripts/tests/test_preview_engine_navigation.gd
```

API получен непосредственно установленным `4.7.2.stable.official.ed1daf0bf`: `--headless --doctool <существующая папка> --quit` вне проекта. XML signatures сохранены в generated outputs; их SHA, имена и параметры выбранных методов зафиксированы в fixture. Тест сверяет build hash, методы, число и имена аргументов с реальным ClassDB. У binary-generated XML нет содержательных описаний: семантика дополнительно сверена с официальными [NavigationServer3D API](https://docs.godotengine.org/en/4.7/classes/class_navigationserver3d.html) и [navigation server lifecycle](https://docs.godotengine.org/en/4.7/tutorials/navigation/navigation_using_navigationservers.html). Background execution обещан для async bake; `query_path` с callback здесь не объявляется background query. Его фактическая CPU стоимость измеряется.

## Authoritative geometry и границы

Тест читает текущие `res://data/block.json` и `printshop_interior.json` напрямую, а не реконструирует планировку по упрощённым стенам:

| Данные | Значение |
|---|---|
| block SHA256 | `1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e` |
| printshop SHA256 | `958a2c2d8cbdc2b2e2e11a57e33bf9bf5a20ec334be8a8997bdad951f9f8086b` |
| Локальный origin | `[395.65, 0, 45.1]`, метры, source grid 4.1 м |
| Пол | 658 dry/walkable клеток; у 303 water клеток нет сухого пола |
| Коллизии | 107 printshop bodies заменяют старые оболочки, плюс 24 остальных crop bodies |
| Bake input | 3046 треугольников, включая фактические interior floor/ramp/ceiling geometry |

Convex polygons, transforms и 4 door leaf poses взяты из source данных. Открытие использует исходную eased fraction, public +π/2/service −π/2; Godot winding меняется только при конверсии исходных triangles. Сервисная створка имеет фактическую толщину 0.11 м. Source stockroom bounds используются для теста разграничения доступа. No-water правило проверяет центр и углы footprint, текущий пол и нормаль; капсула непрерывно проверяет физические стены и потолки.

Тестовый provider разрешает только явно тестовые IDs, а staff membership задаётся тестом. Он **не является** игровым serviceFSM, authenticated roster, occupant registry или заменой правил доступа. Реальная source authority должна поставлять эти данные при подключении. Контракт требует нынешних water/terrain/headroom/door/access правил; наличия navigation polygon недостаточно для допуска движения.

## Публичный контракт

Все вызовы — на main thread. Host создаёт `Backend.new(shared_path_queue, physics_space_provider)`; второй callback возвращает текущий `PhysicsDirectSpaceState3D`. Коллизии окружения ожидаются на mask 1. Backend не создаёт World3D и не владеет shared queue.

1. `publish_source(faces, authority, generation, version) -> bool`: CPU collision triangles в локальных метрах. Принятый immutable snapshot копируется. Одна authority, положительная generation, монотонная version внутри поколения; новая generation может начинать новую version. Чужие authority и устаревшие версии отвергаются. Host обязан обновить и source authority, и реальные физические коллизии при изменении доступности.
2. Принятая версия немедленно делает старые receipts `STALE`, освобождает старые map/region и запускает async bake. Одновременно возможны только один worker и один заменяемый последний snapshot. Старый worker может закончить работу, но его результат не публикуется. `state()` проходит `BAKING → SYNCING → READY`; пустая/слишком большая mesh даёт `EMPTY_MAP`/`LIMIT_REACHED`.
3. `request_path(owner, start, target, admit, exclude=[]) -> id`: owner — настоящий `PathJobQueue.Owner` с source ID/life generation; backend хранит weak reference и проверяет идентичность. Повторный запрос той же owner instance отменяет предыдущий. `admit(point_metres, source_id, life_generation) -> bool` должен синхронно проверить текущий полный source passage contract и вернуть именно bool.
4. `pump(physics_frame_id)` вызывается хостом каждый physics frame через общую очередь. Запрос движка и последующие порции admission используют её cap/cohort/expiry/actual-spent. До готовности карты/результата/всех проверок статус остаётся `PENDING`. Callback deferred на main thread проверяет epoch, owner life, map iteration и cancel. Старый результат не становится новым маршрутом.
5. `poll(id)` возвращает status и provenance. Путь раскрывается только при `READY`; даже частично проверенные точки у `PENDING` не выдаются. Полный путь включает реальные start/target connectors: ближайшая navmesh точка не используется для телепортации. Engine partial path получает `NO_PATH`, ограничения размеров — `LIMIT_REACHED`.
6. `admit_motion(id, from, to)` обязателен перед каждым реальным шагом длиной не больше 0.25 м, даже после `READY`. Он снова проверяет жизнь/версию, оба source endpoint, capsule overlap и непрерывный cast. Dynamic wall/ceiling/access change блокирует старое предложение. Controller затем выполняет физическое движение, не присваивает позицию waypoint.
7. `cancel(id)` освобождает receipt/provider и отменяет owner в очереди. `dispose()` обязателен до потери host reference/World3D: отменяет все jobs, освобождает RID, очищает providers и не допускает публикации позднего bake. Shared queue освобождает её собственный host. Completed receipts сохраняются до cancel, поскольку нужны движению; они учитываются в общем лимите.

Callbacks должны быть total, synchronous, без await/reentry/изменения authority во время вызова. Мутации publish/cancel/dispose во время admission запрещены и отвергаются; reentrant mutation помечает обрабатываемый запрос stale. Нельзя передавать callback, который замыкает сильную ссылку на умершего игрового NPC и рассчитывать только на weak owner; host снимает receipt на retirement. CPU стоимость callback входит в actual admission budget, но отдельный долгий вызов прервать посередине нельзя.

`NO_PATH` означает отсутствие полного допустимого предложения в данной ограниченной карте, а не доказательство недостижимости через весь мир. Source provider может отвергнуть выбранный движком коридор; этот пакет пока не строит отдельные role-specific maps и не повторяет поиск альтернативы вокруг запрещённой зоны.

## Реальные engine/lifetime особенности

Async map iteration 1 в этом build оказалась синхронизированной **пустой** картой до завершения region iteration. Одного `map_get_iteration_id()>0` недостаточно. Readiness также требует region iteration, непустые bounds и подтверждение принадлежности первой mesh vertex этой region через map query. В проверках готовая карта имела iteration 2. Принудительный `map_force_update` не используется.

Физический radius 0.36 м и height 1.9 м, max climb 0.20 м, max slope 45°, cell height 0.05 м. `CELL_SIZE=0.12000000476837158` — точное float32 `.36/3`: буквальное .12 здесь округлялось так, что Recast эрозия занимала 4 voxels, а не 3. Low-height/ledge filtering включены. Source square sweep radius .18 cells — отдельный контракт предыдущего reference module; он не объявлен равным новой физической капсуле.

Тестовый NavigationAgent3D используется только как штатный follower тестового CharacterBody3D. Перед чтением следующей точки fixture проверяет READY receipt; при invalidation host обязан остановить движение, затем перепривязать agent к новой map после новой READY receipt. Старый RID уже освобождён. Все реальные шаги дополнительно проходят source/physics admission.

NavigationAgent способен сам инициировать C++ repath. Эти внутренние запросы **не покрыты** cap8 backend queue и её query timing. Production host должен либо физически следовать уже проверенному server path, либо отдельно ограничить обновление targets/repath агентов. Этот тест не доказывает суммарный бюджет сотен NavigationAgent.

## Пределы ресурсов

| Ограничение | Значение |
|---|---:|
| Jobs, включая готовые receipts | 128 |
| Geometry vertices / triangles | 180000 / 60000 |
| Snapshot X/Z extent, Y extent, XZ area | 256 м / 64 м / 20000 м² |
| Simultaneous bake / latest waiting snapshot | 1 / 1 |
| Navigation polygons / proposal points | 4096 / 4096 |
| Search/return distance | 512 м |
| Physics excludes per job | 16 |
| Validation/motion segment | ≤0.25 м |
| Diagnostics history per timing category | 256, ring replacement |
| Main pump budget | 4 мс soft, конец атомарного engine query/admission |

Лимиты проверяются fail-closed. Каждый update сейчас инвалидирует и перебекает **весь этот crop**. Это консервативный working backend, не обещание масштабирования такого же rebuild на весь город или каждый кадр анимации двери. Нужны стабильные door authority versions и последующая локализация regions/дверных переходов; физический admission закрывает промежуток до новой mesh.

## Проверки и CPU стоимость

Actual headless: **357 checks PASS**, exit 0, без SCRIPT ERROR. Покрыты закрытая/открытая public door, физический подъём по source ramp, closed service door для staff, открытая service door для staff и отказ тому же проходу public owner, water target, Recast headroom exclusion, dynamic ceiling, 1-см препятствие перед footprint, source access revocation, cancel до deferred callback, реальный устаревший bake, worker-thread/reentry/NaN/oversize/stale version/owner death, bounded queue и disposal при активном worker.

Физический actor дошёл до authored inside anchor за 150 physics frames (fixed 60), максимум перемещения 0.035176 м/кадр; identity сохранена. В actual run old bake и canceled callback были отвергнуты по одному. 24 конкурентных запроса завершились READY; validation действительно продолжалась в следующих admitted slices. Кандидатный PENDING path не раскрывался.

Одинаковые 3046 треугольников текущего crop, одинаковая капсула, 1 прогрев + 5 измерений каждого Recast варианта:

| Вариант | Bake wall p50 | p95 / max | Polygons |
|---|---:|---:|---:|
| Fine voxel .06 м, baseline | 1244.090 мс | 1274.818 мс | 1477 |
| Native voxel .12 м, выбранный | 261.747 мс | 264.523 мс | 814 |

Геометрия/коллизии/вода не удалялись. Это wall latency фонового bake; физический маршрут проверен на выбранном варианте. Это не main-thread frame time и не FPS игры.

| Измерение выбранного backend | n | p50 | p95 | max |
|---|---:|---:|---:|---:|
| Publish source validation/copy/submit | 6 | 0.815 мс | 1.201 мс | 1.201 мс |
| Bake submission | 6 | 0.201 мс | 0.275 мс | 0.275 мс |
| Engine query call | 34 | 0.040 мс | 0.128 мс | 0.131 мс |
| Shared queue pump | 33 | 0.155 мс | 4.076 мс | 4.101 мс |
| Actual movement source + physics admission | 153 | 0.059 мс | 0.088 мс | 0.117 мс |

Однократная test fixture construction 19.446 мс создаёт все тестовые physics nodes; это не production per-frame update. Реальная интеграция должна держать static CPU geometry и переиспользовать её при изменениях source door bodies, а не пересоздавать fixture world. Производительность общей игровой сцены не проверена; bake benchmark не запускался одновременно с root GPU QA.

## Следующий host slice

Подключить trusted existing roster/life IDs и точные source passage/door-occupants providers, source-version publication и физический controller lifecycle. До этого `main` не получает выдуманных NPC. Door service death/new ID rules остаются в NPC first-slice contract. Затем в одном согласованном LIVE окне измерить total frame cost с настоящей population и физическим arrival, отдельно проверив budget автоматических Agent repaths, если они будут выбраны host.
