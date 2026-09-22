# Чёрный телефон с антенной — 23 сентября 2026

**READY: production и CPU проверки. LIVE и производительность общей сцены ещё не проверены; владелец единственной игровой вкладки — Координатор20.**

Владелец этого узкого этапа: `/root/astra_local_inventory23`, после явного отзыва phone scope у Художника20 координатором. Не изменены `npc_actor.mjs`, source lifecycle, authority, часы источника или игровые сроки звонка. Не было commit/stage/push, новых вкладок или GPU-прогонов.

## Production

- `assets/maps/city_rebuild_v1/npc_phone_visual.mjs` — чёрный корпус с фасками, тонкая антенна, скромные динамик/LCD/кнопки. Один opaque MeshBasicMaterial с baked vertex colors и одна общая BufferGeometry, без текстур/света/дочерних мешей. Сохранены shared pool, reuse, no-raycast, no-shadow и однократное освобождение ресурсов.
- Габариты корпуса 105×215×36 мм, антенна выступает на 70 мм; общий размер 105×285×36.2 мм. 110 треугольников вместо 12 у прежней коробки: +98 на активный телефон, число draw calls не увеличивается. Position+color buffers 7920 байт на общий пул.
- Динамик следует голове модели, кисть поворачивается вместе с телефоном и находится ниже ладони. Подъём идёт по короткой дуге. Сохраняются прежние сроки draw .28 s, raise до .78 s, stow .56 s, clamp dt .1 s и жест свободной руки.
- Отмена звонка во время draw/raise начинает stow с достигнутой высоты. Ранее сброс к начальной фазе stow телепортировал руку почти к уху.
- `phoneBlocked` сразу скрывает телефон и прекращает его pose: старый stow ещё .56 s перезаписывал новую позу оружия/посадки. Обычное завершение звонка сохраняет плавный stow.
- Head/chest overlays используют повторно выделенные scratch-объекты. 120 прогретых обновлений не создают ни одного THREE-объекта внутри phone module. Существующие выделения памяти в walker IK этим утверждением не покрываются.

Production SHA256: `ae866463e4ab393dd39243d68cbab7ddd7f18172a1b2c4c5e2d93cede3232997`.

## Actual GLB evidence

Использованы настоящие `player_male.8130dfb1f7eb.glb` и `player_female.298d50e6244a.glb`, SkeletonUtils-equivalent clone и production walker/phone/actor. Измерены head-weighted вершины SKIN: наружный край правого уха head-local `(0.702,0.4,-0.015)` для male и `(0.652,0.4,-0.015)` для female; при росте1.9 это 0.2585/0.2536 м от центра головы по X.

Раньше правая ладонь была на 63/67 мм ниже запястья: кисть у уха перевёрнута вниз, ориентация телефона задана относительно корня актёра. Теперь ладонь на 63/67 мм выше запястья, телефон следует кисти и повороту головы. При 7/15/60 Hz, росте1.6/1.9/2.2 и yaw0/1.37 максимальное расстояние динамик–наружное ухо 11.01 мм male /16.68 мм female. Центр корпуса от ладони —50.77 мм. Шесть матриц thigh/shin/foot остаются нетронутыми, включая движение.

Первый шаг stow после короткого звонка, dt .1 s, actual rigs:

| Модель / длина звонка | До | После |
|---|---:|---:|
| male / .1 s | .8380 м | 0 м |
| male / .4 s | .7203 м | .0067 м |
| female / .1 s | .8205 м | 0 м |
| female / .4 s | .7203 м | .0074 м |

Actual actor проверен для уже активного звонка с последующим medical prone crawl, stun, death, flee, cower, surrender, cash offer, weapon и реальной vehicle binding: телефон скрывается сразу. Actor caller не изменён. Controller-level проверка также доказывает отсутствие каких-либо изменений матриц костей на заблокированном кадре.

## Проверки и стоимость

- `node --test test_npc_phone_glb23.mjs`: **13 PASS**, production import напрямую. Новый тест не трансформирует runtime и не зависит от локального кандидата. Optional `NPC_PHONE_BASELINE_MODULE` используется только для before/after CPU сравнения; без него обычные проверки работают самостоятельно.
- `node --test assets/maps/city_rebuild_v1/test_npc_phone_visual.mjs`: **6 PASS**, изменено только ожидание новой геометрии/material.
- Actual actor/activity/social suites с `--import ./assets/maps/city_rebuild_v1/test_npc_death_offline_setup.mjs`: **3 PASS**. Без сетевых запросов.
- Syntax и scoped `git diff --check`: PASS.

Сопоставимые interleaved CPU измерения: одни GLB/рост/походка, 700 updates на вариант, первые200 исключены. Измеряется только `phone.update`, без walker.update, рендера и общей сцены.

| Модель | До p50/p95 ms | После p50/p95 ms |
|---|---:|---:|
| male | .1641 / .1881 | .1660 / .1858 |
| female | .1562 / .1769 | .1605 / .1825 |

Разница мала; это **не утверждение улучшения FPS**. Cold pool geometry/material creation, 50 samples после10warm: box p50/p95 .0303/.0650 ms → new .0929/.2491 ms. Работа выполняется один раз на общий pool, а не каждый кадр/каждого NPC.

До production переноса отдельный candidate прошёл bounded actual GLB suite. Его и baseline копии в `.git/ai-pipeline-local/npc_phone_visual_{candidate,before}23.mjs` — локальные audit artifacts, **не runtime dependencies и не часть checkpoint**.

## LIVE для координатора

Отдельный reload существующей вкладки после water/intimidate. Подтвердить видимый чёрный корпус и антенну сбоку/сзади, хват у уха обоих полов и у идущего NPC, полный draw→raise→hold→stow и раннюю отмену, отсутствие старого телефонного меша. Проверить приоритет ранений/оружия/автомобиля и отсутствие застрявшего props после завершения звонка. Сравнивать loaded p50/p95 frame time, draw calls/triangles в одинаковой сцене; CPU результаты выше этого не заменяют.
