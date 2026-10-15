# Police response30 — начальный read-only аудит

15 октября2026. Это план native-владельца; выезд/прибытие ещё не заявлены проверенными.

## Готовые компоненты в game54

- `data/transport/vehicle_descriptors.v1.json`: профиль `police_interceptor` / Patrol LX,4 места,1830кг, wheelbase3.0504м, steering limit0.56rad; chassis half-extents1.26960001×1.071997269×2.7092м. Торможение11м/с². Непредоставленные исходником suspension/COM параметры дополняет существующий native profile, не изобретать второй физический движок.
- `assets/vehicle_visual/manifest.json`: `police_interceptor.4f6d8a8e668a.glb.bytes`,4501764bytes. Geometry/doors/wheels уже импортируются `vehicle_visual.gd`; есть `update_wheels`, source seat/door anchors.
- `vehicle_physics/vehicle_body_factory.gd::spawn_from_descriptor`: собственный vehicle_id, generation и monotonic source_clock; возвращает настоящий RigidBody3D.
- `vehicle_native_body.gd`: `submit_authoritative_control`, `snapshot_state`, `body_sweep`, `is_upright`. Только force controls после spawn; не писать transform для движения/прибытия.
- `data/city_block.json`: native current origin `[395.65,0,45.1]`, cell4.1м, surface163×178, `roadMask/walkableMask/policeMask/bridgeDeckMask`. Полные generated Godot scene collisions служат текущей проверкой реальных препятствий.
- `data/transport/parking_access.v1.json`:39 lots,46 walking routes,78 permitted road/access rectangles. Использовать только совпадающие с актуальной физической сценой, не предполагать сохранность исторических зданий.

## Что не готово к прямому повторному использованию

`npc_native_trip_driver.gd` — реальный force follower, но принимает только pinned static `DRIVE_THEN_WALK.json`, конкретный departure bay и существующий exact driver/seat lease. `npc_transport_adapter.gd` привязан к текущему curated/player factory car и его logical host. Нельзя подставить fake owner/seat/ACK для вызова полиции или отнять пользовательскую машину.

Фабрика новых сессий содержит8 ordinary parked slots, police slot отсутствует. Для запроса пользователя нужен отдельный явный local police owner с собственной машиной и двумя офицерами. Он не объявляет импорта source-save roster/server authority.

Текущий `assets/npc_city/session_packet.json`:287 rows, **0 police**, роли businessman/homeless/housewife/pensioner/student/worker. Prepared manifests не содержат police identity. Использовать существующий canonical28 male appearance как ресурс, отдельный полицейский visual style/identity и двух физических актёров; не перекрашивать/переименовывать мирного resident_1. Требуется отдельная native/rendered проверка посадки и выхода.

## Исходная игра

`world.html:14800` — `spawnPoliceCar`: не дублирует машину рядом с тем же адресом, берёт физически свободный source response bay, создаёт2 cop crew, source seat front_left/front_right. Ниже `_policeResponseBays`, `_policeInitialBayAdmit`, `_policeSceneParking`: доступность, road-targets, origin, отступ от места происшествия. Это семантический референс; source JS живёт в другой физике и напрямую не используется как native ACK.

Source directed lane/road modules присутствуют в `assets/maps/city_rebuild_v1/city_road_navigation.mjs`, `city_directed_lane_router.mjs`, `city_lane_curve.mjs`, `city_road_traffic_plan.mjs`. В candidate native нет динамического общего road dispatch для произвольного incident. Первый native owner должен иметь ограниченную очередь и планирование, выдавать BLOCKED при недоступном пути.

## Узкая реализация

1. Один постоянный pool:1 police car,2 canonical patrol capsules. Поддержанные source road/service staging spots, native hull/floor clearance до spawn; не появляться на месте преступления. Собственный monotonic vehicle identity/clock.
2. `Node.submit_report30(report)->{accepted,case_id,reason}`. Проверить scene id, witness current session/life/body, report id, call_completed, kind и конечную crime_position; dedupe по incident_id. Hearing-only без crime_position — `unlocated_incident`, не подставлять координаты игрока.
3. Bounded road planning по актуальному native roadMask с учётом габаритов. Выбрать доступный curb/service stop рядом с адресом и путь выхода пешком. Сохранить accepted case как реальную работу владельца, а arrival публиковать только после фактической поездки/остановки.
4. Native force steering/braking, low-speed approach, actual hull sweeps/floor checks, collision stop. Никаких position updates для продвижения машины. При недоступном пути/препятствии — честный waiting/blocked, bounded retries, без телепорта.
5. На остановке проверить скорость, направление, door corridor и floor. Те же2 офицера физически выходят; затем bounded пеший подход/патруль рядом с наблюдаемой точкой. Канонические анимации и collision capsule, отдельный owner движения.
6. State evidence: parked→planning→departing→driving→braking→door_exit→foot_patrol→complete/blocked. Native assertions реального travel distance, zero transform-written ticks, stop distance/speed, two actual actors, dedupe, retirement/free cleanup. Render departure/arrival/foot patrol.

Threat30 contract согласован с injury_fix30: schema `native_police_report30/v1`, report_id/incident_id, witness_source_id/generation/session/body, observed_scene_instance_id, accepted_time_ms, kind, source_identified, weapon_id, crime_position(Vector3 или null), retreat_m, committed_phone_frames, call_completed. Threat owner не подтверждает arrival. Его пакет пока UNTESTED; окончательный SHA/contract ожидается.

Все новые файлы — здесь; shared game, старые transport/frozen пакеты не меняются. Integration main hook — только точный отдельный hunk для root после функциональной и визуальной приёмки.
