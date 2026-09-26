# S01 — подключение записи кадров в main

26 сентября 2026, чистый Координатор21.

`main.gd` создаёт один `PreviewPerf` только после успешной проверки сцены.
По умолчанию адаптер OFF, без process callback. Запуск разрешён явно через
`-- --preview-perf`, export property `preview_perf_enabled`, либо
`main.begin_preview_perf_capture(config)`. Неудачная загрузка сцены не создаёт
адаптер. Caller завершает запись через `main.preview_perf.finish_capture()` или
ограниченную async JSON очередь; автоматической записи на диск нет.

Начало записи отвергается, если включён `--preview-capture=...`: PNG readback
и кодирование нельзя включать в измеряемый маршрут. Контекст фиксирует настоящий
малый квартал, population=0, vehicles=0; caller задаёт scenario/route/source SHA.
Сам адаптер записывает действующие настройки движка. Этот контекст не означает
проверку города с NPC и транспортом.

Проверки actual Godot4.7.2 headless:

- `scripts/tests/test_preview_perf_hook.gd`: 18 assertions PASS при default OFF;
  ещё один запуск тех же 18 assertions с CLI opt-in PASS.
- `test_preview_admission.gd`: 5 ожидаемых отказов без частичной 3D сцены,
  затем настоящий main READY, 16 visuals/27 source colliders PASS.
- Независимая приёмка exact core/adapter SHA: core48, async77, дополнительный56
  PASS, `outputs/coordinator21_perf_acceptance/RESULT.md`. Покрытие пересекается;
  эти числа не складываются в количество уникальных сценариев.

Core SHA `4cc30a2b7b681c1177f6cfa403dd80ae2f10aef9b84d214ce5fa0234f6e101a0`.
Adapter SHA `84d39fb251a89dc94b7834d63107737c8340921be97e6d2bbcb905e0aa810c7b`.
Завершение двух синтетических worker jobs по100000samples при уничтожении
адаптера заняло374.161ms в отдельной проверке; контракт допускает join.
Уничтожение/формирование report выполнять за пределами игрового измерения.

Экспорт исключает вложенный `scripts/tests/*`. Новый экспорт пока не проверен.
Существующий release PID43332/session9305 сохранён и этих изменений не содержит.
LIVE OFF/ON/ON/OFF и производительность общей сцены **не проверены**.
