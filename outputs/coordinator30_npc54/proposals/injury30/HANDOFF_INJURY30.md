# Координатор30: ранение и удержание взглядом

## Подтверждённая причина в коде53a

`npc_daily_life.step()` вызывает `_attention29.step()` до проверки активной
больницы; при `true` немедленно возвращается. В `npc_attention29.step()` было
условие живой строки `hp > 0`, обычная hit/recoil-пауза и исключение тревоги,
но отсутствовал запрет удержания при медицинском приоритете.

`dsh_notice_damage()` действительно снимает внимание в синхронном обработчике
попадания. Однако после краткой физической реакции следующий кадр снова
разрешал взгляд, удерживал уже выбранный госпитальный маршрут и не давал
контроллеру больницы сделать шаг. Ожидаемое следствие — именно стоящий перед
игроком житель с12/60HP. Предыдущий native proof `attention_alarm53_01` проверял
только выстрел мимо и прямо содержит `no_hp_edit_or_hit: true`.

## Минимальная правка

Единственный production-файл:
`patch/scripts/npc_visual/npc_attention29.gd`; исходные/новые SHA — `PATCH.json`.
Дополнительный guard запрещает attention при low-health, необходимости больницы
или уже активной задаче больницы. Низкое здоровье проверяется независимо от
medical retry cooldown; активная больница блокирует взгляд вплоть до лечения
и физического выхода. Часы, HP, route target и очередь задач не меняются.

## Native проверка

`stage_and_run.py` создаёт отдельную копию frozen53a через scheduler write lease.
`observer_injury30.gd` начинает с полного здоровья без `--city-hp`, делает два
настоящих нажатия огня TT, проверяет совпадение shot/native owned terminal/health
receipt, наблюдает HP<50%, взгляд вблизи, взгляд в сторону, лечение и выход.
NPC не перемещается тестом; прямых HP-записей, подставных contact/hit receipts нет.
Все полученные результаты сохраняются отдельно, включая неуспешные прогоны.

Команды из корня проекта:

```powershell
python -B outputs/coordinator30_npc54/proposals/injury30/stage_and_run.py stage
python -B outputs/coordinator30_npc54/proposals/injury30/stage_and_run.py import import01
python -B outputs/coordinator30_npc54/proposals/injury30/stage_and_run.py run baseline02 --graphical
python -B outputs/coordinator30_npc54/proposals/injury30/stage_and_run.py patch
python -B outputs/coordinator30_npc54/proposals/injury30/stage_and_run.py run candidate01 --graphical
```

## Результат15октября

`runs/baseline02/INJURY30.json` воспроизвёл дефект: два настоящих попадания TT
снизилиHP60→36→12;303кадра подтверждённого взгляда,267кадров held при уже
освобождённом health/recoil gate. БольницаINBOUND и маршрутattention_paused.
После ударного смещения0.195м житель стоит. Это ожидаемый regressionFAIL,
не успешная игровая приёмка.

`runs/candidate01/INJURY30.json`:10проверокPASS, то же настоящее снижениеHPдо12;
131кадр подтверждённого близкого взгляда,0held,92кадра физического движения;
180кадров взгляда в сторону. Житель дошёл до больницы, прошёл лечение60/60,
физически вышел; production объявилhospital complete накадре2472.
Максимум1routejob/77nodes, выход0/0; schedulerexit0,stderr0,source drift0.

`runs/baseline01` — диагностическийheadless: попадания60→12реальны, но gaze
не подтверждается без графического mouse capture. Он сохранён какFAIL и не
используется для вывода о дефекте. Первоначальное ожидание scheduler остановлено
поtimeout доstaging; root позднее завершил чужой зависший тест по прямому
разрешению пользователя. Этот пакет чужих процессов не завершал.

Это функциональная проверка рядом с другими разрешённымиheadless тестами,
не сопоставимый замерFPS; `performance_accepted` остаётсяfalse.
Для итоговой объединённой сцены runner принимает только read-only override:
`run final54 --graphical --game <absolute-final-game-path>`.

## Смежная стоимость

В физическом планировщике jobs держатся WeakRef, ограничены бюджетами, а
`cancel()` освобождает job и массивы A*. У самого attention есть не более одного
route reference, который снимается clear(). Новый guard не создаёт запросов пути.
Root отдельно подтвердил дорогой полный поиск service_approach на68м и передал
его release_qa30; этот пакет не меняет long_route/simple_hospital и не утверждает,
что устранил общую просадку FPS либо доказал отсутствие всех утечек.
