# Service → threat → physical exit → normal

Fixture подготовлен; до root GO engine не запускался. `run30.py <name> --case
shop|restaurant --go` читает общую сцену под scheduler read lease, сохраняет
1120+ source hashes и fixture archive, сверяет source после процесса. Следующий
case может получить `--source <первый SOURCE.json>` и не запустится при drift.
`--game` принимает другой существующий абсолютный проект. Полных копий нет.

Сценарий использует один здоровый resident и исходные 12 staff. Единственная
установка agenda вызывает production `_choose_purchase(kind,true)` и
`_economy28_try_begin(row)`; price и account принадлежат прежним владельцам.
Стартовые HP/energy/cash задаются существующими launch flags. NPC никогда не
перемещается fixture. Player один раз размещается на реальном свободном полу
снаружи двери; настоящий viewport input делает TT miss-shot наружу/вверх.

Приёмка требует native entry, активного staff service slot и физической позиции
у продавца; настоящее замеченное событие выстрела; физического выхода до
освобождения capacity; сохранения неоплаченной покупки и денег; бегства быстрее
обычного шага; отпускания через 15 секунд без новых угроз; возвращения за
настоящей покупкой, одного правильного списания, восстановления энергии и
завершения обычной физической прогулки. Фиктивных claim/settlement/hit нет.

Маршрутный read-only audit после mass64:

- Планирование уже имеет общий бюджет: `hospital/npc_route_budget29.gd`
  1800 μs soft /128 units/frame; long guide: `navigation/npc_navigation_work29.gd`
  не более 2 native queries inflight, 1 submit/frame, 600 μs/64 preparation items.
  Эти пределы не означают ограничения всей стоимости physical tick.
- У каждого реально движущегося NPC `hospital/npc_simple_hospital.gd:538`
  перепроверяет floor, затем `hospital/npc_physical_route51.gd:330` делает
  debris cast+overlap и `move_and_slide`. На обычной суше это как минимум три
  дополнительных native queries на движущегося за tick; для 287 одновременно
  движущихся — 861 плюс обязательный body motion. Это источник линейной нагрузки,
  а не доказательство утечки. Без профиля менять safety guards нельзя.
- `hospital/npc_walk_surface28.gd:77` на каждой floor проверке строит source/cell
  dictionaries и footprint samples; на берегу/мосту добавляет 16 rim samples и
  дополнительные live rays. Это кандидат для измерения allocations/cost. Можно
  кэшировать неизменяемую классификацию source cells и переиспользовать query
  objects, сохранив live floor/полный capsule и generation reset.
- `_dsh_resdiag_step` в `scripts/npc_daily_life.gd:294` при включённом HP label
  строит walk snapshot и несколько dictionaries даже при выключенной подробной
  диагностике. Это уже участок staff/diag владельца; здесь не редактировался.
- Door occupant snapshot копирует текущих occupants по запросу открытия двери,
  с лимитом повторения 250 ms; не является общей покадровой стоимостью всех 287.
  Spatial avoidance refresh один раз на frame и использует current active index.

Следующий объективный профиль должен разделить physical move, support admission,
planner, avoidance и label cost. Нельзя снижать реальную частоту движущихся NPC
или число жителей и выдавать это за ускорение той же сцены.
