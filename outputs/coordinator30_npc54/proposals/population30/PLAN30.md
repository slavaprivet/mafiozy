# Population30 — восстановление всех сохранённых жителей

Каталог текущего города содержит **287 уникальных жителей**; исходный полный каталог — 288. `resident_15` отсутствует в уже закреплённом городском пакете из-за границы загруженной карты. Пакет `assets/npc_city/session_packet.json` SHA256 `b9c810e81b8b3da6afc048a32c4fe50745f32e4b15d0fd55ff876e69c35c54a1` сохраняется без изменений. `AUDIT30.json` фиксирует каждый source ID, bridge ID, descriptor SHA и хеш исходной строки. В этом конкретном пакете нет `empireBoss` и полиции; восстановление их исходной логики нельзя объявлять выполненным этим изменением. 12 сотрудников заведений считаются отдельно.

`--city-qa=1` выбирает одного жителя; отсутствие ограничения или значение 0 выбирает весь закреплённый городской пакет. `--city-qa=16/64/287` пригодны для этапов проверки. Имеющиеся `--city-early-cohort=N`, `--city-stream-ms=N`, порядок `dist|packet` и проверка видимости ограничивают только поступление новых тел, а не физический такт уже движущихся жителей. Источник placements, appearance и исходные identities остаются прежними.

Обнаружены два препятствия для простого снятия ограничения: прежний SingleLifecycle принимает только resident_1, а новые Simple-контроллеры физически двигаются внутри `life.step`. При `--city-daily-slice=286` для 287 записей выполнялось два опроса за кадр; один житель получал физический вызов примерно раз в144кадра. Увеличение delta не исправляет это: `move_and_slide` интегрирует текущий физический кадр.

Пакет меняет четыре файла, общую54 не трогает:

- Host сохраняет полный `_records`, но в каждом кадре обрабатывает только рабочий индекс: admitted body, corpse, pending cleanup/respawn. Admission, generation replacement, retaliation и ragdoll обновляют индекс. Финальное снятие тела освобождает request/retaliation/ragdoll/activity один раз. Поздний callback старой записи не снимает новую.
- Avoidance adapter строит дополнительную сетку16м из того же текущего снимка тел. Поиск соседей ограничен32результатами/128кандидатами, два фиксированных канала имеют по128единиц просмотра на физический кадр и сохраняют круговой курсор. Это только поиск кандидатов; никакой новой authority движения/урона.
- Population сопоставляет найденное тело с текущим health через словарь и проверяет полный существующий token. Никакого NPC×NPC поиска владельцев.
- Daily с новым `--city-physical-dispatch30=1` вызывает каждый активный physical/visit/attention/threat controller каждый физический кадр. Dormant decisions остаются в ограниченной очереди. Движение не выключается по дальности/видимости, delta не растягивается. Default OFF сохраняет54. Полная стоимость этого такта должна пройти проверку, а не скрываться уменьшением населения.

Root объединяет general lifecycle из `proposals/lifecycle30` и threat из `proposals/threat30` в coherent55. После этого последовательно:16,64,287 настоящих жителей плюс12staff. Для каждой ступени нужны ровно выбранные source IDs и appearance; все admitted жители имеют настоящий body/health/account/life; бытовые маршруты проходят door/staging/service/exit, услуги реально меняют HP/energy и деньги, saldo и число покупок сохраняются. Проверить госпитализацию после настоящего попадания, еду после истощения, снятие денег/покупки, лавки/случайную прогулку, освобождение claims при смерти и новое поколение с той же исходной личностью. Не использовать proxy-only проход как массовую приёмку.

Проверки нагрузки: ограниченные ring samples по кадрам, p50/p95/p99/максимум логики и render frametime; движение каждого активного controller на каждом кадре; время ожидания dormant decision; route queue jobs/nodes/heap и progress/retry counters; nodes/resources/objects/private bytes на одинаковом сроке после разогрева и после повторных death/respawn. Увеличение памяти нужно отделять от первоначального поступления жителей и кэшей. Финальный perf — отдельный scheduler `probe --mode perf`, затем exclusive lease на сопоставимую baseline/candidate пару при свободном игровом окне. Игра пользователя не закрывается.

Component QA использует уже существующую частную папку `route30/runs/city05/project`; новых полных копий нет. Это не coherent55 и не измерение FPS города. Все источники и точная fixture заморожены в run ZIP, есть pins до/после, child identity, scheduler lease. Старый component01 сохранился как честный FAIL ошибочного fixture target-source (он запрашивал medical door); component02/03 исправили стенд и прошли. Последняя проверка пакета указана в MANIFEST30.

## Interfaces для объединения

`host._active_track30(record)` вызывается после `_records[id]=record`; обычный `_admit_record` уже делает это. При замене поколения обязательно track новой exact dictionary. `active_records30()` — внутренняя read-only cached view; её нельзя менять внешним кодом.

`host._cleanup_removed30(record)->bool` — только окончательное cold removal после жизненного цикла. Он отвергает старую dictionary и живые corpse/respawn флаги `single_dead28`/`single_successor28`; lifecycle сначала завершает свою authority. Прежний corpse нельзя выбрасывать по нулевой collision layer или owner.dead.

`daily.wake_physical30(id)->bool` ставит текущий точный Life на следующий физический кадр. Использовать после нового admission/respawn и принятой угрозы. `daily.forget_physical30(id, exact_life)->bool` вызывается перед удалением старого Life; поздний callback не удаляет successor. Текущий single death путь уже подключён. Lifecycle владеет очисткой account/health/hit owner, daily activity/door/service claims и новым generation; этот индекс не заменяет её.

`life.threat_physics_active30()->bool` удерживает активную реакцию угрозы в физическом такте. Метод опционален; threat-owner добавляет его в Life.

`population.health_from_body30(body)->health|null` — точный lookup по metadata hint с existing target_current проверкой. `population.query_near30(origin, radius, max_results=8, max_scan=64, channel="perception")` возвращает `body, source_id, life_generation, position, health, token`. Radius0..64м, каналы только `perception`/`shot`. `health` — искомый current hit owner. Empty cell тоже расходует scan. Caller сохраняет необработанные shot events при исчерпании бюджета; выполняет актуальные LOS/aim и повторные generation guards перед действием.

`physical_dispatch_state30()`, `active_index_state30()`, `query_state30()` дают ограниченные counters, без растущих историй.

Применение: сначала `python -B apply30.py --project <candidate55>` для review, затем `--apply` под writer lease владельца. Exact base/candidate SHA проверяются, изменённые соседние участки сохраняются через уникальные контекстные hunks; конфликт требует явного review. После lifecycle/threat merge нужны повторный import и actualcity acceptance на единой source подписи.
