# Трава: total / visible, дальность и безопасная передача буферов

13 сентября 2026. Исполнитель: mercenary_input_audit, Координатор 17. Прочитан ENVIRONMENT_GRASS_HANDOFF.md (V4 contact/boots). Сначала read-only аудит; затем root отдельно разрешил только prefix upload patch. Плотность, геометрия, shader, лимиты, дальность, camera culling, raycast и vehicle не менялись. Браузер/GPU не использовались.

## Главный результат LIVE, переданный координатором

Камера root около 133/174:

| Показатель | Значение |
|---|---:|
| Всего в плане | 67250 tufts |
| totalTriangles | около 6.103 млн |
| visibleTufts | **257** |
| visibleTriangles | **22212** |
| visibleBatches | **3** |
| environment update last / max | 0.1 / 1.3 ms |
| mapEnvironment p50 / p95 | 0.8 / 1.1 ms |
| renderer p50 / p95 | 61.7 / 70.7 ms |

**6.103 млн — сумма теоретических triangles всех запланированных экземпляров, не число отрисованных triangles кадра.** `environment_grass.mjs` считает totalTriangles при создании как geometry triangles × capacity каждого chunk/style. Перед показом mesh.count сбрасывается в 0 и заполняется выбранным префиксом. visibleTriangles суммирует именно mesh.count × triangles. Renderer дополнительно имеет frustum test, поэтому visibleTriangles — submitted selection, не доказательство покрытия каждым треугольником пикселей.

В этом конкретном ракурсе из переданных метрик не следует, что CPU травы является основной причиной лага. Стоимость её shader/GPU отдельно от общего renderer этими CPU цифрами не измерена.

## Что действительно загружено и как отсекается

`environment_grass_plan.mjs`:

- Детерминированный план всего мира, максимум 90000 tufts. Production вызывается planning worker (`environment_planning_worker_core.mjs:33`) с native topology, landscape, road/parking keepouts и decor colliders. Это загрузка/планирование всего набора, а не GPU draw всего мира.
- Пучки разбиты на клетки **64 м**. Максимальная дистанция selection **105 м**, начало fade **66 м**; при достижении budget fadeFar дополнительно уменьшается до cutoff-.4.
- Ограничения выбранного набора: **1200 tufts, 90000 triangles, 24 batches**. На практике triangle budget часто срабатывает раньше: grass84 / reed108 / shrub168 triangles на tuft.

`environment_grass.mjs:160+` создаёт 3 общих набора исходных vertex attributes, один MeshStandardMaterial, отдельный InstancedMesh для каждой непустой пары chunk/style. У каждой пары есть capacity arrays матриц/цветов/slopes для всех её tufts. Это не 6 млн отдельных vertices в CPU geometry: индексы/вершинные attributes базовых трёх форм разделяются.

Матрица+цвет+slope дают 84 байта typed instance data на capacity tuft (16+3+2 float32); для 67250 это 5649000 байт, плюс CPU descriptors/precomputed matrices/colors, индексы chunks и небольшой geometry overhead. Это расчёт массива, **не полный memory-profile процесса/GPU**.

Selection обычным образом работает раз в .25 с; срабатывает раньше при camera quaternion change >.1 rad, перемещении focus ≥4 м или force. Пространственная выборка уже использует nearby rows/cells + conservative tuft radius; полная сортировка уже заменена bounded heap, сохраняющим stable nearest order. Затем chunk AABB пересекается с frustum и circle105м, и отдельные tuft roots проходят distance/budget.

Между selections обновляются только время, focus и uniforms следов/ботинок. Скрытые tufts не получают CPU деформацию: wind/contact/нормали вычисляет vertex shader только для submitted instances. Grass castShadow=false, receiveShadow=true; дополнительных lights/shadow casters нет. При selection очищаются только прежние activeChunks, а не весь мир.

Обычный renderer обходит часть scene graph; неактивные meshes имеют count=0/visible=false. После первого создания chunk group может оставаться visible=true до первого попадания в active set, но его child meshes count0/visiblefalse, поэтому это traversal overhead, не отрисовка полного плана. Изменять hierarchy visibility ради этого сейчас не предлагалось: эффект мал, а нужна отдельная проверка всех consumers.

## Внесённая точная оптимизация

До patch update переписывал только первые mesh.count матриц/цветов/slopes, но выставлял needsUpdate без updateRanges. Реальный Three WebGLAttributes в установленном vendor при пустом ranges вызывает bufferSubData на **весь capacity array**. Большой chunk передавал также неиспользуемый хвост.

Production patch ограничен helper и финальным upload loop `environment_grass.mjs`: отмечаются prefix ranges count*16, count*3 и count*2 перед прежним needsUpdate. Если range со start=0 уже ожидает загрузки, helper увеличивает count до max(old,new); иначе использует addUpdateRange. **clearUpdateRanges не вызывается**, чужие non-prefix ranges сохраняются. Несколько selections до render сохраняют bounded union; сам Three объединяет ranges и очищает их после bufferSubData. Первая bufferData остаётся полной, как раньше. Размер arrays и mesh.count не менялись; данные за пределами изменённого prefix не переписываются.

