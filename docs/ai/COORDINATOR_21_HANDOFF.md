# Координатор21 — передача от Координатора20

Действующий чистый преемник: **Координатор 21**, `01a0df60-f834-7e23-a846-00b47c48e0cc`.
Сначала читать `COORDINATOR_21_START.md`. Промежуточный fork
`01a0df5c-6cff-7341-a3a5-b7f8b3d00f31` завершил передачу; чистая задача закреплена,
hourly automation перенаправлена. Общий каталог проекта сохранён.

Передача подтверждена самим21; inventory проверил pinnedIndex1 на прежнем месте20.
Automation walk-godot-14 target_thread_id=21, ACTIVE/hourly; prompt роли обновлены.
Проверщик и Художник получили ID21 и переводят готовые пакеты непосредственно ему.
Оба работающих субагента20 тоже получили ID для прямой сдачи21, без дублирования.
Этот handoff/AGENTS/board сохранены локально после20:05checkpoint, в следующий
hourly scoped Git save координатора21; не считать их уже наremoteff717eb.

26 сентября 2026, около 20:15 UTC. Пользователь разрешил создать и закрепить
преемника большого чата. Позднее прямое поручение: **Проверщик ЧАТОВ 1-8
управляет всеми 14 Astra**. Художник21 и координатор непосредственно внедряют
игру в Godot. Старые указания о Художнике21 как диспетчере отменены.

## Поручение и роли

Полностью, поэтапно перенести существующий Walk от третьего лица в Godot.
Сохранить модели, карту, идентичности, коллизии, механики, прогресс и серверные
правила. Не заменить игру показом моделей. Пользователь хочет постоянно видеть
одно живое окно Godot, проверять каждый переносимый участок и производительность.
Ему нравится новая плавность/физика. Обещать отсутствие всех лагов нельзя.

- Координатор21 наследует root: project/main, интеграция, LIVE, экспорт, Git.
- Проверщик ЧАТОВ 1-8: `01a0bbdc-edb1-7cc3-9cda-1160f3bc057b`, единственный
  диспетчер 14 Astra и сборщик полных пакетов. Получил базу, все 14 направлений,
  границы файлов, правила доставки и следующей волны. Сам не внедряет runtime.
  Его cwd — worktree b60d, актуальный shared путь ему сообщён отдельно.
- Художник 21: `01a0cb2d-a8ab-78e1-ba8e-3ef7915a2d71`, внедрение perf сейчас,
  затем конкретные согласованные игровые пакеты. Старый heartbeat21-14-astra
  больше не диспетчерский: переименован во внедрение Godot, ACTIVE10min,
  без назначения/мониторинга Astra. Dispatch/collection субагенты остановлены.
  Не дублировать рассылку. У Проверщика пользовательский npc-2 ACTIVE5min.
- Координатор20 `01a0bc08-cb3e-7181-be11-a53aaee54535` заканчивает только
  передачу двух уже работающих субагентов. Новые production правки не начинает.
- Старых художников, координаторов и browser-владельцев не будить.

Пользователь явно разрешил субагентов и просит занимать их постоянно. Четыре
слота включают root. Независимые задания с точными файлами, не параллельные правки
одного контроллера. Агентов нового координатора создавать лишь после проверки
непересечения с двумя завершающимися ниже.

## Путь, Git, сохранения

Shared проект: `C:/Users/Слава/Desktop/Мафиози`, PowerShell, danger-full-access.
Текущий main и проверенный remote main:
`ff717ebf20293620e500b54d2deb30f4a940a6f9`.
https://github.com/slavaprivet/mafiozy/commit/ff717ebf20293620e500b54d2deb30f4a940a6f9
Push и ls-remote совпали около20:05UTC. Сохранён 41 curated Godot/docs/tools файл.
Git index после commit пуст. Новый perf и следующие работы остаются WIP.

**Сохранять раз в час**, уточнил пользователь. Не каждую правку и не раз в чат.
Явный список своих проверенных файлов, scoped commit/push, проверка remote SHA.
Никакого add-all/reset/stash: в каталоге огромное количество старого чужого Walk
WIP. Сборки/кэши локальные и ignored; исходники, модели, сцены, тесты в GitHub.
Данные пользователей/секреты не брать. Пустые коммиты не делать.

## Единственный видимый Godot — не закрывать

