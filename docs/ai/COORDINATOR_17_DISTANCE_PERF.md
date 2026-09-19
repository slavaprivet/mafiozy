# Дальность мира, загрузка и скрытые матрицы — аудит 17

13 сентября 2026. Подзадача `roster_cost_audit`, новое read-only поручение root. Production не изменён. Браузер/GPU не открывались. Выполнены чтение actual source, JSON-заголовков 33 GLB и короткая структурная проверка используемого Three r180 без WebGL. Трава, NPC и транспорт оставлены их владельцам.

## Ответ на вопрос пользователя

**Да, статический город сейчас создаётся целиком, в том числе далёкие здания с интерьерами. Но целиком каждый кадр он не рисуется.** Дальность главным образом переключает видимость уже загруженных объектов. Скрытые здания сохраняют JS-иерархии, геометрию, материалы и связанные ресурсы; стандартный обход `updateMatrixWorld()` продолжает обходить скрытых потомков.

Это обоснованный кандидат лишней CPU-работы и удержания памяти. Он не доказывает, что главная причина текущих лагов — дальность: для attribution нужен populated profile координатора. Нельзя считать весь объём загруженной геометрии отрисованным, а число placement — числом draw calls.

## Что реально загружается

`walk_preview.mjs:1202–1211`:

1. Собирает все buildings, detention sites и decor placements.
2. Строит `unique` по binding SHA-256, загружает **все** типы GLB с concurrency 3.
3. Для **каждого** bound placement клонирует template, добавляет group в `content`, создаёт окна/entry/storeys/interior design, lights/glass registrations и коллизии.
4. Затем создаёт exploration decor целого плана, terrain, railway, environment и static batches.

Нет условия расстояния перед GLB fetch, clone или генерацией интерьера. У окон есть отдельный helper очереди, но данный путь вызывает `applyResidentialWindows()` непосредственно через `createWindowedBuildingEntry()`, поэтому наличие queue API не означает текущий streaming.

Короткий census actual размещения и JSON GLB:

| Показатель | Значение |
| --- | ---: |
| Buildings placement | 75 |
| Detention native placement | 3 |
| Authored decor placement | 164 |
| Всего bound placements | 242 |
| Уникальные GLB по SHA | 33 |
| Сумма binding bytes уникальных GLB | 19 337 364 байт |
| Уникальные определения GLB nodes | 2 289 |
| GLB node definitions × число placements | 7 704 |
| GLB mesh-node definitions × число placements | 6 820 |
| Image definitions внутри 33 GLB | 1 |

Это census файлов, не runtime acceptance. Числа nodes — определения GLB, не точное число live `Object3D`: loader может добавлять/менять иерархию; сгенерированные комнаты/мебель/окна/батчи и exploration decor сюда не включены. 19.3 MB — asset bytes, **не RAM/VRAM**. Shared template clones обычно сохраняют ссылки на общую geometry/material; нельзя умножить bytes на placements и назвать результат потреблением памяти.

## Какие расстояния действуют

`walk_preview.mjs:1770`, раз в >250 мс:

- Authored placements: `node.visible = node.position.distanceToSquared(controls.target) < 220*220`.
- `staticRenderBatches.update({focus:controls.target,maxDistance:220})` отдельно синхронизирует видимость копий вне исходной иерархии.
- `explorationDecor.update({focus:controls.target,maxDistance:420})`; расстояние до ближайшей точки расширенного XZ bounds chunk, а не центра. ChunkSize 128, поэтому полный chunk может пересекать порог границей.

Three renderer отдельно применяет frustum rejection. `visible=false` действительно прекращает спуск render/shadow traversal в этот subtree (`three.module.js:16551`, `:8733`). Это не выгрузка и не остановка scene matrix traversal.

Decor уже имеет существующие LOD: near 64, far 180, hysteresis 8; меняется tessellation с сохранением instances/transforms. Этот аудит ничего в них не меняет. Уменьшать расстояния/LOD/число объектов ради результата не предлагается.

`exploration_decor.mjs:175–223` создаёт все bucket matrices, instance colors и chunk meshes из полного плана сразу. Его `stats.renderedInstances` — созданные component instances, а не количество фактически нарисованных сейчас. `visibleDrawCalls`/`visibleTriangles` учитывают distance-visible chunks, но ещё не камерный frustum/GPU occlusion. Default `maxDistance=360` внутри модуля в общей игре переопределён **420**.

## Скрытая CPU-работа подтверждена

Используемый vendor Three r180, `three.core.js:14280–14316`:

