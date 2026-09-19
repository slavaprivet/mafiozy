# Native terrain: exact triangle acceleration — design before implementation

13 сентября 2026. Исполнитель: mercenary_input_audit, root Координатор 17. **LIVE A/B успешно выполнен root; native triangle index теперь включён по умолчанию, `nativepick=0` отключает build. История design/opt-in этапа сохранена ниже; актуальный итог в последней секции.** Scope: native terrain picking; grass blades, rendering, vehicle и мировая дальность не меняются.

## Основание

Root LIVE natural hover: native asphalt около3.4ms, water3ms, grass2ms, paving1.1ms — примерно10ms из15.6ms exclusive hover. Cars3.6ms, environment1.1ms, registry0.2ms — отдельные владельцы/задачи.

`walk_preview.mjs`, terrain(grid,protectedMask,asphalt): каждый native tile добавляет **6 nonindexed vertices /2 triangles** в один большой mesh по tile key. Y=0 либо-.18 для воды. `protectedMask` перегруппировывает material key, но не меняет геометрию tiles. Geometry получает position и computed normals, **setIndex отсутствует**. Поэтому indexed-only specialization не ускорит текущие meshes.

`environment_surface_materials.mjs:235+` не меняет position/index: воде добавляет surfaceDepth и заменяет material. Вода становится transparent=true, opacity=.92, но сохраняет обычный CPU Mesh raycast. **Не ограничивать fastpath opaque material**, иначе пропускается измеренный water bottleneck. Прозрачность не влияет на стандартное Mesh triangle intersection, важен material.side.

Все перечисленные meshes — обычный single-material Mesh с `userData.nativeTerrainKind`. Rendering vertex/index data остаются исходными; water shader deformation остаётся только GPU, как прежде. Не пытаться пересчитывать CPU hit по анимированной поверхности воды.

## Рекомендуемый механизм

Новый модуль native_terrain_raycast_index.mjs: консервативный локальный triangle-AABB BVH и **per-mesh hook только _computeIntersections**. Оригинальный Mesh.raycast остаётся неизменным, включая original bounding sphere check, near/far sphere admission, inverse matrix, world→local ray и optional local boundingBox. Не менять THREE.Mesh.prototype и не переписывать renderer.

BVH строится один раз для immutable geometry. Каждый leaf хранит **исходные triangle offsets** (0,3,6...), а не новый mesh/index buffer. Bounds содержат исходные Float32 vertex positions без квантования. Parent bounds — объединение children. Небольшое наружное padding допустимо как консервативное расширение; никогда не уменьшать bounds. Расщепление по максимальной протяжённости, bounded leaf size (например16triangles). Общий лимит ray.far остаётся **Infinity** в hover.

Query использует готовый local ray, полученный original Mesh.raycast. Обходит все пересекающиеся BVH boxes, **не останавливается на первом/ближайшем hit**. Начальный patch не делает локальный near/far pruning: actual world near/far оставлен Three. Собранные candidate offsets сортируются по возрастанию, как original triangle loop.

Для exact triangle math предпочтительно не копировать вручную private checkGeometryIntersection. Вместо этого для каждого candidate выполнить сохранённый original Mesh.prototype._computeIntersections на локальной **facade**:

- geometry facade с текущими ссылками attributes/index/groups оригинальной geometry и отдельным drawRange={start:originalTriangleOffset,count:...}; **исходный geometry.drawRange не мутируется**;
- material и matrixWorld — текущие оригинальные ссылки;
- getVertexPosition связан с оригинальным mesh;
- original helper сформирует исходный faceIndex=floor(offset/3), face.a/b/c, face.normal, materialIndex0, uv, uv1, interpolated normal с его face-forward правилом, barycoord, distance и point;
- только у добавленных hit records заменить `.object` с facade на исходный mesh. Остальные поля не изменять.

