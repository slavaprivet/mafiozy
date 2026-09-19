# Статические детали woodland / chalet — structural audit

13 сентября 2026. Исполнитель: mercenary_input_audit, Координатор 17. Сначала выполнен read-only аудит; затем по отдельному разрешению root внесён **только woodland assetId в существующий audited architecture allowlist**. Renderer/vehicle, sorting/matrix варианты и GPU не затрагивались. Выполнено чтение GLB JSON и две ограниченные CPU-сборки пяти размещённых домов с production windows/entry/storeys без renderer. Это структурный подсчёт, не timing benchmark или FPS-приёмка.

## Внесённый patch и фактическая проверка

Production diff: static_render_batches.mjs:11 — только добавлен woodland_crosswing_house_v1 в existing список assetId. DoorHeader/Canopy, residential pools и любые другие guards **не менялись**.

Новый test_static_woodland_batches.mjs собирает два реальных woodland GLB с actual transforms, windows/entry/storeys. До patch тест падал, поскольку woodland архитектура не участвовала в audited groups; после patch PASS:

- **58 source meshes / 70 members / 8 architecture batches**; всего для отдельной woodland fixture **17 batches**. Отличие от 60/72/+5 в общей пятидомовой fixture ниже объясняется общей группировкой совместимых source UUID: при отдельной сборке другие дома не дополняют малые группы до min3. Числа относятся к разным явно указанным fixtures.
- Проверены **4416** вершин: packed local positions и triangle indices совпадают точно; transformed world positions имеют максимальную разницу **0.0000088285 м** из-за Float32 batch matrices. Source material UUID, geometry UUID, world matrices и shadow/render flags каждого architecture member сопоставлены с оригиналом.
- **165** отдельных ray checks по исходным meshes: списки hit distance/instanceId до/после идентичны. Source geometry, parent, matrixWorld и существующие instanceColor arrays сохранены.
- Hidden mesh, hidden parent и moving hinge parent negative fixtures используют то же allowlisted имя и материал, но остаются исключёнными. Двери, фурнитура, DoorHeader/Canopy, ResidentialWindow pools и стекло сохраняют исходные материалы.
- A/B выключение возвращает только architecture источники, прежние batches продолжают работать; far culling не воскресает от toggle; dispose восстанавливает исходные материалы и удаляет batches.

Четыре существующих suite также PASS: test_static_render_batches (15 реальных hidden proxy + authored per-instance furniture colors), test_static_render_culling (BatchedMesh и InstancedMesh fallback), test_static_houses_batches (townhouse/chalet/pine), test_static_pavilion_batches (4 реальных GALLERIA, 72 panes, 92 door descendants). **Итого 5 файлов тестов PASS.** Прогоны были bounded regression, без тяжёлого benchmark/renderer.

Parent reveal проверен read-only: building_window_integration:41–42 временно скрывает окна при startup CSG и восстанавливает до batching; roomReveals:53 только dispose; building_storeys:78 скрывает ceiling на setup, а :178 восстанавливает при dispose. Runtime переключение видимости участвующих parent groups не найдено. При появлении такого механизма copied geometry нужно исключать или синхронизировать; этой правкой контракт visibility не расширялся.

Готово к согласованному root reload/LIVE сравнению. Производительность общей сцены **не проверена**, FPS не заявлен.

Исходный LIVE census, переданный root: woodland 236 calls / 122 shadow, chalet 234 / 26 shadow. Эти числа не индивидуальная стоимость моделей и не равны приведённым ниже fixture counts.

## Материалы и проверенные источники

Прочитаны STATIC_PAVILION_BATCHING_HANDOFF.md, HIDDEN_PROXY_BATCHING_FIX_HANDOFF.md, COORDINATOR_16_MEMORY.md (этап houses), static_render_batches.mjs и test_static_houses_batches.mjs.

Реальные LOD0:

| Модель | Размер GLB | Mesh nodes | Размещений в production JSON | SHA256 |
|---|---:|---:|---:|---|
| woodland_crosswing_house_v1 | 199000 bytes | 62 | 2 | 060efe1399086eba29b8ba0871787792aa4bfd8187a54203837e5f7ddf44814b |
| hillstep_chalet_v1 | 210060 bytes | 65 | 3 | 26f0868537c6e95136cdf69f9d3a7a554b61b29e974fc1949cdd94f8819c8714 |

