# Gameplay checkpoint после 31f8ea6 — зависимости тестов

23 сентября 2026. Аудит состава checkpoint; сам аудит не меняет runtime, тесты, индекс Git или браузер. Позднее в список добавлено отдельно разрешённое исправление времени удержания E — `VEHICLE_ENTRY_HOLD23_HANDOFF.md`. Точный список и SHA256 снимки выбранных файлов находятся в локальном `.git/ai-pipeline-local/live23/gameplay23-manifest.json`.

## Подтверждённый внешний fixture

Два transport entrypoint нового пакета требуют существующий локальный файл:

- `assets/maps/city_rebuild_v1/test_parking_exit_resume23.mjs`;
- `assets/maps/city_rebuild_v1/test_native_parking_lifecycle.mjs`, включая `--resume-exit23 --async`.

Оба вызывают `createCivilianNativeFixture` без `snapshot`. Его текущий штатный default читает:

`outputs/roads_logical_20260912/integration_candidate_snapshot.json`

Файл не отслеживается Git, **94 917 719 байт**, SHA256:

`7cc0043339615a3fecf74eb0c3c0ebc46b75a76c78cf82f133952f891bd8f8d9`

Для воспроизведения именно зафиксированных проверок этот артефакт должен находиться по указанному пути до запуска тестов. Размер и хеш проверять, например, `Get-FileHash -Algorithm SHA256 -LiteralPath <путь>`. Один свежий checkout не обеспечивает этот prerequisite. Новый файл на 95 MB в checkpoint **не предлагается**.

Это тестовая зависимость, не runtime-зависимость игры. Тесты artist cohort/escort уже явно передают tracked compressed fixture и не требуют данного default. Локальные transport PASS честно относятся к окружению, где исходный snapshot был доступен.

## Почему нельзя просто подставить существующий gzip

Tracked `assets/maps/city_rebuild_v1/test_fixtures/native_static_collision19.json.gz` занимает 516 417 байт; после распаковки — 2 175 491 байт. Сравнение распарсенных данных подтвердило точное равенство:

- всех 78 building records, включая transform/binding/entry;
- collision records всех 164 authored decor;
- `decorPlan.colliders`, `roadPlan.colliders`, `parkingPlan.colliders`.

Однако его `roadPlan` и `parkingPlan` содержат **только colliders**. Отсутствуют traffic/prepared lane graph, lot/bay records, authored entry/exit paths и данные дорожных правил. Новый parking suffix test проверяет реальный reverse exit; полный lifecycle использует эти планы и async worker. Подмена на collision-only gzip изменила бы проверяемое поведение. Такой fallback не внесён.

## Предложение для отдельного переносимого fixture

Минимальное консервативное дополнение к уже tracked collision gzip — отдельный compressed overlay с неизменёнными полями исходного snapshot:

- `roadPlan`: `trafficPlan`, `preparedLaneGraph`, `serviceAccess`;
- `parkingPlan`: `lots`, `bays`, `surfaceRects`, `roadSupportRects`, `coverage`, `walkingAlternatives`, `access`.

Эти поля обнаружены в текущем parking origin / road navigation / async worker и fixture. Они должны объединяться с существующей collision-only геометрией. Размер точного выбранного JSON — **63 881 924 байт**, gzip level9/mtime0 — **16 566 069 байт**. SHA256 выбранного JSON, сериализованного Python `json.dumps(..., separators=(',', ':'), ensure_ascii=False)`:

`67fab376453ee9c3e9b8d6afb3d8447474b58de8c13e2475bf8a5bc2c5aaa7ff`

В provenance нового `test_fixtures/transport_plan23.json.gz` следует сохранить исходный путь, исходный SHA256 выше, перечень сохранённых полей, алгоритм сериализации и compressed/uncompressed SHA256. Сам overlay пока **не создан и не добавлен**: перед переносом нужно подтвердить равенство полного route/lifecycle trace на старом input и новом объединённом fixture, включая controls, route IDs, gear, swept hull, source IDs и interrupted-exit режим.

Prepared-only вариант, оставляющий в `trafficPlan` только `drivingSide/speedLimitKmh`, сжимается до 10 352 839 байт. Его эквивалентность не доказана (в частности, нельзя молча потерять unprepared/rebuild semantics); он не предлагается как готовая замена. Перегенерация графа из другой текущей сцены также не равна сохранённому исходному fixture.

## Остальные границы состава

`test_mercenary_long_follow23_candidate.mjs` включён несмотря на историческое имя: сейчас он импортирует **production** helper и предоставляет physics fixture для полного host regression. Два старых implementation-файла `mercenary_long_follow23_candidate.mjs` / `mercenary_long_follow23_host_candidate.mjs` не нужны и исключены.

Тесты настоящих GLB используют существующий внешний THREE vendor (`THREE_VENDOR` там, где поддерживается, иначе `D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor`). Это ещё один известный prerequisite среды, не новый runtime-модуль.

Generated outputs не являются обязательными входами, за исключением явно указанного transport snapshot. Старые native-site, blast, prototype/candidate WIP, `outputs/interiors_resume` и probes, требующие ignored LIVE exports, остаются вне выбранного пакета. LIVE/FPS и окончательный commit review выполняет координатор.

## Финальная граница пакета

После release/rearm исправления и добавления `VEHICLE_ENTRY_LIVE23.md` в manifest
ровно **54 пути**: **12 runtime** (10 изменённых tracked файлов и 2 новых helper),
18 тестов, 1 fixture, 20 документов передачи/проверок и 3 документа координации.
Новые runtime helper — `mercenary_long_follow.mjs` и `vehicle_entry_hold_clock.mjs`.
Последняя правка отпускания E новых зависимостей не добавила.

Повторный статический обход: 337 runtime и 364 test dependency paths, 632 ребра;
необъяснённых отсутствующих файлов или пропущенных untracked зависимостей нет.
Шесть старых optional City V3 imports учитываются относительно фактического
HTTP пути `/preview/three_preview.js`; соответствующие файлы уже tracked.
Единственное намеренное исключение входа тестов — transport snapshot выше.

36 синтаксических проверок прошли: 29 отдельных JS/MJS файлов и 7 исполняемых
inline scripts `world.html`. Проверка whitespace выбранного tracked diff и всех
37 новых файлов прошла.
Полные игровые/FPS прогоны этим аудитом не повторялись; состояние последнего
LIVE хранится в `VEHICLE_ENTRY_LIVE23.md`.

На момент аудита индекс Git пуст. Вне списка остаётся tracked generated
`outputs/interiors_resume/ladder-discoverability-results.json`, а также новые
shore/Nico/guard/collect/transport-QA кандидаты. Пакеты Проверщика из commits
`59106fe` и `fa110c3` не входят в checkpoint и не являются предками текущего HEAD.
Перед выборочным staging нужно сверить **все 54 SHA256** со свежими байтами:
обновление памяти или LIVE документа после аудита делает соответствующий hash
устаревшим. `git add .` / `git add -A` не соответствует этому составу.
