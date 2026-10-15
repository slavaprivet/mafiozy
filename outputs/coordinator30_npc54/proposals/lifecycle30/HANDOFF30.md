# Lifecycle30 — проверенный пакет для массового кандидата

Готово к объединению после `population30`. Общую игру этот агент не менял.
`MANIFEST30.json` SHA256: `01c8c38977e1541edc6c48f9dae53ad916ffb5d2440c678ed29bcfa889f81d31`.

`apply30.py --project <абсолютный путь> --apply --receipt <файл>` применяет только
шесть scoped patches и один новый manager. До любой записи проверяет все
исходные и конечные хеши, а также уникальность контекста. Без `--apply` — только
предпросмотр. Вызывающий держит scheduler write lease на целевой проект.
`SHARED_DRY_RUN30.json` подтверждает совместимость с актуальной общей сценой:
population `c8f251580914bb39556d314e604e2632c4787f4508548753a0c36d32c8db13d1`
объединяется в `1449483336cd974a817729049fda4bdda03422b7147d216ea97df937a5679ba4`.
Изменения root для 24 колец допуска и выключения подробного trace сохранены.

Пакет обобщает прежний подтверждённый death/respawn controller на каждый
допущенный resident ID. На живых жителях нет новых покадровых lifecycle callbacks;
таймер создаётся только после смерти. Общий gate допускает не более одного
дорогого рождения за physics frame. Staff остаётся отдельным набором.

Сохраняются native health receipt, source ID, appearance и generation guards.
Смерть снимает только собственные daily/health/queue/physical dispatch; тело
проходит прежнюю физическую смерть и холодную уборку. Занятый spawn ждёт и
повторяет ограниченный поиск. Новое поколение получает новые body, health,
daily life, account и queue owner, полное HP, energy100, cash1000 и пустые задачи.

Исправлены найденные дефекты:

- Один пропущенный `pop.owners.get(ID)` мешал смерти любого ID кроме resident_1.
- Capsule snapshot сохраняется в successor record для повторов admission.
- После успешного рождения удаляется временный `single_successor28`, поэтому
  последующая уборка не удерживает завершённую запись.
- Проверка stale token сначала проверяет валидность уже освобождённого body.
- Dispose освобождает registry lifecycle owners.
- `--city-resident-name` раньше перемещал всех подписанных жителей в одну точку
  и перезаписывал проверенный respawn position. Теперь старый inspection spawn
  действует только для первого допуска в `--city-qa=1`; массовые жители и любые
  возрождения сохраняют валидированное место. Само имя остаётся доступным.

Приёмка: `runs/multi05/MULTILIFE30.json`, 50/50 checks PASS. Три настоящих жителя
в исходном городе, четыре native sniper input → projectile terminal → exact
health receipt → death, поколения resident_1 и resident_2: 1→2→3. Занятое место
рождения остаётся без нового тела и daily life, после освобождения рождается
полное поколение. Повторные death receipts не продлевают таймер; stale refs
не воздействуют на преемника. Третий житель сохранил своё поколение и здоровье,
прошёл 23.9204 м, из них 12.5474 м во время смерти/рождения других. После циклов
health/lives/accounts/controllers/active work/body count снова равны 3;
активных ragdolls нет, разрешён штатный IDLE pool.

Старый одиночный режим: `runs/single02/DEATH28.json` PASS, real native death,
181 corpse frames без продолжения его daily/health/nav работы, полный новый
resident_1 generation2. Обе финальные проверки имеют exit0, stderr0, source
drift0 и одинаковые 1120 source pins в `SOURCE.json`.
SHA256 файла source pins:
`f05f123e3418c1b056b6bb7059548535f8c8bc9dd80d9670ac5174bddb2bb5e2`.

Ни одного NPC fixture не перемещает и synthetic damage не вызывает. Для
прицеливания fixture размещает только player на проверенном свободном полу;
временный StaticBody блокирует место рождения для проверки ожидания.
Сохранены source snapshots, точные launch flags, engine receipts, stdout и stderr.
`multi03` и `multi04` сохранены как промежуточные FAIL, а не принятые результаты:
первый обнаружил missing optional threat meta; второй выявил повреждение CRLF
в приватном staging helper. Финальные тесты восстановили точные owner bytes
peer файлов и включают три исправления threat владельца (`PEER_FIXES30.json`).

Новый режим включается `--city-multi-lifecycle30=1` вместе с
`--city-simple-hospital=1` и `--city-physical-dispatch30=1`; полный набор QA flags
сохранён в `runs/multi05/FLAGS.json`. Для обычного времени трупа не переносить
тестовое `--city-respawn-seconds=3` без отдельного решения.

Массовая приёмка 64/287 и сопоставимые performance measurements этим пакетом не
заявлены. Это следующие проверки root на общей сборке после import. Graphical
death acceptance также остаётся отдельной проверкой root. Приватная копия
`proposals/injury30/game` свободна после завершения обоих финальных запусков;
новых полных копий города в этой задаче не создавалось.
