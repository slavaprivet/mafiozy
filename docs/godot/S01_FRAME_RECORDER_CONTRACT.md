# S01: frame recorder — внедрение Художника21

26 сентября 2026. Exclusive files согласованы с Координатором20. Реализация находится в Godot project; root подключает adapter к main. Main/project/player/surface/export не изменены автором. Это собственная реализация, не полученный пакет Astra1: его чат недоступен через приложение.

## Асинхронный JSON и потери маркеров — обновление

По замечанию независимого reviewer координатора добавлены events_total/events_retained_count/events_overwritten_count. Restart сбрасывает счётчики. Пустые labels не доказывают отсутствие события, если кольцо маркеров потеряло историю.

Основные48actualGodot checks PASS. Дополнительный независимый isolated пакет outputs/astra21_async_perf_test:77checks PASS,exit0,4 реально наблюдавшихся pending responses. Exact copied production core/adapter SHA указаны ниже; результат и границы в RESULT.md. Эти результаты не складывать с прежними73rootchecks как число уникальных сценариев.

Дополнительный API adapter (только main-thread callers):

```gdscript
var task_id := perf.finish_capture_json_async()
if task_id >= 0:
    # Позже: неблокирующая проверка, не spin-loop на главном потоке.
    if perf.is_json_ready(task_id):
        var result: Dictionary = perf.take_json_result(task_id)
        # result.ready / result.error / result.json; caller owns disk output.
```

Queue максимум2 незабранных задач. При заполнении finish_capture_json_async возвращает-1 и не останавливает/не теряет текущую запись. is_json_ready неизвестного/потреблённогоID=false; take_json_result для него ready=true,error=UNKNOWN_TASK. Pending ready=false без ожидания. Готовый результат потребляется один раз; completed task join освобождает handle. pending_json_count сообщает текущую длину очереди.

Worker RefCounted получает собственный immutable report DTO, выполняет только JSON.stringify и освобождает DTO после строки. Не обращается к Node/сцене/мониторам/файлам. Node exit останавливает capture и join-ит ограниченную очередь: shutdown может ждать. Обычный polling join-ит только уже completed задачу. Core report/copy/sort остаётся main-thread, около9ms при6000samples; только JSON около18ms вынесен в worker. Большой доверенный context не ограничен кольцом: передавать небольшие JSON-compatible metadata, не scene tree/wholeworld. Документация [WorkerThreadPool](https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html).

## Подключение

```gdscript
const PreviewPerfAdapter = preload("res://scripts/perf/preview_perf_adapter.gd")
var perf = PreviewPerfAdapter.new()
add_child(perf)
# OFF по умолчанию: set_process(false), нет callback за кадр.
perf.begin_capture({"capacity": 20000, "warmup_us": 5000000,
    "event_capacity": 128, "context": {"scenario": "quarter-motion", "source_sha": "...",
    "population": 0, "vehicles": 0, "camera_route": "...", "focus_policy": "..."}})
perf.mark_event("jump")
# После маршрута, вне измеряемой игровой нагрузки:
var report: Dictionary = perf.finish_capture()
# Сериализация/сохранение только по завершении, root владеет местом вывода.
```

API adapter/core: `begin_capture(config)->bool`, `snapshot()->Dictionary`, `finish_capture()->Dictionary`. Adapter дополнительно `mark_event(label)` и `is_capturing()`. Core RefCounted; timestamp даёт только adapter один раз в `_process`. Нет двойного update, изменений мира, disk IO или mesh/scene scans за кадр. Invalid config не сбрасывает текущую запись. Begin/restart создаёт новую запись; старую сначала сохранить через finish. Node выходящий из дерева останавливает запись. Не обновлять HUD через snapshot каждый кадр: snapshot копирует/сортирует данные.

Config: integer capacity1..100000 (default6000), warmup_us≥0 (default5s), event_capacity1..4096 (default128); context — небольшой доверенный JSON-compatible dictionary. Actual renderer, physics tick, engine cap/time scale, debug/headless, vsync и viewport size записывает adapter; он не выдумывает население, железо и маршрут.

## Семантика

