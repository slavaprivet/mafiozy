# Двери и стекло — технический срез 2026-09-08

Запрос пользователя: двери и окна всех зданий должны соответствовать уже принятому
эталону и хорошо выглядеть с камеры от третьего лица. Художнику 13 пользователь
ставит задачи лично; этот срез подготовлен техническим помощником координатора.

## Фактический охват и статус

- Прочитаны ART_DIRECTION_CANON.md, память Координатора 13, фактические catalog и placement.
- Проверены JSON-узлы, материалы и SHA256 всех **21 LOD0 GLB** каталога.
- В `/walk` стоят **72 здания, 19 типов**. Полиция и пожарная часть из каталога
  сейчас не расставлены. Настоящий полицейский комплекс не заменяется этим срезом.
- **43 жилых дома** ещё используют старое непрозрачное стекло: 30 городских
  домов с DeepGlass и 13 частных с WindowWarm. Это открытая художественная работа,
  а не выполненное соответствие канону.
- Автоматическая проверка модуля: **5 проверок PASS**, включая все 72 экземпляра,
  4 скрываемые вывески, 13 точечно исправляемых ручек и неизменность общей геометрии.
- **Живой прогон этого среза не выполнен автором модуля.** Координатор подключает
  его в `/walk` и записывает результат отдельно; unit PASS не означает LIVE PASS.
- GLB, их закреплённые хеши, расстановка, коллизии, ID и игровые привязки не изменены.

## Реализованное поведение

`assets/maps/city_rebuild_v1/building_doors_glass.mjs` работает только с клоном
загруженной модели и только при совпадении assetId, SHA256 и LOD0.

1. У `glass_pavilion_small_v1` скрывается только фактический `Small_Galleria_Sign`.
   Его не было в placement.hideNodeNames, поэтому четыре надписи сохранялись
   в текущей прогулочной расстановке. Остальные вывески города не затронуты.
2. У шести типов частных домов только `PublicDoorKnob` получает клон материала
   с линейным RGB/metalness/roughness из `Muted brass` эталона. Исходная ручка была
   `ClayStone`, общим материалом с каменными частями дома; общий материал не меняется.
3. Только существующие прозрачные материалы у pavilion, tower, pawnshop, civic_hall,
   hospital и nightclub получают FrontSide, depthWrite=false и single pass. Их
   авторские цвет, прозрачность, шероховатость, AO и transmission сохраняются.
   Часть этой настройки уже делал loader; модуль фиксирует её по проверенному
   профилю на экземпляре и позволяет вернуть исходное состояние.
4. Непрозрачные WindowWarm/DeepGlass не превращаются в прозрачные плоскости.
   На частных домах **PorchLamp разделяет WindowWarm с окнами**: глобальная замена
   испортила бы и светильник. В городских домах окна входят в общий Shell.

Модуль не добавляет одинаковые прямоугольные дверные накладки, не создаёт
фиктивные интерьеры и не открывает проход в существующих коллайдерах. Открывание
дверей и вход в игровой интерьер требуют привязки к действующей механике игры.

## API координатору

```js
import {applyBuildingDoorsGlass} from './building_doors_glass.mjs';

// После проверки bytes/SHA256 и source.clone(true), до добавления в сцену:
const doorsGlass = applyBuildingDoorsGlass(visual, item);
group.userData.doorsGlass = doorsGlass;

// При удалении поколения расстановки, до удаления группы:
group.userData.doorsGlass?.dispose();
```

`item` — запись placement с `assetId` и `binding:{lod:0,sha256,...}`.
`report` содержит assetId, status, glassMeshes, brassKnobs, hiddenNodes,
materialClones. Статусы: `not-profiled`, `binding-mismatch`,
`applied-needs-live-review`. Повторное применение к тому же экземпляру
идемпотентно; dispose восстанавливает материалы/видимость и освобождает
только собственные клоны материалов, не общие текстуры или геометрию.

Новая авторская ревизия GLB требует нового аудита и обновления профиля:
несовпадение hash специально оставляет модель без модификации.

## Матрица всех типов

Путь каждой строки: `assets/maps/city_rebuild_v1/building_models/<assetId>/<GLB>`.
Имена узлов ниже взяты из реальных GLB, не угаданы по фасаду.

