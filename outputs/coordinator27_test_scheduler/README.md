# Общая очередь Godot-проверок

Готовый модуль: `tools/godot/test_scheduler.py`. Root GO для каждой functional проверки больше
не требуется. Старые frozen wrappers не изменены: владелец подключает Lease в новом адаптере,
сохраняя source/fixture/engine pins, assertions, логи и свой жёсткий timeout.

## Минимальная адаптация Python runner

```python
from tools.godot.test_scheduler import Lease

# Убрать внешние shared_slot()/exclusive() в НОВОМ адаптере.
# game — фактический canonical project directory, не путь к ASSEMBLY.json.
with Lease(mode="headless", project=game, access="read", wait_seconds=120) as lease:
    guard.full_pins(game, manifest["source_pins"])  # Повторить после ожидания.
    process = subprocess.Popen(command, cwd=game, stdout=stdout, stderr=stderr)
    child_identity = lease.register_child(process)  # Немедленно, до ожидания.
    process.wait(timeout=60)                       # Сохранить owner timeout.
    guard.full_pins(game, manifest["source_pins"])
    # Сохранить lease.request и child_identity в owner RUN.json.
```

При выходе по исключению Lease завершает только свой ещё живой Popen child. Foreign PID/name
никогда не служит целью terminate. Один child на Lease; для следующего нужна новая Lease.
`register_child` требует прямой дочерний процесс, argument list, единственный `--path`, совпадающий
с project, точные executable/command/creation time. Headless команда содержит `--headless` перед
разделителем `--`, без другого display driver. Не использовать console wrapper, запускающий grandchildren.

| Mode/access | Допуск |
|---|---|
| headless/read | До двух независимых functional процессов, в том числе рядом с пользовательской игрой |
| graphical/read | Одна общая graphical/input lane; headless могут работать параллельно |
| perf/read | Исключает все scheduled проверки и посторонние игры/диагностики; обычный editor разрешён с зафиксированной identity |
| любой/write | Staging/import/export исключает все другие leases ТОГО ЖЕ canonical project; другие проекты независимы |

Для `--editor --import --quit` нужен `mode="headless", access="write"`. Для CPU staging также
использовать write Lease на целевой project directory. Не запускать stage/import по read Lease.
Если пользовательский editor/game использует этот же project, writer ждёт: готовить отдельную QA copy.

Очередь FIFO для конфликтующих lanes/resources, wait ограничен 600 s (default120 s). Более ранний
writer не вытесняется новыми readers. Perf, заблокированный пользовательской игрой, не останавливает
functional очередь. Timeout ожидания ничего не закрывает. Orphan child не освобождает слот только
по истечению TTL: нужен фактический exit с проверкой creation time.

Headless child получает affinity на два доступных logical CPU; второй получает другие два при наличии.
Меняется только affinity дочернего процесса. Число Godot worker threads не подменяется; production
project/settings не правятся. Это функциональный режим с ограничением CPU, не сопоставимый perf run.

## Perf и пользовательский launcher

Perf runner должен вызывать `lease.audit_perf()` в своей polling-петле примерно раз в секунду
(CLI ниже делает это сам). При появлении игры/незарегистрированной диагностики или изменении
editor identity выставляется contamination; `__exit__` выбрасывает `PERF_CONTAMINATED`.
Сохранять `lease.request.editor_identities` и требовать равенство baseline/candidate. Это не оценка
FPS: `performance_accepted` остаётся false, полноценный comparator и owner acceptance обязательны.

Старый `Local\MafioziUnifiedPreviewLaunch` сохранён: новый модуль использует его как prelaunch bridge;
perf держит его до конца. Functional может сосуществовать с занятой пользовательской игрой только
при распознанном stable launcher bootstrap. Один editor сам по себе не разрешает обход занятого mutex.
Старые неприспособленные diagnostics по-прежнему блокируют запуск; их нужно перевести на новый API.

```powershell
python -B tools/godot/test_scheduler.py status --json
python -B tools/godot/test_scheduler.py coexist --json
```

Оба возвращают ASCII JSON, schema `mafiozi.test-scheduler.status/v1`, `registered_children`,
`coexist_pids`, `perf_active`, `active`, `pending`, свежую `inventory`, `performance_accepted:false`.
`coexist_pids` включает только живые зарегистрированные headless/graphical children, совпавшие
со свежей inventory. Строка child: `pid` (int), `creation_filetime` (decimal string Windows UTC FILETIME),
`command_line` (exact), `executable_path` (canonical absolute), `mode`, `project`, `lease_id`.
F5 дополнительно сверяет эти четыре identity поля со своей свежей inventory. Raw PID без сверки
не является разрешением. Status/coexist не берут preview mutex, не запускают engine и не меняют pointer.
State: `%LOCALAPPDATA%/MafioziTools/test_scheduler/state.json`; не править вручную. Private `_store`
предназначен только для CPU tests, не для независимых owner queues.

## Готовый CLI wrapper

```powershell
python -B tools/godot/test_scheduler.py run --mode headless --project <game> --timeout 60 --out <fresh-run> -- <absolute-Godot.exe> --headless --path <game> --script <fixture.gd> -- --out=<owner-result>
```

Он требует locked GUI engine из ENGINE_LOCK, новый output directory, сохраняет stdout/stderr и
SCHEDULER_RUN.json, проверяет exit/stderr/native errors и bounded timeout. Owner source pins и
семантический RESULT остаются обязанностью fixture/runner; «child execution passed» их не заменяет.

## Проверено

- CPU: `python -B tools/godot/test_test_scheduler.py -v` — 9 tests PASS,15,002 s,
  `CPU_TESTS.log`: реальные Python children с overlap/max2/третьим ожидающим, непересекающиеся affinity
  у перекрывающихся children, writer FIFO, отдельная graphical lane, PID reuse rejection, bounded wait,
  cleanup только своего child и обязательное исключение при perf contamination. Godot здесь не запускался.
- Отдельный root native run: `outputs/coordinator27_scheduler_native/run_20261003_045641/RESULT.json`
  passed=true, два headless Godot overlap17,8937266 s, оба exit0; affinity masks3/12, естественный exit.
  Реальный F5 predicate принял обе identity, editor сохранён, user_processes_closed=false.
  Это проверка scheduler; игровые фичи и performance не принимаются.

Frozen scheduler SHA256 `6f86204fdb510a9f3d850792891fc9902301ad68b5a67688080d0ac888c3cad9`.
CPU test SHA256 `dbcb789c9258c9c41a6ee6a673c53fa23e41ba6b79e8b8dac226904b32e7d8c9`.