У single material groups стандартный Three игнорирует groups; facade сохраняет их всё равно. Для original drawRange ограничить candidate offsets тем же start/end. Если start не кратен3 — fallback, поскольку исходный loop тогда задаёт другие тройки vertex/index offsets. Count, не кратный3, сам по себе допустим: original loop всё равно проверяет полную последнюю тройку при offset<end; facade должна повторить это правило, а не обрезать сами vertices.

Facade — объект для функции пересечения, не renderer mesh; scene hierarchy/UUID/geometry/material не подменяются. Существующие root profiling wrappers над mesh.raycast сохраняются. Hook устанавливать при сборке native meshes, до профилировочного wrapper; dispose снимает только собственный hook и возвращает исходное состояние.

## Почему это сохраняет exact hits

1. Каждый исходный triangle целиком содержится в leaf AABB. Ray-triangle hit принадлежит этому AABB; консервативное ray-box admission не должно его отбросить. BVH не использует невидимость/материал/дальность для дополнительных исключений.
2. Окончательный triangle test исполняется **той же установленной Three функцией** на тех же трёх vertices, material.side, local/world ray и matrixWorld. Нет нового приближённого box hit и нет своей интерполяции UV/normal.
3. Original Mesh.raycast по-прежнему отвечает за начальный sphere/box admission. Candidate traversal не меняет near/far включительность: Three rejects distance<near или distance>far, границы остаются включительными.
4. Candidate offsets упорядочены так же, как original full loop. Попадания на shared edge/vertex в обе соседние triangles сохраняются; **не deduplicate hits**. До глобальной stable distance sort Raycaster per-mesh hit order идентичен. Object identity возвращается исходная.
5. Идеальный box geometric аргумент нуждается в numerical regression: degenerate zero-height bounds, axis-parallel ray, origin на плоскости, signed zero и почти параллельные лучи. Не объявлять proof полной реализацией до такого сравнения.

## Admission / invalidation / fallback

- Только обычные nativeTerrainKind meshes; nonindexed обязателен, indexed можно поддержать тем же offset mapping.
- Single material; без skinned/instanced/morph/custom getVertexPosition/custom _computeIntersections. Не цеплять unrelated landscape, grass tuft geometry, batching или vehicles.
- Сохранить geometry/index/position references, array references, count и attribute versions. При замене geometry/position/index, version/count/layout changes — **сразу original fallback**, rebuild только отдельно/без hover hitch. Direct array mutation без needsUpdate не обнаруживается без полного scan; текущий immutable builder должен быть частью контракта. При нарушении контракта индекс снимается, а не молча работает с устаревшими bounds.
- Dynamic uv/normal/material.side можно читать текущими на финальном native test; candidate bounds зависят только от position/index. MatrixWorld меняется без rebuild, потому что индекс local-space и original raycast делает новый inverse transform. Singular/nonfinite transforms безопаснее отправлять в fallback.
- Unsupported drawRange start, nonfinite coordinates, malformed triangle count, interleaved/custom position provider — fallback первой версии.
- Nearest-only mode, finite replacement for Infinity, пропуск transparent water и visibility filters запрещены: это меняет текущие results.
- Build до первого interactive hover; не делать большой lazy build на горячем луче. Учесть одноразовые buildMs/memory отдельно от hover timing. Общая scene refresh уже пересоздаёт native geometry; dispose освобождает typed BVH arrays.

## Meaningful regression перед разрешением production integration

Исполнить **actual terrain builder** на реальном topology и protected mask в Node, без renderer. Сохранить original raycast/compute метод как reference. Для одних и тех же meshes сравнивать raw ordered hit arrays и result после Raycaster.intersectObjects sort:

- object strict identity, hit count/order, distance/point, faceIndex, face.a/b/c/materialIndex/normal, interpolated normal, uv/uv1/barycoord presence и values;
- downward/upward/горизонтальные/почти горизонтальные rays, origin на земле и под ней, общие tile edges/diagonals/corners, outside map, вода Y=-.18, protected geometry;
- near=0, finite near/far, exact near/far boundary, far=Infinity, transformed parent scale/rotation/translation, reversed material.side и DoubleSide;
- changing drawRange, single-material groups, indexed small fixture с nontrivial indices и UV/UV1;
- fallback после geometry/position/index replacement/version updates; morph/custom/material array negative cases; disposal restores exact method;
- before/after raw attribute/index bytes и UUID, geometry bounds/renderer values/source hierarchy unchanged кроме разрешённого lazy boundingSphere, которое делает original Three.

