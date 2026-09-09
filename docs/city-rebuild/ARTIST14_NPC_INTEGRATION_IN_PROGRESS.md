# Artist14 NPC — интеграция продолжается, не релиз

2026-09-09. Пользователь поручил перенести всех NPC world на мужской/женский
скелет главного героя, разнообразить внешний вид и сохранить/улучшить AI.

## Подключено

- `npc_role_catalogue.mjs`: 19 именных боссов, Саид, гражданские/служебные
  архетипы. Полный список источников и фактическая логика в
  `NPC_WORLD_INVENTORY.md`, `NPC_BEHAVIOR_REVIEW.md`.
- `npc_appearance.mjs`: 13 причёсок, 8 бровей, 6 оттенков кожи, 8 цветов волос,
  рост 1.65–2.05, комплекция, одежда/полицейские и служебные аксессуары.
- `npc_actor.mjs`: общие hero_walk, artist14 poses/surface. Раздельные ресурсы,
  мокрая одежда, раны, синяки, смерть, нефатальное оглушение, наручники.
- `npc_population.mjs`: реальные IDs из единственного world runtime; никакой
  второй AI. Интерполяция 10Hz, GPU cache8s, CPU состояние повреждений на сессию.
- `world_walk_host.mjs`: тот же world.html, ShadowRoot для нового renderer;
  старый three_preview исключён. `/world.html?render=3d&renderer=walk`.
  Для локального UI QA используются существующие `direct=1&previewcity=1`.
- Source-owned firing/ammo/selection/reload, skinned ray contact, deferred
  подтверждения с привязкой к треугольнику текущей позы.
- Source melee input и физический объём кулака/стопы; source выбирает тип
  один раз, отрисовка повторяет его. Контактное окно/финальный miss.
- `?npcgallery=1`: отдельная явно подписанная примерка, только qa-копии.

## Живые проверки и проблемы

Gateway действительно загрузил 54–59 NPC из world snapshots. Исправлена
ошибка часов: getWorldClock возвращает объект `{now,epochNow,renderer}`.
Общая ошибка GPU uniforms из сотен комнатных PointLights исправлена другим
владельцем на 32 slots. После этого город/герой/NPC видны, shader logs пусты.
При следующей длительной проверке/перезагрузке тестовая вкладка упала;
причина ещё не доказана. Оптимизация дальних NPC и повторный live обязательны.
Не считать CPU tests финальной живой приёмкой.

## Текущие владельцы

- Root Artist14: walk NPC/input/contact hooks, живой прогон, итоговая передача.
- shot_effect_upgrade: новый реальный server NPC melee handler/ACK. Работа
  продолжается; source `melee_hit` ранее не имел обработчика. Runtime bounded
  dedupe, только server damage/range/LOS/charge/unarmed, не client dmg.
- wet_clothing: LOD обновления дальних акторов; source AI не изменяется.
- weapon_art_upgrade: source melee API/input/catalogue/gallery завершены.
- Задача оружия `01a06e4d-e3ed-7f13-bda3-7fd677972336`: новый HUD/portrait,
  source hero appearance и отдельно разрешённые пользователем server G/E
  drop/pickup. Не пересекать её inventory/HUD scopes.
- Координатор14 `01a08279-8066-7563-83fd-2d3fc4cbca41`: карта/железная дорога,
  сервер18538. Его user /walk вкладку не трогать.

## Не объявлять завершённым

- Production Python server ещё должен быть перезапущен/проверен владельцем
  после server receipts/prone/melee изменений. 18538 — статическая проверка,
  недоступный backend профилей не заменяется выдуманным пользователем.
- Подтверждение server melee и безопасный dropkick без server jump window
  ещё проверяются. Не доверять client airborne для бесплатного heavy damage.
- Per-pellet/penetration/blast exact contact arrays и NPC-only adapter PvP
  не реализованы этим этапом; существующие механики не считать перенесёнными.
- G/E server transfer делает отдельный владелец; до него gateway guards
  запрещают local mint. Standalone /walk инвентарь не менять.
- Общая миграция интерьеров, custody/medic переносимого тела и остальных
  игровых систем не завершена этим renderer. Не выдавать preview за релиз.

## Сохранение совместной работы

Shared walk/world редактируются несколькими задачами. Только свежие адресные
правки и сравнение исходных байтов непосредственно перед записью. Один раз
gallery/receipt hooks исчезли после чужой записи; восстановлены. Проверять
`npcGallery`, `worldWalkMelee`, deferred `resolveConfirmedReceipt` после правок.
Root temporary patch scripts уже применены; повторять только при подтверждённой
потере соответствующих hooks, не поверх новых реализаций.

## Обновление — поведение и темп NPC

- Lazy bruise projection устранил дорогую подготовку каждого NPC: 32 модели в CPU проверке ~0.54 с вместо ~21.66 с. В живом gateway после queue1/frame загружены59–64 sourceNPC, pending0, console errors0. Это не замер общего FPS.
- Сохранён source цикл гражданского: реальная дверь, entering/browsing, выход, резервируемая скамья, отдых6–12с, следующий цикл. Walk регистрирует настоящие exploration benches с верхом сиденья item.y+.61*scale.
- Activity pose принимает source seat.height/phase:sit, плавно садится/встаёт, телефон только при настоящем phoneCalling. Оба пола/рост проверены тестом; live посадку ещё проверить.
- Свидетели убийства запоминаются в момент события с LOS. Поздние прохожие не получают чужое свидетельство. Телефон завершается либо прерывается угрозой/ранением, звонки ограничены и повторные выстрелы не замораживают таймер.
- Source NPC melee handler и ACK реализованы, проверены тестами; production restart/live ещё не выполнены. Серверный dropkick пока не даёт неподтверждённую силу/оглушение по одному client airborne.
- _parkingNpcs включены в renderer с исходными ID/состояниями и action refs. Реальные поездки автомобилей и 3D source cars presentation остаются отдельной незавершённой работой с владельцем автомобилей.
- По запросу пользователя скорость обычной ходьбы ограничена эталоном героя4.6м/с, panic/snitch7.8м/с, native4.1. Усталость/ранения/медленные архетипы сохранены. Шаг анимации рассчитывается от измеренной скорости source snapshots, не от ошибочного src.speed в тайлах. Default hero gait не изменён.
- Проверки: test_npc_hero_pace, test_npc_motion_speed, test_npc_gait_speed; purposeful-plan, witness, murder-observation, activity, population/LOD PASS.
