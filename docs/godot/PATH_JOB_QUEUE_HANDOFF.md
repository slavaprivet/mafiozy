# PathJobQueue admission/cohort — передача Координатору21

26 сентября 2026. Runtime component implemented, native headless/source parity PASS. Не подключён к main; NPC, поиск геометрического маршрута и движение этим пакетом не внедрены. Одна живая игра PID43332/session9305 не затронута.

## Файлы и происхождение

- `godot/mafiozi_walk/scripts/navigation/path_job_queue.gd` — новый `RefCounted`, точный порт admission/cohort slice.
- `godot/mafiozi_walk/scripts/tests/test_path_job_queue.gd` — native Godot source-oracle parity, host negatives, ownership/ref bounds, CPU cost.
- `tools/godot/build_path_queue_oracle.cjs` — читает актуальный `world.html`, извлекает текст от `let _npcRouteWorkFrame=null` до `function _planNpcRouteTo(` и выполняет **сам source в Node vm**. Scheduler в JS не переписан. Пути разрешаются от местоположения generator, независимо от cwd; generator предназначен для Git.
- `outputs/coordinator21_next_package/oracle.json` — воспроизводимая fixture: операции и source results/snapshots/owner metrics.
- `outputs/coordinator21_next_package/headless_result.txt` — последний actual headless report.
- `outputs/coordinator21_next_package/REVIEW.md` — предыдущий bounded выбор этого пакета, не актуальный runtime acceptance record.

База HEAD `ff717ebf20293620e500b54d2deb30f4a940a6f9`. Source берётся из **локального WIP**, а не притворяется содержимым HEAD. `world.html` не изменялся/не коммитился этим автором.

SHA256 source bytes: `9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5`.
SHA256 exact extracted scheduler: `362c93b8f5b69ae3fa7d422ffae3c622323e332de427e45429883647170464d7`.

## API и host contract

```gdscript
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
var queue = Queue.new() # Time.get_ticks_usec(), native admission enabled
var job = Queue.Owner.new(source_id, life_generation)
# Before normal AI: host rejects dead/custody/panic/stale goal/life/chunk owners.
if queue.reserve(Engine.get_physics_frames(), job):
    # Existing planner performs resumable work, respecting queue.expired().
    # Host guarantees finish on every completion/error/early return path.
    queue.finish()
else:
    # PENDING only: keep reservations and continuation; do not infer NO_PATH.
    pass
# On replacement/unload/death/goal cancellation:
queue.cancel(job)
# On owner-host shutdown:
queue.dispose()
```

Это пример границ вызова, не реализация отсутствующего planner. GDScript не имеет finally: host должен построить единственный общий finish-путь и не yield/await между reserve и finish. Нельзя вложенно запускать planner поверх уже открытого slice. Source-compatible обработка забытых finish сохранена для parity и диагностики, но не является разрешением на reentry host.

Дополнительный конструктор `Queue.new(clock_usec_callable, native_enabled)` нужен для deterministic tests и source native-disabled branch. Clock возвращает monotonic nonnegative **integer microseconds**. Browser source использует milliseconds, oracle переводит результаты в целые microseconds; parity доказывается для microsecond-exact входов, не для submicrosecond browser timestamps.

`reserve(frame_id, Owner|null) -> bool`: admission only. Explicit frame_id должен быть одним и тем же во всех системах текущего frame. Anonymous reserve допускается только без ожидающих owners. `finish() -> bool`, `expired() -> bool`, `cancel(owner) -> bool`, `diagnostics() -> Dictionary`, `dispose() -> bool`.

Owner — один постоянный lightweight record **на source entity life/job owner**, не Node и не render instance. Identity очереди — object identity; source_id/life_generation доступны через getters, их backing fields являются внутренними. Не создавать новый record на каждый poll; новая жизнь получает новый record даже при совпадающем source_id. Один record не должен одновременно принадлежать нескольким queue instances. Host не мутирует внутренние identity fields и не хранит queue/scene tree в continuation. `continuation`, `search_pending`, `search_kind`, `request_at` — domain work state; cancel очищает все четыре, как `_cancelNpcDirectedSearch`. Это не `_clearNpcRoute`: готовый маршрут сюда не передаётся и не очищается.

`dead`, `empire_route_queued`, `empire_pending_route` синхронизирует source host до вызовов. Постоянный empire request exempt от stale expiry только при обоих true. Эта очередь сама не проверяет HP/authority/custody и не порождает stale completion callbacks. Freshness `{life, goal, world/chunk revision}` и проверка перед применением READY остаются у будущего planner adapter. Отменённый record host больше не опрашивает без нового валидного запроса.

Main-thread enforced. Вызов из worker не меняет очередь. API reentry во время clock callback отклоняется; `expired()` при запрещённом доступе возвращает true, чтобы не разрешать работу. Неверный/обратный clock отклоняется без изменения scheduler state. Clock callback не вызывает scheduler, не испускает signals и не освобождает владельца. Для production предпочтителен встроенный monotonic clock.

## Сохранённые semantics и явные source edges