Сначала небольшой parity set, затем real topology randomized/adversarial comparison по согласованию CPU окна. Только после PASS выполнить LIVE тот же natural hover и population/camera: native exclusive p50/p95, candidate triangles vs total, index query time, hit counts/order, общий frame p50/p95. До build/profile нельзя обещать конкретный gain из10ms.

## Решение для root

Самый узкий следующий patch — отдельный opt-in native terrain triangle index с original Three intersection facade и exhaustive fallback, плюс tests. Root-owned integration — одна install per native mesh после geometry creation/material preparation и dispose на refresh. Никаких render indices, vertices, normals, материалов, теней или дальности не менять. **В этом этапе выполнен design, production ещё не тронут.**

## Реализовано после разрешения root: helper готов, integration pending

`assets/maps/city_rebuild_v1/native_terrain_raycast_index.mjs` экспортирует `installNativeTerrainRaycastIndex({THREE,mesh})`: null для unsupported meshes, иначе `{stats,dispose}`. Существующий Mesh.raycast не меняется; hook только instance `_computeIntersections`, final test — saved original Three метод через отдельную facade. Immutable position/index version/layout guard, single material включая transparent water, nativeTerrainKind allowlist. Candidate offsets сортируются, не deduplicate. DrawRange и render attributes/index не мутируются. Direct attribute array mutation без needsUpdate остаётся вне immutable-контракта; current terrain builder таких mutations не делает.

Leaf максимум16 triangles, median BVH, outward bounds padding `1e-7 * max(1,abs(coordinates))`. Build scratch triangle bounds освобождён после построения; dispose отпускает tree/order и восстанавливает только свой hook, не перетирает чужую замену. Внутренний BVH не ограничивает near/far и не отбрасывает transparent water. UI-toggle и production install/dispose ещё не добавлены.

Meaningful test `test_native_terrain_raycast_index.mjs` исполняет **actual terrain() из текущего walk_preview** на сохранённой реальной topology (200×180=36,000 tiles,72,000 triangles,6 meshes). Сравнивает baseline и helper на тех же objects: raw ordered hit arrays и actual Raycaster global sort, exact numbers/UV/UV1/normal/face/barycoord/object identity. Не сравнивает приблизительно собственные вычисления.

- **PASS 1,240 comparisons /995 hits**, real nonindexed terrain и indexed/nonindexed UV fixtures; transparent water и protected-water fixture Y=Float32(-.18).
- Grazing directions вплоть до1e-14, flat/axisparallel/signedzero, origins на поверхности/сверху/снизу и до1e16 по высоте, tile edges/diagonals/corners; shared-edge duplicate hits и их порядок сохранены.
- Near/far exact boundaries и Infinity, Front/Back/DoubleSide, translated/rotated/nonuniform parent и reflected scale; dynamic UV/normal также остаются исходными Three results.
- **13 invalidation cases**: replacement/version/layout/array changes, nonaligned drawRange, morph, custom vertex/attribute methods, material array. Unsupported install и ownership-safe dispose проверены отдельно. Real source position bytes/geometryUUID/materialUUID/index/parent identities неизменны.

Команда `node assets/maps/city_rebuild_v1/test_native_terrain_raycast_index.mjs --bench` завершилась PASS (4.55s процесс). CPU-only comparable terrain benchmark:120 deterministic oblique downward rays, одинаковые6 roots,30 warm pairs, порядок baseline/index чередуется по samples, без renderer/GPU:

| Метрика | Original Three | Triangle index |
|---|---:|---:|
| per-ray p50 |16.2061ms|0.0475ms|
| per-ray p95 |17.1918ms|0.0741ms|