На20:13UTC живой **PID43332**, `MafioziPreview.exe`, Responding ранее подтверждён.
Окно «Мафиози — перенос в Godot», standalone release:
`godot/mafiozi_walk/exports/win64/s01-20260926-review02/MafioziPreview.exe`.
**Exec session9305 держит WaitForExit: не terminate/не закрывать shell.**
`outputs/godot_release_lifetime26.json` содержит pid/start/exitCode:null.
При завершении та же оболочка запишет exitCode/время. Лог release пуст из-за
настроек вывода; пустой лог не доказательство отсутствия runtime ошибок.

Пользователь сам управляет игрой; Computer Use обнаруживал user input. Не
перехватывать управление для случайного скриншота. Кадр собственного viewport
`outputs/godot_release_live26.png` просмотрен root, это настоящая release сцена.
Два предыдущих Windows screenshot вызова падали SetIsBorderRequired0x80004002;
не выдумывать desktop capture. Для своего приложения допустима viewport QA.

Причина прежнего самозакрытия debug PID48888 НЕ установлена: он отсутствовал,
лог заканчивался успешным QA; найденный RADAR_PRE_LEAK64 не доказывает причину.
Новый release не назван исправлением причины или long-session PASS. Не запускать
вторую GPU игру. Для нужного обновления сначала подготовить проверенную сборку,
затем краткий последовательный перезапуск и немедленно вернуть окно. Пока
пользователь гуляет, интегрировать исходники без перезапуска после каждой правки.

## Движок и экспорт

Godot4.7.2.stable.official.ed1daf0bf:
`C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/`.
Exe GUI и `_console.exe`: `Godot_v4.7.2-stable_win64`.
Фактическое железо i9-10900F, GTX980 около4GB, RAM17113399296 bytes.
Официальные matching Windows debug/release templates установлены в
`%APPDATA%/Godot/export_templates/4.7.2.stable`.
Точные lock/SHA: docs/godot/ENGINE_LOCK.json, S01_EXPORT.md.
`tools/godot/export_preview.ps1` сверяет бинарники, экспорт и неизменность inputs.

review02 EXE109268480 bytes SHA
`d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562`;
PCK2379688 bytes SHA
`6748159a51e6524998378005d426dcc1ff34be5aff4e1d85c5dfbce61845c6f5`.
28 PCK entries, payload/import remaps проверены; 21 source/import inputs stable.
Двоичная повторяемость не доказана: review01/02 различаются UID cache.
Текущий release не содержит новый perf/airborne/interior WIP.

## Что перенесено и проверено

`godot/mafiozi_walk`: 8 настоящих зданий, 8 фонарей, 6 uniqueGLB, 27 исходных
внешних коллизий, 961 source cells (253road/114sidewalk/291grass/303water), герой
1.9m. NPC/трафик/экономика/интерьеры/сохранения/authority ещё не подключены.
WASD/arrows, Shift бег, Space обычный прыжок; RMB+mouse камера, Tab capture, Esc.
Water без floor; возврат ниже-12 — preview fallback, не игровое воскрешение.

Forward+1280×720/MSAA4, ACES white6, sun1.5/ambient.65. Physics60Hz.
Изолированный user dir MafioziGodotPreview. Mobile override не принят как профиль.
Compatibility реально давал белый пересвет тротуара, одно white6 его НЕ исправило.
Последующий реальный A/B подтвердил цвета Forward+/Mobile без перекраски GLB.
docs/godot/S01_RENDERER_COMPARISON_20260926.md. Сравнение vsync144 маленькой
статичной сцены не доказывает преимущество рендера по полной производительности.

Исходные surface shader: preview_surface_materials.gd, asphalt/paving/grass/sand
с source world coordinates и финальными Walk overrides; water detail ещё открыт.
43 headless material checks и настоящий GPU shader compile/render пройдены.

Hero8338 linear COLOR_0/7surfaces: включены vertex colors в4копиях материалов,
не менять пропорции/mesh/PBR. Исходный GLB имеет0clips.
preview_locomotion.gd: procedural exact hero_walk coefficients, actual body
horizontal movement, cached rig/rest/boot hull, visual sole contact, no physics
writes. 23rigtests/720poses,17controllerchecks,actualskin734vertices PASS.
Пока airborne поза blended rest, полноценная замена в отдельном агенте ниже.

preview_block_validation.gd проверяет schema/material descriptors и заранее
загружает PackedScene assets; main.gd готовит actual materials до3Dnodes.
50negativecases +5actualmain failures readyfalse/zero3D, затем valid16visuals/
27colliders; 961cell/62shoreedge/54ray checks пройдены. Не возвращать false READY.