- `updateMatrixWorld()` не проверяет `visible`.
- При `matrixAutoUpdate` вызывает `updateMatrix()`.
- Затем рекурсивно вызывает всех детей, независимо от видимости.
- Обычный `scene.updateMatrix()` помечает world dirty, передавая `force=true` потомкам. Поэтому только `matrixAutoUpdate=false` на static children ещё не убирает повторные world multiplications.
- `matrixWorldAutoUpdate=false` убирает multiplication, но **не рекурсию**.

Renderer вызывает `scene.updateMatrixWorld()` перед render traversal (`three.module.js:16376`). В изученном production static content/decor нет замораживания таких матриц. Opt-in `render_freeze_qa` удерживает presentation, но не заменяет production matrix policy и тоже рисует scene.

Короткая actual-Three проверка, без renderer: Scene → invisible Group → 4 обычных Object3D. Один проход, счётчики prototype calls, затем восстановление всех методов:

| Режим | updateMatrixWorld visits | local compose | world multiply |
| --- | ---: | ---: | ---: |
| Обычный hidden subtree | 6 | 6 | 5 |
| Static descendants matrixAutoUpdate=false | 6 | 1 | 5 |
| Descendants local+world auto=false | 6 | 1 | 0 |

Это доказательство semantics используемого vendor, не benchmark и не количественная оценка общего FPS.

Static batching дополнительно сохраняет source meshes для picking/коллизий/восстановления материала. В `static_render_batches.mjs` они не удаляются: получают material clone с `visible=false`, а batch copies живут отдельно. Поэтому draw reduction не обязано давать такое же сокращение Object3D traversal. Дальние placement groups скрываются, ближние retained source descendants продолжают посещаться при матрицах и render traversal до проверки материала.

## Дальние интерьеры и текстуры

- `building_window_integration.mjs:41–54` сразу создаёт окна, entry/storeys, затем `createBuildingInteriorDesign()`; нет gate «игрок приблизился/вошёл».
- В интерьере сразу создаются furnishing pools, room doors, safes и registry bindings. Делать lazy весь интерьер без разделения логики/коллизий/визуала опасно: это может потерять доступные двери, сейфы, body volumes и server/source ID.
- Но неправильно утверждать, что каждый дальний интерьер полностью симулируется каждый кадр: `updateBuildingEntries()` уже пропускает entries без `needsUpdate` после первоначальной сборки. `needsUpdate` включает движущиеся doors/safes; движущиеся процессы продолжаются корректно и на расстоянии.
- Glass update уже ранне выходит при отсутствии pending fracture/active shards. Street lighting имеет static placement cache, daylight early-out и ограниченный light pool. Не переписывать эти уже оптимизированные владельцами механизмы.
- `templates` Map сохраняет parsed GLB по SHA. `clearContent()` освобождает runtime entries/decor/etc, но не очищает template Map и не делает distance eviction. Изменённые SHA могут оставаться в сессии после refresh; это кандидат отдельного memory census, не доказанная утечка текущей стабильной игры.
- В рассмотренных 33 GLB только один embedded PNG image definition (pavilion AO). Интерьерные отделки `interior_finishes.mjs` — procedural shader patterns + ref-counted material cache, а не отдельные raster textures для каждой комнаты. Поэтому гипотеза «тысячи дальних интерьерных текстур» здесь не подтверждается. Данные не охватывают NPC/car/sky/environment textures, их память отдельно не исследована.

## Узкий безопасный вариант без ухудшения качества

Первым этапом измерить и оптимизировать **матрицы доказанно неподвижных ветвей**, сохранив текущие distances/geometry/materials/instances/collisions. Самый узкий candidate — `exploration_decor` chunks: их update меняет visibility и geometry reference для существующего LOD, а не transforms. Geometry/color/instance data остаются теми же.

1. После сборки один раз обновить world matrices и сохранить transforms.
2. Для явно immutable decor descendants отключить local и world auto recomputation. Это сохраняет обход, но убирает compose/multiply; standalone correctness A/B сравнивает все `matrixWorld` и projected bounds, в том числе hidden→visible и LOD transitions.
3. Проверить реальное уменьшение `matrix` p50/p95. Только если traversal всё ещё заметен, рассматривать scoped static-root traversal guard. Такой guard требует explicit dirty invalidation при parent/root transform change, добавлении/удалении/reparent и восстановлении на dispose. Просто `if(!visible)return` в общем Object3D или глобально выключить scene updates нельзя: сломаются двери, bounds, raycast и живые объекты.
4. На здания расширять только после аудита static leaves. Не замораживать целиком building group: в нём есть door hinges, safes, windows/glass replacements и живые world-bound callbacks.

