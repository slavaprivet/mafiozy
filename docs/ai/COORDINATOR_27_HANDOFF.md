# Координатор27 — непрерывный перенос Walk в Godot

## Актуальное состояние 3 октября, после выпуска48

Разделы ниже про accepted45 и ожидающий C4 описывают историю передачи26.
Теперь `godot/current_version.json` указывает на принятую `s01-20261003-c4-release48`:
`outputs/coordinator27_release48/ACCEPTED_ASSEMBLY.json`, SHA
`51484885ce069970cecb234b7c016d5cc7e3b5611c3422ddeaa915a0d9c712b7`, 486 pins.
Приёмка и границы: `ACCEPTANCE.json`, доставка: `DELIVERY.json` рядом.
Усиленный C4, физический проход после взрыва, эффекты Fire3, исправления камеры
и жизненного цикла зарядов уже включены. Цена измерена на текущем квартале,
трёх исходных NPC и текущих машинах; это не завершение всего переноса.
Main/origin/удалённый main подтверждены `f6a019cab77771370d40d3dc3254262d56b0d061`.

Пользовательская игра48 и editor сохранены. Последние PID34540/25808 исторические:
перед действием нужен свежий inventory. F5 использует постоянный launcher и указатель.
Обычные проверки владельцы запускают самостоятельно через `tools/godot/test_scheduler.py`:
два headless и один graphical/input слот; замеры производительности эксклюзивные.
Ожидающий perf не останавливает functional. Не закрывать пользовательскую игру ради FPS.
Инструкция и доказательства actual overlap: `outputs/coordinator27_test_scheduler/README.md`.

Следующие пакеты: car49 exact accepted48, native drive/damage/critical PASS, но
ещё нужен сопоставимый полный путь активного дыма/прокола; owner «Быстрые введения»
получил адресную задачу. Ticket gaps сами по себе не опровергают чистую exclusive pair;
старые raw UNVERIFIED не переписывать. NPC24 исправляет коллизию торса/падение и
стоимость ближнего боя; функциональная проверка не заменяет новый полный perf.
Root проверяет exact step33 в `outputs/coordinator27_step48_native`: только кандидат,
без включения в игру и без возвращения townhouse. Buildings4 готовит новые коробки
отдельно; текущий48 остаётся Palazzo-only. Полная цель ACTIVE.

Git lock: подтверждённые stale lock сохранены архивированием после fresh writer check
и exclusive-open. Audits в `outputs/coordinator27_git_recovery`; не удалять новую
блокировку вслепую, не stage-all чужой WIP. Подробная последовательность и новые
ограничения находятся в свежей шапке `COORDINATOR_27_MEMORY.md`.

## Окончательная передача и GO, 3 октября

Пользователь дополнительно прямо потребовал передать ВСЕ задачи27 и закрыть26.
27 —01a0fed6-c1dc-75b2-8fda-194f729e8bb8, pinned1. Root26 откреплён,
production/GPU/Git прекращены; все3его субагента completed подтверждено API.
Rootheartbeatgodot-4 ACTIVE перенесён27, target_thread_id проверен на диске.
27 уже создал собственную большую цель. CURRENT_COORDINATOR.json теперь active;
после отдельного GO сообщения все оставшиеся действия выполняет27.

Окончательный QA freeze (root сверил SHA):
`outputs/coordinator26_c4_47/qa/FREEZE_CURRENT47.json`
`2377a68c6a9d17a8c9dde3870a747eca375e59fff8c63c0c3c540f7d9afa1de0`.
Floor entry `floor_blast47_v2.gd`
`1d398954177016b50cc8d282dfcdb0e94f37158ec07a7075a0c69db03dfca6f7`;
рядом exactf405 и frozen9. Новый override только actualglass query с четырьмя
настоящими контактами; реальные перекладины не исключены из лучей. GPU,
`--out=<freshJSON>`,55s. Старые12manifestpins неизменны.
Perf `qa/perf_commonwall47/patch`3файла, entry
`60d86947a96e7caeed044759abda27368b3ac0aa306bd34b04a152adb24aec2b`.
120warmup, ≥240frames/2s idle, ≥600frames/5.3s damage, ≥6s recovery;
watchdog56/60s прежний, нехватка=INCOMPLETE. Staging/args в FREEZE.
Новые QA ещё не запускались; parser/native/perf PASS не заявлены.

Диспетчер подтвердил9отправок из10; originalАстра8 не загружается. Пользователь
прямо разрешил взять ЛЮБОЙ другой существующий свободный чат вместо неё.
Диспетчер уже получил указание немедленно использовать idle «Astra 8»
`6ab2d17d-76a8-83e9-965e-4c8033b0e66e`; при повторном сбое выбрать другой
свободный обычный чат, пока не будет10успешныхотправок. Не ждать пользователя,
не опрашивать original8, не дублировать активную9. Проверить фактический реестр.

