# Координатор 17: HUD performance audit

13 сентября 2026. Scoped субагент `hud_perf_audit`, запрос пользователя об оптимизации без ухудшения качества. GPU/браузер не запускались, тяжёлых CPU benchmark нет. ToolSearch/Ruflo в доступном каталоге отсутствуют. Чужие изменения сохранены.

## Установленная работа в кадре

- `walk_preview.mjs:1690` вызывает `walkPlayerHud.update` из actual frame, внутри controller ограничение 200 мс. В perfqa это часть `healthHud`, не отдельное GPU-время.
- В `walk_hud_controller.mjs` уже оптимизирована повторная нормализация через WeakSet canonical snapshots; обход до 48 портретов уже не создаёт 3 массива клонов. Эти исправления не присваивать новой работе.
- `walk_player_hud.mjs` уже кеширует Intl formatter, переиспользует карточки/портреты и меняет metadata карточек лишь при изменениях. Однако общий `setState` безусловно записывает textContent, title, ARIA, dataset, disabled, hidden и width каждые 200 мс, в том числе при свёрнутом HUD.
- Детерминированный actual-module test `test_walk_player_hud_dom_writes.mjs --report`: 19 боссов + игрок/NPC с одинаковым raw ID7, точная большая сумма денег. Одинаковый новый snapshot вызывает **103 DOM setter calls** и при collapsed=true, и при collapsed=false: textContent15, attribute12, title34, disabled30, dataset5, hidden6, style1. При 5 Гц это 515 вызовов/сек; это число операций, НЕ стоимость в мс и НЕ FPS.

## Предложенная безопасная доработка

Сверять новое значение с текущим DOM перед записью в `walk_player_hud.mjs`. Не кешировать весь snapshot по object identity (источник может мутировать объект), не менять частоту обновления, не пропускать обновления закрытого HUD, не менять внешний вид/портреты/источник состояния/ID/click diagnostics. Строгий вариант нового теста требует ноль DOM writes на повторный snapshot и проверяет немедленное обновление HP/денег/имени/permissions, независимые ID player/NPC, сохранение портрета, unavailable/reconnect.

Координатор подтвердил ownership и разрешил conditional DOM only. Исправлено только `walk_player_hud.mjs`: helper сравнивает текущее значение DOM перед записью; удаление ARIA только при наличии. CSS, callbacks, click diagnostics, cadence и данные не менялись.

После: **0 вместо 103 DOM setter calls** на повторный новый snapshot как в закрытом, так и в открытом HUD. Неизвестное состояние также 0 повторных записей. Речь только об этом `setState`, не обо всех UI игры.

PASS: `test_walk_player_hud_dom_writes.mjs`, `test_walk_player_hud.mjs`, `test_walk_hud_controller.mjs`, `test_walk_hud_status_membership.mjs`. Новый тест дополнительно проверяет изменение того же объекта snapshot in-place и восстановление текущего DOM после внешнего изменения имени/disabled. Все существующие callbacks/portrait identity проверки проходят.

Production ready для следующего согласованного reload. На момент передачи текущая LIVE вкладка загрузила старую версию перед shadow A/B; ради HUD отдельно не reload. Измерение общей сцены до/после остаётся у root и не подменяется подсчётом setter calls.

## Другие наблюдения, без изменений

- `world_walk_hud_data.getWalkHudOpenPanels` вызывается bridge и затем controller при ложном blocked. Повторные DOM queries/geometry reads есть, но controller второй вызов также защищает панели, открывшиеся во время callbacks; не удалять вслепую.
- `walk_hud_shell` уже ограничил MutationObserver верхним body и profileContent. Controller всё ещё вызывает refresh 5 Гц; возможна работа со скрытым inventory. Без actual populated evidence менять observer контракт не стоит.
- `mercenary_command_ui` уже обновляет закрытый UI не чаще ~300 мс для больницы и Follow; это нужные видимые элементы, отключать по closed нельзя. В personal card остаются renderPeople скрытых candidates/getActions и JSON.stringify(currentWeapons) на каждую карточку. Это вторичный target, без замера не главный источник лагов.
- `mercenary_world.getRoster()` создаёт полный roster/candidates/skills/inventory и вызывает adoptCandidates. У UI и других callers есть повторные чтения. Не кешировать по времени: это source contract, а не чистая HUD функция; передать владельцу core/координатору.

**Производительность общей сцены не проверена.** Известный renderer/traffic dominated baseline не позволяет обещать устранение сильных лагов только HUD доработкой. Root контролирует единственную игровую вкладку и LIVE очередь.
