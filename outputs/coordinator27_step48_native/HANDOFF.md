# Exact step33: native evidence на accepted48

Только isolated `outputs/coordinator27_step48_native/game`: все 486 исходных source pins принятой48, единственная замена `scripts/preview_player.gd` на точный patch `b33505b2bbadcadb5754e474f1a9cbb7b218f0abcbfa7ea7b70db8facff19d6c`. Base accepted assembly SHA `51484885ce069970cecb234b7c016d5cc7e3b5611c3422ddeaa915a0d9c712b7`. Shared/runtime/current_version не менялись. Staging/import/headless runs — через scheduler; пользовательские игра и editor сохранены. Финальный inventory содержит прежние34540/25808, собственных детей не осталось.

## Результаты

- `runs/import01`: native import PASS, 11.013 s, exit0/stderr0; source486 до/после неизменны.
- `runs/boundary01`: **265 из266 assertions**, 24 случая,2160 наблюдённых physics ticks,52.383 s, stderr0. Исходный FAIL сохранён: `bounded vertical rise 13` (120 мм при5.8 м/с). Остальные assertions, включая один native displacement/serial и неизменные capsule/filters/platform policy, проходят.
- `runs/corpse01`: **PASS2804**,38.237 s,exit0/stderr0. Это загруженная main сцена48+step с исходными тремя NPC, реальной смертью resident72 от конечного магазина TT и родным corpse owner.354 pressure frames,302 проверенных dead contacts,19 admitted owner impulses, shift45.541 мм, max native depth1.641 мм. Исходные IDs/capsules/masks/marks сохранены. Три унаследованных QA файла скопированы побайтно, provenance в `CORPSE_PROVENANCE.json`.
- `runs/diagnostic02`: узкий повтор106/120 мм при5.8 м/с; тот же cap123 FAIL сохранён,24 checks,stderr0. Добавлены actual collision normals/velocity/floor flags. `diagnostic01` — отдельно сохранённый QA parse failure (mixed indentation), до game run; он не подменён успешным результатом.

## Матрица условий

Каждое условие проверено на walk3.2 и run5.8.106/120 мм проходят;121/210/400 мм, низкий потолок1.95 м, rigid world-layer1, AnimatableBody3D и StaticBody3D с constant_linear_velocity блокируют step. Flat native walking проходит. При явно выключенном free-look controls и при явно установленной external seat authority персонаж неподвижен. Motion>120 мм отвергается helper на всех2160 наблюдениях. Q menu/реальная посадка в этой компонентной матрице не проверялись.

Capsule1.9×radius0.30, default layer2/mask1, platform layers/floor snap/angle/margin остаются родными. Между искусственными дорожками есть по одному объявленному setup placement; во время90 W-тиков и15 stop-тиков положение меняет native player. Копирование старого test_lip не возвращает townhouse в production: дорожки искусственные, никакой Palazzo passage из них не заявляется.

## Разбор сохранённого FAIL

Cap `max_y - start.y <= 0.123` унаследован из `outputs/coordinator25_step33/test_lip.gd`, SHA `7ae88f451179d20cc89106a1edd58e7ee9440cb07f336e0b6c7db8c7f31e522c`. Это историческая QA оценка максимального подъёма стоп, а runtime ограничивает **высоту поверхности относительно пола** (`top_height <= MAX_STEP0.12`). CLEARANCE0.002, MAX_STEP и epsilon не менялись.

120run: старт footY0.001191406; admission поднимает native move кY0.122000016; следующим тиком падение кY0.119277798; ещё через тик обычный slide даётY0.125965178. На пике helper=0, native deltaY=+0.006687, два контакта с тем же StaticBody3D topY0.12, normals `(0,0.993690,0.112158)` и `(0,0.995383,0.095987)`, on_floor=true, on_wall=false. Следующий тикY0.120594084. Peak выше authored top на5.965 мм; общий подъём124.774 мм > исторического cap123.106run имеет аналогичный corner slide, но меньшую абсолютную высоту.

Вывод из native evidence: FAIL относится к краткому подъёму круглой капсулы при последующем скольжении, не доказывает admission ступени>120 мм.121 и210 мм реально блокируются на обеих скоростях. Runtime исправление не вносилось, исходный FAIL не переименован в PASS; решение о значимости исторического cap остаётся root. Полная точная карта и trace — `REVIEW.json` и raw RESULT.

## Ограничения и воспроизведение

Это headless functional на scheduler2CPU; никакой performance/GPU/OS-input приёмки. Ни `accepted`, ни `performance_accepted` не выставлены. Реальный Palazzo порог/проход должен проверяться отдельно; corpse actual main coverage не означает полную игровую приёмку step.

`python -B outputs/coordinator27_step48_native/runner.py boundary --label NEW_LABEL` воспроизводит24-case fixture; `diagnostic` — narrow trace; `corpse` — исходный full-scene corpse contract. Каждый label свежий. Runner проверяет base/engine/all486 pins до/после, сохраняет exact frozen helpers в каждом run, timeout bounded, завершает только своего child. Все source/runner/proof hashes в `EVIDENCE_FREEZE.json`.
