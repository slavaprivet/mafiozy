# Guard wait / staged detour — isolated review, 23 September 2026

**NOT APPLIED. Four of six crowded scenarios resolved; two remain BLOCKED.**
This supersedes the paused `NPC_GUARD_WAIT_DETOUR23_WIP.md`. Root resumed this
assignment after the short LIVE surface-fix check. No runtime/authority edits.

**Later work deferred again for user walk/dive priority.** The diagnostic follow-up
found a two-segment geometric route for the remaining print-shop case. Its
candidate now reaches a safe staging point, then correctly rejects the next
segment from the source follower's actual earlier stop (`second-leg-blocked`).
The hospital case still returns `no-safe-two-leg-post`. Thus later results below
claiming both failures caused no movement describe the earlier reviewed version.
No guard has a fabricated final arrival and no runtime integration was performed.
Optional `--diagnose` writes `outputs/npc_guard_crowded23_diagnosis.json`; its
offline grid queries are explicitly outside the production-candidate budget.

## Bounded behavior

After the direct producer finds no connected exterior post, wait 1500 ms with
zero geometry queries. Then perform one direct retry. If still blocked, test
at most 12 intermediate bends. Retain caller-owned shared route admission:
96 callbacks per slice, 4096 across the whole job, cooperative deadline ≤2 ms,
30-second whole-job timeout. There is no hidden queue or per-frame retry loop.

Current owner/site/instance/revision/manifest and actor generation/context are
rechecked. Command cancellation, death, combat, vehicle/interior entry, owner or
revision change cancel the job. A planned final post carries a 12-second lease;
arrival, cancellation, conflict, obstruction or expiry releases it. The host must
atomically register/release those returned intents; this module owns no global
authority or reservation registry. At most 64 supplied local reservation/body
points may participate.

Expiration removes only a reservation intent, **never a physical body**. Callback
geometry remains authoritative even when another actor's reservation expired.
No safe route results in an explicit failure and retains the current position.

## Two actual physical legs

The existing guard follower stops a single leg up to .34 cells before its target.
Blindly appending a bend and final post would cut the corner. This candidate
therefore emits one staging leg first, waits for actual source movement to reach
it, and validates the next leg from the **actual stopped position**. Only the
second physical arrival is a post arrival. No teleport, exact-position snap,
guard-kind switch or production follower edit is used.

Both movement legs retain full static and current guard-body sweeps plus exterior
sampling. A separate optional `siteBodyClear` / `siteSweepClear` only proves that
the chosen post is connected to its existing entrance through fixed geometry.
That proof must preserve full building/body/water/ground tests; it excludes
transient guards whose current occupancy is checked on both actual movement legs.
Using transient guard bodies for entrance connectivity was an additional veto
even when the actor could physically walk around them.

## Tests and exact outcome

`node test_npc_guard_wait_detour23.mjs`:

- 20 lifecycle cases: query-free wait, cancelled/expired/stale-revision leases,
  owner/generation/death/combat/vehicle cancellation, source false-arrival refusal,
  conflict/movement-blocked release, no-admission and finite job expiry.
- Six recorded actual-geometry cases from
  `assets/maps/city_rebuild_v1/test_fixtures/native_guard_crowded23.json`.
- **4/6 physical arrivals**, 80 actual movement steps, zero blocked body sweeps,
  zero interior steps, no teleport. All four use two actual source single legs.
- **2/6 explicit `no-safe-two-leg-post`**, no movement: hospital slot1/step1 and
  print-shop slot2/step3. This does not prove geometric impossibility, only no
  accepted path in the bounded candidate set. Do not repeatedly restart unchanged
  failed jobs. Keep the valid post until a meaningful geometry/occupancy change.

The original exterior producer regression still passes: 33 contract checks,
36/36 solo arrivals and 30/36 occupied arrivals. Default callbacks are unchanged.

The first detour experiment retained the overly restrictive entrance occupancy
proof and resolved 0/6. The corrected proof resolves 4/6. Expanding the bend list
from 12 to 24 resolved no extra case and increased work, so it was reverted.

Recorded corrected run: total116.712 ms CPU for six entire jobs; per-job
8.511–41.917 ms spread over admitted slices, maxslice2.728 ms, max1824callbacks/job.
Cooperative deadlines can overrun by a callback/GC pause; hard callback limits
are checked. Waiting contributes no geometry work. These timings are not FPS or
a controlled baseline of the complete city. **Производительность общей сцены не
проверена.** Root controls the only LIVE/GPU window.

## Files and remaining boundary

- `npc_guard_wait_detour23_candidate.mjs`
- `test_npc_guard_wait_detour23.mjs`
- `outputs/npc_guard_wait_detour23_candidate.json`
- Optional fixed-geometry proof callbacks in `npc_exterior_guard_post23_candidate.mjs`

Still no runtime adapter, shared queue integration, live reservation registry,
moving-crowd acceptance or general guard behavior claim. Before integration root
must own lease commits, actual actor state, scheduler slices and continuous
movement collision checks. Two-leg READY is not total guard readiness.


## Поздняя read-only диагностика после production freeze

`outputs/npc_guard_exact_staging23_readonly.json`: print-shop путь физически
проходит при точном подходе к промежуточной точке в 15/7/5/3 Hz (4/4,0unsafe).
Подмена follower существовала только в памяти диагностического процесса;
production и кандидат не изменены. Обычный .34-cell ранний stop нарушает угол.

`outputs/npc_hospital_grid23_readonly.json`: у больницы неподвижная пара охраны
перекрывает проход в исследованной grid .15cell (4500 nodes). Исключение любого
одного guard body из отдельного контрфактического прогона открывает путь. Это
не доказательство невозможности обхода во всём городе.

Затем без исключения тел из движения проверено реальное уступание: guard2
проходит 3 обычных source шага к безопасному месту и останавливается
r7.3857506/c164.3159462; ожидающий guard проходит 15 шагов к посту, остаток .28518
cell, 0 небезопасных sweep/body/interior шагов. Использован существующий follower
с .34 ранней остановкой, без snap или нового kind. Поиск guard0 среди 96
локальных уступающих точек не помог. Эта диагностика превышает production-budget
и не импортируется runtime. Для внедрения нужен отдельный ограниченный контракт
уступания, очереди, leases и отмены двух акторов. Текущий кандидат всё ещё4/6.


Дополнительный rate-check: первое уступание .6cell не открывает проход при15Hz
(второе движение корректно запрещено,0unsafe), хотя работает7/5/3Hz. Тот же
отступ длиной .8cell работает в15/7/5/3Hz с существующим follower,0unsafe и
каждым шагом ≤speed×dt. Сохранено в
`outputs/npc_hospital_yield_rates23_readonly_0.8.json`. Это всё ещё read-only
физический эксперимент, не новый runtime-кандидат.
