# Координатор21 — актуальная память

## Новое поручение пользователя около00:50MSK

Добавлены к внедрению существующие закреплённые3/4/5: Transport3 (logicaltransport),
ФизикаАвтомобилей12-13 (nativephysics), Добавитьпрыжокиперелезание (nativetraversal).
Итого5 внедряющих сroot/Artist21. Прямые задания доставлены; Transport3 подтвердилстарт.
Пользователь ВЕРНУЛ общий штаб: Проверщик публикует там пакеты, все5 ихвнедряют.
Это отменяетзаглушение в старомразделениже. Канонические IDs/границы AGENT_HUB.md.
Новый запрос: постояннообновлять «Чтонового». /root/perf_acceptance делает новый
preview_update_panel.gd с Timer2s/stat, boundedJSON, revisionguard; main/data уroot.

## Актуально 27 сентября, 00:44 MSK — выше исторических записей ниже

Предыдущий turn дал progress: отдельная светлая клавиша E над реальной дверью,
45 проверок взаимодействия PASS и пользователь подтвердил «я проверил все ок».
Пользователь остановил Computer Use физическим Escape; управление окнами не
продолжать без нового основания. Он затем подтвердил замеченное выпрямление после
броска и прямо поручил исправить. Штаб по-прежнему заглушён; туда не писать.

Текущий свежий inventory: editor Godot4.7.2 PID6508, единственная игра из редактора
PID32648 (`--editor-pid 6508`). Release06/07 старые PID больше не актуальны.
Проект зарегистрирован в `%APPDATA%/Godot/projects.cfg`; новый helper
`tools/godot/register_project.gd` сохраняет другие записи. Editor autosave убрал
явные default settings: фактический renderer Forward+, physics60 сохраняются.

Готовый runtime: free mouse/wheel, источник прыжка/позы, удлинённый бросок Max Payne
1.25s до приземления / .45s восстановление после контакта, типография с физическими
дверями и интерьером, brick/concrete source finishes, волны/глубина воды, старт у
publicApproach, список изменений справа и floating `[E] Открыть/Закрыть дверь`.
Обычный прыжок .8s/1.05m сохранён. Source IDs/данные карты не менялись ради спавна.

Final player SHA13e3d83baa7648be5040bde64d1b899404bc2d7984aed22afe8b02b0c9b4db57:
исправлено зависание над полом при перепаде <2cm и один кадр стоячей позы до
физического контакта. Добавлена проверка overlap конечной точки permission capsule
.36m для тонких стен; body .30m не менялся. Три integration runs по6489 PASS,
independent101 PASS (все8 premature_recovery пусты), actual-main2 прыжка PASS.
Root legacy player PASS / обычный airborne231 PASS. Это CPU, не LIVE/FPS новой позы.

Export09 `exports/win64/s01-20260927-landing-fix09` содержит final13e3d83b и новую E.
Export08 содержал предыдущий e2a742 и НЕ окончательный pose fix. Export07 содержал
старый короткий бросок; его GPU-прогон нельзя выдавать за новый длинный бросок.
Открытая игра32648 запущена раньше final13e3d83b, обновление ещё требуется.

Настоящий native GPU QA воды07: OFF/ON/ON/OFF,1280x720,Forward+,GTX980,144fps cap,
600 кадров/окно после прогрева, p50 примерно6.94ms/p95 7.12–7.15ms,1507draw calls.
Примитивы235423→232393. Кадры воды/полёта/interior просмотрены, ошибок shaders нет.
Это квартал без NPC/машин под cap, не полный город и не доказательство ускорения.
Evidence `outputs/water_render_qa_07/report.json`; новый motion harness
`tools/godot/preview_motion_perf.gd` готов для единственного согласованного окна.

Текущие владельцы:
- Root: main/project/export, Git, одна игра, дальнейшая интеграция static batching.
- Художник21 сдал static helper53618a28:71+130+172452 CPU checks; runtime ещё не
  подключён, оценка179surface submissions не фактические GPU draw calls. Новое
  назначение — source NPC appearance/model bridge scripts/npc_visual, без births.
- /root/migration_next_package: native NavigationServer3D backend actual crop +
  printshop107 bodies; async bake/query lifecycle, version fences, physical admission.
  Main/реальные NPC ещё не подключены. Source reference planner/index10977 PASS
  остаётся отдельным пакетом, не заменяет встроенную навигацию новой ветки.
- /root/perf_acceptance и /root/airborne_integration завершили final player13e3d83b.
- Проверщик ЧАТОВ1-8 единственный lead14; batch08/09 сохранены в outputs/коллектор.

Открытые fidelity находки: A6 Godot не переносит source KHR_ior/specular у4hero
материалов; analytic F0 не доказательство pixel/BRDF parity, скаляр наугад не ставить.
Два source PointLights типографии также OPEN (near-distance attenuation mismatch).
A13 cash=0 mirror, concurrent robbery pending slot, conditional ID truncation —
source defects для отдельного владельца, не считать проверенной миграцией/backend.
NPC session authority/roster/agenda/commerce/save/полный город остаются OPEN.

Hourly scoped checkpoint готовится сейчас; предыдущий verified remote0c08e01e...
Не добавлять чужие Walk/server WIP или outputs. Старые ссылки/PID ниже — история.

26 сентября 2026. Чистая задача `01a0df60-f834-7e23-a846-00b47c48e0cc`.
Предыдущий goal turn дал реальный progress: perf подключён и проверен,
scoped checkpoint `0c08e01e844ca3ae88f9dacd02e49cad45104170` опубликован,
remote main сверён. Полный перенос не завершён.

