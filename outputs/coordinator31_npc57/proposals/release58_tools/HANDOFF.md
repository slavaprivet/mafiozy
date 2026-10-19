# Инструменты выпуска 58 — подготовлены, выпуск не принят

Владелец интеграции, freeze, F5 и Git — root. Этот пакет содержит инструменты и
сохранённые отдельные функциональные проверки. Freeze и activate не выполнялись.
Новая release58 ещё не принята.
Результат `--inspect`: `PREPARED_NOT_ACCEPTED`; будущие receipts остаются PENDING.

## Контракт

- Baseline: точная неизменяемая `outputs/coordinator31_release57/game` и текущий указатель57.
- Candidate: `outputs/coordinator31_npc57/game`; root интегрировал портал, освобождение
  дверной створки и двухфайловое исправление выбора пути побега. Финальные проверки
  относятся к `extended31/stage58_03/CANDIDATE58.json` (1135 pins).
- Требуется финальный cumulative integration manifest с `applied=true` либо exact
  passed native import receipt (`import_receipt` указывает на соседний `RESULT.json`), полными
  `source_pins` и `changes` всей разницы57→candidate. Каждая запись содержит
  `base_sha256` и `candidate_sha256`; для нового/удалённого файла отсутствующий SHA — null.
  Текущий candidate ещё имеет presentation56, поэтому два metadata-различия против57
  также надо включить явно. Одного `INTEGRATION_portal58_01.json` недостаточно.
- Основной soak: свежий `qa58_merged`, минимум1200сек, ≥1197 выборок,10 исходных
  жителей+12 сотрудников, movement/queue10/30с. `SPATIAL58.json` пересчитывается из
  точных `SOAK31.json`: окно30с, bbox diagonal1.5м, никаких confined-motion episodes.
  Архив harness должен содержать тот же проверенный spatial-checker. Старый57PASS
  без этой проверки не подходит. Длинный soak не заменяется короткой fixture.
- Services: общая native graphical проверка всех4 услуг, исходный roster и полный
  pinned checker. Формат сохранён `SERVICES56.json`/`accept(native)`; название файла
  историческое, SOURCE обязан быть финальным58candidate.
- Threat/visual: общая native проверка и настоящий видимый поворот/изображения,
  без synthetic state/HP writes. Схемы `CITY_THREAT56.json` и `VISUAL31.json`.
- Отдельные обязательные `shop_interruption` и `restaurant_interruption`: настоящий
  выстрел во время ещё неоплаченной услуги, физический выход и освобождение claims,
  побег минимум2м с обычной скоростью,15сек тишины, повторная услуга с одной оплатой
  и продолжение прогулки. Проверяются19 именованных gates и сырые данные, exact source,
  immutable harness и controls. Изолированные overlay и прежний реальный FLEE0 FAIL
  не принимаются даже с подменёнными итоговыми PASS. Обычный soak не заменяет эти роли.
- Perf: новая matched rendered pair baseline57→candidate, ≥90сек, одинаковый warmup,
  camera, harness, editor environment. Физический window/output и логический viewport
  обязаны быть1920×1080; нужен `WINDOW31.json` протоколV4. Exclusive scheduler lease,
  stderr/errors/drift0. Сохранены12 gates57, включая p95≤16.667ms и mean≥90%baseline
  и≥60. Это пороги отсутствия существенной регрессии, не доказательство ускорения.
  `qa58_merged/run58.py` пока headless-only: FPS PASS из него получить нельзя.

## Provenance и план

Скопировать `RELEASE_PLAN58.example.json` в новый рабочий plan и заполнить null
после завершения прогонов. Путь задаётся относительно repository root; `harness_root`
может быть `.` для repository-relative inventories либо каталог проверочного пакета.
`entry`/`checker` задаются POSIX relative к `harness_root`. SHA — конкретные
рассмотренные root байты entry/checker. Путь, схема или helper могут измениться в новом
QA-пакете; это повод обновить adapter после review, а не отключить gate.

Каждая роль требует `RUN`, `SOURCE/SOURCE_AFTER`, `CONTROL_PINS/AFTER`, stdout/stderr
и immutable `HARNESS.zip` (либо явно названный archive) с полным inventory. Нет fallback
на новые файлы текущей diagnostic-папки. В freeze архивируются точные receipts,
интеграция, заполненный plan, инструменты и заново проверенные tested harness bytes.
Последующие изменения соседней harness-папки не инвалидируют сохранённый тест.

## Шаги root после появления доказательств

1. `python -B .../release58_tools/freeze58.py --plan <plan>` — полная CPU-проверка;
   без `--go` ничего не копирует. `--inspect` лишь перечисляет незаполненные поля.
