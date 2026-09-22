# LIVE render attribution — 23 сентября 2026

Root Coordinator20, одна существующая18538game, GTX980,1280×720,ratio1.
Штатный automatic render isolation:45warm frames +121sample frames/phase;
probe reports120samples. Camera[167,2.74,168], shadowculling ON.
Это замороженная3Dпрезентация; source simulation продолжает работать.
Измерение НЕ является gameplay FPS и не подтверждает исчезновение лагов.

| Режим / phase | render p50/p95 ms | GPU p50/p95 ms | main/shadow calls | triangles |
|---|---|---|---|---|
|shadows baseline-before|62.3/68.5|46.02/50.96|2197/850|2989746|
|shadows variant|47.5/53.3|32.27/35.81|2197/0|2362288|
|shadows baseline-after|61.5/69.2|45.63/49.97|2197/850|2989746|
|pointlights baseline-before|58.2/63.6|42.64/47.09|2067/850|2816016|
|pointlights variant|54.2/59.6|39.51/43.27|2067/850|2816016|
|pointlights baseline-after|55.4/59.9|41.81/45.49|2067/850|2816016|

Оба complete, baseline draw totals restored. Тени и свет восстановлены;
production отключение не применялось. Shadows snapshot:72cached/17visibleNPC,
15cars, no pendingloads. Перед pointlights120secfreeze перезапущен: та же
камера/день, но новый presentation snapshot, поэтому два режима напрямую
между собой не сравнивать. Внутри каждого трио геометрия/камера фиксированы.

StreetLighting diagnostics:night0,activeLights0,fixedLights8. Baseline и
variant screenshots pointlights (phase0/frame90 и phase1/frame150) показывают
одинаковую3Dкартинку. HUD/minimap продолжают меняться. Автоматического pixel
diff нет; визуальное сходство не подменяет точную попиксельную проверку.
Во втором baseline render уменьшился и без variant — это дрейф замера;
GPU variant ниже обоих baseline, дальнейшую оптимизацию принимает Checker2.

Результаты и ограничения переданы Проверщику ЧАТОВ2, владельцу perf/8Астра.
