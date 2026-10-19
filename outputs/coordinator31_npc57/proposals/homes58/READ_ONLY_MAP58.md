Рабочая карта для нового контроллера дома; реализации и запуска пока нет.

`npc_simple_hospital.gd` уже даёт native движение к обычной точке через
LongRoute/PhysicalRoute, peer avoidance, поиск живого пола и текущую капсулу.
Новая roam-правка принята отдельно. Дом должен использовать этот мотор, не
записывать координаты жителя и не отключать world/player/door collisions.

`npc_restaurant_visit28.gd` содержит проверенную последовательность staging →
outside → opening → inner → room и обратный физический выход. У него уже есть
измерение радиуса створки, точное безопасное положение перед её открытием,
проверка реальной fraction, envelope вместо бесконечной полуплоскости и
сохранение владения при заблокированном выходе. Прямой `begin` не подходит:
он выбирает торговый registry по вывеске и может запросить чужой venue/room.
Возможен отдельный наследник маршрута с адаптером только назначенного дома;
торговая очередь, сотрудники, счета и оплата в домашний адаптер не входят.

`ambient_controller28.gd` и `ambient_benches28.gd` показывают существующий
контракт physical dock + реальные support-ray проверки + current-generation
weak claim. Позой управляет только `preview_resident_host.gd`, после gait,
под охраной смерти/ragdoll/transport/hit/combat. Готовой позы сна нет.
Домашнему helper нужен отдельный pure pose composer, current-frame metadata,
`sample_current` и `pose_committed`; статус подтверждённого сна нельзя выдавать
до настоящего host commit. Капсула и скорость остаются прежними; схема dock и
skeletal pose на кровати согласуется с root-геометрией.

Публичный интерфейс для владельца daily:

- `configure(life, scene, map) -> bool`, `available() -> bool`.
- `begin({kind: home_sleep|home_rest, hour, wake_hour, source_id}) -> bool`.
- `active()`, `step(delta,row) -> active|done|blocked`, `snapshot()`.
- `needs_exit()` остаётся true после реального входа до подтверждённого выхода.
- `request_wake(reason)` немедленно прекращает sleep-публикацию и начинает
  физический выход; это не освобождение движения для следующего владельца.
- `cancel(reason)` освобождает строго своё владение при death/dispose/stale
  generation; обычная угроза сначала требует пробуждения и выхода.

Обязательные integration места у addons/root: ThreatLife._release_service
должен ждать home release до FLEE; daily injury/death/dispose должны прекращать
сон; `npc_city_daily._physical_needed30` должен включать active home даже во
время сна. Поддержка кровати/дома, поколение, угроза и физика проверяются также
при остановленном визуальном clock клавишей T. Новый отдельный таймер суток
не вводится. Root назначает 1–3 жильца/дому и настоящие разрушаемые кровати;
helper не создаёт геометрию и не выбирает произвольный свободный дом.

Предварительные наблюдаемые фазы: HOME_APPROACH, HOME_ENTER, HOME_BED_APPROACH,
HOME_SETTLE, HOME_SLEEP/HOME_REST, HOME_WAKE, HOME_EXIT, HOME_BLOCKED. Переход в
idle для QA допустим только при действующем claim, живой опоре и подтверждённой
позе; invalid/destroyed bed никогда не легализует длительную неподвижность.
Нужны native proof входа/сна/выхода, concurrent 1–3 жильцов, stale generation,
реального повреждения/угрозы/разрушения и часов 23:xx→00:xx/остановки T.