| assetId / GLB | В walk | Фактические двери и стекло | Следующий проверяемый результат |
|---|---:|---|---|
| old_town_narrow_townhouse_v1 / old_town_narrow_townhouse_v1.glb | 22 | DoorLeaf, ServiceDoorLeaf, DoorHinge, DoorFrame; OldTownDeepGlass внутри old_town_narrow_townhouse_v1Shell | Автор: отделить остекление Shell, углубить оконные ниши, интерьер; скруглённые рамы и фурнитура DoorLeaf. Сохранить узкий силуэт. |
| eastside_garden_walkup_v1 / eastside_garden_walkup_v1.glb | 4 | DoorLeaf, ServiceDoorLeaf, DoorFrame; GardenDeepGlass внутри eastside_garden_walkup_v1Shell | Автор: оконные ниши/стекло/локальный свет; подробный вход при сохранении сада и террас. |
| eastside_stepped_apartment_v1 / eastside_stepped_apartment_v1.glb | 4 | DoorLeaf, ServiceDoorLeaf, DoorFrame; SteppedDeepGlass внутри eastside_stepped_apartment_v1Shell | Автор: те же требования с сохранением ступенчатой массы. |
| coastal_orchard_house_v1 / coastal_orchard_house_v1.lod0.glb | 2 | PublicDoor, ServiceDoor, PublicDoorKnob; FrontWindow1, RearWindow1/2; WindowWarm | Runtime: латунная ручка. Автор: заменить светящиеся оконные плоскости на окна с глубиной; сохранить PorchLamp. |
| garden_lane_house_v1 / garden_lane_house_v1.lod0.glb | 3 | PublicDoor, ServiceDoor, PublicDoorKnob; FrontWindow1, RearWindow1/2; WindowWarm | Runtime: латунная ручка. Автор: окна с нишами, интерьером и рамами. |
| hillstep_chalet_v1 / hillstep_chalet_v1.lod0.glb | 3 | PublicDoor, ServiceDoor, PublicDoorKnob; FrontWindow1, RearWindow1/2; WindowWarm | Runtime: латунная ручка. Автор: окна и фурнитура без потери силуэта шале. |
| pine_ridge_cottage_v1 / pine_ridge_cottage_v1.lod0.glb | 2 | PublicDoor, ServiceDoor, PublicDoorKnob; FrontWindow1, RearWindow1/2; WindowWarm | Runtime: латунная ручка. Автор: глубокие окна и подробный вход коттеджа. |
| veranda_bungalow_v1 / veranda_bungalow_v1.lod0.glb | 1 | PublicDoor, ServiceDoor, PublicDoorKnob; FrontWindow1, RearWindow1/2; WindowWarm | Runtime: латунная ручка. Автор: окна с глубиной, сохранить веранду. |
| woodland_crosswing_house_v1 / woodland_crosswing_house_v1.lod0.glb | 2 | PublicDoor, ServiceDoor, PublicDoorKnob; FrontWindow1, RearWindow1/2; WindowWarm | Runtime: латунная ручка. Автор: окна с глубиной, сохранить поперечные крылья. |
| compact_podium_glass_tower_v1 / compact_podium_glass_tower_v1_lod0.glb | 2 | EntranceAnchor, ServiceEntranceAnchor; SmokedTealGlass в объединённом compact_podium_glass_tower_v1_LOD0 | Runtime: безопасная прозрачность. Автор: отделить именованные дверные створки/петли и проверить интерьер за стеклом с земли. |
| pawnshop / pawnshop.1a95f97569d9.glb | 4 | Double oak door, Door handle, Door handle.001; Display left_glass/right_glass, Smoked shop glass | Runtime: безопасная прозрачность. Live: детализация дверей/дисплеев с 1,9-метровым героем, боковой сервисный вход. |
| print_shop / print_shop.ad7b8ef7e7e4.glb | 4 | Burgundy entry door, Side stock door steel shutter; Production window deep glass, Clerestory dark glazing.001; Deep workshop glass OPAQUE | Автор: реальные глубокие производственные окна, красивые створки и фурнитура; сохранить ставни склада. |
| gun_shop / gun_shop.e97d6fac4097.glb | 4 | Armored public door, Door pull, Door pull.001; Clerestory dark pane.001; Deep smoked display glass OPAQUE | Автор: сохранить бронедверь, углубить витрины и интерьер, локальное тёплое освещение. |
| bookmaker / bookmaker.cf7da54c2037.glb | 4 | Glazed burgundy door, Employee door, Door pull; Central odds display smoked glass; Deep odds-board glass OPAQUE | Автор: отделить стеклянную створку и показать интерьер за стеклом, не потерять информационное табло. |
| strip_club / strip_club.a29f4603767b.glb | 4 | Entrance_Door/.001, Entrance_Door_Glass/.001, Entrance_Door_Pushbar/.001, Service_Door; M_Deep_Smoky_Glass и M_Warm_Recessed_Glass OPAQUE | Автор: глубокое дымчатое остекление входа/окон, интерьерные ниши, сохранить приватность и характер здания. |
| glass_pavilion_small_v1 / glass_pavilion_small_ao.ecae5f97bd53.glb | 4 | Small_Public_Double_Door_GLASS_LEAF_L/R, BRASS_PULL_L/R, DEEP_LOBBY_BACKDROP, Small_Service_Door_HANDLE | Runtime: Small_Galleria_Sign скрыт; авторские AO, латунь и стекло сохранены. Live: полный эталонный вход, боковой/задний вход, отсутствие надписи. |
| civic_hall / civic_hall_canon_v2.glb | 1 | CivicHall_DoorLeaf_Main_L/R, DoorGlass_L/R, DoorHandle_L/R; Canon glass + Civic_Soft_BlueGlass OPAQUE; 47 CANON узлов | Runtime: только Canon glass. Live: ступени/порог CivicHall_DoorThreshold, обе створки, не считать синий непрозрачный остаток автоматически принятым. |
| police_station / police_station_canon_v2.glb | 0 | Public_Door_L/R, Public_Door_Glass_L/R, Service_Door, Garage_Door; 86 CANON узлов | Не подменять настоящий комплекс. Авторский пакет проверять отдельно; сохранение настоящей полиции/интерьеров обязательно. |
| hospital / hospital_exterior_canon_v2.glb | 1 | DOOR_HOSPITAL_PUBLIC_MAIN_GlassLeaf/.001, Handle/.001; DOOR_HOSPITAL_SERVICE_AMBULANCE_Glass; 109 CANON узлов | Runtime: Canon glass. Live: главный вход, подъезд скорой, размеры порогов/дверей и доступный проход. |
| fire_station / fire_station_exterior_canon_v2.glb | 0 | Apparatus_Bay_Door_01/02/03, Bay_Door_Window_01; 137 CANON узлов | Сначала достаточный участок и подъезд; потом живой осмотр ворот и отдельного пешеходного входа. |
| nightclub / nightclub_southside_canon_v3.glb | 1 | DoorLeaf_Main, DoorHinge_Main, DoorGlowPanel, ServiceDoorLeaf_Main; FrontWindowGlow; 56 CANON узлов | Runtime: Canon glass. Live: согласованность добавленных CANON деталей с подвижной дверной створкой. |