Все документы/QA локально сохранены. HEAD035b195e7159bc12c1041a4b0af482e9e0fa4646.
ЧужойWIP сохранён. Пустой .git/index.lock mtime02.10.21:44:57 root26 не трогал:
рядом наблюдались appreadonlygit ls-files процессы. Перед scopedcommit сверить
свежие процессы/exclusiveaccess; подтверждённый stale lock только сохранить
перемещением, не удалять вслепую. AGENTS/AGENT_HUB уже содержали чужиеWIP —
не stage целиком без разбора. Передача не означает завершение всей миграции.

## Прямое поручение пользователя, 3 октября 2026

Пользователь разрешил большую цель полного переноса, непрерывную работу,
субагентов, постоянные задания десяти существующим Астра и автоматические
продолжения Координатор27/28 и далее при большом контексте. Старый координатор
должен прекратить работу и быть откреплён, новый закреплён первым.
Полный текст правил: `CONTINUOUS_MIGRATION_MANDATE_20261003.md`.

Важное уточнение: Астры — ОБЫЧНЫЕ ЧАТЫ, не Work. Передавать им самодостаточные
короткие фрагменты кода, контракты и вопросы; просить патчи текстом, ревью,
граничные сценарии. Не требовать локальный запуск, доступ к диску или Git.
Внедрять и проверять их предложения должны локальные рабочие агенты/root.

Текущий root и автоматизации записаны в `CURRENT_COORDINATOR.json`. Это имеет
приоритет над историческими записями26/25. Root26 прекращает production перед
созданием27; до отдельного GO новый чат читает эту передачу и готовит исходники.

## Принято и доступно пользователю

- Постоянный указатель `godot/current_version.json` всё ещё accepted45,
  `s01-20261001-palazzo-frames45`.
- Manifest `outputs/coordinator26_frames45/ASSEMBLY.json`, SHA
  `f797214092875a9e91cd47aa30cf751b99909f089d9b3b6bb8f4be34c6336b21`,473pins.
- Исправлены ложная опора оконных рам и оставшиеся статичные стекло/осколки
  при разрушении стены; дверь E по неподвижному проёму, оба направления.
- Среди зданий активен ТОЛЬКО Палаццо. Старые здания/скрытые коллизии не
  возвращать. Дороги/декор/водная геометрия/3 исходных NPC/авто сохранены.
- `PALAZZO_FRAMES45.md` и ACCEPTANCE: actual RPG/K/W/J61/0, дверь109/0,
  glass173/0; одинаковая сцена damage p95 10.096→10.457ms, peakWS+13MiB.
  Это текущий квартал, НЕ приёмка полного города/всех механик.
- Последняя обычная игра была открыта1октября03:28, PID43964. На3октября
  свежий inventory не нашёл Godot. Старые OPENED/PID исторические, перед
  действиями сверять процесс, start time, command line, window.
- User launcher `tools/godot/launch_current_game.ps1 -Quiet`, CheckOnly
  проверяет frozen pins. Desktop «Мафиози — актуальная версия» и sharedF5
  используют один pointer. Сохранять этот путь запуска.
- Engine4.7.2 в LOCALAPPDATA/MafioziTools/Godot-4.7.2, SHA
  `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`.
  Общий mutex `Local\MafioziUnifiedPreviewLaunch`. Не запускать второй движок.

## Ближайшее реальное внедрение: C4 candidate47

Root26 создал isolated source stage, не меняя accepted45/shared runtime:
`outputs/coordinator26_c4_47/ASSEMBLY.json`,484pins, SHA
`5c5b4455ee8f8b7f9d81766a4977974faf6482aaed15be9b82968f2d5786714f`.
Подготовка `prepare47.py` и PREPARED фиксируют exact45 + 12 owner resources:
поверхности/иконки/FX revision2, root main revision/5notes/export closure.
Нет car46, player/dive/pose44 или новых зданий.

Импорт3октября выполнен root: `outputs/coordinator26_frames45/runs/c4_47_import01`:
7.099s, exit0, stderr0,484source pins unchanged, до/после Godot inventory пуст.
Это только импорт, fullgame/native/perf/PCK/delivery ещё НЕ приняты.

Владелец Buildings3: `outputs/buildings3_c4_delivery45r2/DELIVERY.json`, SHA
`2f179163cf6cbd53db710b64556758b79b24ce2d46bb8682c86e3f5d95d3c5e7`.
Runtime typed Array[RID] + FXartv2 +2готовыхPNG; componentquery179/0.
Мощность960/радиус3.2, максимум8зарядов, bounded queue/pool.
NativeNPC/vehicleHP этим пакетом не заявляется. Отдельный artv3 НЕ подмешивать
без рендера/приёмки; runtime45r2 остаётся frozen.

Старая root floor QA f405/frozen9 наследует ошибку прицеливания в центр стекла,
где настоящая латунная перекладина. Owner исправил fixture-only revision3:
4 настоящие точки контакта, без обхода масок/коллайдеров. Source latest:
`outputs/buildings3_c4_surfaces45_revision3/visual/patch/` entry6b3c8e55…03e0,
рядом обязательный `test_c4.gd`12db538f…1b34. Старый standalone parent не запускать.
Root integration агент готовит отдельный `floor_blast47_v2.gd`, сохраняя
первыйf405. Перед запуском прочитать актуальные qa README/manifest.