Не начинать с выгрузки далёких интерьеров: потребуется отделить постоянную game/collision identity от visual resources, сохранить окна с видимыми комнатами и prefetch без появления пустоты при подходе. Это гораздо больший риск, чем устранение лишнего преобразования неизменных матриц.

## Как измерять полезность

Root сохраняет одну populated вкладку. На текущей камере после pending=0 снять baseline 120 кадров, затем controlled render-only A/B при одинаковых quality/shadows/population/camera. Нужны `matrix` p50/p95, renderer/frame/interval p50/p95, `frameDraws.main/shadow/total` и triangles. Прирост от matrix candidate должен идти при **неизменных** draws/triangles/положениях объектов.

Для attribution отдельно один DOM-published structural census: content total/visible-by-ancestor nodes, hidden static nodes, matrix auto flags, static source meshes vs batch meshes, loaded placement counts, decor total vs distance-visible chunks. Не делать scene.traverse и JSON.stringify всего census каждый кадр. `renderer.info.memory.geometries/textures` даёт количества, не bytes; asset byte census не заменяет JS heap/GPU memory измерение.

После A/B короткий normal gameplay: движение через существующую границу 220/420, поворот камеры, вход в здание, дверь/сейф, выстрел в стекло, возвращение к дальнему месту. Сравнивать тени и рисунок сцен без отсутствующих объектов. **Производительность общей сцены этим аудитом не проверена.**

## Уточнение root: конкретный exploration leaf candidate

После первоначального отчёта root запросил сравнить local-only с local+world freeze **только immutable exploration leaves**, без вмешательства в buildings/doors, траву или общий `updateMatrixWorld`. Выполнен новый CPU structural test `assets/maps/city_rebuild_v1/test_exploration_static_matrix_candidate.mjs`; experimental policy определена только внутри теста и нигде в production не импортирована.

Точный scope: прямые mesh leaves `explorationDecor.object → chunk → mesh`, с `isInstancedMesh`, `userData.explorationDecor`, `userData.explorationShape` и нулём детей. Все такие mesh создаёт сам `createExplorationDecor`; их local transforms после создания не меняются, размещение элементов хранится в instanceMatrix. Рендерер меняет только geometry reference при существующем LOD. Chunk/root продолжают наследовать обычные parent transforms.

Actual `createExplorationDecor` с реальным `RoundedBoxGeometry`, всеми 21 видами объектов, разными position/yaw/scale, без общего тяжёлого planning:

| Один structural frame | Local compose | World multiply | updateMatrixWorld visits |
| --- | ---: | ---: | ---: |
| Baseline: 73 leaves + 21 chunks + root + scene/parent | 97 | 96 | 97 |
| Только leaf matrixAutoUpdate=false | 24 | 96 | 97 |
| Leaf local+world auto=false, включая root/parent guard | 27 | 25 | 97 |

Ни один вариант не пропускает traversal. Local-only сохраняет inherited world updates как раньше. Local+world вариант перед каждой render/spatial-query boundary явно обновляет root/ancestors и сравнивает root.matrixWorld с сохранённым. При изменении parent/root/reparent восстанавливает world-auto у owned leaves для полного refit, затем замораживает снова. На dispose возвращает исходные flags. **Нельзя вызывать такой guard только раз в 250 мс через decor.update:** тогда query/render между transform change и guard может видеть старые world matrices. Production wiring этого контракта ещё не сделан и требует решения root.

Проверены exact world matrices, существующие LOD geometry buffers и detail levels, hidden→show, instance arrays/colors/IDs, material identities, conservative world bounds, изменение parent position/rotation/nonuniform scale, отдельное изменение root, reparent, **ненулевые actual InstancedMesh ray hits** и восстановление flags/dispose. PASS. Прогон ~0.3 с всего процесса, без timing benchmark; число операций важнее этой случайной длительности.

Root передал уже снятые LIVE counts: **66 chunks / 444 total decor mesh batches / 28 563 component instances / 2 422 objects / 1 998 trees**; distance-visible 34 chunks / 245 mesh batches. 2 854 956 — total full-quality decor triangles, не текущие main draw triangles.

Следовательно, узкий leaf-only upper bound в текущей сцене — **444 исключённых local compose за scene matrix pass**; local+world дополнительно исключает **444 leaf world multiplications**, с небольшими затратами guard. Число посещений узлов, geometry, instances, материалы, LOD, дальность 420, shadows и collisions остаются теми же. Это умеренный кандидат; нельзя обещать, что он устранит измеренные root 8.2/10.1 мс matrix p50/p95 целиком. Для более существенного выигрыша придётся после LIVE оценки отдельно аудировать многочисленные static building leaves, сохраняя динамическое владение авторов.

