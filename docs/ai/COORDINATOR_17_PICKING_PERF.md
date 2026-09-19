# Координатор 17: остаточная стоимость mercenary picking

13 сентября 2026. Scoped audit `hud_perf_audit`, начат read-only. После отдельного разрешения координатора реализован только opt-in probe (checkpoint ниже). Браузер/GPU и тяжёлые CPU benchmark не запускались. Пользователь требует устранения лагов без ухудшения качества. LIVE от координатора: `mercenaryPicking.lastMs ≈ 9.9`, sticky `maxMs ≈ 51.7`; это входное наблюдение, не мой замер.

## Где именно измеряется работа

`mercenary_walk.mjs:58` начинает lastMs **до** `isBlocked`, `host.getRoster().members.length` и `pick()`. Внутри pick также source target resolution. Поэтому весь lastMs нельзя называть временем raycast. `host.getActions`/selection.setTarget находятся после окончания lastMs и при этом также внутри updateMercenaries/healthHud.

`mercenary_targets.mjs:40` pick делает: refresh реестра всех fleet/traffic/NPC/building targets → setFromCamera → getPickRoots → `ray.intersectObjects(roots,true)` → поиск первого подходящего visible hit → recognize/describe. `pickGround` использует тот же полный raycast, а ограничение 80 м проверяет **после** него. Новое ограничение дальности сейчас не предлагать: сохраняем существующую семантику Infinity, occluders и порядок равных попаданий.

`walk_preview.mjs:605` getPickRoots уже использует shotObstacles plus все NPC. `shotObstacles:543` фильтрует только static roots через `shotRaycastIndex.query`; все fleet и traffic cars добавляются без broadphase, NPC также целиком. Модули автомобилей принадлежат optimizer, NPC — Artist17. Здесь их не менять.

## Статические корни, которые остаются крупными

`staticShotRoots:542` раскрывает ровно два контейнера: `landscape.object.children` и `explorationDecor.object.children`. Остальные прямые дети content остаются целыми корнями.

| Корень | Что реально осталось в exact raycast |
|---|---|
| Native terrain (`walk_preview:1173`) | Один BufferGeometry Mesh на тип исходной клетки/материал, без пространственных чанков. Все треугольники соответствующего материала разбросаны по городу; после попадания в общий bbox/sphere Mesh перебирает их все. |
| EnvironmentVisuals (`environment_visuals:22`) | Один корень «Город · покрытия, трава и дорожное оформление» → Roads, Grass, Parking. Root bbox охватывает город, поэтому рекурсивно обходятся все дочерние chunk/batch objects. |
| Grass (`environment_grass:168–183`) | Уже есть реальные GrassChunk и консервативные chunk.bounds/mesh.boundingBox; они не являются корнями shot index. В каждом admitted InstancedMesh используется текущее mesh.count. Матрицы активных экземпляров переупаковываются при update: нельзя заморозить index по instanceId. |
| Roads (`city_road_dressing:9–10,46–68`) | Paint уже по 128 м чанкам. Equipment новая BatchedMesh по форме охватывает несколько чанков; group records сохраняют локальные spheres. TrafficBulbs динамически меняют матрицы и видимость. Все под одним environment root. Владелец дорог должен согласовать любую правку. |
| Parking (`city_parking:23`) | InstancedMesh уже по 128 м/shape bucket и имеют bbox/sphere. Корень среды пока не использует их как spatial candidates. |
| Railway (`exploration_railway:16–63`) | Один корень: рельсы/шпалы/платформы/балласт вдоль линии плюс движущиеся вагоны. Разбить static и train нельзя простым snapshot bbox: поезд движется. |
| Landscape (`landscape_terrain`) | Ground уже разбит по 40×40 ячеек и передан в root index. Однако каждая поверхность озера и общая ribbon дорог/троп остаются одним Mesh. |
| ExplorationDecor (`exploration_decor:206–236`) | Уже индексируются 128 м chunks. Внутри InstancedMesh по форме/материалу; после попадания в общий sphere перебираются все instances выбранного mesh. LOD меняет geometry, габариты нормализованы к authored reference. |

