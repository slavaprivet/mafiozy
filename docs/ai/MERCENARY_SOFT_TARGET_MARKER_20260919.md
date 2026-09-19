# Спокойный маркер объекта вместо обводки — 19 сентября 2026

CPU READY. Исполнитель `safe_operator_clearance18`; `mercenary_selection_view.mjs` и focused tests освобождены. **LIVE / визуальная приёмка пользователя ещё не выполнялись**, браузер не использовался.

По последнему поручению пользователя отказались от обводки геометрии предмета. Теперь выделение — четыре раздельные низкие эллиптические дуги вокруг основания и две плавные скобки по высоте. Без заливки объекта, коробки, контуров досок/ручек/прутьев и угловатых деталей. Ширина ленты 2–4 см; прозрачность плавно убывает поперёк ленты и на концах дуг через vertex alpha. Все шесть дуг объединены в **один mesh / один draw call**. Depth test остаётся включён; маркер не рисуется сквозь стены.

Цвета: красный `f03532` при выборе, зелёный `61df89` при работе. Завершённые/открытые/invalid цели удаляют маркер. Дополнительно учитываются `object.userData.mercenaryOpened`, meta.opened, прорезанная сетка и отключённый щиток. Машины целиком по-прежнему НЕ маркируются, отдельная посадочная дверь остаётся другому модулю. NPC/member/player сохраняют только существующее нижнее кольцо, без материала тела. Rally marker не менялся.

Размер вычисляется один раз при первой встрече цели и кешируется по object. При authored `mercenaryTarget.highlightBounds` используются именно они: щиток обрамляется без удалённых фонарей. Иначе локальный box объединяет видимые mesh/instances, исключая скрытые материалы, proxy и mercenaryPickIgnore. Bounds/нормали/вершины исходной geometry не изменяются. Дуги прикреплены к объекту, поэтому его движение и поворот не требуют пересчёта bounds или geometry каждый кадр. При повторном выборе используется кеш. Полные hull build/нормали/таймеры sliced build убраны; старый отдельный `mercenary_outline_normals.mjs` не удалялся.

## Проверки и стоимость

- `node --test assets/maps/city_rebuild_v1/test_mercenary_selection_view.mjs` — **7/7 PASS**.
- `node --test assets/maps/city_rebuild_v1/test_mercenary_walk.mjs` — **PASS** (real Three/core integration, fleet effects, plant/retreat/fuse, classic scripts parse).
- Контракты: red→green без перестройки → none; сохранность buffers/materials/source boundingBox; soft alpha края/концы; authored panel bounds не захватывают фонарь в40м; visible instances; transform tracking; actual QA door bounds и исчезновение после breach; NPC/no-car; rally lifecycle/disposal.
- Стоимость выбранного предмета всегда **594 vertices / 768 triangles / 1 draw call**, независимо от числа его деталей. Нет lights/postprocess/material clones. NPC/rally существующие эффекты остаются самостоятельными; эта цифра относится именно к object marker.
- На high-detail sphere + box 2500 повторных setTarget/update: CPU p50 `.0009 мс`, p95 `.0019 мс`; bounds/build всего один. Это CPU без renderer; **производительность общей сцены не проверена**.

Финальную эстетическую оценку сделать в единственной игре на сейфе/щитке/сетке/новой двери: размер/читаемость разных направлений камеры и красный→зелёный→исчезновение. Подсказкой X владеет существующий host, этот модуль её не меняет.
