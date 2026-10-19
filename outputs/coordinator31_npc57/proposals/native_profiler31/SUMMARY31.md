# Встроенный профайлер Godot — настоящий запуск31

Native ScriptProfiler включён в неизменной57:10 жителей+12 сотрудников,30с прогрева,60с наблюдения. Все10 покинули исходные позиции. Ошибок движка и изменения исходников/F5 нет.

Самые дорогие собственные участки в этом диагностическом запуске:

| Участок | Собственное время, с | Вызовов | мкс/вызов с профилированием |
|---|---:|---:|---:|
| `res://scripts/venues/npc_venue_staff_actor29.gd::55::_physics_process` | 1.407 | 28980 | 48.55 |
| `res://scripts/hospital/npc_physical_route51.gd::337::move` | 0.835 | 20443 | 40.83 |
| `res://scripts/npc_visual/preview_resident_host.gd::1285::step` | 0.572 | 2415 | 236.73 |
| `res://scripts/venues/npc_compact_service_site29.gd::121::_physics_process` | 0.501 | 19320 | 25.93 |
| `res://scripts/hospital/npc_walk_surface28.gd::78::check` | 0.495 | 32102 | 15.42 |
| `res://scripts/npc_visual/preview_resident_host.gd::2053::target_current` | 0.464 | 44645 | 10.40 |
| `res://scripts/hospital/npc_physical_route51.gd::73::floor_at` | 0.433 | 32102 | 13.49 |
| `res://scripts/city/runtime/npc_city_clone_door_swing.gd::279::_occupants` | 0.431 | 3219 | 133.93 |
| `res://scripts/npc_visual/preview_resident_host.gd::1883::occupants` | 0.397 | 3219 | 123.35 |
| `res://scripts/destruction/palazzo/palazzo_glazing.gd::238::_sync_one` | 0.353 | 340284 | 1.04 |

Основные кандидаты для дальнейшего измеренного упрощения: каждый физический кадр12 сотрудников; полное движение/проверки опоры жителей; многократный сбор списка обитателей для разных дверей; обновление стекла. Сам поиск пути через NavigationServer в этом окне занимает мало времени. Ничего из этого не отключено ради цифр.

Это диагностический headless запуск с включённым профайлером и открытой пользовательской игрой. Он не измеряет чистый FPS/GPU. Печать результатов и сброс профайлера сами дороги; время observer исключено из списка, а измерение заканчивается до финальной печати. Inclusive total нельзя складывать.

Документация: https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html ; https://docs.godotengine.org/en/stable/classes/class_enginedebugger.html .

Полный журнал,4408 зарегистрированных функций (включая не вызванные), предупреждения debug и исходные pins находятся в `runs/city_headless04`. Неудачные попытки01–03 сохранены отдельно: отсутствующий необязательный файл, отсутствие --debug и преждевременная остановка по предупреждениям.