Никаких production изменений по дальности/матрицам в этой подзадаче не сделано.

## Root review: local+world отклонён, следующий scope — static batch sources

Root нашёл предел экспериментальной world-freeze policy: guard root.matrixWorld не замечает изменение local transform отдельного chunk при неизменном root, а freshness требует `prepare()` до **каждого** spatial caller. Поэтому local+world prototype выше **не разрешён к production**. PASS перечисленных сценариев не доказывает произвольный transform contract. Общий traversal override также не предлагается. Дальше рассматривается только local `matrixAutoUpdate=false` с сохранением world-auto.

### Более крупный census без повторной генерации города

Новый воспроизводимый скрипт `assets/maps/city_rebuild_v1/audit_static_source_leaf_census.mjs`:

- actual GLTFLoader прочитал 33 текущих GLB для 242 placements; для единственного PNG применён тот же image-upload stub, что в существующем pavilion CPU test;
- применены loader hidden proxies, placement visibility masks, actual `applyBuildingDoorsGlass`, placement transforms;
- actual `createStaticRenderBatches` выполняется **только до allocation**: audit копия модуля возвращает собранные groups перед `new BatchedMesh`. Используются настоящие admission, geometry-layout, material grouping и minInstances=3;
- не вызывались entry/storey/interior generation, planning, road navigation, AI, renderer или GPU;
- один проход реального Three matrix traversal до/после экспериментального local-only freeze, затем inherited parent transform parity и restore flags. Общий процесс ~0.7 с, не timing benchmark.

| Authored-stage показатель | Количество |
| --- | ---: |
| Actual GLTFLoader mesh objects, включая helpers | 7 113 |
| Принятые material/layout groups с ≥3 members | 208 |
| Уникальные принятые source meshes | 4 609 |
| Из них leaf и matrixAutoUpdate=true | 4 609 |
| Authored building leaves | 4 269 |
| Authored decor leaves | 340 |
| Animation clips в GLB | 0 |
| Local compose, вся audit hierarchy, до → после | 8 518 → 3 909 |
| updateMatrixWorld visits, до → после | 8 518 → 8 518 |

**4 609 — не точный LIVE `restores.length`.** Это authored-stage admission count. Generated interiors добавляют sources; entry CSG/material changes и hidden authored components могут менять grouping/acceptance. Например, три detention sites отдельно объединяют shell и скрывают оригиналы **до** общей batching: 159 authored police candidates из census могут отсутствовать в её LIVE restores. Ни точный нижний, ни точный верхний предел общей игры из 4 609 не выводится. Различие 7 113 actual mesh objects и прежних 6 820 mesh-node definitions нормально: GLTFLoader разворачивает multi-primitive nodes.

Крупные authored contributions: gun_shop 744, bookmaker 628, pawnshop 612, pavilion 428, strip_club 320, print_shop 312; вместе **3 044** source leaves. Эти типы/количества не являются отдельным новым allowlist: freeze должен брать только **фактические принятые source records** после полной сборки текущего мира. Census показывает порядок тысяч операций, приблизительно в десять раз больше decor leaf candidate 444, а не обещание FPS.

### Аудит динамического контракта

Existing static batching уже копирует матрицы sources один раз при создании. Её runtime `update()` меняет лишь distance visibility; `setOptimizationEnabled()` меняет материалы. Поэтому accepted source local transforms по существующему контракту уже должны оставаться неизменными до batch disposal. Предлагаемый local freeze использует этот контракт, не вводит новый запрет на inherited world transforms.

- Guard `batchableMesh` исключает skinned meshes, неподдерживаемые InstancedMesh, material arrays, прозрачность/opacity/transmission, breakable glass, hidden ancestry, effects и morph geometry.
- Ancestry guard исключает Door/Hinge/Window/Light/Lamp/Glow и runtime entry ветви. Исключения узкие: четыре audited house asset IDs + точные static architecture names; static `Interior_Furnishings_*` pools допускаются отдельно. Вывеска GLASS у pavilion — исключение только для root group, не для panes/doors.
- `building_entry_profiles.update()` и strip-club entry update вращают `Entry_Hinge*`, их потомки не допускаются в batch.
- `interior_room_doors.update()` вращает pivots и обновляет door instance matrices, названия/ancestry Door и отсутствие `Interior_Furnishings` исключают их.
- Safe door вращает `doorPivot`; безопасные корпусные mesh уже имеют matrixAutoUpdate=false, а runtime entry/door ветки всё равно не входят в proposed new frozen set.
- `Interior_Furnishings_*` создаются `pool.flush()`, после flush добавление parts запрещено, staging matrices очищены. Это уже immutable object-local источник, instanceMatrix остаётся прежней.
- Window integration меняет geometry/visibility при сборке и dispose; refresh пересоздаёт runtime. Glass breakage ведёт свои replacement effects и исключена из accepted static copies.
- Detention shell merger имеет отдельное владение и изменяет состав источников до общей batching. Не обходить её через глобальный freeze всех исходных GLB.
- При `clearContent()` **staticRenderBatches.dispose вызывается до buildingEntry.dispose**, который возвращает прежние parent/local transforms. Значит восстановление auto flags в batch dispose сохраняет этот lifecycle.