Лёгкий статический census **текущего topology_for_placement.json**, без построения сцены: 200 строк × 180 столбцов, 36 000 клеток = 72 000 terrain triangles. По buckets: asphalt0 **23 778**, water16 **21 598**, grass8 **14 816**, paving9 **8 504**, protected **3 072**, sand14 **232**. Первые четыре имеют ширину bbox через все 180 столбцов. Это потенциально проверяемые треугольники admitted мешей; не утверждение, что все 72 000 проверяются при каждом направлении луча.

Native mesh не имеет своего custom raycast/BVH. `createRaycastRootIndex` строит snapshot Box3 с padding4 один раз после refresh (`walk_preview:1233`), возвращает исходные roots, без synthetic hits. Он уменьшает число корней, но не ускоряет геометрию внутри admitted Mesh.

## Проверенная семантика локального Three

Прочитан локальный `D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.core.js`:

- `Raycaster.intersectObjects` (54866) проходит корни рекурсивно и сортирует все hits один раз; internal intersect (54892) уважает layers и `raycast() === false`, **не проверяет visible**.
- Mesh.raycast (20399) делает sphere/local bbox, затем `_computeIntersections` (20445) перебирает indexed/non-indexed triangles в material groups/drawRange.
- InstancedMesh.raycast (25835) после общего sphere вызывает Mesh.raycast для всех `count` экземпляров, затем сохраняет исходный object и instanceId.
- Mercenary visible ancestor filtering происходит уже после raycast. Нельзя переносить этот фильтр в общий shot index: другие оружейные callers имеют иной existing visibility contract; `test_raycast_root_index` намеренно сохраняет hidden-parent candidate.

BVH/acceleratedRaycast/boundsTree в просмотренных served production modules не найден. `walk_collision_index` — индекс физических polygonCR, не exact render triangles; он не заменяет picking стен, стекла, травы и декора.

## Конкретный opt-in probe до следующей оптимизации

Предлагаемый URL флаг `mercenarypickqa=1` совместно с perfqa; по умолчанию полностью выключен. Потребуются отдельный helper probe + узкие injection hooks в mercenary_targets/mercenary_walk. Не добавлять ещё один raycast и не запускать периодическое synthetic picking.

1. Разделить scalar timings: `guardAndRosterMs`, `registryMs`, `raySetupMs`, `candidateQueryMs`, `intersectTotalMs`, `resolveMs`, `hostActionsMs`, `wholePickMs`. Измерять естественный hover pick в его существующем расписании; V/X отметить отдельным kind. Показывать measured/blocked/skipped counts отдельно.
2. Один естественный pick в секунду диагностировать подробнее: перед original intersectObjects временно обернуть существующие методы `object.raycast` у actual candidate subtrees, делегируя с точным this/args/return/error. После вызова восстановить original property descriptor, а для inherited метода удалить временную own property. Всегда finally; никаких prototype overrides. Не менять transforms, visibility, arrays корней, layers, far и hit sorting. Не вызывать setFromObject/traverse геометрии внутри measured raycast.
3. Привязать каждый node к исходному root/category в подготовке. Для обычных Groups их собственная raycast почти no-op; **per-root** = сумма времени raycast методов дочерних meshes, а не время пустого Group. У custom recursive raycast учитывать inclusive отдельно и не складывать nested probes дважды. Одни и те же nodes оборачивать один раз. Сохранить точные hit counts по увеличению исходного intersects.length; никаких отдельных ray.intersectObject(root) и повторных сортировок ради таймера.
4. Обёртки дадут `rootRaycastMs`, calls, generatedHits и идентификаторы root (uuid/name/category/nativeTerrainKind), meshCalls/instanceCounts. Census descendants/triangles считать при сборке generation, не каждый hover. `intersectTotalMs - exclusiveRaycastSum` обозначить **traversal+sort+probe residual**, не чистый sort time. Probe preparation/restore overhead публиковать отдельно; это диагностический режим с overhead, не production FPS acceptance.
5. DOM один раз/сек: `document.documentElement.dataset.mercenaryPickingProfile` JSON: version, kind, enabled, sampleId, total/blocked/measured, timing rolling p50/p95, ray origin/direction/far (`null` + farKind:'infinite' для Infinity), candidate counts по категориям, top10 roots, first hit object/instanceId/faceIndex/distance и selected targetId. Ограничить окно 120 measured picks и размер top10, не сериализовать meshes/arrays геометрии. По отключению удалить dataset и все wrappers.
6. Проверка helper лёгкими tests: возвращаются **те же hit objects** и их порядок; original methods restored при нормальном ходе/exception; original exception identity; custom raycast false/layers/inherited/own/повторяющийся root; штатный режим не вызывает дополнительных performance.now/DOM. LIVE один корневой владелец, нужна загруженная scene и направление вниз/горизонтально/дальний объект.

