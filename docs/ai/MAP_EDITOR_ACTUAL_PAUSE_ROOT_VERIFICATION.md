# Реальная сцена: независимая диагностика паузы, 27 сентября 2026

Root повторил tools-only probe на свежей изолированной копии
`outputs/actual-main-pause-probe-5FPYLM`: 336 файлов, 146 153 791 байт;
main SHA256 `0916381441df9a9d111006aed2b34e4e1c2ec195ee24609757a552b388017571`.
Фактический runtime revision `s01-20260927-melee21`, 8 зданий, 8 decor,
27 исходных коллайдеров, настоящий player/transport body/melee/printshop/water.
NPC выключены по исходным настройкам; nav query completion НЕ проверена.

Finalizer повторно проверил 303 staged raw source файла. На момент финализации
текущий `transport_debris_material_pool.gd` изменился у владельца; точные SHA
перечислены в `FINAL_DIAGNOSTIC_RECEIPT.json`, currentSourceMatchesSnapshot=false.
Доказательство относится к точной staged closure, НЕ автоматически ко всей
последней рабочей копии или открытому exported melee21b. Main/player/melee
сопоставимы с указанным pin. Derived importer cache не является owner approval.

Godot 4.7.2 headless import и run завершились exit0. Повторный import проверен
на отсутствие error/failed, run без ScriptError; report failures=[],
diagnostic_pass=true, editor_pause_ready=false. Проект не использует production
user directory; GPU, открытая пользовательская игра и main не изменялись.

Наблюдения при паузе 647 773 мкс:

- Native vehicle tick остался 91→91; фактические transforms игрока и машины,
  velocity машины и runtime main не изменились.
- Time продолжил идти; Input singleton сохранил удержанный forward.
- Реальный melee cooldown сохранил один pending timer и cooldown=true,
  поскольку advance остановился. После resume tick92 и cooldown=false/timers0:
  исходный абсолютный deadline успел истечь. Часы, source timestamps и timers
  не переписывались, cancel/reset до наблюдений не вызывались.
- RefCounted deferred marker выполнился во время паузы. Это synthetic marker,
  НЕ свидетельство готовности или остановки реального владельца navigation.

Вывод: SceneTree pause действительно останавливает native physics текущей
сцены, но НЕ даёт точного freeze/resume всей gameplay semantics. Требуется
решение владельца combat/input/water/nav: preserve-time clock либо явно
согласованная cancellation policy. Молчаливый сдвиг исходных timestamps
не допускается. Не выдавать этот diagnostic PASS за готовую editor lease,
за проверку всех NPC или за edited terrain adoption.

Отдельные boundary defects существующего tools-only editor_host_adapter
SHA256 `1147d035070488da5b01e558faeee41fde40fc18b0ef86ab1d4a3f5385a3f360`
воспроизведены root script
`tools/godot/map_editor_host_adapter_review/test_lifetime_reentry.gd`:
7 checks/failures=[], fixtureOnly=true. Queued-for-deletion owner допускает
enter до фактической удаления; verify callback reenters leave и внешний
transaction_ready возвращает true после удаления lease. Замороженный исходник
не изменён; эти проверки НЕ применяют фиктивные callbacks к actual main.
