# Interior CPU follow-up — read-only

13 сентября 2026, после native terrain LIVE A/B и принятого lifecycle cleanup. GPU/браузер и полный городской planner не запускались. После read-only отчёта root разрешил только маленький empty-door early return, он реализован и проверен. Grouped collision index архитектора, source matrix policy, renderer и E-интеграция Художника17 исключены из scope.

## Вывод

Сильный новый bottleneck внутри runtime мебели/окон/этажей не обнаружен. Их построение и flush не выполняются каждый кадр. Нельзя объяснять текущие лаги количеством строк planner или повторно предлагать уже установленный batch/cache. Есть небольшой доказанный empty-door fast path и отдельный кандидат уменьшения временных массивов в floor/ceiling queries; ни одному пока нельзя приписать измеренный выигрыш ms/FPS.

## Что проверено

- `interior_mesh_pool.mjs`, `residential_windows.mjs`, `building_window_integration.mjs`: instance creation, clipping, cache keys и transforms выполняются при создании/перестройке. У мебели/окон нет recurring runtime update. Optional residential window queue не пересоздаёт завершённые jobs.
- `building_interior_design.mjs:134–135`: entry.update вызывает doors.update и только active safes. needsUpdate оборачивает original entrance и проверяет doors.active/safe.needsUpdate.
- `interior_room_doors.mjs:28`: idle update выходит сразу; active iteration меняет только реально движущиеся листья и instance matrices их частей. Повторяющийся needsUpdate setter на частях — малая операция, не повторный upload всей geometry; значимого bottleneck не доказано.
- `interior_interactive_safe.mjs:121`: idle/zero-dt выход, анимация без новых Vector3 и массивов; pose/collision revision меняется только при активном открытии. Source state/награды/ID не затрагивались.
- `building_storeys.mjs`, `interior_staircase.mjs`: после build нет анимационного update. Повторяются только точные floor/ceiling/contains queries от ходьбы/камеры.
- `stable_entry_lights.mjs`: fixed slots, reusable nearest/distance buffers, уже устранён filtered-array stats scan. Живые light values нельзя кешировать только по position: color/intensity/visible/layers остаются игровыми данными. Свет не предлагается снижать.
- В актуальном `walk_preview.updateBuildingEntries` уже установлен `updateWalkEntryCollisionGroups`: прежний отчёт про citywide flat/index rebuild — исторический кандидат, который теперь ведёт/исправляет архитектор. Не повторять старое предложение как новое открытие.

## 1. Empty room-door controller: малый доказанный кандидат

До исправления `interior_room_doors.near:18` всегда создавал `new T.Vector3(point.x,point.y,point.z)` и вызывал `root.worldToLocal` **до** прохода `doors`. У open-plan здания список doors пуст, результат всегда null, но Three успевал обновить цепочку ancestor matrices и инвертировать transform.

Входы: `building_interior_design.entry.proximity` вызывает original entrance proximity и doors.near; текущий walk использует nearby entries при поиске взаимодействия и камеры. Это уже ограничено соседними buildings, не все75 каждый кадр. При camera contains=true короткое замыкание вообще исключает proximity.

Bounded проверка actual Three + actual createInteriorRoomDoors, пустой controller, четыре уровня Scene→placement→visual→root.120 запросов с конечными координатами:

| Операции | Текущий near | In-memory proposed empty guard |
| --- | ---: | ---: |
| Vector3 allocations |120|0|
| ancestor updateMatrix/composes |480|0|
| изменённые результаты |0|0|

Proposed guard: немедленный null при doors.length===0. Это controlled operation-count comparison, не actual-city timing. Default Three matrix policy использована только для подсчёта; текущая frozen source policy может уменьшать реальное число matrix composes. Политика матриц не меняется.

**Реализовано по разрешению root:** сначала читаются point.x/y/z в том же порядке, затем при текущем doors.length===0 возвращается null без выделения Vector3 и worldToLocal. Populated path прежний; cached empty flag не добавлен. near(undefined) по-прежнему бросает TypeError, late door.create сразу попадает в обычную ветку.

`test_interior_room_doors.mjs` — **3 tests PASS**. Один дополнительный actual Three test проверяет120 отрицательных empty queries:0 Vector3/0 worldToLocal; затем создаёт дверь в том же controller и проверяет positive/negative proximity, height exclusion, exact anchor/action/door/instance identity под scaled/rotated/translated root и после перемещения ancestor. Существующие meaningful door width/batching/animated sweep/idle tests также PASS. Это tiny cleanup, не FPS fix; приведённые baseline counts получены до patch, новый guard дополнительно проверен на production module.

## 2. Floor/ceiling temporary arrays: следующий возможный bounded scope

`building_storeys:169–174`: каждый прошедший bounds floor query создаёт local Vector3, samples array и filter array; ceiling создаёт Vector3/values. `stairs.find` выполняется для уровней. `oriented_staircase:20,30–31` выделяет двухэлементный toLocal array на **каждый** sampleFloor/sampleCeiling, включая отрицательный footprint test. `interior_staircase:76–93` внутри footprint собирает values[] только ради min/max.

Безопасный в принципе подход: прямое скалярное преобразование rotated coordinates и streaming min/max с отдельным found-флагом вместо values[]. Сохранить все проверки +/-epsilon, referenceY, slab, hole/roof rules, null/fallback semantics и порядок original callbacks. Не кешировать конечный результат по x/z: referenceY, выбранный этаж и поза героя важны. Не менять exposed floors/stairs и не строить stale lookup по ним без контракта неизменности. Reusing scratch Vector3 требует анализа reentrancy; scalar-only изменения проще доказать.

Это не изменение grouped collision index: речь о floor/ceiling sampling. Тем не менее paths принадлежат архитектору, поэтому до edits нужен новый узкий ownership scope от root. Проверка должна сравнить точные численные результаты old/new на stair flights/landings/holes/roof, rotated/unrotated stairs, границы и referenceY; затем сопоставимый indoor walk замер. Сейчас выполнен только read-only code audit, такого patch/результатов нет.

## Сознательно не трогалось

Повторный root.updateWorldMatrix при движущейся двери и `clampBuildingCamera` входит в matrix/renderer ownership. `getCollisionBodies` временные safes.map/combined arrays входят в текущую работу архитектора по entry collisions. Hero visibility и input взаимодействия относятся к Artist17. Эти точки не исправлялись параллельно и не представлены как готовый новый выигрыш.

**Производительность общей сцены внутри зданий этим аудитом не измерена.**