Это уточнение добавлено после root review: начальное простое append на каждой selection без GPU flush могло накапливать range objects. Actual BufferAttribute.updateRanges в установленном Three — открытый массив mutable {start,count}; addUpdateRange добавляет такой объект, WebGLAttributes сам сортирует/сливает/меняет count. Helper изменяет только существующий prefix count и не использует private renderer state.

`test_grass_prefix_uploads.mjs` выполняет **actual WebGLAttributes из установленного Three** с имитацией GL buffers в памяти — без GPU. До patch RED на отсутствии pending prefix ranges, после PASS:

- Dense fixture 3000 reed tufts, выбрано 833 / 89964 triangles. Первый upload **252000 B**, последующие полные передачи раньше столько же. Теперь union prefix **69972 B**, те же 3 bufferSubData calls. Это сокращение данных конкретного synthetic selection, не общий FPS.
- До одного render выполнены shrink/grow/shrink selections: 833→423→833→423; pending union сохранил больший изменённый prefix. После потребления ranges последующий малый update передаёт только 423×84 B.
- Отдельный тест **1000 selections без flush** до bounded-helper воспроизводил 1002 pending records. После helper — ровно **2**: один prefix и один добавленный foreign non-prefix tail range. Foreign объект сохранён, его два изменённых float values 123/456 доходят до имитированного GPU; prefix также совпадает, после real uploader ranges очищены. Без foreign range собственная очередь остаётся размером 1 независимо от числа selections.
- Проверены точный tuft order, матрицы, цвета, slopes, имитированное GPU содержимое активного prefix, неизменные CPU/GPU bytes за пределами pending prefix.
- Проверены count0 при уходе далеко, первое появление другого chunk (полная allocation), возвращение старого chunk (prefix update), очистка ranges **самим Three** после загрузки и отсутствие buffer updates на обычном uniforms-only кадре.
- maxVisibleTufts/triangles/batches/viewDistance сохранены. Existing test_environment_grass_selection также PASS.

**2 файла тестов PASS.** Полный тяжёлый placement/boot sweep не запускался: shader/геометрия/контакт/selection не менялись. Первоначальная попытка выделить WebGLAttributes захватила последующие declarations и дала Color undefined; harness исправлен на границу самой функции. Это была ошибка тестового harness, production не затрагивалась.

## Raycast и возможные следующие шаги — пока read-only

Grass входит в content через environmentVisuals.object (`walk_preview.mjs:1212`). Его meshes не имеют raycast-ignore override. Three InstancedMesh.raycast проверяет bound sphere и затем **this.count** instances; скрытая capacity не превращается в 67250 triangle tests. Сам Raycaster не обязан пропускать invisible nodes, поэтому при полном content raycast он может обойти и пустые mesh bounds, но count0 не даёт instance loops.

Удалять grass из raycast без отдельного gameplay решения нельзя назвать exact optimization: сейчас он может участвовать в выборе попаданий/перекрытии. Shader wind/fade не исполняются CPU raycast; смена этой семантики также выходит за текущую правку.

Потенциальный точный следующий аудит — более мелкие staticShotRoots для grass chunks. Сейчас environmentVisuals.object — одна пространственно широкая root-группа (в отличие от уже разбитых landscape/decor). Разделение **только для индексного списка**, без изменения scene hierarchy, могло бы пропускать далёкие grass chunks до InstancedMesh.raycast. Консервативность тут легче доказать: план неизменяемый, каждый chunk хранит bounds всех своих tufts и subset переключается только внутри них, disposal/rebuild заменяет индекс. Но patch затрагивает root-owned integration и требует exact hit/instance/distance parity; **не внесён**.

`grass_actor_contact.mjs:13` считает 5 groundHeight samples для actorGround каждый кадр; production grass.update принимает actorGround, но не читает его — используется постоянный slope каждого tuft. Это потенциальная небольшая CPU экономия, однако actorGround описан в V4 handoff как доступный контракт интеграции. Без изменения контракта/владельца удалять его не стал. Проверка допуска позиции героя над землёй в grassHeroContact остаётся необходимой.

## Что измерить root в LIVE после согласованного reload

DOM `body.dataset.environmentVisuals` уже содержит grass total/visible stats и общий environment update. В том же ракурсе/населении проверить visibleTufts=257, visibleTriangles=22212 и visibleBatches=3 либо объяснить изменение камеры/динамики; объём/тип геометрии не должен измениться из-за prefix patch.

Сравнить populated frame p50/p95, mapEnvironment и renderer/GPU; отдельно для upload — фактический объём bufferSubData на grass attributes либо согласованный diagnostic counter capacityBytes/prefixBytes. Не интерпретировать 252000→69972 synthetic bytes как такой же процент FPS. Проверить поворот/ходьбу/переход chunk boundary и наступание на траву; видимые листья должны остаться прежними.

Общая дальность мира — отдельный аудит координатора. Здесь установлено: **трава не отрисовывает весь план одновременно**, selection максимум105м и90000tri. Оправданность других world distances этим grass scope не оценивалась. Производительность общей сцены после patch пока не проверена.