### Предлагаемое минимальное изменение, пока НЕ внедрено

Только в фактическом пути добавления уникального source в `restores`, после успешного создания batch и первоначального `root/group.updateWorldMatrix`:

```js
// The source has already been accepted by the existing static batch guards.
const freezeLocal = mesh.children.length === 0 && mesh.matrixAutoUpdate === true;
restores.push({ mesh, material: source, hidden, optimization, freezeLocal });
if (freezeLocal) mesh.matrixAutoUpdate = false;
```

В `dispose()` перед возвратом ownership:

```js
for (const restore of restores) {
  restore.mesh.material = restore.material;
  if (restore.freezeLocal) restore.mesh.matrixAutoUpdate = true;
}
```

Не менять `matrixWorldAutoUpdate`, `updateMatrixWorld`, transforms, parentage, geometry, material semantics, distance, shadow flags или raycast. Уже false flags не «включать назад». Instanced sources учитываются по source mesh один раз, а не по числу component instances. `setOptimizationEnabled(false)` может показывать исходные meshes: это тоже сохраняет ту же картинку, потому что их local matrix остаётся той же, world matrix продолжает следовать родителю.

Для точного LIVE count при реализации достаточно добавить к existing `stats()` число unique `restores`/`freezeLocal` — один раз при сборке, без обхода сцены каждый кадр. Existing `stats.members` для этого не годится: один furnishing source разворачивается в сотни members, но экономит только один Object3D compose.

В audit frozen 4 609 actual authored leaves показали exact local matrix parity и exact `parent.matrixWorld × matrix` после parent position/rotation/nonuniform scale; visits и world-auto сохранились. Полной correctness приёмкой будут existing static batching/house/pavilion tests после реального scoped изменения, включая A/B material restore, generated interiors, moving doors, raycast и disposal. Их сейчас не запускали, чтобы не генерировать город во время LIVE окна root.

**Production по этому кандидату не изменён. Общая сцена и FPS ещё не измерены.**

## Разрешённая реализация local-only — default OFF

После отдельного разрешения root изменён **только `static_render_batches.mjs`** и добавлен `test_static_local_matrices.mjs`. Прежние пункты «не внедрено» выше относятся к моменту census; этот раздел — актуальный статус.

API:

```js
createStaticRenderBatches({ THREE, root, instances, localMatrixOptimization: false });
api.setLocalMatrixOptimizationEnabled(true); // explicit comparison opt-in
api.setLocalMatrixOptimizationEnabled(false); // restores captured local matrix/flag
api.stats().localMatrixOptimizationEnabled;
api.stats().frozenLocalSources; // unique currently frozen source meshes, not batch members
```

Default **OFF**. В `walk_preview`/QA DOM ничего не подключено. Изменение само по себе пока не включает ускорение в игре; root согласует hook и LIVE A/B отдельно.

Реализация опирается только на фактические unique `restores` после успешного batch creation. Дополнительные guards: leaf, исходный `matrixAutoUpdate===true`, нет animations/morph targets, стандартные `updateMatrix`, `updateMatrixWorld`, `updateWorldMatrix`, before/after render и shadow callbacks. Матрица и auto-флаг сохраняются лениво при включении. Disable/dispose возвращает их до entry disposal; исходное чужое `matrixAutoUpdate=false` не меняется. World-auto, world matrices traversal, hierarchy, instance buffers, culling и materials не оптимизируются этим переключателем. Никакого parent/root spatial guard не требуется.

Проверки после разрешённого CPU release:

- `test_static_local_matrices.mjs`: synthetic negative guards + BatchedMesh/InstancedMesh fallback, default OFF/explicit ON, idempotent toggle/dispose, чужое owned-false состояние; actual **2 woodland + 1 pavilion** после `createWindowedBuildingEntry` со сгенерированными этажами/мебелью/окнами.
- Actual fixture: **234 unique accepted frozen sources**; local compose **477 → 243**, selected compose **234 → 0**. Это structural count, не FPS.
- Identity/material/geometry/source parent и local/world matrix parity; unchanged source/batch instance arrays, colors и geometry IDs; material optimization A/B и distance culling; root position/rotation/nonuniform scale; **3 настоящие entry двери анимируются**, colliders обновляются; **70 ненулевых source raycasts** совпадают при toggle; flags/material/local matrix восстановлены до dispose entries.
- Все шесть suites PASS: static_local_matrices, static_render_batches, static_render_culling, static_houses_batches (22 townhouses/3 chalets/2 cottages), static_pavilion_batches (4), static_woodland_batches (2). Общий runner около 1.1 с. Последующее усиление custom world/shadow callback guards повторно проверено новым opt-in suite, PASS.

Точный число `frozenLocalSources` всей populated игры ещё неизвестно. **LIVE и производительность общей сцены после включения этого opt-in не проверены.**

## Узкий QA hook после передачи ownership от optimizer

По отдельному поручению root добавлены только:

- `render_freeze_qa.mjs`: optional `applyStaticMatrices`, кнопка **`static-matrix-qa` / top 236px**, dataset `staticMatrixComparison` (`optimized`/`previous`). Сравнение выполняется только внутри active hold; ранний/последующий click не отключает оптимизацию.
- `walk_preview.mjs`: `staticMatrixOptimization = staticRenderBatching && allowRenderFreeze(location.href) && staticmatrix==='1'`; это только локальный unauthenticated `perfqa=1&staticmatrix=1`, при renderbatch не 0. В этом случае constructor получает initial ON, иначе library и игра остаются OFF. Callback переключает `setLocalMatrixOptimizationEnabled` и публикует актуальные existing `staticRenderBatches.stats()`, включая `frozenLocalSources`.
- На всех hold exits (ручной, Escape, timeout, projection/readiness change, draw/probe ошибки, dispose/pagehide) static matrices возвращаются к opt-in initial ON. Restoration вложен в finally так, чтобы ошибка details/wheels/static/GPU callback не пропускала cleanup других controls.
- Существующие `applyVehicleWheels`, `vehicle-wheel-batch-qa` top198px, wheel URL+multi-draw gating, factory/frame hooks, детали, GPU, shadow onHoldStart/onHoldEnd и controls preservation не изменены по смыслу. Source NPC/cover/E hooks не затронуты.

`test_render_freeze_qa.mjs`: **28/28 PASS** (исходные 24 и четыре новых static cases). Проверены exact URL/identity gates, batching disabled, hold/pending guard, порядок callback → probe.reset, camera preservation, native keyboard isolation, all-exit restoration с одновременно выключенными колесами/details/GPU и injected callback errors, removal/listener cleanup, actual extracted walk setup/frame prefix.

Root уведомлён, что combined reload может включить `staticmatrix=1`. CUA/GPU подзадачей не открывались; **LIVE A/B ещё не выполнен**.

## LIVE результат local matrices и новый read-only аудит eager interiors

Актуализация после LIVE root: **2232 frozen sources**, одинаковые **4422 draws / 4 345 460 triangles**. Переданные root времена render **89.6/99.9 → 89.1/94 ms**, matrices **7.9/10.2 → 7.8/9 ms** (p50/p95). Эффект небольшой, поэтому local matrices остаётся **opt-in**, default OFF. Этот результат заменяет прежнее «LIVE ещё не выполнен» выше; сам подагент GPU не запускал.

Новая задача выполнена **read-only для production**: eager creation/retention интерьеров, стоимость ресурсов, возможность lazy без потери вида и gameplay; grouped collision, renderer и NPC принадлежат другим авторам. Новых дальностей, скрытия мебели и production изменений нет.

### Что загружается и остаётся в памяти

`walk_preview.mjs:1185,1272,1278` подтверждает прежний вывод: все типы GLB сначала загружаются тремя workers, затем все placements клонируются и проходят `createWindowedBuildingEntry`; расстояние не участвует в этом цикле. `templates` содержит promises с parsed scene, `clearContent` его не очищает. 33 типа / 242 placements и 19 337 364 GLB bytes из census выше — это файловый inventory, **не RAM/VRAM**. Клоны делят исходные geometry/material; новые CSG, этажи, окна, мебель добавляются поверх.

`building_window_integration.mjs:40–53` синхронно создаёт окна, entry, storeys, вырезы внутренних стен и интерьер. `building_interior_design.mjs:18,91–99` создаёт furnishing pool, doors и safes, подключает collision bodies, proximity/interact/update и dispose. Passive мебель не имеет per-frame animation. `needsUpdate` уже ограничен активными дверями/сейфами и исходным entry runtime. Однако hidden ancestry сама по себе не исключает Object3D matrix traversal, как показано выше.

