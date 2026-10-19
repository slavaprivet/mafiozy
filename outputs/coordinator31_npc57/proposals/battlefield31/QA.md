# Приёмка боевого поля 31

Проверяется общая сцена `res://scenes/castle.tscn` с замком в `(0, 0, 900)`.
Координаты в таблицах ниже локальны относительно замка: ворота около `z=68`,
поле занимает примерно `x=-90…90`, `z=82…250`. Скрипты QA лежат отдельно в
`game/scripts/tests/dsh_battlefield_*.gd`; исходники сцены они не меняют.

## Функциональные ворота

1. Ворота открываются штатной функцией. Капсула игрока проходит из замка к
   дороге и далее к стороне атакующих. Пробники проверяют высоту ног и груди,
   не полагаются только на луч по поверхности.
2. Тот же тип капсулы проходит от центральной дороги к левому и правому
   флангу. Отдельные позиции в лагере доступны с центрального входа.
   Помимо неподвижных запросов, `dsh_battlefield_player_walk31.gd` проводит
   настоящий `PlayerController` штатным вводом от старой дороги (`z=96`)
   к лагерю (`z=224`) и к флангам (`x=±48,z=156`). Фиксирует реальные кадры
   `is_on_floor`, высоту стоп относительно рельефа, провал, скачок по вертикали,
   затор и достижение цели. Перемещение каждый кадр выполняет сама игра.
3. Деревья, повозки, валуны и тяжёлые заграждения имеют настоящие коллизии;
   небольшие пучки травы не получают отдельную дорогую физическую форму.
4. Центр дороги не перекрыт травой, ветками и невидимыми мешами. На стыке
   старой дороги и нового поля нет зелёной полосы или ступени.
5. Число объектов и draw calls логируется для трёх одинаковых ракурсов:
   ворота, центральное поле, фланг. Расход памяти/примитивов и время создания
   сцены также фиксируются. Границы приёмки определяются относительно
   замка **в той же сборке и тех же условиях**: падение каждого ракурса >15%
   не проходит текущий gate, а 90 FPS остаётся абсолютным целевым уровнем.

## Условия измерения

- Функциональные Godot проверки используют очередь
  `tools/godot/test_scheduler.py` и отдельную копию игры на `D:\MafioziCombat31`.
  Графический FPS прогон выполняется в эксклюзивном perf окне без игрового
  окна пользователя и без одновременных проверок DeepSeek/координатора.
- Размер окна, рендерер, разрешение, vsync, качество теней и ракурсы обязаны
  быть одинаковыми. Для FPS отключается vsync и снимаются как FPS, так и p95.
- Результат `PASS` требует отсутствия ошибок Godot в журнале. Статические
  счётчики без физического прохода или реального графического запуска не
  закрывают приёмку.
- При блокировке очереди или нехватке места записывается `PENDING`, а не
  искусственный `PASS`. Пользовательскую игру и чужие процессы не закрывать.

## Текущее состояние проверки — checkpoint `1fa47168`

Точная копия опубликованного `origin/main` находится в
`D:\MafioziCombat31\battlefield_publish\outputs\coordinator31_npc57\game`.
Функциональные проверки на этой копии завершились `exit0/stderr0`:

| Проверка | Итог | Лог на D: |
|---|---|---|
| Import после QA parser fix | PASS | `battlefield_qa\run_publish_import02` |
| Terrain capsule/ground, 237 проб | PASS, blocked/steep/no_ground 0 | `battlefield_qa\run_terrain04` |
| Настоящий PlayerController: центр z96→223, фланги x±48,z156 | PASS, grounded 100%, stalls 0 | `battlefield_qa\run_player_walk03` |
| Настоящий PlayerController вне дорог, насыпь x20,z112→140 | PASS, 518 ticks, grounded 100%, stalls 0, max step 0.0098 м | `battlefield_qa\run_berm_walk01` |
| Ворота/дорога/фланги capsule r0.38 h1.72 | PASS, 1136 клеток, blocked 0 | `battlefield_qa\run_routes04` |
| Декор и повреждения | PASS, 16 mesh, 36 MultiMesh, 1358 instances, 64 colliders, 48 covers; grass-on-road 0; cover после stone hit разрушен | `battlefield_qa\run_geometry04` |

Статический gate probe учитывает существующий `GateOuterApron`: его поверхность
на `y≈0.08`, поэтому низ тестовой капсулы размещён на `y≈0.16`. Первое
ложное срабатывание на полу сохранено в `run_routes03`. Исходники карты не
менялись ради проверки.

