# Редактор карты Godot — фактическая граница внедрения, 29 сентября

## Сверка 30 сентября (не статус LIVE)

Рабочий `godot/mafiozi_walk/scripts/main.gd` уже изменился до SHA-256
`d2de587dfc0e109acb2a722ecc445080f89ddaaeacbaa10bd94d40c464f6b9a7`;
`preview_residents_enabled=true` по умолчанию, население создаётся до
`preview_ready` и обновляется в `_physics_process`. Поэтому старый K-stage,
прибитый к `653837...`, не применим к текущей сцене. Даже перепривязанный
pause-only кандидат верно откажет во входе при действующих NPC/navigation,
пока их владелец не выдаст реальную квитанцию остановки/возобновления.
Проверки 54 PASS ниже относятся только к предыдущей версии main и сценарию
без жителей. Отдельный независимый аудит v2 обнаружил обход нейтрального ввода
через Escape; исправление и негативные тесты пока только в tools-кандидате.

Существующий production `scripts/map_editor` не равен полному tools-кандидату:
например, production `editor_controller.gd` содержит синхронный
`install_document`, но не `begin_atomic_install`/`prepare_install_document`, а
production `map_document.gd` не имеет `begin_install_guard`. Полный 9901-object
assembly и курсор подготовки поэтому нельзя просто вызвать из нынешнего main;
нужна отдельная согласованная миграция API и всех owner-адаптеров. Никаких
production/LIVE изменений эта сверка не вносит.

Проверка байтов моделей `tools/godot/map_editor_asset_adoption_audit/manifest.json`
на 30 сентября: все 196 исходных GLB и 13 зависимостей целы, но в дереве
действующей игры есть лишь 8 точных моделей, отсутствуют 188 (25,601,564
исходных байта). Из 33 уже размещённых видов доступны 6, отсутствуют 27.
Все 8 имеющихся файлов доступны именно по объявленному в каталоге `resPath`;
новый путь `assets/map_editor/<SHA>.glb` — лишь будущая схема миграции, сейчас
он заполнен для 3/196. Это проверка файлов, не Godot-импорта/материалов/LIVE;
ресурсы в production не копировались.
Отдельный проверенный outputs-пакет ровно этих 188 отсутствующих GLB:
`outputs/map-editor-missing-assets-aE6EyN/package_manifest.json`, SHA-256
`50fe3ca72c5b7a6956495e870c0c2f618019abf62c92b5eaca4f7a1cddf9fa27`.
Сохранены исходные байты, 882 материала, 3079 glTF mesh и встроенные изображения;
8 уже имеющихся моделей указаны ссылками, а не скопированы снова.
Изолированный headless-импорт позднее согласован и выполнен: checkpoint
`outputs/map-editor-188-import-WictKB`, Godot 4.7.2 exit0, 196/196
`PackedScene` загружены, 785 native checks без отказов, все 196 sidecar и
ненулевые cache-сцены проверены. Три ссылки каталога отсутствовали в самом
checkpoint и были дополнены исходными точными байтами; остальные пять
сохранились там. Receipt `import_verification.json` SHA-256
`23b466c83500a042ce06466ac158e437a31d0d8ff8e125ce902422d98d9419be`.
Это по-прежнему **не поставка в production**, не LIVE/визуальная приёмка и не
доказательство стоимости кадра; активацию путей и перенос согласует владелец.

Владелец main/player/project/LIVE/Git теперь Координатор22, задача
`01a0eec3-2733-7130-9aea-c289c76574af`. Единственное восстановленное окно
игры по передаче от 29 сентября — braking22, PID43120; этот пакет НЕ запускал
вторую игру и не менял production.
Main на 29 сентября имел SHA256 `653837bb2365c92f9e290e1f8c5126bf6fbb5357da8db3570cdb6f1bec9f6d50`
после отдельной правки braking22; состав квартала остаётся31×31. Объективный критерий пользователя — полный
редактор K/полёт/все объекты/ПКМ/undo/save/export и LIVE — остаётся OPEN.

## Готовые инструменты, проверенные против настоящей сцены