Существующий **полный CPU inventory** `outputs/interior_rebuild_20260912/current_runtime.json` даёт 75 зданий, 174 этажа, 261 комнату, 99 лестниц; 1101 предмет мебели, **19 157 render parts, 390 local interior meshes, 958 460 triangles**, 16 504 combined entry colliders. Из них pool report — **19 085 instanced parts / 318 meshes**, 24 сейфа; остальное включает реальные safe/door visuals. `tools/interior_rebuild/audit_runtime.mjs:19–23` считает `draws` обходом interior root, а не renderer: это **полный построенный inventory до global batching/frustum/shadows**, не LIVE calls.

Проверка provenance: placement, building_interior_design, functional_furnishing, oriented_staircase совпадают с hashes в `final_resized_obstacles_navigation.json`; storeys, spacious_layout, staircase уже изменены другими авторами. Поэтому общий inventory — **существующая историческая CPU оценка масштаба**, а не утверждение о нынешних colliders и точной текущей сцене. Полный город повторно не генерировался.

Крупнейшие группы в этом artifact:

| Тип | Зданий | Interior parts | Local meshes | Triangles | Combined colliders |
|---|---:|---:|---:|---:|---:|
| old_town_narrow_townhouse_v1 | 22 | 3808 | 88 | 169160 | 5398 |
| compact_podium_glass_tower_v1 | 2 | 1641 | 12 | 77660 | 1615 |
| strip_club | 4 | 1497 | 44 | 93756 | 1052 |
| eastside_garden_walkup_v1 | 4 | 1448 | 20 | 76512 | 1507 |
| eastside_stepped_apartment_v1 | 4 | 1169 | 21 | 58256 | 1394 |

Самый насыщенный отдельный интерьер: tower-002 **881 parts / 6 local meshes / 41 508 triangles**, затем tower-001 760/6/36 152, большой банк 690/5/30 640, hospital 687/4/30 888. Chalet весь набор 3 зданий — **489 parts / 18 local meshes / 24 816 triangles**. Следовательно большая детализация мебели не равна сотням CPU draw submissions на один chalet.

### Реальная структура resource cost

- `interior_mesh_pool.mjs:49–103`: **3 общие геометрии + 2 общих материала** на весь runtime через refcount. Нет geometry на каждую из 19 тысяч деталей. После flush staging buckets очищаются. 19 085 pool parts означают **1 450 460 bytes** матриц Float32 (64 B/part) + RGB Float32 (12 B/part) в локальных instance buffers вместе; это только один точный компонент исторического CPU inventory, не общий heap/VRAM. Doors/safes/geometry/material/JS metadata сюда не входят.
- `interior_finishes.mjs:5`: wall/floor finish — refcounted MeshStandardMaterial с процедурным shader pattern; текстуры на каждую комнату не создаются.
- `building_window_integration.mjs:17–31` и `residential_windows.mjs:64–65`: refcounted CSG geometry / shared window bundle; detach не уменьшит число referenced ресурсов. Dispose отписывает и освобождает их, но также меняет gameplay.
- `static_render_batches.mjs:99–164`: сохраняет исходные local instanced sources для raycast/restore и отдельно `member.matrix.clone()` для каждой детали; BatchedMesh хранит упакованную geometry и matrix/color DataTextures. Поэтому простой detach source interiors **не удаляет мебель из глобальных batches и не освобождает retained instance resources**. Это граница renderer owner; здесь ничего не менялось.
- `three.core.js:27195–27239`: каждый BatchedMesh выделяет matrices + indirect DataTexture, colors появляется при `setColorAt`. При N slots размеры: matrices `max(4,4*ceil(sqrt(4N)/4))²*16 B`, indirect `ceil(sqrt(N))²*4 B`, colors ещё `ceil(sqrt(N))²*16 B`. Поэтому historical LIVE **textures803 нельзя называть 803 файлами/растровыми текстурами**; только GLB census обнаружил один embedded image. Точный состав 803 без runtime resource census не установлен.

### Room reveal / прозрачность: проверка actual source

В `building_window_integration` **roomReveals — CSG geometry replacement + restoration**, а не прозрачный материал и не opacity animation. `interior_finishes`, storeys walls и entry walls используют opaque DoubleSide. Opaque DoubleSide само по себе не даёт два transparent passes. Authored прозрачные GLB материалы ещё в `walk.template` получают FrontSide + forceSinglePass=true; `building_doors_glass.mjs:43–58` клонирует variants по source/kind внутри одного placement и сохраняет тот же контракт.