Графические кадры `visual_publish02` сняты из общей сцены на высоте игрока
при z155 и z215, а также с ~15 м от палатки и телеги. Технически screenshot
PASS, визуально **FAIL**: центр поля слишком пуст, палатка выглядит плоской,
колёса телеги кажутся оторванными от грунта. Кадры:
`D:\MafioziCombat31\battlefield_qa\visual_publish02\battlefield_*.png`.

Первое paired измерение на чистой perf lane (1280×720, vsync off) дало
**raw FAIL** по относительным потерям, хотя абсолютный FPS >90:

| Ракурс | Замок, FPS | С полем, FPS | Потеря | Draw calls |
|---|---:|---:|---:|---:|
| Ворота | 399.9 | 329.9 | 17.52% | 34.8→132 |
| Центр | 416.0 | 346.7 | 16.66% | 21→85 |
| Фланг | 399.9 | 309.1 | 22.69% | 55→154 |

Raw лог: `D:\MafioziCombat31\battlefield_qa\run_perf01\stdout.log`;
receipt подтверждает `perf_environment_clean=true`, `exit1/stderr0`.
Визуальный и perf gate требуют второго прохода; после него повторить все
четыре функциональные проверки на новом source pin.

## Второй визуальный проход — кандидат

На terrain SHA `4C7195DA` и props SHA `756D98ED` повторён import
(`run_publish_import04`, PASS), грунт (`run_terrain05`, PASS 237/237,
9 terrain chunks/9 draw max), ворота/три маршрута (`run_routes06`, PASS),
декор (`run_geometry06`, PASS: 9 meshes, 18 MultiMesh, 1642 instances,
65 colliders, 56 covers, grass-on-road 0, разрушение cover PASS).
`run_player_walk04` PASS на настоящем персонаже: центр, оба фланга и
поперечная насыпь x20,z112→140, grounded 100%, stalls 0, максимальный
вертикальный шаг 0.0126 м, ошибка уровня стоп −0.062…+0.037 м.

Новые кадры: `D:\MafioziCombat31\battlefield_qa\visual_publish03\battlefield_*.png`.
Геометрия палатки теперь узнаваемая A-frame, колёса телеги круглые и у
земли, ограждения видны в масштабе игрока. Центральная полоса между ними
остаётся бедной деталями относительно стены замка.

Второй paired FPS на чистой perf lane снова дал **raw FAIL** по порогу 15%:

| Ракурс | Замок, FPS | С полем, FPS | Потеря | Draw calls |
|---|---:|---:|---:|---:|
| Ворота | 391.3 | 326.4 | 16.58% | 34.7→68 |
| Центр | 419.6 | 336.9 | 19.71% | 21→45 |
| Фланг | 401.2 | 322.7 | 19.58% | 55→95 |

В сравнении с первым проходом draw calls поля сократились примерно вдвое,
но относительная потеря FPS всё ещё выше заданного порога. Raw лог:
`D:\MafioziCombat31\battlefield_qa\run_perf02\stdout.log`, receipt
`perf_environment_clean=true`, `exit1/stderr0`. Абсолютно FPS >90 во всех
ракурсах. Дальнейшая оценка качества сцены принадлежит root и пользователю.

### Разложение стоимости второго прохода

`dsh_battlefield_attribution31.gd` на том же field ракурсе измерил четыре
состояния в зеркальном порядке `none→terrain→props→all→all→props→terrain→none`.
Каждое измерение длилось 2.5 с; perf lane была чистой, exit0/stderr0.

| Видимо | FPS | Средний кадр | p95 | Draw calls |
|---|---:|---:|---:|---:|
| Ничего | 415.0 | 2.409 мс | 3.214 мс | 20.9 |
| Только рельеф | 361.4 | 2.767 мс | 3.700 мс | 27 |
| Только реквизит | 375.9 | 2.661 мс | 3.575 мс | 39 |
| Всё поле | 331.6 | 3.015 мс | 3.919 мс | 45 |

Рельеф добавляет 0.358 мс, реквизит 0.251 мс к 0.606 мс полной добавки;
эффекты близки к сумме. Примерно 59% стоимости поля приходится на рельеф,
41% на реквизит в этом ракурсе. Raw:
`D:\MafioziCombat31\battlefield_qa\run_attribution01\stdout.log`.

### Материал рельефа A/B/C

Три варианта сравнены на одной изолированной полной копии игры
`D:\MafioziCombat31\battlefield_attr_ab\game` с неизменным реквизитом SHA
`85EC466A` и одним ракурсом. Для каждого записаны import PASS, clean perf
receipt и source SHA; для A/B/C дополнительно кадр с высоты игрока на z155.