| Пакет | Точная полезная граница | Проверка | Не доказано |
| --- | --- | --- | --- |
| `tools/godot/map_editor_native_building_adoption_candidate` | Существующие native-модели8 зданий,16 отдельно стоящих ordinary collision bodies, special Printshop111generated bodies,69 batch receipts под исходными корнями;67 из75 зданий вне loaded crop | Root повторил326 default +962 staticbatch, exit0/noengine errors на source snapshot main091638 | Право двигать/удалять, Printshop doors/anchors/nav, 67 отсутствующих native зданий, все каталожные виды |
| `tools/godot/map_editor_actual_terrain_inventory` | Точные существующие961 клетки,3 surface groups/658 dry instances,169 floor strips,303 water cells,24 direct source convex, jump cache | Root повторил815 assertions, errors[], stage-check337files PASS | GPU MM buffers Dummy renderer не доступны; редакторская замена земли/water/nav не принята |
| `tools/godot/map_editor_actual_pause_probe` | Реальная native physics стоит при SceneTree pause | Root повторил diagnostic PASS, vehicle tick91→91 при ~648ms; Inputheld и absolute melee cooldown продолжают | Безопасная editor lease, NPC/nav deferred quiescence, корректные все игровые часы |
| `tools/godot/map_editor_host_adapter_v2` | Tools-only lifecycle guard для queued owner, callback reentry, post-ground stale owner и workspace input | Root57 boundary +13 legacy contract PASS; независимо написанный негативный тест 3 сценариев теперь утверждает отсутствие прежних пробелов, exit0 | Actual owner callbacks всё ещё отсутствуют; тестовый lease не останавливает игру |
| `tools/godot/map_editor_input_router_pause_candidate` | Только роутер K в ALWAYS под PAUSABLE игровым владельцем, чтобы та же клавиша закрывала реальную SceneTree pause | Root7 native input/process checks PASS, исходный роутер/production не менялись | Игровая пауза в тесте переключается fixture callback; actual main K/owner/nav/clock пока нет |
| `tools/godot/map_editor_native_clock_candidate` | Tools-only clock поверх actual main/melee host, сохраняющий исходную absolute-Time базу до первой паузы и точную границу паузы | Свежий `outputs/actual-native-clock-gcGkqy`: Godot4.7.2 headless PASS, 663420µs wall pause, at_ms=paused=first resumed read точно; исходная и candidate первая атака seq1/timer1/cooldown; sourceDrift[] | Не принят в production; NPC/nav/water/transport/input и общий editor lease не покрыты |
| `tools/godot/map_editor_main_pause_candidate` | Изолированная копия actual main: K входит/выходит из pause-only на стабильном default on-foot, сохраняет player/body/water/melee, отказывает при удержанном W, residents и seated | Stage `outputs/actual-main-pause-5y7P26`, Godot4.7.2 headless54 checks PASS, оба варианта 8buildings+8decor+27colliders; +2 nodes/~0.01MiB, две пары тёплой загрузки без доказанного регресса | Пока **не в production/LIVE**, не полноценный UI/editor и не admission для жителей/навигации/посадки/активного боя; GPU/FPS не проверены |
| `tools/godot/map_editor_paged_filter_cache_candidate` | Кэширует только индексы совпавших объектов по каталогу/запросу/категории; права, текст отказа и выбор перечитывает при показе | Fresh full9901 fixture80528 PASS,62 страницы,5 пар: p50/p95 sweep132706/144154→44821/46983µs; ошибки движка отсутствуют | Только headless UI CPU, не actual game FPS и не production. Отдельный setup-once вариант80463 PASS, но ~1% p50 в шуме, выигрыш пока не доказан |
| Full assembly (`tools/godot/map_editor_assembly_candidate` и paged UI) | Все9901 source IDs,62 страницы, обычные select/move/delete/undo, source save/load CPU | Previous root80452 headless assertions exact staged source, 196GLB imported | Не загружено в current main,38 protected owners, графика/GPU и реальный пользовательский save/load |

Независимый аудит K-кандидата `docs/ai/MAP_EDITOR_K_CANDIDATE_REVIEW_20260930.md`
помечает даже этот narrow default route **HOLD до исправлений**: отмена старого
request может освободить новую паузу, нет проверенного teardown сцены, потеря
фокуса меняет held/input authority, predicate idle melee читает несуществующее
поле; дополнительно impact host, rolling car и настройки stage ограничивают
проверку. Значение `54 PASS` доказывает только перечисленный обычный сценарий,
не готовность переноса в main. V2 hardening готовится вне production.

## Ближайший порядок внедрения, не заменяющий полный объём

1. Владелец main выдаёт genuine pause/input/clock lease, отдельному редактору
   `PROCESS_MODE_ALWAYS`, не меняя режим игрового parent на ALWAYS. K вход/выход
   проверяется на реальном player/vehicle/melee. Настоящий owner clock preserve
   будет НОВЫМ offline editor contract, не обещанием паритета прежнего Walk:
   текущий источник не содержит установленного K editor freeze.
2. Только под lease owner принимает существующие native nodes/resource identities
   текущего квартала без перестройки. Обычные здания — root + соответствующие
   sibling colliders как единая транзакция. Printshop — отдельный transform/delete
   адаптер его дверей, источников якорей, внутренних тел и nav. Static batches
   восстанавливаются checked owner-операцией до bounds/selection.
3. Земля требует owner-captured existing surface/floor/water/jump capsule,
   затем отдельную prepare/commit/rollback геометрии; nav, NPC support/access
   и water readiness должны подтвердить свежий generation до первого игрового
   физического кадра. Сейчас callback `{ok:true}` без такой работы недопустим.
4. Расширить native main за квартал с теми же исходными75 зданиями и остальными
   каталоговыми видами/ID, не выдавая CPU-catalog instantiation за loaded game.
   Пагинация и lazy CPU-image cache уменьшают цену редактора без снижения
   моделей/текстур/коллизий; для результатов игры нужны paired LIVE p50/p95
   на одной сцене, не только headless.
   Изолированные кандидаты находятся в
   `tools/godot/map_editor_paged_filter_cache_candidate`: кэш только индексов
   поиска (не прав/причин отказа) дал проверенный CPU-выигрыш при листании;
   отказ от повторного заполнения временной панели доказал parity, но его
   небольшое изменение setup time пока в шуме. Оба ещё не применены в игре.
   Особые38 ID и точные владельцы перечислены отдельно в
   `docs/ai/MAP_EDITOR_PROTECTED_OBJECTS_20260929.md`; 3 банка,3 изолятора и32
   железнодорожных элемента должны получить реальные owner-адаптеры, а не
   снятие блокировки в каталоге.
5. После реального K и full world: top/fly/RMB/delete/undo/redo, save→fresh
   reload всех ID/terrain, import/export/publication, русские подсказки и
   визуальное сравнение. Только тогда закрывать системную цель.

Нельзя переносить статусы «PASS» из приведённых узких сценариев на весь город,
игровые права или FPS. Source files могут изменяться одновременно другими
владельцами; повторная интеграция сверяет актуальные SHA и lifetime вместо
доверия историческому тесту.