## Последние прямые указания

- Продолжать полный перенос игры и сразу оптимизировать каждый пакет.
- Регулярно обновлять единственную видимую сцену готовыми изменениями:
  подготовить сборку, один последовательный restart, оставить игру открытой.
- Справа сверху список «Что нового и что попробовать», пункты 1/2/3.
  Root добавил `data/preview_updates.json` и панель в main; следующий экспорт.
- Мышь без ПКМ вращает камеру, колесо приближает/отдаляет. Root внедряет;
  независимый camera input test у airborne_integration.
- Макс Пейн обязателен. В source поздние параметры speed4.2/max3.36/apex.42,
  flight.8/recovery.45/secondSpace≤500ms; текущий release содержит обычный прыжок.
- Общий штаб пользователь заглушил ради токенов: больше туда не писать/не будить.
  Художник и Проверщик уведомлены; роли остаются прежними.

## Текущая живая игра

UPDATE около20:49UTC: единственная игра теперь **PID12540**, release
`s01-20260926-camera-notes06`, **session49876** не terminate.
Предыдущий2868 завершился сам/пользователем в20:46:51 с exitCode0;
причина не установлена. Root перед заменой подтвердил отсутствие процесса
и всех остальных release, запустил только новый06. Live viewport
`outputs/godot_release06_live.png` просмотрен: правильная панель сверху справа
с пунктами1–4, новая строка управления, герой/квартал видимы. Responding=true.
В06 свободная мышь/колесо3..16/EscTabClick и numberednotes. Независимый50checks
PASS, затем rootrerun50PASS, exportedPCK main/printshop/airbornePASS,38entries.
ФизическийOScapture/feel userinput не объявлен rootLIVEтестом.
Ниже прежний05 как история.

**PID2868**, release `godot/mafiozi_walk/exports/win64/s01-20260926-jump-interior05/`.
Lifetime shell **session67057**, не terminate. Старый43332 завершён корректным
CloseMainWindow по прямому указанию обновить сцену. Запущен только один visible
экземпляр, Responding=true. `outputs/godot_release05_lifetime.json`.
Root просмотрел фактический viewport `outputs/godot_release05_live.png`:
новый HUD «Типография открывается через E», герой и исходный квартал.
В этом release уже обычный airborne+printshop, но ещё НЕТ новой camera/notes/water.
Screenshot малой сцены не полноценная визуальная/перфприёмка интерьера/походки.

## Принятый код и доказательства

- Perf core48/async77/independent56 headless PASS, mainhook18OFF/18ON PASS.
- Airborne integration root независимо298checks/4physicscycles PASS,
  owned_pose CPU66/130µs p50/p95; full author4000×8338 skinPASS.
- Printshop main root независимо42headlessPASS: actualE, physical вход/выход,
  obstruction, exact24unmodifiedold +111newbodies. Admission5reject+valid PASS.
- Export05: 37PCK entries; все9runtime script payloads,6GLBimports,2JSON.
  Source selectedinputs unchanged. Actual exportedPCK admission PASS через
  console engine --main-pack: mainready, printshopready, airbornebound.
- Release templates здесь ИГНОРИРУЮТ внешний --script: два headlessprobe
  запустилиdefaultmain и не завершились, точечноостановлены поPID+path+headless.
  Не выдавать consoleengine --main-pack тест за executionreleaseEXE или егоFPS.
- Native OFF/ON/ON/OFF harness готовится у airborneagent; 4windows20checks
  protocolselftest PASS, GPU/LIVE overhead ещё OPEN.
- PathJobQueue: author7075checks/11375exactsourceoperations PASS; rootreview
  и mainNPCintegration ещё OPEN. SourceWIPworld.html неизменён, некоммититьего.
- Water material root47headlessPASS, factory exactsource shader; GPUcompiler
  и renderedparity ещё OPEN. Автор делает actualdepth/geometryhost.

## Владение

- Root: main/project/export/UI/camera controls/Git/LIVE.
- Художник21: preview_water_surface + exporter/data/tests; factory сдан.
- /root/perf_acceptance: теперь MaxPayne purepose/semantics+hostcontract,
  main/interior scope освобождён.
- /root/airborne_integration: camera tests + perf protocol doc correction,
  production player/locomotion уже освобождены.
- /root/migration_next_package: NPC first vertical slice source contract,
  queue runtime scope освобождён.
- Проверщик ЧАТОВ1-8 единственный lead14Astra. A8review очереди, не второйавтор.

## Экспорт и следующие шаги

Preset resources selected явно включает main и все literal runtime scripts,
а также GLB, которые main загружает из JSON: Godot не включил GDScript preloads
автоматически при первоначальном selected export03. Он НЕ показан пользователю.
Export04 прерван receiptcheck из-за независимого WIPnavigation изменения.
Exporter теперь хэширует только выбранные inputs и explicitJSON filters;
сохраняет unchangedgate. Добавлена проверка code/data/importpayload в PCK.
`launch_preview.ps1 -CheckOnly` распознаёт release, не создаётдубликат.
Новыеcamera/notes и прочие пакеты пока localWIP, следующий пользовательскийпоказ
после cameraheadless+сборки+проверки. Git обычно раз в час;0c08e01 был внеочередной
checkpoint по прямому поручению пользователя через20. Не add-all/reset/stash.