## После атрибуции: безопасные направления exact acceleration

1. **Environment subroots**: переиспользовать существующий `createRaycastRootIndex` для неизменяемых paint/parking meshes и фиксированных conservative GrassChunk bounds. Не трогать их render graph/geometry/draw calls. Динамические TrafficBulbs, BatchedMesh equipment и train оставить в exact fallback, пока владелец не даст консервативный полный envelope/инвалидацию. Нельзя просто собрать frozen Box3 для текущих visible/count0 grass instances или текущей позиции поезда. Новый mercenary-specific index предпочтительнее изменения общего оружейного visibility contract.
2. **Native terrain**: если probe подтверждает его доминирование, делать geometry-local BVH либо ray-cell/triangle index по текущей неизменяемой BufferGeometry. Индекс хранит исходные triangle offsets, не переставляет source vertex/index buffers; narrowphase теми же triangles/material.side/drawRange. Возвращать original object, original faceIndex/normal/UV/distance. Сохранять Infinity, near, grazing/coplanar/water/границы клеток и stable tie order. Не заменять groundHeight/физическим полигоном, не разрезать render geometry и не увеличивать draw calls.
3. **Instance index**: только там, где матрицы статичны, geometry LOD поддерживает консервативные bounds и index IDs стабильны. Отбирать instanceIds через exact conservative box, затем делегировать идентичный Mesh narrowphase и восстанавливать original object/instanceId. Grass переупаковку и динамический transport не включать без version/refit contract владельца.
4. Для каждого варианта нужен parity тест baseline/indexed по first accepted hit + всей необходимой информации и отдельная actual populated p50/p95 before/after. Известные tests `test_raycast_root_index`/`test_forest_raycast_index` подтверждают только свои forest/terrain fixtures и ограниченный набор лучей; они не доказывают native terrain/environment/движущийся train или merchant Infinity сценарий.

Вывод: код доказывает несколько сохранённых крупных narrowphase обходов, но **не доказывает, какой из них создаёт наблюдаемые 9.9/51.7 мс**. Первая следующая работа — opt-in per-root attribution; никаких обещаний FPS по статическому census.

## Реализованный probe — готов к LIVE

Координатор разрешил `mercenary_picking_probe.mjs` и узкие hooks в `mercenary_targets.mjs` / `mercenary_walk.mjs`. Уточнил: включать **только perfqa**, один natural pick/sec. Выполнено: `perfqa=1` включает helper, отдельный mercenarypickqa-флаг из первоначального предложения не нужен. В обычной игре helper возвращает null без таймеров/DOM/обхода. Не добавляются интервалы, synthetic picking, ещё один raycast или сортировка; частота hover не меняется. V/X пользовательские picks не профилируются — минимальный вариант измеряет только естественный hover.

`document.documentElement.dataset.mercenaryPickingProfile` публикуется после sampled hover, не чаще 1 Гц. Root читает JSON с:

- `timings.guardAndRosterMs`, `registryMs`, `raySetupMs`, `candidateQueryMs`, `intersectTotalMs`, `resolveMs`, `sourceResolveMs`, `hostActionsAndSelectionMs`, `wholeHoverMs` (фазы отсутствуют, если этот путь не выполнялся);
- `timings.prepareMs`, `restoreMs`, `exclusiveRaycastMs`, `traversalSortProbeResidualMs`;
- `categories` (`native-terrain:asphalt/water/...`, environment, landscape, exploration-decor, railway, cars, npc, building-or-decor, other): roots/calls/raycastMs;
- `roots` top10 по exclusive raycastMs с uuid/name/category/calls;
- `candidateCount`, `visitedNodes`, `instrumentedNodes`, `intersections`, `raycastCalls`, `instrumentationComplete`, `blocked`, `failed`;
- `firstAcceptedHit` (первый visible/nonignored hit, в том числе occluder), `selectedTargetId`, ray origin/direction/near/farKind/far;
- `rolling` p50/p95/max по каждой фазе, окно не больше 120 sampled hover; `totalSamples`, `blockedSamples`.

Временные own raycast wrappers устанавливаются только у geometric/custom descendants, без клонирования объектов и без вычисления геометрии/bounds. Пустой inherited Group.raycast не измеряется. Original this/args/return/exception сохраняются, descriptors восстанавливаются в finally. Вложенные custom вызовы учитываются exclusive, чтобы не суммировать одно и то же время дважды. Immutable callback остаётся original, coverage помечается incomplete. Методы, которые custom callback намеренно заменил во время запроса, не перетираются старым descriptor; coverage также incomplete. Корни и hits не дедуплицируются/не переставляются. Все изменения локализованы, vehicle modules, Three, static houses и source world не менялись.

**Это диагностика с overhead.** При perfqa sampled кадр содержит подготовку обёрток и timers; старый `mercenaryPicking.lastMs` на таком кадре тоже содержит overhead. `intersectTotalMs - exclusiveRaycastMs` включает обход дерева, сортировку и неучтённую часть instrumentation, НЕ чистая стоимость сортировки. Whole-hover включает подготовку/восстановление. Не сравнивать profiler-on FPS с прежним profiler-off как ускорение.

После разрешения root о завершении LIVE запущены только лёгкие suites: `test_mercenary_picking_probe.mjs`, `test_mercenary_targets.mjs`, `test_mercenary_walk.mjs` — **PASS**. Новый тест использует actual локальный Three: те же ссылки hit entries и stable equal-distance order; root duplicates; layers; ancestor hidden semantics; custom return false; точный this; оригинальная exception identity; восстановление own descriptors и inherited Mesh/InstancedMesh; nested exclusive accounting; unsampled bypass без traversal/timer; QA-off zero access; реальные target/instance parity. Scope ready, reload/живой замер у координатора.

Последний дополнительный LIVE baseline от root, до probe reload: picking last9.6/max68.8 и healthHud p9511.1; общий renderer всё ещё около74мс. Это отдельные заметные spikes, не доказательство, что picking — единственный источник низкого FPS.

## LIVE атрибуция и дальнейшее включение

Root получил natural hover: native asphalt3.4ms, water3ms, grass2ms, paving1.1ms; cars3.6ms/8270calls, environment1.1ms/720calls; registry.2ms. Exclusive15.6ms, originalintersect20.4ms; prepare6.9/restore1.4/residual4.8ms являются дополнительной диагностической стоимостью. Native terrain передан отдельному агенту для exact triangle index, geometry/quality/far сохраняются.

После атрибуции root добавил обязательный дополнительный URL flag **mercenarypickqa=1 совместно с perfqa=1**. Обычный perfqa больше не включает подробные wrapper timings после следующего reload: нельзя оставлять пользователю 10–20ms диагностического overhead каждый sampled hover. V/X/попадания не менялись; mercenary_walk и probe suites PASS. Предыдущая формулировка «только perfqa» описывает первый диагностический reload.
