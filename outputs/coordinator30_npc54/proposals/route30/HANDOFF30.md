# Route30: длинные подходы к услугам, физический вход и ограничение поиска

Готовы три узких патча. Общая game54, launcher/F5, Git и пользовательские процессы этим агентом не менялись. Выбранные доказательства — `runs/hospital08` и `runs/local09`; их production SHA совпадают. Точные хеши и проверка применения — `MANIFEST30.json`, `BASELINE30.json`, `APPLY_CHECK.json`.

## Что исправлено

`npc_long_route28.gd`: обе проверки прежнего порога75м используют отдельный локальный предел; только `service_approach` получает24м. Обычные вызовы сохраняют75м. Используются прежние native map, authoritative queue и shared prepare budget. Новых владельцев навигации нет.

В реальном городе native карта старше геометрии клонов. Её checkpoint `(96,.1,0)` находился в Cornice30; даже найденная земля не давала стоять полной капсуле. Для service guide добавлен ограниченный ремонт промежуточных предложений: исходная точка и до32 кандидатов на радиусах1/2/4/6м, по одному кандидату на единицу существующей очереди. До предыдущего принятого checkpoint не более24м; проверяются native floor и полная стоящая капсула. Конечная цель не переносится. Все участки затем всё равно планирует и проходит прежний физический водитель; checkpoint не означает успешного прибытия. Слабая ссылка на физический водитель не удерживает его после удаления.

`npc_simple_hospital.gd`: service guard возвращает честный `blocked` после500000мкс суммарной работы локального поиска без прогресса,15000мс локального ожидания либо4000мс безуспешного движения. Допускается превышение на один неделимый шаг. Внутренний replan не сбрасывает накопленный бюджет; сброс требует реального продвижения0,25м. Attention/hold/dwell не считаются движением, native очередь имеет прежние собственные таймауты. Отказ освобождает route/guide и обнуляет X/Z скорость. Economy owner сохраняет pending purchase и свой retry8с.

`npc_restaurant_visit28.gd`: исходная проверка «внутри» использовала только сторону плоскости двери, поэтому далёкая улица за зданием ошибочно пропускала staging/outside/inner. Свежий приём теперь также требует измеренный AABB самого клона, уровень внутреннего пола и физическую опору. `needs_exit()` не требует выхода из далёкой улицы; после настоящего входа существующий `_entered` сохраняет authority выхода. База этого патча — версия game54 со staff, SHA `b904845f2710e8486020c35d8b6d57e2eb4b879f834715e11ccb1e7b7151a29a`. FIFO/service/staff gating сохранены.

## Проверенный результат

- `hospital08`:10/10 PASS, настоящий единственный resident_1, обычный daily owner,12 сотрудников, обычный флаг `--city-hp=20` (HP12/60). Начальная позиция `(136.338562,.003,-13.815775)` задаётся до medical begin. После begin переносов0; дополнительных тестовых NPC0. До комнаты68,63м; пройдено108,186м через staging, дверь, обслуживание врача и выход за65,869с. HP12→60 только при authoritative staff service; расстояние до врача0,283м. После выхода claims и service requests освобождены.
- `local09/service_guard30`:36/36 PASS. Реальная непроходимая native стена дала `blocked` при500287мкс, без ложного arrival; jobs/nodes/heap освобождены. Pending purchase/цена/деньги сохранены, retry8с проверен через настоящую economy ветку. Её life/account/outcome bridge явно тестовые. После удаления стены тот же actor физически дошёл до прежней цели. Attention pause/resume, первый кадр движения и24циклических отмены прошли.
- `local09/integration_fixture29`:17/17 PASS; unchanged regression очереди, движения, attention, смены native map, отмены и удаления тела. Часть прежних bound проверок использует явно указанные synthetic counters.
- `local09/daily_policy_fixture29`:10/10 PASS; unchanged daily policy/death hook и cooldown. Host/health/route — явно тестовые doubles, дополнительные286 тел не создаются.

