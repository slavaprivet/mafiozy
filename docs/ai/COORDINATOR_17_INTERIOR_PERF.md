# Координатор 17 — интерьеры: стоимость и lifecycle

13 сентября 2026. Прямое поручение пользователя: «так же оптимизация внутри зданий объектов проверь». Аудит `hud_perf_audit` по запросу root; GPU/браузер не открывались, городские планировщики и тяжёлые benchmark не запускались.

## Владелец и границы

Архитектор/интерьеры `01a087f0-fda6-7e13-8baa-1bbd1c5cc26e`, память `INTERIORS_20260912_MEMORY.md`, `ROADS_CAMERA_20260912_MEMORY.md`, передача `INTERIOR_REBUILD_20260912_HANDOFF.md`.

Основные owned paths: building_window_integration, building_entry/profiles, building_storeys, building_interior_design, interior_mesh_pool, interior_room_doors, interior_staircase/oriented_staircase, residential_windows, interior_finishes, interior_interactive_safe. Renderer/shadows/static_render_batches принадлежат optimizer; текущая static source matrix policy — другой агент17. Они не изменялись. Safes сохраняют source/registry authority, rewards и IDs.

## Что уже оптимизировано, что остаётся

- Мебель: `interior_mesh_pool:57–110` делит 3 geometry и 2 materials с refcount между зданиями; до6 InstancedMesh на building. `building_interior_design:129` flush только при создании; планировка/предметы не пересчитываются каждый кадр. `static_render_batches` дополнительно переносит эти экземпляры в общие BatchedMesh, оставляя source material.visible=false для точных gameplay объектов. Нельзя считать local draws дополнительной полной нагрузкой поверх global batches.
- Этажи: `building_storeys:166` walls/ceilings, floors, door frames уже instanced по material; shared resources с refcounts. Opaque architecture allowlist отдельно расширяет optimizer. Не начинать то же объединение заново.
- Двери комнат: `interior_room_doors` — wood/brass dynamic batches по материалу внутри здания. Idle update рано выходит. `entry.needsUpdate` включает только actual moving doors/safes; `walk_preview:859` не вызывает update у неподвижных entries. Сам факт сотен комнат не означает сотни animators каждый кадр.
- Сейфы: `interior_interactive_safe` — 3 pooled geometries, 2 materials глобально; видны2 draws закрытого/открытого пустого и3 при source loot. Анимация лишь пока needsUpdate. Corpse/loot/transaction поведение не трогать. Исторический актуальный manifest —24 фактически размещённых сейфа, не сотни.
- Окна: residential_windows использует5 InstancedMesh pools на поддерживаемое building (4 opaque + отдельный transparent breakable glass), общие geometry/materials, cached CSG. Interior reveal clipping также cached. Это startup/rebuild стоимость, не per-frame cutting. DeepGlass — BoxGeometry толщиной.012м и DoubleSide transparent: blanket forceSinglePass/FrontSide не доказан эквивалентным.
- Lights: `stable_entry_lights` собирает source PointLights в32 постоянных non-shadow slots; decorative luminaires мебели новых lights не добавляют. Каждые250мс проверяются visible ancestors/intensity и nearest32, source getWorldPosition. Цвет/интенсивность/маска/позиция остаются живыми. Existing `point_light_loop` сохраняет тот же GLSL свет, уменьшая разрастание программ. Уменьшение32 источников или их distance здесь не предлагается.
- Finishes: `interior_finishes` уже reuse immutable palettes и shader cache key по mode/floor. GPU fragment-паттерны wood/tile/etc действительно остаются, но без GPU measurement нельзя объявлять их bottleneck или убирать узор.

Исторический actual75 census от владельца, НЕ новый FPS замер:174этажа/261комната/99лестниц/1101предмет/19157primitive parts/390local interior draws/958460triangles/16504colliders. Полный инвентарь отличается от видимых main+shadow draws кадра.

## Непросматриваемые комнаты

Room/portal occlusion не найден: distance culling building в220м и Three frustum/depth test не определяют, закрыта ли мебель стеной/дверью. Furniture batches имеют castShadow=true/receiveShadow=true и group-wide bounds; непросматриваемые элементы могут участвовать в vertex processing/main submit и shadows. Depth test отсекает часть фрагментов, не отменяет draw submission.

Скрывать весь интерьер при внешней камере, комнату за дверью или неактивный этаж сейчас небезопасно: существуют прозрачные окна/CSG отверстия, открытые проходы/лестницы, отражения и тени. Для точного portal culling нужны authored portal graph, все окна и exterior cameras, conservative visibility union и отдельное сохранение shadow casters; городские BatchedMesh потребуют room↔instance membership. Это отдельный измеряемый этап владельца renderer, не текущий patch.

## Существенный оставшийся CPU кандидат: двери → общий collision rebuild

`walk_preview.updateBuildingEntries:859–860`: одна moving entry меняет массив collision bodies → `entryBodyVersions.flat()` → **заново createWalkCollisionIndex([bodies,buildingBodies]) по всему городу**. `interior_room_doors:27` инкрементирует version на каждый фактический шаг двери; safe collisionRevision также меняется каждый шаг открытия. `building_interior_design:131` возвращает новый combined массив при таком изменении.