| Вариант рельефа | Его стоимость относительно none | Всё поле, FPS | Потеря |
|---|---:|---:|---:|
| Baseline SHA4C7195, texture + fragment shading | +0.366 мс | 332.7 | 19.83% |
| A SHA72819E, texture убрана | +0.375 мс | 332.9 | 20.08% |
| B SHA3635F5, per-vertex без texture | +0.030 мс | 373.4 | 10.28% |
| C SHA4078D6, per-vertex с texture | +0.041 мс | 370.6 | 10.98% |

Вариант C выбран для интеграции: фактура земли сохранена, стоимость рельефа
снизилась примерно на 0.325 мс. Сравнение относится только к этой D копии
и props85EC; его нельзя напрямую смешивать с предыдущими замерами props756D.
Raw и точные pins: `D:\MafioziCombat31\battlefield_qa\run_ab_*\{stdout.log,SOURCE_PINS.json}`;
скриншоты `D:\MafioziCombat31\battlefield_qa\ab_visual_{A,B,C}`.

## Отчёт

### Третий визуальный проход и точная физическая приёмка

Общая сцена на world-baked terrain SHA `2B8D737C` и props SHA `B8BF6C43`
импортируется и проходит геометрию/три прохода; скриншоты после удаления
белых штрихов и воздушных камней:
`D:\MafioziCombat31\battlefield_qa\visual_final02\battlefield_*.png`.
На версии props `E7287F03` (временное объединение grass и box batches)
проверка `run_candidate_geometry01` подтвердила 344 настоящие травинки по
индивидуальным индексам, ни одной на дороге, 68 крупных укрытий и освобождение
коллизии после разрушения камнем. Настоящий PlayerController прошёл центр,
оба фланга и поперечную насыпь: `run_candidate_walk01`, exit0/stderr0,
grounded 100%, stalls 0, max vertical tick 0.0126 м, max feet error 0.037 м.
Полная физическая проверка не использовала отключение коллизий и достигла
высоты 1.208 м на насыпи.

Clean 1280×720 paired FPS на B8 дал raw FAIL только у ворот: 400.84→340.29
FPS, −15.105% при пороге 15%; центр −12.24%, фланг −11.23%. Повтор ABBA
`run_final_gate_repeat01` подтвердил ворота 403.80→340.70 FPS, −15.628%.
1920×1080 `run_final_perf1920` PASS во всех трёх ракурсах: ворота
200.40→181.38 (−9.49%), центр 206.66→192.30 (−6.95%), фланг
202.90→187.99 (−7.35%), clean receipt, stderr0. Порог 1280 **не снижен**.
Разложение у ворот `run_final_gate_attribution01`: hidden 2.456 мс,
terrain-only 2.607 мс (+0.151), props-only 2.827 мс (+0.372),
all 2.950 мс (+0.494). На этом ракурсе реквизит даёт около 75% добавки.

Объединённый grass batch E728 уменьшил число draw calls 65→63, но чистый
ABBA `run_candidate_gate_perf01` дал raw FAIL 402.30→334.39 FPS,
−16.879%; этот вариант не принимается по perf. Следующий точечный вариант
props `FDB301E7` сохраняет отдельную траву и отключает тени только у колёс.
Import `run_fdb_import01`, geometry `run_fdb_geometry01` (344 grass,
0 на дороге), визуальный `run_fdb_visual01` PASS. Чистый gate ABBA
`run_fdb_gate_perf02`: 406.80→339.91 FPS, −16.443%, 60 draw calls;
raw FAIL по порогу15%, exit1/stderr0.
Первый запрос на FDB FPS отменён **до запуска Godot**, чтобы пропустить
функциональную проверку координатора. Причина сохранена в
`D:\MafioziCombat31\battlefield_qa\run_fdb_gate_perf01\CANCELLED_PENDING.txt`;
это не результат измерения и не PASS/FAIL FDB FPS.

Grass visibility 95 м `00DDCC79` также import/geometry/player z155 PASS,
но `run_00dd_gate_perf01` дал raw FAIL: 408.83→338.33 FPS, −17.245%,
64 draw calls. Все три микрооптимизации batch/тени/LOD проверены на чистой
perf lane; уменьшение draw calls само по себе не обеспечило нужный FPS.
Материал props `DFAB90ECF42DB99DCDED008F18F836C436552EFCEF2EDFC3FF7ACCB96BF455BC`
(per-vertex lighting на общих batch materials) выбран как финальный кандидат.
Import `run_dfab_import01` PASS, снимок игрока `visual_dfab01` сохранён;
декор чуть темнее, силуэты ограждений, телег и вышек читаются.

