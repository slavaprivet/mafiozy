# services31 — продолжение и передача, 15 октября 2026

Статус: **PASS_NATIVE_COMPONENT_READY_FOR_ROOT_INTEGRATION**.
Старый агент `01a13f76-b441-73f2-bcdb-9f85a7a648de` прочитан через read_thread:
idle/interrupted. Все его `services31` файлы и результаты сохранены.
ToolSearch/Ruflo отсутствуют в доступном каталоге инструментов.

Production-код побайтно совпадает с проверенным `services31/candidate04`:
исправлений production после подхвата не потребовалось. Добавлены воспроизводимый
runner с проверкой SHA движка/очереди/исходников, свежие native пары на release56,
встречные потоки из шести жителей и окончательная передача.

## Изменение поведения

Живые жители и сотрудники могут проходить друг сквозь друга только в общей
области узкого зарегистрированного входа. Один и тот же набор участников задаёт
симметричные native collision exceptions, исключения физического планировщика
и фильтр локального избегания. Вне прохода столкновения NPC восстанавливаются.
Геометрия, створки, игрок, debris и оружейные ray-запросы сохраняются.

Область строится по реальной закрытой створке: её полуширина +0,45 м и глубина
3,3 м с каждой стороны. Ограничения: 448 актёров, 64 входа, 32 участника одного
входа. В процессе этой задачи в общую игру число жителей не увеличивалось.
Сборка не назначает глобальное отключение collision mask и не телепортирует NPC.

## Только эти четыре production-файла

Все пути ниже относительно `patch/`. Полные base/candidate SHA находятся в
`PATCH.json`; корень целевой интеграции — `outputs/coordinator31_npc57/game`.

| Файл | Candidate SHA256 |
| --- | --- |
| scripts/navigation/npc_passage31.gd (новый) | 49ab9e218f37aac086dfe2fd3817f08b759cf2ecb1dc41091cce97c29a5b518e |
| scripts/hospital/npc_physical_route51.gd | ce8bca0c9d45b88ae45ec3973544838267ef88db2d62911f781e25bed6b7168f |
| scripts/navigation/npc_local_avoidance29.gd | eb745234cd6df1803c4d44e00535e81a27e6c9384dbff534d062efff87e0854a |
| scripts/navigation/npc_avoidance_world29.gd | 43d8778d5d42a769e4be3c81218d8fc891194ee42262863dd6d3b2e93ca6e1fa |

`PASSAGE31.patch` — точный unified diff от release56.
`PASSAGE31_SOURCE.zip` — только эти четыре файла.
SHA256 архива: `7d128809f444c463e9edc1b7c6cb1c126f02f2aa7557a1e99a57854cca7ebd8f`.
`PATCH.json` SHA256: `9f130bb9089882f3067e5fb0c141257ae6dff799b770b7a8a0749bde08fb05b3`.
`ACCEPTANCE.json` SHA256: `9718f879d813fbaf00a9ea7287208d980a37426b1aebd93e054433a6e70028e1`.

## Новые реальные прогоны

Обе пары используют один и тот же immutable `outputs/coordinator30_release56/game`:
source manifests в каждой паре одинаковы. Candidate применял четыре исходника
только в памяти отдельного процесса. Во всех четырёх финальных прогонах exit0,
stderr0, source drift=[], harness drift=[]; текущий scheduler SHA совпал с
`TEST_SCHEDULER.md`. Lease: headless/read, два logical CPU, собственный watchdog.
Fixture принудительно задаёт Engine60Hz/time_scale1; каждый step возобновляется
только на physics_frame. Engine.is_in_physics_frame=true на каждом шаге,
наблюдённый delta строго 1/60. Записаны отдельно wall и physics elapsed.

| Проверка | Исходная release56 | Исправление |
| --- | --- | --- |
| `physics_baseline06` / `physics_candidate06`: настоящий магазин, клиент и житель в проёме | Выхода нет | 30/30 PASS, 0 blocked, выход 2,875 wall / 2,883 physics с |
| Встречная пара той же fixture | Не завершила за 480 кадров | Оба за 154 кадра: 2,566 wall / 2,567 physics с; 13,02 мм минимального разделения |
| `streams_physics_baseline03` / `streams_physics_candidate03`: по трое с двух сторон | Дверь открыта, все 6 не завершили за 720 кадров | 12/12 PASS, 6/6 за 252 кадра: 4,187 wall / 4,2 physics с; все 9 встречных пар пересеклись |

Шесть клиентов начинали с расстоянием 0,8 м друг от друга. Максимальный шаг
0,03089 м; наименьшие расстояния всех девяти встречных пар 0,747–26,12 мм.
Native masks/ground collision сохранены, все 15 исключений удалились после
удаления шести тел. В парной fixture отдельно прошли стены, закрытая реальная
дверь, игрок, ray hit, выход из зоны, death layer, respawn, same-frame free.

`streams_candidate01` и `streams_baseline01` сохранены как FAIL самой fixture:
начальные внутренние тела стояли в sweep ещё закрытой створки, поэтому реальная
дверь справедливо не открылась. В fixture02 створка сначала физически открывается,
затем задаются начальные позиции; во время движения она получает обычный native
open request как от Visit-контроллера. Production при этом не менялся.

`baseline05/candidate05` и `streams_baseline02/streams_candidate02` также
сохранены, но не используются для окончательной приёмки времени/движения:
старый step ожидал сначала physics_frame, затем process_frame и вызывал native
movement в process context. Именно это исправлено в новых physics_* парах выше.

## Действия root при интеграции

1. Проверить целевые три base SHA из `PATCH.json` и отсутствие нового файла.
   При чужих изменениях использовать `PASSAGE31.patch` для ручного объединения;
   не заменять чужую работу целыми файлами без сверки.
2. Под write Lease общей candidate скопировать только четыре production-файла.
   Frozen56/F5/пользовательское окно/старые proposals сохранять.
3. Импортировать candidate через write Lease. Затем провести merged native
   проверки через `entry_merged31.gd` под headless/read Lease. Этот адаптер
   **не подменяет исходники в памяти**: использует фактический код общей game.
   Передать `--qa-out=<отдельный каталог>`; для шести встречных добавить
   `--streams31=1`. Проверить exit/stderr, все `NATIVE31.json.checks` и pins.
4. Общая приёмка четырёх услуг, настоящего урона/реакций, долгого цикла десяти
   жителей и чистого FPS остаётся у root/QA. Только после неё выпуск/F5/Git.

Адаптер `entry_merged31.gd` подготовлен для root, но на общей game здесь ещё
не запускался. Свежее повторение baseline/candidate без интеграции:
`run31_resume.py <новое_имя> [--candidate]`; шесть жителей:
`run_stream31.py <новое_имя> [--candidate]`. Эти runners проверяют неизменённую
release56 и откажут при несовпадении base SHA.

Native hit здесь означает обнаружение живого NPC физическим лучом. Реальный
damage/reaction цикл и городской FPS эта fixture не подтверждает. Измерение
max_refresh_us на двух/шести телах не является performance-приёмкой города.

Общая `game`, frozen56, F5, Git и пользовательские процессы не изменялись.
