# Police source → Walk emergency presentation

20 сентября 2026. Read-only аудит production, staged candidate для root review. Dispatch, incidents, civilian release, source движение и руление не менялись. GPU-вкладки не открывались, reload не выполнялся.

## Проверяемые разрывы

1. `world.html` snapshot serviceVehicles (около70225) уже публикует `emergency:'police'`, `emergencyLights: state !== 'police_parked'`, `serviceKind`, `serviceState`. Фазы boarding/search/arrest/reboarding/returning также имеют включённый флаг, даже когда машина стоит. Это существующая source policy; аудитор её не менял. Quest police patrol (около70256) использует `police_patrol` и `q.siren`, UI/server обновляют `q.siren` около31347/26953.
2. `world_traffic_presentation.mjs::normalizeWorldTraffic` сохраняет `emergencyLights` только в presentation metadata, теряет `serviceState/serviceKind/emergency/policePatrol`. `update` до candidate меняет metadata и колёса; потребителя флага ламп нет. `vehicle_fleet_models.mjs::createArtistVehicle/update` обновляет колёса/руль/стоп-сигналы, без мигалок.
3. Legacy `three_preview.js` около5347 мигает своими лампами, но Walk использует artist fleet через `walk_preview.mjs` около473. Поэтому наличие кода мигания в legacy renderer не доказывает мигалки Walk.
4. Реальные GLB `police_interceptor`, `city_ambulance`, `fire_engine` имеют `LOD0_<id>_LightbarRed` и `...Blue`. EmissiveStrength1.3/1.4 постоянно включён. `vehicle_render_batches.mjs` исключает имена Light/Lamp из batching. Материалы клонируются per-car, но разделяются между частями одного автомобиля.
5. `worldTrafficProfile` сразу возвращает null для `/armored|swat|paddyvan/`. Source `police_armored_van` не имеет Walk actor. Подменять его обычным седаном в узком эффектном патче нельзя; нужен authored armored profile от владельца автопарка.
6. В source/Walk не найден генератор полицейской siren audio. `world.html::_audioCtx/_ac/_sfxOut/_sfxVol` владеют общим AudioContext и шиной. Наружу опубликован только `MafioziWorldWeaponAudio` для принятых выстрелов. Повторный AudioContext для полиции не предлагается.

## Candidate для переноса root

`test_police_emergency_visual18_candidate.mjs::stagePoliceEmergencyVisuals(source)` добавляет только визуальные эффекты в current `world_traffic_presentation.mjs`, не изменяет source движения или steer формулы.

- При создании actor один traversal, только две authored lamp mesh; отдельные клоны материала ламп, чтобы не мигала вся полицейская окраска.
- Флаг false → emission0, но цветная физическая лампа остаётся видна. True → красный/синий поочерёдно каждые170мс, emission3.2. Wreck/hidden → off.
- Лампы мигают независимо от `driveChanged`, поэтому стоящий вызванный экипаж тоже виден.
- Никаких PointLights, геометрии, новых draw calls или изменений mesh.visible. Повторные значения не записываются в material.
- Перед release/dispose helper восстанавливает старые материалы и освобождает свои клоны; общий существующий release очищает исходные actor resources. Body/door batching владельца не затрагивается.

`node test_police_emergency_visual18.mjs` PASS: три actual GLB, приватность материалов/неизменный исходник, off/active/off, стационарный автомобиль, выключение wreck, удаление/dispose; существующий `test_world_traffic_presentation.mjs` и `test_npc_traffic_steering18.mjs` также PASS через staged source hook.

Микробенчмарк100000 helper.update: police3.41мс, ambulance3.23мс, fire0.74мс (JIT/порядок влияют). Это не замер кадра общей сцены. Добавляются два приватных материала на emergency actor; лампы уже существуют в исходном GLB, поэтому число draw calls/треугольников не увеличивается по структуре.

## Интерфейс владельцу audio/source

Для отдельного bounded siren mixer нужны source-authoritative `sirenActive` (отдельно от parked lightbar), `serviceState`, `emergency`, ID и координаты, listener player, существующие `getContext/getOutput/getVolume`. Ограничить ближайшие голоса, spatial falloff, остановку удалённых/уничтоженных/припаркованных, muted volume и pagehide disposal. Выезд/погоня должны звучать по source state; не включать звук автоматически во всех поисках/передачах в тюрьму только потому, что лампы мигают. Сами incident/dispatch переходы остаются у владельца транспорта.

Production candidate не применён субагентом. LIVE, визуальная читаемость под текущим освещением и производительность общей сцены не проверены.

## APPLIED root

Root перенёс candidate в `world_traffic_presentation.mjs`, сохранив steer fallback. Дополнительно helper пропускает автомобили без ламп, clock отвергает Infinity/nonfinite dt. `test_police_emergency_visual18.mjs` теперь распознаёт applied source; actual GLB проверка извлекает helper из production source, интеграционный load hook также использует applied source. Applied suite PASS: три GLB, off/active/off, stationary/wreck/remove, существующие presentation/steering проверки. Извлечённый helper выполняется в VM: его CPU microbench33–35мс/100k нельзя сравнивать с прежним native-module microbench0,7–3,4мс. Это различие тестового окружения; общий frame-time не измерялся. **LIVE текущей сборки и производительность общей сцены не проверены.**