## Точное поручение на авторскую геометрию

Это подготовленный список для пользователя/координатора, не сообщение Художнику 13.

Начать с трёх городских жилых типов: они покрывают 30 экземпляров. В каждом
`<assetId>Shell` остекление сейчас — материал внутри общего mesh. Выделить его в
отдельные именованные оконные узлы; выполнить реальные ниши, тёмные боковины,
отодвинутый задник, небольшие силуэты мебели, локальные тёплые бра/подвесы.
Соблюдать мягкие края, латунь и дымчато-бирюзовый тон эталона, сохраняя индивидуальный
силуэт каждого типа. Не подменять интерьер жёлтым emissive-квадратом.

Следующий пакет — шесть частных домов. `FrontWindow1`, `RearWindow1`, `RearWindow2`
нужны как отдельные окна с реальной глубиной. `PorchLamp` отделить по материалу,
чтобы исправление окон не меняло светильник. Для `PublicDoor` и `ServiceDoor`
предусмотреть подробные рамы, петли, обрамление проёма, ручку/замок с мягкими
краями. Не уменьшать двери вместе с общей моделью при создании меньших зданий.

Для будущего открытия двери сохранять существующие EntranceAnchor/
PublicDoorSocket, ServiceDoorSocket, DoorOpeningBounds и DoorHinge, где они есть.
Создать отдельные hinge/leaf, где сейчас объединённая геометрия. Проверить,
что ручки, стекло и накладки дверной створки являются её дочерними узлами и
поворачиваются вместе. Ориентир проверки — герой 1,9 м, ширина прохода и
положение ног на существующем тротуаре; сохранение точного масштаба 4,1 м/клетка.

Эталонный исходный файл ART_DIRECTION_CANON имеет SHA256 `0dfd79a8...ef33c`;
в walk используется производная версия с AO `ecae5f97...72873`. Это разные
проверенные байтовые версии, их нельзя путать или заменять запись хеша без аудита.

## Первый живой прогон координатору

1. Открыть `/walk` сразу с существующим героем, дождаться всех моделей; в отчёте
   загрузки нет failed. Главный игровой runtime не считается мигрированным.
2. Через меню выбрать `glass_pavilion_small_v1`, приблизить камеру до уровня
   третьего лица. Осмотреть фронтальную надпись (отсутствует), обе створки,
   фурнитуру и интерьер под прямым и косым углом, затем сервисный вход.
3. Выбрать `coastal_orchard_house_v1`: ручка латунная, каменные цоколь/отделка
   исходные. Зафиксировать, что жёлтые окна остаются открытой художественной задачей.
4. Выбрать civic_hall/hospital: проверить существующие прозрачные двери,
   сохранённую глубину и детали, без исчезновения мебели/задников.
5. Проверить WASD, прыжок, подход к двери и отступ камеры; обработка материалов
   не меняет коллизии. Обновление расстановки не накапливает клоны материалов.
6. Ночная приёмка возможна только при наличии реального режима ночи. Не объявлять
   дневной screenshot доказательством качества ночного освещения.

Результат живой проверки пока **PENDING**. Требуется визуальное принятие; модуль
не заявляет, что все 72 здания уже достигли художественного эталона.
