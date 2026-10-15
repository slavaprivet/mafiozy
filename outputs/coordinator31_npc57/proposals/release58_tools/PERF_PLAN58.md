# Новая пара57→58 — подготовлена, не запущена

Текущий candidate — stage58_03 с интегрированным исправлением побега.
`RELEASE_PLAN58.partial.json` принимает только доказательства этой версии исходников.
Незаполненные soak/services/interruptions/perf роли остаются null/PENDING.
Функциональные проверки не заменяют FPS; старые stage02 receipts сохранены отдельно.

`run_perf58.py` использует неизменённый `qa31_resume/run_soak31_v4.py` и его реальный
V4 WINDOW протокол. Обе роли:10жителей+12сотрудников,1920×1080,20сек warmup+90сек
measurement, обычный RNG, idle10/30с, одинаковый фиксированный view. Никаких extras.
Baseline — frozen57/1130pins, candidate — stage58_03/1135pins. Оба manifest, F5,
engine/scheduler, reference camera и все helpers присутствуют в одном и том же
inventory обеих ролей. CPU-проверка обеих ролей:14 gates; актуальные source/control и common harness SHA
записываются в `PERF_CPU_CHECKS58.json`. Исторический stage02 результат сохранён отдельно.

Камера берётся из `qa31_resume/runs/baseline56_perf1080_03/MASS30.json` только как
геометрический reference, не как performance baseline. Её actual WINDOW/current/final
view уже сверены CPU. Новые обе роли обязаны совпасть с **полным** reference camera
dictionary на старте и конце, включая basis/position/FOV/clips/projection/rotation,
physical+logical output и window metadata. Одного совпадения положения недостаточно.

Default выполняет только точную CPU-сверку и один fresh read-only scheduler probe.
Проверенный dry-run обнаружил `perf_requires_idle_game` (пользовательская57) и активные
functional leases; движок не запускался. Даже при `--go` ineligible probe выходит до
V4 без ожидания. V4 дополнительно делает свой свежий probe, затем Lease и аудит
contamination во время/после процесса. Ни один пользовательский процесс не закрывается.

## Конкретные команды root

Из корня проекта, пока только dry-run:

```powershell
python -B outputs/coordinator31_npc57/proposals/release58_tools/run_perf58.py baseline57_perf1080_01 --role baseline --candidate-manifest outputs/coordinator31_npc57/extended31/stage58_03/CANDIDATE58.json
python -B outputs/coordinator31_npc57/proposals/release58_tools/run_perf58.py candidate58_perf1080_01 --role candidate --candidate-manifest outputs/coordinator31_npc57/extended31/stage58_03/CANDIDATE58.json
```

Root добавляет `--go` последовательно каждой команде только при освобождённой
пользовательской игре и завершённых functional проверках. Не редактировать controls,
tooling/source/reference между двумя ролями. При FAIL сохранить evidence; не повторять
в том же каталоге и не трактовать неуспешный baseline как доказательство выигрыша.

После двух чистых прогонов пересчитать12 исходных performance gates:

```powershell
python -B outputs/coordinator31_npc57/proposals/release58_tools/perf_compare58.py outputs/coordinator31_npc57/proposals/qa31_resume/runs/baseline57_perf1080_01 outputs/coordinator31_npc57/proposals/qa31_resume/runs/candidate58_perf1080_01
```

Пути результатов будут в неизменённом `qa31_resume/runs`. Внутри новых run папок
сохраняются исходные `RUN_NATIVE`, `HARNESS_NATIVE`, `CONTROL_PINS_NATIVE` и новый
полный transitive archive. Adapter может только понизить native PASS при drift,
несовпадении source/view или archive; `performance_accepted` всегда false до root review.
Release validator заново читает samples и пересчитывает gates, не доверяет одному PASS.

Read-only review `/root/godot_addons31` подтвердил полноту dependencies и отсутствие
обхода probe/source/view checks. Единственное замечание о mismatched runname/role
исправлено до CPU checks. Реальная производительность58 всё ещё не измерена.

## Исторические graphical receipts stage02

- `attention31_resume/runs/merged58_threat01`:81.961с,16проверок PASS.
- `attention31_resume/runs/merged58_visual01`:50.854с,11проверок PASS,5PNG.
- SOURCE before/after обоих равен stage58_02, stderr/errors/all drift0.
- `01_neutral.png` и `02_alert_facing.png` просмотрены: житель повернулся лицом к
  вооружённому игроку. HUD пока показывает presentation56, как и tested candidate;
  смена metadata на58 предусмотрена только при будущей freeze-копии.

Graphical lease после visual освобождён и передан QA для420с services. F5/Git,
пользовательская игра и source обоих проектов не менялись.

Stage03 требует новых attention02, services03 и двух service interruption receipts.
Ни один stage02 PASS не закрывает финальные gates после интеграции flee patch.
