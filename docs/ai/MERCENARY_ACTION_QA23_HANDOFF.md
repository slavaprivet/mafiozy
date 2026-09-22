# QA история действий наёмников — 23 сентября

READY, только диагностика. Изменены QA locals и `reportMovement` в
`mercenary_world.js`, плюс тесты в `test_mercenary_water_follow23.mjs`.
`move`, `approachWaypoint`, core и exports не менялись.

В прежнем `document.documentElement.dataset.mercenaryMovement`:

- `actionHistoryVersion: 1`;
- `crew[].action`: kind, phase, progress, targetId, targetR/C, targetWalking;
- `crew[].lastAction`: kind, phase, reason, at, либо null;
- `actionHistory`: максимум 16 записей, каждая содержит at, memberId,
  memberR/C и поля действия/цели. Активное действие записывается не чаще
  раза в секунду на бойца; terminal lastAction — один раз при изменении.
  Бездействие не заполняет историю повторными terminal записями.

Глубина и координаты остаются в прежних единицах: r/c — source;
history `at` — epoch milliseconds, `lastAction.at` — source epoch seconds.
`targetWalking` читается из source flags; фактическое перемещение подтверждается
изменением targetR/C между сэмплами. Для объекта без известного walking-флага — null.
История хранит копии чисел/строк/флагов, а не ссылки на персонажей или цели.

Сохранены loopback + `npcqa=1` gate и глобальный report не чаще 1/сек.
На обычной странице дополнительная работа функции не выполняется.

Проверка: `node --test --test-name-pattern=QA assets/maps/city_rebuild_v1/test_mercenary_water_follow23.mjs`
— **4/4 PASS**, плюс `node --check mercenary_world.js`.
Настоящий production intimidation в fixture дал ≥2 working сэмплов с растущим
progress и изменяющейся координатой движущейся цели, затем один completed.
Отдельно проверены cap16, неизменность истории после перемещения цели,
частота и отсутствие диагностики вне loopback/без флага. Полные actor/core
состояния при QA ON/OFF после одинакового moving intimidation идентичны.
LIVE остаётся у координатора в существующей вкладке.