Owner perf `outputs/buildings3_c4_input_perf45/revision2`: entry
206eb1462076848f85c6d90669ca0812596e69665104e6688a822c0d9bc26d65,
observerb4c6a0…53e25,parent12db. ActualQ/LMB/remote1или8, очереди/опоры/FX
должны завершиться, timeout=INCOMPLETE. Root готовит малый frame-minimum
overlay120warmup/240idle/600damage, сохраняя прежние временные нижние границы.
Использовать ОДИН и тот же frozen QA для baseline45 и candidate47,1/8 отдельно.
Не выдавать tinyFX performance за общую игровую сцену.

Runner `outputs/coordinator26_frames45/run45.py` принимает import/fixture,
`--assembly`, `--script`, `--gpu`, `--timeout` (fixture<=70s), `--extra`.
Логи создаёт под frames45/runs/<NEW_NAME>, существующие не перезаписывает.
Для C4 нужен `--extra=--out=<ABSOLUTE_RESULT_JSON>`; qa45-out не используется
этим owner fixture. Внешний runner сохраняет100msRSS/private; внутренний
watchdog55/60s сохраняет неполный результат. stdout И stderr проверить на
SCRIPT/SHADER/PARSE ERROR, потом содержательные assertions и изображения.

Первое действие после GO: выбрать окончательные новые QA, проверить pins,
один native floor/remote GPU прогон, просмотр PNG; исправлять реальные
проблемы у владельца. Затем сопоставимый loaded perf и export/PCK с PNG,
только после PASS promote/pointer/Что нового/scopedGit/одна обычная игра.
После приёмки вернуться к следующим механизмам из общего backlog.

## Car46 — второй ближайший пакет

`outputs/car_damage_20261001/current45/ASSEMBLY.json`: frozen runtime480
на exact45/473, прежний manifestd1238; QA сейчас меняет владелец, взять новый
SHA из штаба. Native и fullgameperf NOT_RUN. Не смешивать с47 до отдельных
прогонов. Owner «Быстрые введения»01a0f37d-8a6f-7560-a8a1-53fca08ba0e1.

Разрешена узкая QA-only поправка после независимого source review:
нормальная отдача меняет muzzle ДО accepted callback, поэтому равенство
pretrigger/acceptedorigin неверно. Нужны unchanged actor/life/item/equip/epoch,
nextpose/serial+1, accepted=actualcurrentmuzzle, прежняя реальная camera targetT,
actualballisticdir от recoilorigin кT, тот же выбранный engine surface,
реальный terminal, один патрон/один engine-onlydamage. Подробности:
`outputs/coordinator26_frames45/NEXT_CAR_REVIEW.md`. Engines владельцу НЕ
выданы. Начать будущую carQA одним bounded45sproof, после FAIL не продолжать
посадку/fullmatrix вслепую. Затем CHECK/smoke/tyre/crash/fullperf.

## Владельцы и десять Астра

Диспетчер всех10: «Продолжить работу Астра 1–10»
`01a0f2a3-81ab-7fe0-b1b1-c259c97818c6`. Уже получил прямое поручение
возобновить все10, читать реальные ответы, вкладывать исходники прямо в
сообщения, выдавать следующий полезный пакет и вести
`ASTRA_CONTINUOUS_DISPATCH_20261003.md`. Проверить фактические10отправок;
не считать поручение диспетчеру доказательством, что все10 уже работают.
Не создавать одноимённых замен Астрам и не будить старые11–14.

Действующие владельцы: Buildings3 `01a0f45b-ed29-7883-b93a-1d6daca19bae`;
NPC24 `01a0f291-6661-7430-bbd8-599c42c32c53`; Transport3
`01a0cb2d-d723-70c2-aa21-79f76a12481f`; Physics
`01a06e4d-e3ed-7f13-bda3-7fd677972336`. Отчёты в существующий штаб
`01a0df67-44d3-79c0-b243-fa6a9b891fde`. Остановленных25ираньше, Buildings2,
старых артистов и traversal01a087e2… не будить. Owner может получать новые
пользовательские поручения: сверять их перед решением о следующем scope.

## Продолжение, сохранение и честный статус

Созданы две ACTIVEheartbeat через API: `godot-4` — root каждые10мин,
`automation` — действующий диспетчер Астра каждые10мин. Первая должна
перейти к27 с полным сохранением полей; вторую не дублировать/не переносить
с диспетчера. Старые4pausedавтоматизации не включены. Включить большую цель
в27 по прямому поручению пользователя; цель26 при передаче приостановить,
НЕ отмечать полный перенос complete.

Repo shared, main с большим количеством ЧУЖИХ WIP/untracked. Не addall/reset/
stash/clean. Только проверенные scoped файлы. Последняя опубликованная база45:
224a3dbd implementation +035b195 followup (проверить свежий HEAD).
Существующие outputs accepted immutable; новые артефакты сохранять отдельно.
Source-only кандидаты не публиковать как принятую игру. До первого полного
внедрения27 остаётся указатель45. Сначала эти конкретные шаги, затем backlog;
не останавливаться на повторном общем аудите.