| DFAB, разрешение/ракурс | Замок FPS | С полем FPS | Потеря | p95 поля |
|---|---:|---:|---:|---:|
| 1280×720, ворота | 402.83 | 349.87 | 13.148% | 3.803 мс |
| 1280×720, центр | 416.18 | 377.98 | 9.179% | 3.572 мс |
| 1280×720, фланг | 399.74 | 358.90 | 10.217% | 3.741 мс |
| 1920×1080, ворота | 202.49 | 185.33 | 8.477% | 6.370 мс |
| 1920×1080, центр | 207.36 | 198.31 | 4.362% | 6.012 мс |
| 1920×1080, фланг | 203.20 | 191.77 | 5.622% | 6.220 мс |

Все шесть paired замеров PASS при абсолютном пороге90 FPS и относительном15%:
`run_dfab_full1280`, `run_dfab_full1920`, clean perf receipt, exit0/stderr0.
Отдельный зеркальный gate ABBA `run_dfab_gate_perf01` подтвердил
406.84→356.53 FPS, −12.365%, две field половины353.57/359.49 FPS.
Геометрия `run_dfab_geometry01`:9 terrain meshes,15 MultiMesh,
1904 instances,77 colliders,68 covers,344 grass/0 road, stone break PASS.
Маршруты `run_dfab_routes01`: ворота и центр свободны, оба фланга
капсулой0.38×1.72 м PASS. Настоящий PlayerController `run_dfab_walk01`
PASS центр/оба фланга/насыпь, grounded100%, stalls0, max vertical
tick0.0126м, max feet error0.037м, высота насыпи1.208м.

Startup guard `main.gd` проверен настоящим PlayerController в
`run_spawn_guard02`, terminal PASS exit0/stderr0: без ввода посторонний
boot teleport на31м вернулся к точке катапульты с ошибкой0.016м; первое
реальное WASD сбросило счётчик396→0, затем персонаж пробежал32.08м
без повторного возврата и стоял на земле332 из340 тиков. Первую
проверку `run_spawn_guard01` сохранить как raw fixture FAIL: assertions
были PASS, но scene teardown дал stderr leak; исправлен только QA cleanup.

`D:\MafioziCombat31\battlefield_publish_next` продвинута с прежней
origin/main `1c4e4c60` на на момент проверки последнюю `63c0d568`.
Сборка содержит site SHA `2B8D737CB54FC21C67935BE33181D5E50D8A4E1C88F30E22CE508CC6D5365C58`,
props SHA `DFAB90ECF42DB99DCDED008F18F836C436552EFCEF2EDFC3FF7ACCB96BF455BC`
и main SHA `521E05E1E984153D95613619A81D1D12B7CEE201943544633936C7254D3708BB`.
Первый raw import `run_latest63_import01` завершился FAIL на transient
Godot `get_multiple_md5` null при массовом реимпорте; повтор без изменения
source `run_latest63_import02` PASS exit0/stderr0. Точный scene/guard
`run_latest63_guard01` PASS exit0/stderr0, graphical smoke
`run_latest63_visual01` PASS exit0/stderr0; кадры общей сцены лежат в
`D:\MafioziCombat31\battlefield_qa\visual_latest63_dfab`.
Перед commit надо повторно сверить origin/main: координатор продолжает
публиковать проверенные checkpoint.

Последний checkpoint координатора `72ce3fce` проверен отдельно на
`D:\MafioziCombat31\battlefield_publish_next`: исходники site2B8/propsDFAB,
guard patch поверх обновлённого main SHA
`3349F117C2FDF58E6B84FE314C9DF57ADDD50D5C53659F76FB7A03BE3F76E217`.
Import `run_latest72_import01` PASS exit0/stderr0. Guard fixture сначала
дала raw FAIL в `run_latest72_guard01`: все игровые assertions PASS,
но Godot сообщил 2 leaked ObjectDB/1 resource при завершении процесса.
Повтор с verbose без source изменений `run_latest72_guard_verbose01`
PASS exit0/stderr0; после увеличения bounded scene cleanup с4 до18 кадров
обычная `run_latest72_guard02` PASS exit0/stderr0. В ней boot teleport
исправляется с ошибкой0.016м, WASD сразу снимает guard, бег до32.08м
не возвращает персонажа. Никакого игрового изменения ради cleanup не было.

На каждый проверенный commit сохраняются: SHA, путь точной копии проекта,
журналы на D, численные показатели и скриншоты трёх ракурсов. Если часть
карты не работает, указывать координату, тип физического попадания и имя
узла. После исправления повторяются исходный дефект и все три маршрута.