Оба GLB имеют 12 материалов: ClayGrass, ClayGrassLight, ClayDrive, ClayWall, ClayStone, ClayRoof, ClayAccent, ClayWood, WindowWarm, ClayLeafLight, ClaySoil, ClayLeaf. В исходном GLB alphaMode=OPAQUE и alpha=1 у всех; это **не разрешение объединять WindowWarm**, потому что production residential integration заменяет оконные поверхности и добавляет отдельные разрушаемые стёкла.

В fixture загружен каждый GLB один раз, модели клонированы по реальным transform и placement ID. Применены applyBuildingDoorsGlass и createWindowedBuildingEntry. Browser texture upload заменён T.Texture; геометрия и material settings сохранены. Использован production batching classifier с экспортом private функций только в `data:` module в памяти. На диске batching-код не изменялся. Группировка выполнялась по реальным material UUID и geometry layout, с прежним minInstances=3.

## Почему детали не объединены

`static_render_batches.mjs:9–12` допускает auditedStaticArchitecture только для old_town_narrow_townhouse_v1, hillstep_chalet_v1 и pine_ridge_cottage_v1. **Woodland отсутствует.** Поэтому его неподвижные окна/полы/стены отсекаются name guards `Window`, `Door`, `Entry_`, `Runtime_`, несмотря на совпадение с уже проверенным именованным набором архитектуры.

В двух woodland fixture 204 mesh objects после integration. Помимо нужных exclusions, отсекаются 36 authored оконных Sill/Lintel/TrimLeft/TrimRight/MullionV/MullionH; 24 Entry плоскости/corridor/ramp; 2 Storey_Walls_And_Ceilings pools; 2 Room_Door_Frames. После применения неизменного min3 **60 source meshes / 72 instance members** из них реально могут войти в batches. Floor/ramp с отдельными material UUID остаются ниже min3.

У chalet whitelist уже действует. Большинство оставшихся причин правильные: PublicDoor, ServiceDoor, ручки/hinges/leaf trim, PorchLamp, Entry_Warm_Fixture, прозрачное ResidentialWindow_DeepGlass, скрытый Entry_Interior_Ceiling и прочие runtime nodes. Нельзя включить все остатки через общий regex bypass.

Обе модели имеют два статических authored sibling mesh `DoorHeader` и `DoorCanopy`, ошибочно попадающих под общий Door guard. Production profile (`building_entry_profiles.mjs:18,115,221–222`) привязывает к hinge PublicDoor + PublicDoorKnob; Header/Canopy туда не входят. Их материалы ClayAccent/ClayRoof непрозрачны. Узкий allowlist этих **двух точных имён только двух assetId** оставит любой moving ancestor под прежним запретом.

Оба дома дополнительно получают четыре opaque InstancedMesh pools из residential_windows.mjs:89: один ResidentialWindow_DeepRecess и три ResidentialWindow_Frame_And_Interior с разными material UUID. Имена мешей и exact group Recessed_Residential_Windows сейчас не допускаются. В пяти размещениях это 20 source meshes / 195 instances. Отдельный пятый pool ResidentialWindow_DeepGlass transparent=.28/breakable и должен остаться исходным.

## Проверяемые patch-кандидаты и структурные числа

Числа получены классификацией тех же объектов в памяти с поэтапным расширением предиката; batches фактически не создавались.

| Вариант fixture 5 домов | Материальные buckets ≥3 | Попавших source meshes | Instance members | Добавлено source meshes |
|---|---:|---:|---:|---:|
| Текущий production classifier | 31 | 292 | 1095 | — |
| + woodland в существующую архитектурную allowlist | 36 | 352 | 1167 | 60 |
| + Header/Canopy только этих двух assetId | 38 | 358 | 1173 | 6 |
| + четыре opaque residential pools двух assetId | 42 | 378 | 1368 | 20 |

**Рекомендуемый следующий patch — только добавить woodland_crosswing_house_v1 в существующий список auditedStaticArchitecture** и добавить его в real houses regression. Это наиболее узкий путь, использующий уже работающий механизм для аналогичных домов. Качество, материалы/UUID, geometry layout, shadow flags, source hierarchy, 220 м culling и picking/collision copies сохраняются. Никаких уменьшений детализации.