Кандидаты на луч: mean33.14 /p95=56 /max72 из72,000 total triangles. BVH build всех6 meshes **111.21ms** в том же запуске (отдельная одноразовая стоимость; предыдущие контрольные runs104.76–135.68ms). Build разрешён **при initial load до первого populated frame**, не lazy first-hover. Это CPU fixture gain, не FPS claim и не замена root LIVE A/B: реальная hover camera может давать иные ray directions и стоимость.

**Ready for root review/integration.** Производительность общей сцены с этим helper ещё не проверена; `walk_preview`, environment preparation, shot index, дальность и renderer данным этапом не изменялись.

## Final: opt-in integration готова после разрешения root

В `walk_preview.mjs` добавлены только import, состояние/diagnostic API, startup install перед существующим shotRaycastIndex (после createEnvironmentVisuals, где выполняется preparation surfaces), и dispose в начале clearContent. URL **`nativepick=1`** включает индексы при загрузке; без флага они не строятся. Метод **`window.MafioziNativeTerrainPicking.setEnabled(false/true)`** переключает уже построенные индексы без rebuild; `.stats()` возвращает buildMs, meshes, enabled и per-index counters. Без начального URL opt-in API не запускает поздний build. UI-кнопка не добавлялась.

Root review дополнен: `finally` возвращает real object identity новым hits даже при исключении original метода; original exception identity не меняется. Actual Three tests с throwing UV getter на второй triangle и throwing append после частичного результата проверяют предыдущие hits и real object. Дополнительно проверены off→on без rebuild и отказ повторного enable после dispose. Итог **PASS 1,243 comparisons/1,001 hits +13 invalidation cases + exception/dispose/toggle cases**. `node --check walk_preview.mjs` PASS.

Для HUD QA добавлены allocation-free getters `.ready` (meshes>0), `.enabled`, `.generation`. API identity стабильна, generation увеличивается при clear и build, при toggle не меняется. `.stats()` также возвращает generation. **Actual integration regression** исполняет текущие source API/startup install/clear prefix: opt-in и отсутствие флага, toggle, clear→rebuild, восстановление Mesh метода PASS. HUD agent владеет кнопкой/rolling timing отдельно, helper не вызывает stats() каждый hover.

**Ограничение QA:** detailed picking probe, который временно оборачивает mesh.raycast, нарушает plain-method admission и вызывает original fallback. Такое поведение проверено тестом. Для измерения ускоренного пути root использует scalar mercenaryPicking и `.stats()`, **`mercenarypickqa` выключен**; counters fallbacks должны оставаться нулевыми. GPU/rendering и дальность не менялись. LIVE общей сцены после integration ожидается у root; CPU benchmark выше не выдаётся за измерение FPS.

## Production default после успешного LIVE A/B

Root сообщил сопоставимый LIVE: viewport911×920, camera(167,2.74,168), same scene; whole-hover OFF40 samples p50/p95 **10.1/11.0ms**, ON32 samples **4.4/5.4ms**. На6 native meshes build130.1ms при загрузке, fallback0/error0. По root renderer/визуальный результат неизменён. Это измерение стоимости hover (окна40/32samples), не новая оценка общего FPS.

По прямому разрешению root единственный production switch изменён на `nativepick !== '0'`: **default ON**, явный `nativepick=1` ON, **`nativepick=0` escape hatch OFF и без build**. Материалы, геометрия, дальности и ray semantics не менялись. Local QA button по-прежнему требует **perfqa=1 + nativepick=1**, detailed mercenarypickqa должен быть OFF; helperQA другого владельца не редактировался.

Actual source integration tests обновлены для всех трёх вариантов URL: отсутствие параметра/default ON, explicit1 ON, explicit0 OFF. Проверены toggle, generation, clear→rebuild и восстановление исходного метода. **1,243 exact comparisons/1,001 hits +13 invalidations PASS**, startup/API/lifecycle PASS, `node --check walk_preview.mjs` PASS. Новых GPU-действий агент не выполнял.