`tools/godot/preview_motion_qa.gd` запускает настоящий main и Input actions,
не teleport. outputs/godot_motion26/motion_qa.json:11.9083m, walk/run/idle/jump
1.4239m/land PASS,6PNG просмотрены. 240 stationary frames p50/p95/p99
6.938/7.365/7.458ms,143.98FPS;966calls188166primitives. Это small debug scene
и programmatic input, не full game FPS/physical keyboard/release benchmark.
PNG/bone tracing outside stationary sample; motion trace содержит QA overhead.

## Ближайшая интеграция и непересекающиеся владельцы

1. Художник21 сейчас владеет scripts/perf/frame_recorder.gd,
   preview_perf_adapter.gd, scripts/tests/test_frame_recorder.gd,
   docs/godot/S01_FRAME_RECORDER_CONTRACT.md. Main hook root ещё НЕ добавлен.
   Author46checksPASS; независимые73actualGodot checks root:
   `outputs/perf_recorder_root_review26/REVIEW.md` и results.json.
   Старые проверенныеSHA core56c988dbae2cd3023d71589c892eaa11dc2803c5dcf5896da9b7eb33ea760171,
   adapter1b1d55bc3415e3f18db08240bf804e2b4595b219c08e1e45ff434b6cbe440e64.
   Теперь автор делает optional asyncJSON и marker total/overwritten counters;
   дождаться его новой сдачи/проверить, не назвать старыйreview проверкой новыхSHA.
   UPDATE20:17UTC: author уже добавил counters,48checksPASS; async candidate
   core4cc30a2b7b681c1177f6cfa403dd80ae2f10aef9b84d214ce5fa0234f6e101a0,
   adapter84d39fb251a89dc94b7834d63107737c8340921be97e6d2bbcb905e0aa810c7b,
   test625f770d6cc7f53babc78deadd8f23a55ad898ee1dc777c0d2f0c9c827de1029.
   API finish_capture_json_async/is_json_ready/take_json_result/pending_json_count,
   queuecap2. UPDATE20:20UTC: independent child77PASS/exit0/noerrors,
   outputs/astra21_async_perf_test/RESULT.md; testartifact SHA
   c37ebdf81dd24e31274e8a51b6f3faebc77b87c2eb926d5cc6ed9be0cc9c6f4f.
   Художник объявил пакет READY дляroot review/integration, LIVE всё ещёOPEN.
   OFF set_process(false), clock wallusec, bounded ring, fullwarmup, nearest rank,
   actual unknown GPUtime=null. Snapshot не для HUD.
   CPU record~.8/1.1µs(batchmeans), cold begin5.013ms/report9.560ms/JSON17.458ms —
   не frame FPS; asyncJSON ещё не убирает synchronous report cost.
   LIVE одинаковое OFF/ON/ON/OFF + independent wallclock, raw traces, no PNG/save
   inside measurement; обязательно остаётся OPEN. Сначала opt-in root hook.

2. Старый root subagent `/root/godot_player_preview` ACTIVE ограниченная работа:
   новые preview_airborne.gd, test_preview_airborne.gd,
   docs/godot/PREVIEW_AIRBORNE_CONTRACT.md. Exact hero_walk jumpPose(non-directional),
   .8flight/.45recovery source, no MaxPayne. bind(hero_root,visual_motion),
   sample(dt,grounded,vertical_velocity,base_poses,base_visual_offset,
   pose_authority,authority_epoch)->package; НЕ пишет Skeleton/body, host единый
   owner применяет package. No dt.1clip, actual grounded transition, reset on
   authority/epoch. Не менять main/controller hooks до интеграции root.
   Ему указано закончить только этот пакет и сохранить контракт. Не дублировать.

3. Старый root subagent `/root/godot_city_import` ACTIVE print_shop001 интерьер:
   tools/godot/export_preview_interior.py, scripts/preview_printshop_interior.gd,
   data/printshop_interior.json, scoped tests;
   docs/godot/PRINTSHOP_INTERIOR_HANDOFF.md — ожидается.
   Точный source GLB ad7b8ef7e7e4 → applyBuildingDoorsGlass →
   createWindowedBuildingEntry (building_entry_profiles/building_storeys/
   building_interior_design); native_print_shop_service_station.mjs stockroom.
   1этаж, print_hall/stockroom/manager_office, второй этаж запрещён источником.
   Экспортировать настоящее JS-generated CSG и изменённые mesh; attach(existing
   visual), не дублировать здание. Заменить только3коллизии print_shop001 indices
   0/1/2, остальные24 сохранить. Headless collisions/100doorcycles доhandoff.
   Экономика/продавец/lifecycle UNKNOWN, visual shader parity отдельно. Astra4
   только independent review, не второй runtime автор. Не дублировать.
   Промежуточно на20:20UTC экспорт1.92MB/22CSGoverrides/41generatedmeshes/
   103staticbodies/3rooms,831actualheadlesschecks включая100двухdoorcyclesPASS.
   Автор ещё доводит failclosedplacement и finalhandoff; в main пока не подключено.