Header/Canopy — второй отдельный маленький кандидат: реально объединятся 6 chalet meshes в 2 buckets; по две woodland детали останутся ниже min3. Не снижать общий min3 ради них.

Opaque window pools — третий кандидат, требующий явного regression до production:

- auditedStaticArchitecture должен признать только exact InstancedMesh names ResidentialWindow_DeepRecess / ResidentialWindow_Frame_And_Interior под двумя assetId. Использовать **architecture lane**, чтобы batchKey (`:51`) сохранил material.uuid, geometryKey (`:91`) — geometry.uuid; не отправлять их через interiorMaterialKey и не включать vertexColors произвольно.
- У ancestor predicate разрешить только exact non-mesh group Recessed_Residential_Windows под этими же assetId. Это не разрешение на все Window ancestors. Проверки visible, breakable, transparent, light/hinge descendants остаются.
- residential_windows.mjs:64,87–91 создаёт эти 4 непрозрачных материала один раз на bundle и статические instance transforms. После создания matrices не меняются. Найденное изменение group.visible в building_window_integration.mjs:41–42 временно относится к startup CSG и восстанавливается до batching. Удаление group/materials происходит в dispose. В основном коде runtime-toggle windows.group.visible не найден.
- Это ограниченное доказательство текущего кода. Если появляется runtime window frame visibility/transform, copied batches должны синхронизироваться или такой pool исключаться. Исходное стекло остаётся вне batch с индивидуальным разрушением.

## Обязательная проверка при реализации

Для первого patch расширить test_static_houses_batches новым woodland: реальные две GLB placements, material UUID separation, geometry/source parent/matrix identity, все окна/двери/ручки/hidden proxies сохраняют динамические материалы, actual door hinge animation не двигает скопированную статическую отделку, near/far 220 м, A/B restoration и disposal. Сравнивать скопированные instance transforms с исходными и учитывать InstancedMesh counts. Не объединять разные UUID даже если material.name одинаковое.

Для opaque pools отдельно: 4 opaque UUID buckets, стекло и breakable state сохраняются; три одноимённых Frame pools не смешивают материалы; geometry UUID сохранены; стекло ломается отдельно; source raycasts/collision geometry прежние; только статические исходники скрываются материалом и восстанавливаются при dispose. Сохранить hidden ancestor и moving ancestor negative cases. Не вводить render/matrix/sorting изменения.

После регрессий root выполняет согласованный LIVE before/after того же ракурса и населения: общий frame p50/p95, census этих зданий и Static_Render_Batch, draw calls/triangles, проверка окон/дверей и входа. Приведённые 60/6/20 source meshes — не обещание такого же уменьшения LIVE calls: frustum, тени и BatchedMesh multi-draw меняют соответствие. Производительность общей сцены не проверена.

## Финальный статус после реализации и загрузки root

Предыдущие разделы с формулировками «предложение», «на диске не изменялся» относятся к историческому read-only аудиту. После отдельного разрешения root **внесена одна production правка**: woodland_crosswing_house_v1 добавлен в existing auditedStaticArchitecture allowlist (`static_render_batches.mjs:11`). Остальные предложения не реализованы.

Новый actual GLB regression test_static_woodland_batches.mjs прошёл RED→GREEN. В изолированной двухдомовой fixture проверено 58 architecture source meshes /70 members /8 architecture batches, 4416 вершин с максимальным world-space Float32 отклонением 8.83e-6 м, идентичные triangle indices и 165 исходных raycast hit comparisons; material/geometry UUID, source instance colors, hidden/moving-parent exclusions, двери/стекло, A/B/cull/dispose сохранены. Четыре existing static/house/pavilion/culling suites также PASS — всего 5 файлов тестов.

Root затем подтвердил **фактическую загрузку в runtime общей сцены: +72 members /+5 batches**. Это соответствует общей fixture с совместным material grouping. Разница с isolated fixture ожидаема из-за minInstances=3 и объединения общих материалов. Это доказательство загрузки и состава batches, а не самостоятельный FPS before/after.

Качество, густота, дальность, renderer/vehicle и какие-либо window-pool whitelist этой правкой не менялись. DoorHeader/Canopy и ResidentialWindow pools остаются предложениями до нового разрешения root.