2. Только после review добавить `--go`. Создаётся новая partial-копия, под read/write
   scheduler leases; hardlinks нет. Копируются `.godot` imports кроме `shader_cache`.
   SHA сверяется до/после. Неудачная partial сохраняется для разбора, target не перезаписывается.
   Разрешённые изменения в копии — точный revision-anchor в `scripts/main.gd` и
   title/revision/пять коротких новостей `data/preview_updates.json`. Основой news служит
   frozen57, её точное прежнее содержимое сохраняется в `history`, текущих пунктов пять.
   Gameplay не меняется.
   Freeze пишет лишь `PROPOSED_CURRENT`, F5 не переключает.
3. `python -B .../release58_tools/startup58.py <unique-name>` — план обычного bootstrap;
   `--go` запускает один зарегистрированный bounded child под lease, по умолчанию headless.
   При timeout завершается только его child. `--mode graphical` даёт capture.
   Приёмка запуска использует exact frozen source, assembly/bootstrap/evidence SHA,
   revision58, roster10/287, staff12, включённые обычные механики и чистый stderr.
4. `python -B .../release58_tools/activate58.py <startup-dir>` — read-only проверка.
   Root добавляет `--go` только после принятого startup. Указатель обновляется атомарно,
   только если он всё ещё exact PREVIOUS_CURRENT57. Код не закрывает и не запускает игры.
5. Обычное видимое открытие и `DELIVERY` оформляет root отдельно, со свежим inventory,
   идентичностью нового процесса и новым native ready. Не копировать `record_delivery57`:
   его зашитые старые показатели не являются доказательствами58.

## Проверено сейчас

`CPU_CHECKS58.json`:62 проверки PASS, включая отрицательные source/delta/SHA/archive,
path traversal, PENDING, недостаточный reserve, spatial looping, подменённый spatial PASS,
неправильный physical/logical viewport, попытку принять headless как FPS, реальный
FLEE0, оплату до выстрела, неверную оплату и неосвобождённые claims.
Ни freeze main, ни startup main, ни activate main в CPU suite не вызываются.

На момент первоначальной подготовки:1130 source files; copy с cache безshader286933902байт;
свободно1081810944байт. Freeze заново считает объём source+evidence и оставляет минимум128MiB.
Диск не резервируется заранее. Существующие57/старые предложения/F5/Git не изменялись.

`prepare_tools58.py` фиксирует происхождение pure validators/startup от57; это generator
для первоначальной подготовки, не шаг выпуска. После sealing не запускать заново.
`spatial58.py` и `perf_compare58.py` — локальные проверяемые копии алгоритмов; их main
не используется release flow. Итоговая приёмка58 PENDING до заполнения всех ролей.
Исторические stage02 functional receipts сохраняются; они не принимаются для stage03.

Последующая фактическая CPU-проверка stage58_02 приняла его passed import receipt,
1135 source pins и полную разницу12файлов относительно frozen57. Это не gameplay PASS.

`run_attention58.py` — новый внешний адаптер существующего `attention31_resume/run_city31.py`.
Принимает явный `--expected-source`, запускает только graphical functional и не меняет
старый runner/harness. Исходные `RUN_NATIVE`/`HARNESS_NATIVE` сохраняются; итоговый RUN
добавляет engine/scheduler/controls/manifest pins и может только снять прежний PASS.
Архив полного transitive harness имеет repository-relative пути; для этих receipts в плане
нужен `harness_root: "."`. До запуска сохраняются точные bytes всех входов, потом они
сверяются с архивом, который создал сам native runner. Переключать в perf этот адаптер нельзя.

`ATTENTION58_STAGE03_ACCEPTANCE.json`: реальные новые graphical threat02(16/16) и
visual02(11/11); два снимка просмотрены, видимый поворот подтверждён. Graphical слот
освобождён и передан QA. Исходные stage02 receipts/план/acceptance сохранены отдельно.

`ACTUAL_ROLES58_STAGE03_01.json`: end-to-end проверка этих двух ролей и окончательных
shop/restaurant interruption (19/19 каждая) через реальные release validator функции.
Flee7.7214м, максимум1.980716м/с в обеих услугах; source1135, stderr/drift0, все controls
сохранены в immutable archives. `RELEASE_PLAN58.partial.json` содержит эти четыре роли.
Общие услуги затем прошли37/37 на final source: `ACTUAL_ROLES58_STAGE03_02.json`
содержит уже пять реально проверенных ролей. Soak и новая performance pair пока PENDING.
Для повторной проверки
доступных ролей без движка/freeze используется `audit_available58.py --output <unique.json>`.

Независимый review mandatory interruption gates выявил неполный declared control inventory.
Исправлено: требуются все12 нормализованных control paths;11 non-engine файлов обязаны
присутствовать с точными SHA в архиве. Пустой набор или удалённый из обеих inventories
observer отвергается. Реальные пять ролей повторно прошли усиленный validator:
`ACTUAL_ROLES58_STAGE03_03.json`. Исторические предыдущие аудиты сохранены.