Единственное выявленное исключение в проверенных домах: generated `ResidentialWindow_DeepGlass` в `residential_windows.mjs:64,90`, создаваемое **после** template нормализации: opacity .28, transparent=true, DoubleSide, forceSinglePass=false, castShadow=false. Three r180 `three.module.js:16852` действительно рисует такой материал back/front отдельно. Это **один instanced glass mesh на дом**, значит только **один дополнительный main draw на видимый mesh**, не сотни. Менять на single pass без визуальной проверки нельзя: это объёмный тонкий box, прозрачное наложение передней/задней сторон влияет на вид.

Короткий актуальный CPU fixture: по одному actual GLB chalet/oldtown/woodland/pine с walk-equivalent template masks, transform, doorsglass и настоящим createWindowedBuildingEntry. Без renderer, GPU, города или планнера всего мира. Время command ~0.53 s; это не FPS benchmark. Материалы классифицированы после integration:

| Actual fixture | Nodes | Meshes | Unique geometry | Unique materials | Unique typed buffer bytes |
|---|---:|---:|---:|---:|---:|
| hillstep_chalet_v1 | 122 | 105 | 97 | 29 | 386140 |
| old_town_narrow_townhouse_v1 | 91 | 65 | 55 | 31 | 1026420 |
| woodland_crosswing_house_v1 | 119 | 102 | 94 | 29 | 374068 |
| pine_ridge_cottage_v1 | 117 | 100 | 92 | 29 | 337020 |

Счёт включает hidden authored meshes и всё созданное для fixture, до global batching. Unique typed bytes суммируют geometry attributes/index и instanceMatrix/instanceColor по identity массива внутри fixture, исключают JS heap, materials, textures и driver memory. **Нельзя умножать на placements без учёта shared caches.** У всех четырёх ровно один transparent material slot — указанное DeepGlass. Residential stone reveal opaque FrontSide; OldTownDarkReveal opaque DoubleSide. Root LIVE chalet234 main/shadow26 и другие counters не воспроизводились этой CPU проверкой и требуют per-pass attribution у renderer owner.

### Lazy creation/attach: границы сохранения результата

Простой lazy по расстоянию/положению игрока/закрытой двери небезопасен. Окна имеют реальные вырезы, есть прозрачные фасады и открытые двери; мебель может быть видна снаружи, участвовать в тени и иметь source действия до входа игрока. `registerInteriorSafe` немедленно создаёт stable target, привязывает object identity, position, unlock/collect и hydrate/subscribe source (`interior_safe_registry.mjs`); lazy create теряет эти targets. `entry.getCollisionBodies` строится из настоящей furniture/door/safe construction. Unregister/dispose при дальнем положении меняет registry revision и ownership runtime. Detach сохраняет память и часть ссылок, но ломает parent/world transform contract для spatial consumers; глобальная batch-копия остаётся.

**Самый узкий допустимый будущий вариант для startup** — staged creation во время existing loading gate, публиковать здание/готовность только после завершения того же синхронного entry contract; все объекты готовы до gameplay и первого обычного кадра. Это может сократить long task/пик одновременной сборки, но **не улучшает steady-state FPS и не уменьшает конечную память**. В нынешнем коде уже есть `createResidentialWindowQueue`, однако полноценный entry/storeys/furnishing pipeline его не использует. Подключение требует отдельного согласования с архитектором.

Visibility-safe resident lazy — значительно более широкая задача: отдельно постоянно хранить детерминированные IDs, logical safe/source state, collision/navigation и физические doors; визуальные immutable pools создавать/возвращать **до первого кадра, где хоть один part может участвовать в main/shadow/другом существующем pass**, учитывать окно/portal, zoom, roof/elevated camera, teleport, broken glass и bounds пересекающие границу. Глобальные batches должны поддерживать такую lifetime без полной пересборки/потери source picking. Пока такого консервативного visibility/attachment контракта нет, конкретного безопасного runtime lazy patch **не предлагается**.

Более узкий resource кандидат для renderer owner — census дублирования packed Matrix4/member arrays и batch DataTextures при сохранении исходных объектов/ID/picking; это потенциальная память/GC экономия без visibility policy. До реализации нужны точные retained bytes/count по unique identity в существующей loaded scene; текущее число ресурсов недостаточно. Для любой lazy ветки обязательны same-camera pixel/pass parity через окна и broken glass, unchanged shadow triangles/IDs, safe hydration при невидимом здании, source updates до attach, двери в движении, teleport/parent transform, raycast/collision parity и dispose/refcount возврат. Ни архитектурные colliders, ни renderer code в этом аудите не менялись.