Time.get_ticks_usec измеряет wall spacing основного цикла, а не GPU duration/presentation latency. Первый timestamp только якорь. Интервал, начавшийся до конца прогрева, полностью исключается. Отрицательное/повторное/обратное время отвергается без изменения якоря; реальные stalls не обрезаются. Pause/focus gaps не скрываются — отметить или держать одинаковую policy.

Ограниченное кольцо хранит последние capacity интервалов. p50/p95/p99 — nearest-rank ceil(p*N)-1 только для сохранённого окна, пустое окно=null. accepted_total/spikes_total относятся ко всей записи, overwritten_count явно сообщает потерю истории. Для60s@240Hz capacity20000 достаточно; требовать overwritten_count=0 для полного маршрута. Spike строго>50ms; события внутри интервала — временная связь, не доказательство причины. Маркеры ограничены своим кольцом.

Snapshot/report сортирует вне tick O(N logN), корреляция маркеров линейная O(N+E), без прежнего перебора всех маркеров для каждого spike. Begin выделяет кольцо заранее; snapshot/JSON/сохранение выполнять на границе диагностики, стоимость не скрывать в игровом hot path.

GPU frame time/unique scene triangles=null. Headless render counters=null. Положительные значения trackedvideo/staticmemory допустимы; неподдерживаемый/нулевой memory counter=null, не доказательство нулевой памяти. MEMORY_STATIC доступен debug, это engine-tracked, не OS RSS. Render primitives не уникальные triangles; point-in-time counters_at_report могут отставать до1s, не whole-run peaks.

## Проверено

Actual Godot4.7.2 ed1daf0bf headless, scripts/tests/test_frame_recorder.gd: **48 checks PASS**, exit0/no errors. Warmup crossing/ring/percentile/clock/events/spikes/mutation/stop/restart/JSON/invalid config/adapter OFF-ON-finish/metadata/marker-loss tested. No GPU окно не открывалось.

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_frame_recorder.gd -- --benchmark
```

Последний CPU microbenchmark:64 batches×1000 calls,10k warmup,74k accepted; контроль p50/p95 **0.057/0.093µs**, запись **0.806/0.948µs**, max batchmean1.164µs. Это процентили среднего CPU времени на вызов в пакетах, **не frame p95**, не общая сцена/FPS. Синтетические валидные timestamps, clock read присутствует в обоих циклах.

Дополнительно измерены операции вне tick при6000 retained samples: begin4.623ms, finish/report9.137ms, синхронный JSON stringify476182characters18.172ms. Это одиночный CPU замер, не p95. Snapshot/report нельзя вызывать в игровом HUD. Optional async API переносит именно JSON на worker; finish/report остаётся главным потоком и требует проверкиroot на границе диагностики. Эти затраты не спрятаны внутри стоимости записи; UI/whole-scene overhead OPEN.

SHA256:

- frame_recorder.gd:4cc30a2b7b681c1177f6cfa403dd80ae2f10aef9b84d214ce5fa0234f6e101a0
- preview_perf_adapter.gd:84d39fb251a89dc94b7834d63107737c8340921be97e6d2bbcb905e0aa810c7b
- test_frame_recorder.gd:625f770d6cc7f53babc78deadd8f23a55ad898ee1dc777c0d2f0c9c827de1029

## Согласованная проверка с координатором

Root подключает adapter в существственную единственную игру. Сравнить OFF/ON/ON/OFF по одному маршруту после одинакового5s прогрева: одна камера/renderer/разрешение/качество/vsync/население/машины/focus/event schedule. Нельзя сравнить oldCompatibility whiteprobe и новыйForward+ как overhead. Полная capacity, overwritten0. Record report только после окна. OFF стенд root измеряет тем же независимым wall clock; OFF не симулировать сохранением samples в наш collector.

Сопоставить raw traces p50/p95/p99, >50ms repeats, реальные событие-зависимые stalls и tracked counters. Измерить отдельно cold begin/finish/report/JSON, чтобы диагностическая пауза не исчезла из отчёта. Если overhead заметен — исправить до расширения игры; не уменьшать население/качество/коллизии. Headless PASS не закрывает LIVE overhead, Windows export или fullcity60fps1080p. Эти gates **OPEN**, root владеет живым прогоном.
