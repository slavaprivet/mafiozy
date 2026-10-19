# K-редактор и жители текущей Godot-сцены — owner-пауза

Статус: контракт для Координатора22 и владельца `scripts/navigation`, **не
внедрён и не проверен в LIVE**. Рабочий `main.gd` SHA-256 на момент аудита:
`d2de587dfc0e109acb2a722ecc445080f89ddaaeacbaa10bd94d40c464f6b9a7`.
В нём `preview_residents_enabled=true`, население создаётся до `preview_ready`,
а `preview_population.step(delta)` вызывается каждый физический кадр.

Узкая последующая проверка на immutable checkpoint Координатора22 (preweapon
main `faac9219...`) прошла отдельно: Godot4.7.2 headless import и
`test_actual_host_pause.gd` exit0, 11/11 checks. Реальный printshop/nav host
принял begin→paused verify→resume и отверг изменённую цель двери. Stage receipt:
`outputs/map-editor-nav-checkpoint-tKefLl/source_snapshot.json`. Жители в этой
fixture были выключены; результат **не** покрывает `PreviewPopulation`, K в
обычной игре, полный город, GPU или LIVE. Требования owner API ниже остаются.

Одна `SceneTree.paused=true` остановит обычный `step`, но не является квитанцией
остановки навигации. `preview_engine_navigation.gd` запускает асинхронный
`bake_from_source_geometry_data_async` и `query_path`; их callbacks ставят
`_finish_bake`/`_finish_query` через `call_deferred`. Оба метода меняют состояние
карты, заданий и результатов независимо от очередного `population.step`.
`diagnostics.jobs == 0` не подходит как критерий: терминальные задания
сохраняются, а отложенный callback ещё не представлен таким счётчиком.

Минимальный безопасный owner API, согласуемый с root, а не подделываемый K-хостом:

1. `begin_editor_pause() -> receipt|refusal` на `PreviewPopulation` делегирует
   навигации и resident host. До общей паузы синхронно закрывает новые
   `request_walk`, `door_transition_started`, publish/bake/query и `step`;
   результаты уже запущенных callbacks либо удерживаются без изменений
   `_map`/`_jobs`/resident pose, либо вход отказывается до их завершения.
2. `verify_editor_pause(receipt)` связывает owner instance/session, lease,
   nav epoch, геометрию, access revision, map iteration, resident life/pose
   generation и состояние отложенных результатов. Каждое редактирование,
   импорт, сохранение, выход K и teardown обязаны проверять receipt.
3. `end_editor_pause(receipt)` одноразовый. После проверки ownership и нового
   source geometry он либо пропускает накопленные результаты через актуальную
   проверку iteration/life, либо помечает их stale и планирует свежий путь.
   Нельзя оставить жителя навсегда в `QUERY_WAIT` или освободить чужую lease.

Негативные native тесты владельца: вход при pending query и bake callback;
несколько кадров неизменности map RID/iteration/jobs, resident position,
velocity/gait; изменение door/source/lifetime во время паузы отклоняется;
устаревший/повторный receipt не освобождает новый; после resume ровно одна
публикация допустимого результата либо явный stale/replan, без застревания.
Затем Координатор22 проверяет тот же путь в одной настоящей игровой сцене.

Пока этих owner-квитанций нет, K-кандидат должен честно отказывать при
`preview_population != null`; отключать жителей ради зелёного теста не является
приёмкой пользовательского редактора.