4. Старый root `/root/godot_s00_inventory` perfreview ЗАВЕРШИЛ.
   Новую runtime работу не назначать ему из двух координаторов одновременно.

## Astra pipeline

Проверщику отправлены роли1perf review,2NPC/serviceFSM,3sourcevalidator,
4interiorreview,5regressions,6assetparity,7SaveStore,8PathJobQueue,9SeatRegistry,
10plan/gates,11rigreview,12chunklifecycle,13protocolauthority,14worldledger.
Полная прошлая передача: docs/godot/astra21_COORDINATION_HANDOFF_20260926.md.
Все14первых заданий доставлены; это НЕ14принятых пакетов. Следующие назначения
могли быть частично прерваны, проверить последние сообщения перед повтором.
Не читать14чатов самим, только через нового единственного lead.

1/2 были loadtimeouts. 4/6/7/12 тексты усечены20k, полныебайты не получены.
API cap20000: один полный codefile≤18000 в начале final, остальные отдельными
ответами. Sandbox link безбайтов/оборванныйcodeblock не пакет.
A9 частичный SeatRegistry10033bytes, docs/godot/astra21_SEAT_REGISTRY_REVIEW.md:
NO_GO staleeffects generation/session/seq, lifetimecaps/tombstones, authoritygates;
MODEL44928PASS не Godot compile/run. Не интегрировать автоматически.
A10 astra21_ASTRA10_RECEIVED_PARTIAL.md содержит все16этапов, gateJSON/36checks
ещё усечены. Поздние userразрешения переопределяют old noGodot/noagents/noGit,
но не отменяют честные quality/authority/perf stage gates.

## Сохранённый исходный Walk и открытые задачи

Старыйbaseline3612fa62f8d3bcb6888c7028ed0791fe0c928085.
S00 docs/godot/S00_BASELINE.md, tools/godot/capture_s00.py;
outputs/godot_s00_20260926_final/source_snapshot.zip SHA
509a6a4ffca16abe8b4dc0e309de775244f5865800c2e121e44ab0c4b2668daa,
711 verified entries. Actualhostsnapshot/heavyWalkbaseline OPEN; не читать
пользовательские базы/токены. Не считать topology полным collider inventory.

Старые желания сохраняются для дальнейших этапов: умные NPC/bosses/gangs,
наём/войны/охрана/штаб только из захваченного существующего здания; безопасный
crew catchup без воды/зданий/машин/занятыхмест, свободныесеаты/совместныйвыход,
X вавто высунуться/стрелять своиморужием поатакующим, убратьнамётки в машине,
E actionpriority+bold, crashseverity/взрыв убиваетвсехвнутриоднократно,
запугивание движущегося NPC, чёрныйтелефон сантенной, правильнаяпоходка,
не слишкомдальнийMaxPayne dive. Полныйmigration ledger должен это сохранять.
Oldhospital22CPU patch и gunproposal HOLD НЕ applied, paths в старой памяти.

## Автоматизация и коммуникация

`walk-godot-14` hourly heartbeat обновляется при передаче на нового координатора;
не создавать дубликат. Hourly отчёт/сохранение явное желание пользователя.
Продолжать одну задачу до полного переноса, не объявлять complete по кварталу.
Новая цель при необходимости в новом чате создаётся по прямому поручению
пользователя о непрерывном полном переносе; старая цель20 не была выполнена.
Отчёт различает код, настоящее наблюдение в игре, измерения, открытые вопросы.
Ruflo/ToolSearch не найдены, работать с файловой памятью, не выдумывать вызовы.

Обновить ID преемника в этом файле/AGENTS/памяти после создания. При переходе
не потерять живойrelease или shell9305. НовыеGPUпрогоны — только после фактического
inventory процесса и согласования работ, один экземпляр всегда.