Оба выбранных запуска: import0, stderr0, source drift0. Всего73 проверки. Короткий12с soak после больницы: residents1, nodes48023, resources4189 постоянны; objects98441–98558 возвращались после временного роста, static memory576,38–576,97MB. В конце native guides/inflight0 и local jobs/nodes/heap0. Сбор samples сам создаёт словари, а житель возобновляет другие занятия. Это функциональные counters, не долгий heap-leak/FPS acceptance.

`city07` — дополнительная капсула без владельца двери — физически прошла79,302м, затем честно остановилась перед больницей. Она не доказывает полный больничный цикл; такое доказательство даёт только hospital08. Старые FAIL и диагностика сохраняются. В hospital08 диагностический массив legs был сохранён по ссылке и в финальном JSON показывает поздние exit legs; bool check реально проверял4 начальных leg. Текущая копия fixture исправляет только снимок `.duplicate()`, production SHA не менялись. Точная запущенная fixture сохранена в source archive hospital08.

## Применение root после ревью

```powershell
python -B outputs/coordinator30_npc54/proposals/route30/apply30.py --project outputs/coordinator30_npc54/game
python -B outputs/coordinator30_npc54/proposals/route30/apply30.py --project outputs/coordinator30_npc54/game --apply
```

Первый вызов read-only. Все hunks и кандидатные SHA проверяются до первой записи; любой конфликт прекращает применение. Два точечных merge-фрагмента Simple сохраняют добавки avoidance в переменных и длинной диагностической строке. Проверенные итоговые SHA:

| Файл | SHA256 после merge со снимком root54 |
|---|---|
| npc_long_route28.gd | 49681adf8f9108d53e559172fe8963ea9e20b278e69b7a03af3dae4015f78c54 |
| npc_simple_hospital.gd | d0fc9ec4bac901225322c9b9e1d4a7ace18bf6a79b72ea82adf1221d52b9653a |
| npc_restaurant_visit28.gd | 177c6fb11c322e09047f8b77962cad530fc63999c28f152c694556f53f3a760a |

Снимок `INTEGRATION_BASE30.json/.zip` получен под read lease:1109pins,20delta к frozen53a. Он содержит staff+injury+avoidance+revision/news54, но не последующее ambient объединение. Root после merge обязан выполнить import и relevant fixtures на общей54; отдельные результаты не подтверждают последующее объединение. Обычные launch flags и freeze/ordinary smoke описаны в `outputs/coordinator30_npc54/qa_plan30.md`.

## Воспроизведение без новой полной копии города

```powershell
python -B outputs/coordinator30_npc54/proposals/route30/run_native30.py UNIQUE --cases local --staged-project outputs/coordinator30_npc54/proposals/route30/runs/city05/project
python -B outputs/coordinator30_npc54/proposals/route30/run_native30.py OTHER_UNIQUE --cases hospital --staged-project outputs/coordinator30_npc54/proposals/route30/runs/city05/project
```

Runner проверяет1098 frozen53a pins и интеграционный ZIP, берёт scheduler write lease для своей reusable staging, накладывает только точные snapshot/patch/QA файлы, импортирует и фиксирует полный SOURCE. Для каждого завершённого запуска сохраняются receipt, результаты, `CHANGED_SOURCES.zip` и `RECONSTRUCTION.json`; они восстанавливают точный запуск поверх immutable53a без сохранения новой полной копии. Одновременно один private stage не использовать. Все тесты functional headless; performance_accepted=false. Ничьи внешние процессы не закрываются.

Active-record index не включён: host loop287 записей также выполняет retaliation/ragdoll/navrequest/generation cleanup. Ранний `body == null` skip потеряет cleanup. Отдельный индекс требует admission896, respawn616/632, removal1351/1394, disposal2103, transport hooks и death/respawn coverage. Число жителей и геометрия не уменьшались.

Во время заполнения диска автоматическая проверка дважды отклонила удаление только собственных завершённых cache каталогов с причиной `blocked by policy`; удаления не выполнены. Дальнейшие прогоны используют один private stage. Доказательства и исходники сохранены.