- 8 admissions/frame, 4 ms **actual charged work**, а не wall time между независимыми поисками. Окно начинается на фактическом admission. Source caps cooperative: отдельный дорогой callback может превысить deadline. 4 ms не включают всю AI/геометрию/очередь и не являются FPS гарантией.
- Ordered dictionary сохраняет insertion order при repeated polling. Cohort до восьми старейших переносится между frames; один owner не обслуживается дважды в одном frame.
- Queue <=512. Source overflow удаляет самого старого ожидающего owner; dropped request больше не получает fairness guarantee. Batch временно может содержать ссылку уже вытесненного queue owner до source cleanup. Это сохранено, а не скрыто новой политикой admission.
- Strong references bounded: queue <=512, batch <=8, served <=8, current <=1, консервативно <=529 owner references (множества пересекаются). Размер объектов continuation этим не ограничен — он обязан быть bounded planner state. Нет registry, который бессрочно накапливает все когда-либо переданные owner IDs. `dispose` освобождает queue/cohort/served/current/clock; weakref test подтверждает освобождение всех records.
- Cancel удаляет queue/cohort и search fields, но **не current/served**. Завершение текущего slice ещё запишет его CPU; served запрещает повторный admission в том же frame. Ссылки исчезают при finish/frame change/dispose. Host вызывает finish перед длительной остановкой; dispose обязателен при завершении host.
- Same-frame reserve без предыдущего finish учитывает незавершённый elapsed. New-frame reserve сбрасывает незакрытый elapsed без начисления — это source edge, сохранённый exact fixture. Host обязан завершать slice до frame boundary.
- Stale cleanup выполняется один раз при начале нового frame; source dead-head cleanup дополнительно работает в текущем frame. **Dead owner не в голове уже существующего cohort может получить admission в том же frame**, если умер после frame cleanup. Это подтверждено exact source fixture `dead_nonhead_same_frame_source_edge`. Host немедленно отменяет смерть и никогда не просит admission для dead owner. Исправлять source policy следует отдельным согласованным изменением, не под видом port parity.
- Native-disabled reserve возвращает true без бюджета; запрет мёртвых/невалидных source owners всё равно является обязанностью host.
- `diagnostics()` копирует массивы labels и stats только по запросу. Это не покадровый renderer/report hook. Labels могут совпасть у разных generations; identity внутри очереди остаётся объектной.

## Проверки

Actual engine: `4.7.2.stable.official.ed1daf0bf`, headless, без GPU scene.

10 exact-source scenarios, 11 375 операций. Сравниваются все admission/expiry returns, точный порядок queue/cohort/served, deadlines/accounting/counters и все owner metrics; JSON float/int представление нормализуется рекурсивным числовым равенством **без tolerance**. Сам тест сверяет fixture SHA с актуальными байтами local Walk, поэтому старый oracle не даёт PASS после изменений source.

Сценарии: 16 forward/96 alternating owners, восемь дешёвых slices, same-frame double/anonymous reserve, 4 ms expiry/overshoot, unrelated CPU gap, cancel активного/queued owner, stale/persistent/dead cleanup, 540-owner overflow, unfinished same/new frame, dead new-frame and dead nonhead same-frame edges, native-disabled. Дополнительно: lifetime replacement при одинаковом ID, invalid identity/clock, reentry, worker denial, dispose/ref release. В CPU workload все 16/96/512 постоянно актуальных owners обслужены за 170 frames.

Финальный actual report: **7 075 checks, 0 failures, exit 0**, включая сверку SHA актуального source. Полные результаты находятся в `headless_result.txt`.

## Стоимость и оптимизация

Синтетический headless workload, ten warmup frames + 160 measured frames, injected search cost 1 ms; actual stopwatch измеряет только Godot queue calls, без поиска, NPC, geometry, renderer. Queue sizes max: 12/92/508 при 16/96/512 owners.

| Owners | CPU scheduler/frame p50 | p95 | max |
|---|---:|---:|---:|
| 16 | 70 us | 93 us | 133 us |
| 96 | 362 us | 533 us | 674 us |
| 512 | 2 013 us | 2 623 us | 3 299 us |

Это один actual run; desktop/shared нагрузка влияет на CPU. Метрики не являются общей frame time. При локальной разработке удалена аллокация `Dictionary.keys()` на каждом poll: `_head()` берёт первый insertion-ordered элемент итератором. На одинаковом раннем 100-frame workload при 512 owners p95 снизился **13 699 → 2 486 us**; exact-source parity осталась PASS. Текущая очередь при 512 polling owners сама стоит около 2 ms/frame, поэтому нельзя объявить её бесплатной или принять full-city бюджет по этому тесту.

Производительность общей сцены не проверена. Draw calls/triangles неприменимы к самостоятельному RefCounted модулю. Следующий host обязан измерить matching loaded scene p50/p95 и NPC queue age без второй GPU игры.

## Воспроизведение

Из корня shared проекта:

```powershell
node tools/godot/build_path_queue_oracle.cjs
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_path_job_queue.gd -- '--oracle=C:/Users/Слава/Desktop/Мафиози/outputs/coordinator21_next_package/oracle.json'
```

Генератор и runtime tests не меняют Walk. Oracle/report reproducible outputs можно регенерировать, production files не зависят от них. Ни main/project, ни airborne/interior/perf файлы не менялись. Lead14Astra/Astra8 получает пакет через root; сам автор другие чаты не открывал и задания не рассылал.
