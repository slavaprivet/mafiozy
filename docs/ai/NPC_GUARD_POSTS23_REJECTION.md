# Guard native routing — новый сценарий НЕ принят

23 сентября 2026, Художник21. Только isolated/read-only после передачи
cached-target production. Runtime guardkind не менялся.

Следующая проверка использует actual `_empireHoldingGuardPost`: три слота,
четыре последовательных поворота вокруг transform-anchor существующего hospital.
Actual hospital GLB/закрытые двери, source route + actual movement + swept steps.
Владение/anchor синтетические; это не серверный объект охраны и не LIVE.

`node test_empire_other_kinds23.mjs --guard-posts` намеренно заканчивается
assertion failure: **candidate must physically arrive at every generated guard
post before readiness**. Полный отрицательный отчёт сохраняется до assertion:
`outputs/empire_guard_posts23_candidate.json`.

| Вариант | Завершён route | Действительно достигнут пост (<.75cell) | CPU суммарно12queries |
|---|---:|---:|---:|
| Production coarse | 12/12 | 6/12 | 317.71мс |
| Только native planner | 6/12 | 6/12 | 2167.46мс |
| Planner + точность углов | 6/12 | 6/12 | 2135.46мс |

У coarse оставшиеся шесть завершили **частичный** маршрут в2.02–5.33cell от
поста (8.3–21.8м). Поэтому12route-arrived не означают12прибытий на пост.
Actual guard branch продвигает патруль только внутри.75cell: эти результаты
могут повторно заказывать ту же недоступную точку. Native честно возвращает
EMPTY, но тяжёлые запросы до9kvisited увеличили CPU; это не готовая оптимизация.
Уточнение: здесь измерены запросы отдельно, не полный guard update/FPS.

Проблема producer: `_empireHoldingGuardPost` принимает ближайшую свободную
точку по кругу без подтверждения связности подхода. Свободный footprint может
быть за закрытым входом/в отдельной области. Поэтому простое включение guard
в native planner не решает полный цикл и пока отвергнуто для production.

Конкретный пример: `(10.5,168.5)`→`(13.5,163.5)`:
coarse route заканчивается в2.024cell отцели; native EMPTY. Следующий независимый
отрезок из `(13.5,163.5)`→`(11.5,161.5)` проходит — сами точки свободны,
но первый подход не соединён в этом fixture. Это не доказательство дверного
состояния всей LIVE сцены.

Нужен отдельный bounded producer/EMPTY fallback для достижимых наружных постов
на том же существующем объекте, согласованный с root native-site authority.
Без перестройки HQ и без превращения частичного маршрута в прибытие. До такого
repro/candidate не внедрять guardkind-only patch по старым24/24sample результатам.
Цели боссов из cached-target пакета этим отрицательным guard тестом не затронуты.