Следствие по коду: открытие одной двери/сейфа может пересобирать общий spatial index на нескольких последовательных кадрах, хотя большая часть примерно16504 исторических interior colliders неподвижна. Это доказанная повторная работа, но её ms/p95 в текущем indoor LIVE не измерены.

Безопасный future вариант: статический base index плюс per-entry изменяемые buckets с version/invalidation. Сохранить exact polygonCR/minY/maxY/body identity/order, wall/door sweep/cover/floor semantics и обновлять только изменившуюся entry. Прежде — separate update/bodies/index timings в одном настоящем E-opening сценарии. Не смешивать с другим агентом matrix policy и не выдавать physics index за замену render geometry.

## Конкретный lifecycle gap, допускающий исправление без изменения картинки

До исправления четыре generated InstancedMesh owners не вызывали mesh.dispose при удалении:

1. `interior_room_doors:30` — batchMeshes только removeFromParent.
2. `residential_windows:91` — group удаляется; bundle geometry/material refcounts освобождаются, но5 generated mesh instance attributes отдельно не dispose.
3. `building_storeys:178` — root удаляется; собственные Storey_* / Room_Door_Frames InstancedMesh не dispose.
4. `interior_staircase:105` — group удаляется и общая box geometry/materials dispose, но steps/rails instance attributes не dispose.

Локальный Three `vendor/build/three.module.js:4345–4400`: WebGLObjects.update подписывается на InstancedMesh `dispose`; **только onInstancedMeshDispose** явно вызывает attributes.remove(instanceMatrix) и attributes.remove(instanceColor). Geometry.dispose не является эквивалентом этого object-owned cleanup. Бессрочную утечку/GPU OOM по одному коду не объявляем; установлен отсутствующий deterministic release path после scene rebuild в том же renderer.

Уже правильный пример: interior_mesh_pool.dispose вызывает mesh.dispose; glass_breakage также вызывает mesh.dispose перед заменой/восстановлением instanceMatrix. Последовательность clearContent: static batches dispose → glass.dispose/reset → entries/windows.dispose; её нужно сохранить.

Root17 получил подтверждение архитектора: эти четыре dispose paths свободны, cleanup согласован. **Исправление выполнено** только для owned generated meshes, без geometry/material double-dispose. Двери используют существующий batchMeshes; окна, этажи и лестницы сохраняют список созданных ими InstancedMesh и вызывают их dispose при teardown. Нет recursive traversal чужих/дочерних владельцев. Существующие refcount releases и последовательность glass reset сохранены. Другие изменения в общем git diff этих файлов не являются частью этого cleanup.

## Проверка исправления

Новый `assets/maps/city_rebuild_v1/test_interior_instance_disposal.mjs` выполняет actual WebGLObjects function из локального vendor с наблюдаемым attributes backend и actual Three EventDispatcher, без GL/context/GPU. Два actual GLB `old_town_narrow_townhouse_v1` проходят production createWindowedBuildingEntry; поскольку их комнаты open-plan, private-door factory проверяется отдельной дверью у каждого fixture, без изменения authored layout. На fixture получено14 meshes:5 оконных,4 лестничных,3 этажных,2 дверных.

| Сценарий | Зарегистрировано instance attributes | После удаления первого fixture | Удалённые, но оставшиеся attributes |
| --- | ---: | ---: | ---: |
| Контролируемое воспроизведение прежних четырёх пропущенных dispose events |28|28|14|
| Исправленные production owners |28|14|0|

Baseline — запуск `node assets/maps/city_rebuild_v1/test_interior_instance_disposal.mjs --report --baseline-dispose`: только tracked meshes получают in-memory no-op dispose, чтобы воспроизвести прежнее отсутствие события; actual geometry/material lifecycle остаётся прежним. Это сравнение deterministic release operations, не исторический GPU memory/FPS замер. Обычный запуск без flags — **PASS**; после удаления последнего fixture и после recreate/dispose остаётся0 зарегистрированных attributes.

Дополнительно проверено: повторный dispose безопасен; shared window geometry/material живы для второго здания и освобождаются ровно один раз последним владельцем; original GLB geometry и позднее присоединённый чужой InstancedMesh не dispose. Actual окно проходит break → загрузку нового instanceMatrix → glass reset → загрузку original instanceMatrix → final owner dispose; временный и восстановленный attributes оба освобождаются штатно.

Регрессии **PASS**: `test_interior_room_doors.mjs`; `test_residential_windows.mjs` (все9 закреплённых hash профилей реальных GLB, clipping/cache/refcounts/porch lamps/transparent breakable glass); `test_glass_breakage.mjs --synthetic-only` (panel/instance isolation, bounded shards, restoration). Тяжёлый полный interior planner не запускался.

Для LIVE памяти остаётся сценарий одного actual building через несколько rebuild **того же renderer**, с подсчётом живых instance buffers и geometry/program counts. Полный page reload не демонстрирует этот lifecycle gap. Счётчик теста доказывает вызов штатного vendor удаления attributes, не измеряет bytes драйвера.

**Производительность общей сцены внутри зданий не проверена.** Cleanup предотвращает удержание ненужных instance buffers; это не обещание изменения FPS свежей сцены. Никаких уменьшений мебели, теней, света, прозрачности окон, детализации или планировки не предложено как готовая оптимизация.
